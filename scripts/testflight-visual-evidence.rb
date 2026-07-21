#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "find"
require "json"
require "optparse"
require "pathname"

module TestFlightVisualEvidence
  class Error < StandardError; end

  SCHEMA_VERSION = 1
  SHA_PATTERN = /\A[0-9a-f]{40}\z/.freeze
  DIGEST_PATTERN = /\A[0-9a-f]{64}\z/.freeze
  JOB_PATTERN = /\A[a-z0-9][a-z0-9-]*\z/.freeze
  EXPECTED_ROUTES = %w[
    kitchen recipes saved-recipes recipe-detail recipe-editor recipe-covers cook-mode cook-log
    cookbooks cookbook-detail shopping-list shopping-list-empty shopping-list-all-complete
    shopping-list-duplicate shopping-list-conflict shopping-list-offline-queued chefs profile
    profile-graph search search-typed-results search-scoped-recipes search-scoped-cookbooks
    search-scoped-chefs search-scoped-shopping search-no-results capture capture-empty capture-draft
    capture-offline-retry capture-provider-blocked capture-signed-out settings settings-notifications
    settings-signed-out settings-apns-denied settings-apns-not-determined settings-apns-authorized
    settings-apns-unregistered unknown-link
  ].freeze
  SETTINGS_ROUTE_VARIANTS = %w[
    settings-notifications settings-signed-out settings-apns-denied settings-apns-not-determined
    settings-apns-authorized settings-apns-unregistered
  ].freeze
  EXPECTED_ROUTE_BY_NAME = EXPECTED_ROUTES.each_with_object({}) do |name, routes|
    routes[name] = SETTINGS_ROUTE_VARIANTS.include?(name) ? "settings" : name
  end.freeze
  SCREENSHOTS = {
    "iosMobile" => ["iosScreenshot", "screenshots/ios-mobile.png"],
    "iosAccessibility" => ["iosAccessibilityScreenshot", "screenshots/ios-mobile-accessibility.png"],
    "iosTablet" => ["iosTabletScreenshot", "screenshots/ios-tablet.png"],
    "macosDesktop" => ["macosScreenshot", "screenshots/macos-desktop.png"]
  }.freeze
  REQUIRED_PROOF_ARRAYS = {
    "accessibilityProofArtifacts" => 3,
    "observedAccessibilityEvidenceArtifacts" => 4
  }.freeze
  OPTIONAL_PROOF_ARRAYS = %w[settingsSurfaceProofArtifacts searchSurfaceProofArtifacts].freeze
  MATRIX_EMPTY_ARRAYS = %w[
    failedRoutes blockedRoutes missingDesignReviewRoutes missingScreenshotRoutes missingRoutes
    duplicateRoutes unexpectedRoutes
  ].freeze

  module_function

  def parse_json(path, label)
    JSON.parse(path.read)
  rescue JSON::ParserError => error
    raise Error, "#{label} is invalid JSON: #{error.message}"
  end

  def positive_integer(value, label)
    parsed = Integer(value, 10)
    raise Error, "#{label} must be positive" unless parsed.positive?

    parsed
  rescue ArgumentError, TypeError
    raise Error, "#{label} must be a positive integer"
  end

  def validate_identity!(identity)
    raise Error, "source SHA must be exactly 40 lowercase hexadecimal characters" unless identity.fetch("sourceSha").match?(SHA_PATTERN)
    raise Error, "source tree must be exactly 40 lowercase hexadecimal characters" unless identity.fetch("sourceTree").match?(SHA_PATTERN)
    raise Error, "workflow run ID must be positive" unless identity.fetch("workflowRunId").is_a?(Integer) && identity.fetch("workflowRunId").positive?
    unless identity.fetch("workflowRunAttempt").is_a?(Integer) && identity.fetch("workflowRunAttempt").positive?
      raise Error, "workflow run attempt must be positive"
    end
    raise Error, "workflow job must be a lowercase job key" unless identity.fetch("workflowJob").match?(JOB_PATTERN)
  rescue KeyError => error
    raise Error, "identity is missing #{error.key}"
  end

  def safe_relative_path(value, label)
    raise Error, "#{label} must be a non-empty string" unless value.is_a?(String) && !value.empty?
    raise Error, "#{label} contains a null byte" if value.include?("\0")
    path = Pathname.new(value)
    parts = path.each_filename.to_a
    if path.absolute? || parts.empty? || parts.any? { |part| part == "." || part == ".." } || value.include?("\\")
      raise Error, "#{label} is an unsafe relative path: #{value.inspect}"
    end
    cleaned = path.cleanpath.to_s
    raise Error, "#{label} is an unsafe relative path: #{value.inspect}" unless cleaned == value

    cleaned
  end

  def source_path(root, reference, label)
    raise Error, "#{label} must be a non-empty string" unless reference.is_a?(String) && !reference.empty?
    raise Error, "#{label} contains a null byte" if reference.include?("\0")
    candidate = Pathname.new(reference)
    candidate = root.join(candidate) unless candidate.absolute?
    candidate = candidate.cleanpath.expand_path
    root_prefix = "#{root}#{File::SEPARATOR}"
    unless candidate.to_s.start_with?(root_prefix)
      raise Error, "#{label} is an unsafe relative path outside the matrix root: #{reference.inspect}"
    end
    reject_symlink_components!(root, candidate, label)
    raise Error, "#{label} is missing: #{reference}" unless candidate.file?
    raise Error, "#{label} is empty: #{reference}" unless candidate.size.positive?

    candidate
  end

  def reject_symlink_components!(root, candidate, label)
    relative = candidate.relative_path_from(root)
    current = root
    relative.each_filename do |component|
      current = current.join(component)
      next unless current.exist? || current.symlink?
      raise Error, "#{label} resolves through a symlink: #{current}" if current.symlink?
    end
  rescue ArgumentError
    raise Error, "#{label} escapes the matrix root"
  end

  def artifact_entry(path, portable_path)
    {
      "path" => portable_path,
      "bytes" => path.size,
      "sha256" => Digest::SHA256.file(path).hexdigest
    }
  end

  def validate_recorded_artifact!(record, path, label)
    raise Error, "#{label} must be an object" unless record.is_a?(Hash)
    raise Error, "#{label} must exist" unless record["exists"] == true
    raise Error, "#{label} byte count mismatch" unless record["bytes"] == path.size
    digest = Digest::SHA256.file(path).hexdigest
    raise Error, "#{label} SHA-256 mismatch" unless record["sha256"] == digest
  end

  def png?(path)
    path.binread(8) == "\x89PNG\r\n\x1A\n".b
  end

  def contains_blocked_true?(value)
    case value
    when Hash
      value["blocked"] == true || value.values.any? { |child| contains_blocked_true?(child) }
    when Array
      value.any? { |child| contains_blocked_true?(child) }
    else
      false
    end
  end

  class Sealer
    def initialize(artifact_root:, matrix_manifest:, output_dir:, identity:)
      @artifact_root = Pathname.new(artifact_root).expand_path
      @matrix_manifest = Pathname.new(matrix_manifest).expand_path
      @output_dir = Pathname.new(output_dir).expand_path
      @identity = identity
      @selected = {}
    end

    def seal
      TestFlightVisualEvidence.validate_identity!(@identity)
      raise Error, "matrix artifact root is missing" unless @artifact_root.directory?
      raise Error, "output directory must not be the matrix artifact root" if @output_dir == @artifact_root
      TestFlightVisualEvidence.reject_symlink_components!(@artifact_root, @matrix_manifest, "matrix manifest")
      reject_blocker_residue!

      matrix = TestFlightVisualEvidence.parse_json(@matrix_manifest, "route matrix manifest")
      validate_matrix!(matrix)
      matrix_relative = relative_source_path(@matrix_manifest, "matrix manifest")
      add_selected(@matrix_manifest, matrix_relative)

      routes = matrix.fetch("routes").map { |row| seal_route(row) }

      results_path = @matrix_manifest.sub_ext(".jsonl")
      results = TestFlightVisualEvidence.source_path(@artifact_root, results_path.to_s, "route matrix JSONL")
      validate_jsonl!(results, matrix.fetch("routes"))
      results_relative = relative_source_path(results, "route matrix JSONL")
      add_selected(results, results_relative)

      provenance = TestFlightVisualEvidence.source_path(
        @artifact_root,
        matrix.fetch("provenanceManifestPath"),
        "screenshot provenance manifest"
      )
      validate_provenance!(provenance, matrix)
      provenance_relative = relative_source_path(provenance, "screenshot provenance manifest")
      add_selected(provenance, provenance_relative)

      write_artifact(routes, matrix_relative, results_relative, provenance_relative)
    end

    private

    def reject_blocker_residue!
      blocker_paths = []
      Find.find(@artifact_root.to_s) do |path_string|
        path = Pathname.new(path_string)
        next if path == @artifact_root
        if path.basename.to_s.downcase.include?("blocker") && (path.file? || path.symlink?)
          blocker_paths << path.relative_path_from(@artifact_root).to_s
        end
      end
      return if blocker_paths.empty?

      raise Error, "blocker residue is present in visual evidence: #{blocker_paths.sort.join(", ")}"
    end

    def validate_matrix!(matrix)
      raise Error, "route matrix manifest must be an object" unless matrix.is_a?(Hash)
      unless matrix["ok"] == true && matrix["fullyValidated"] == true && matrix["completeRouteSet"] == true
        raise Error, "full route matrix was not validated"
      end
      unless matrix["buildBlocked"] == false && matrix["buildBlocker"].nil?
        raise Error, "full route matrix contains a build blocker"
      end
      unless matrix["provenanceVerifiedBefore"] == true && matrix["provenanceVerifiedAfter"] == true
        raise Error, "full route matrix lacks before-and-after provenance verification"
      end
      unless matrix["sourceSha"] == @identity.fetch("sourceSha") && matrix["sourceTree"] == @identity.fetch("sourceTree")
        raise Error, "route matrix source identity does not match the workflow identity"
      end
      unless matrix["expectedRoutes"] == EXPECTED_ROUTES && matrix["selectedRoutes"] == EXPECTED_ROUTES &&
             matrix["routeCount"] == EXPECTED_ROUTES.length && matrix["expectedRouteCount"] == EXPECTED_ROUTES.length
        raise Error, "full route matrix does not contain the canonical #{EXPECTED_ROUTES.length}-route set"
      end
      MATRIX_EMPTY_ARRAYS.each do |key|
        raise Error, "full route matrix #{key} must be empty" unless matrix[key] == []
      end
      routes = matrix["routes"]
      unless routes.is_a?(Array) && routes.map { |row| row.is_a?(Hash) ? row["name"] : nil } == EXPECTED_ROUTES
        raise Error, "full route matrix rows do not match the canonical route order"
      end
      routes.each do |row|
        unless row["route"] == EXPECTED_ROUTE_BY_NAME.fetch(row["name"])
          raise Error, "route #{row["name"].inspect} does not use its canonical capture route"
        end
        unless row["status"] == "pass" && row["blocked"] == false && row["missingDesignReview"] == false
          raise Error, "route #{row["name"].inspect} is not a terminal passing visual route"
        end
      end
    end

    def validate_jsonl!(path, expected_rows)
      rows = path.each_line.map.with_index do |line, index|
        JSON.parse(line)
      rescue JSON::ParserError => error
        raise Error, "route matrix JSONL line #{index + 1} is invalid: #{error.message}"
      end
      raise Error, "route matrix JSONL differs from the summary rows" unless rows == expected_rows
    end

    def validate_provenance!(path, matrix)
      provenance = TestFlightVisualEvidence.parse_json(path, "screenshot provenance manifest")
      unless provenance.dig("source", "sha") == @identity.fetch("sourceSha") &&
             provenance.dig("source", "tree") == @identity.fetch("sourceTree")
        raise Error, "screenshot provenance source identity mismatch"
      end
      unless provenance["manifestSha256"] == matrix["provenanceManifestSha256"] &&
             provenance["manifestSha256"].is_a?(String) && provenance["manifestSha256"].match?(DIGEST_PATTERN)
        raise Error, "screenshot provenance manifest digest mismatch"
      end
    end

    def seal_route(row)
      name = row.fetch("name")
      route_root = Pathname.new(row.fetch("artifactRoot")).expand_path
      unless route_root == @artifact_root || route_root.to_s.start_with?("#{@artifact_root}#{File::SEPARATOR}")
        raise Error, "route #{name} artifact root escapes the matrix root"
      end

      design_path = TestFlightVisualEvidence.source_path(
        @artifact_root,
        row.fetch("designReview").fetch("path"),
        "route #{name} design review"
      )
      TestFlightVisualEvidence.validate_recorded_artifact!(row.fetch("designReview"), design_path, "route #{name} design review")
      design = TestFlightVisualEvidence.parse_json(design_path, "route #{name} design review")
      raise Error, "route #{name} design review contains a blocker" if TestFlightVisualEvidence.contains_blocked_true?(design)
      raise Error, "route #{name} design review blockers must be empty" unless design["blockers"] == []
      raise Error, "route #{name} design review route mismatch" unless design["screenshotRoute"] == row["route"]

      design_portable = add_selected(design_path, relative_source_path(design_path, "route #{name} design review"))
      screenshots = {}
      SCREENSHOTS.each do |key, (row_key, expected_relative)|
        review_record = design.fetch("screenshotArtifacts").fetch(key)
        unless review_record.is_a?(Hash) && review_record["path"] == expected_relative
          raise Error, "route #{name} screenshot #{key} path mismatch"
        end
        screenshot_path = relative_route_file(route_root, expected_relative, "route #{name} screenshot #{key}")
        TestFlightVisualEvidence.validate_recorded_artifact!(row.fetch(row_key), screenshot_path, "route #{name} #{row_key}")
        unless review_record["bytes"] == screenshot_path.size && review_record["sha256"] == Digest::SHA256.file(screenshot_path).hexdigest
          raise Error, "route #{name} screenshot #{key} design-review hash mismatch"
        end
        raise Error, "route #{name} screenshot #{key} is not a PNG" unless TestFlightVisualEvidence.png?(screenshot_path)
        screenshots[key] = add_selected(
          screenshot_path,
          relative_source_path(screenshot_path, "route #{name} screenshot #{key}")
        )
      end

      proofs = []
      REQUIRED_PROOF_ARRAYS.each do |key, expected_count|
        values = design[key]
        unless values.is_a?(Array) && values.length == expected_count
          raise Error, "route #{name} #{key} must contain #{expected_count} proofs"
        end
        proofs.concat(seal_proofs(name, route_root, key, values))
      end
      OPTIONAL_PROOF_ARRAYS.each do |key|
        next unless design.key?(key)
        values = design[key]
        raise Error, "route #{name} #{key} must be a non-empty proof array" unless values.is_a?(Array) && !values.empty?
        proofs.concat(seal_proofs(name, route_root, key, values))
      end

      {
        "name" => name,
        "route" => row.fetch("route"),
        "designReview" => design_portable,
        "screenshots" => screenshots,
        "proofs" => proofs.sort
      }
    rescue KeyError => error
      raise Error, "route #{name || "unknown"} evidence is missing #{error.key}"
    end

    def seal_proofs(route_name, route_root, key, values)
      values.map.with_index do |relative, index|
        safe = TestFlightVisualEvidence.safe_relative_path(relative, "route #{route_name} #{key}[#{index}]")
        path = relative_route_file(route_root, safe, "route #{route_name} #{key}[#{index}]")
        proof = TestFlightVisualEvidence.parse_json(path, "route #{route_name} #{key}[#{index}]")
        raise Error, "route #{route_name} proof #{safe} contains a blocker" if TestFlightVisualEvidence.contains_blocked_true?(proof)
        add_selected(path, relative_source_path(path, "route #{route_name} proof #{safe}"))
      end
    end

    def relative_route_file(route_root, relative, label)
      safe = TestFlightVisualEvidence.safe_relative_path(relative, label)
      TestFlightVisualEvidence.source_path(@artifact_root, route_root.join(safe).to_s, label)
    end

    def relative_source_path(path, label)
      path.expand_path.relative_path_from(@artifact_root).to_s.then do |relative|
        TestFlightVisualEvidence.safe_relative_path(relative, label)
      end
    rescue ArgumentError
      raise Error, "#{label} escapes the matrix artifact root"
    end

    def add_selected(path, relative)
      portable = "payload/#{relative}"
      existing = @selected[portable]
      if existing && existing != path
        raise Error, "portable evidence path collision: #{portable}"
      end
      @selected[portable] = path
      portable
    end

    def write_artifact(routes, matrix_relative, results_relative, provenance_relative)
      if @output_dir.to_s == File::SEPARATOR || @output_dir.to_s.empty?
        raise Error, "refusing unsafe visual artifact output directory"
      end
      FileUtils.rm_rf(@output_dir)
      @output_dir.mkpath
      @selected.sort.each do |portable, source|
        destination = @output_dir.join(portable)
        destination.dirname.mkpath
        FileUtils.copy_file(source, destination)
      end

      files = @selected.keys.sort.map do |portable|
        TestFlightVisualEvidence.artifact_entry(@output_dir.join(portable), portable)
      end
      manifest = {
        "schemaVersion" => SCHEMA_VERSION,
        "identity" => @identity,
        "matrix" => {
          "summary" => "payload/#{matrix_relative}",
          "results" => "payload/#{results_relative}",
          "provenance" => "payload/#{provenance_relative}",
          "expectedRouteCount" => EXPECTED_ROUTES.length,
          "routes" => routes
        },
        "files" => files
      }
      manifest_path = @output_dir.join("visual-evidence-manifest.json")
      manifest_path.write(JSON.pretty_generate(manifest) + "\n")
      digest = Digest::SHA256.file(manifest_path).hexdigest
      { "artifactDir" => @output_dir.to_s, "manifestPath" => manifest_path.to_s, "manifestSha256" => digest }
    end
  end

  class Verifier
    def initialize(artifact_dir:, expected_identity:, expected_manifest_sha256: nil)
      @artifact_dir = Pathname.new(artifact_dir).expand_path
      @expected_identity = expected_identity
      @expected_manifest_sha256 = expected_manifest_sha256
    end

    def verify
      TestFlightVisualEvidence.validate_identity!(@expected_identity)
      raise Error, "visual evidence artifact directory is missing" unless @artifact_dir.directory?
      reject_any_symlink!
      manifest_path = @artifact_dir.join("visual-evidence-manifest.json")
      raise Error, "visual evidence manifest is missing" unless manifest_path.file?
      manifest_digest = Digest::SHA256.file(manifest_path).hexdigest
      if @expected_manifest_sha256 && manifest_digest != @expected_manifest_sha256
        raise Error, "visual evidence manifest SHA-256 mismatch"
      end
      manifest = TestFlightVisualEvidence.parse_json(manifest_path, "visual evidence manifest")
      raise Error, "visual evidence schema version is unsupported" unless manifest["schemaVersion"] == SCHEMA_VERSION
      validate_identity_match!(manifest.fetch("identity"))
      files = validate_files!(manifest.fetch("files"))
      validate_matrix!(manifest.fetch("matrix"), files)
      { "manifestPath" => manifest_path.to_s, "manifestSha256" => manifest_digest, "fileCount" => files.length }
    rescue KeyError => error
      raise Error, "visual evidence manifest is missing #{error.key}"
    end

    private

    def reject_any_symlink!
      symlinks = []
      Find.find(@artifact_dir.to_s) do |path|
        pathname = Pathname.new(path)
        symlinks << pathname.relative_path_from(@artifact_dir).to_s if pathname.symlink?
      end
      raise Error, "visual evidence artifact contains symlink(s): #{symlinks.sort.join(", ")}" unless symlinks.empty?
    end

    def validate_identity_match!(actual)
      TestFlightVisualEvidence.validate_identity!(actual)
      labels = {
        "sourceSha" => "source SHA",
        "sourceTree" => "source tree",
        "workflowRunId" => "workflow run ID",
        "workflowRunAttempt" => "workflow run attempt",
        "workflowJob" => "workflow job"
      }
      labels.each do |key, label|
        raise Error, "visual evidence #{label} mismatch" unless actual[key] == @expected_identity[key]
      end
    end

    def validate_files!(entries)
      raise Error, "visual evidence files must be a non-empty array" unless entries.is_a?(Array) && !entries.empty?
      indexed = {}
      entries.each_with_index do |entry, index|
        raise Error, "visual evidence file #{index} must be an object" unless entry.is_a?(Hash)
        relative = TestFlightVisualEvidence.safe_relative_path(entry["path"], "visual evidence file #{index}")
        raise Error, "visual evidence file must be under payload/: #{relative}" unless relative.start_with?("payload/")
        raise Error, "duplicate visual evidence path #{relative}" if indexed.key?(relative)
        path = @artifact_dir.join(relative)
        TestFlightVisualEvidence.reject_symlink_components!(@artifact_dir, path, "visual evidence file #{relative}")
        raise Error, "visual evidence file is missing: #{relative}" unless path.file?
        raise Error, "visual evidence file is empty: #{relative}" unless path.size.positive?
        digest = Digest::SHA256.file(path).hexdigest
        raise Error, "visual evidence file #{relative} SHA-256 mismatch" unless entry["sha256"] == digest
        raise Error, "visual evidence file #{relative} byte count mismatch" unless entry["bytes"] == path.size
        indexed[relative] = entry
      end

      actual = []
      Find.find(@artifact_dir.to_s) do |path|
        pathname = Pathname.new(path)
        actual << pathname.relative_path_from(@artifact_dir).to_s if pathname.file?
      end
      expected = ["visual-evidence-manifest.json"] + indexed.keys
      extras = actual.sort - expected.sort
      missing = expected.sort - actual.sort
      raise Error, "unallowlisted artifact path(s): #{extras.join(", ")}" unless extras.empty?
      raise Error, "allowlisted artifact path(s) missing: #{missing.join(", ")}" unless missing.empty?
      indexed
    end

    def validate_matrix!(matrix, files)
      unless matrix.is_a?(Hash) && matrix["expectedRouteCount"] == EXPECTED_ROUTES.length
        raise Error, "visual evidence matrix route count mismatch"
      end
      routes = matrix["routes"]
      unless routes.is_a?(Array) && routes.map { |route| route.is_a?(Hash) ? route["name"] : nil } == EXPECTED_ROUTES
        raise Error, "visual evidence does not contain the full route matrix"
      end
      referenced = {}
      summary_path = require_file_reference!(matrix["summary"], files, "matrix summary", referenced)
      summary = TestFlightVisualEvidence.parse_json(summary_path, "sealed route matrix summary")
      if TestFlightVisualEvidence.contains_blocked_true?(summary) || summary["buildBlocked"] != false || !summary["buildBlocker"].nil?
        raise Error, "sealed route matrix summary contains a blocker"
      end
      unless summary["ok"] == true && summary["fullyValidated"] == true && summary["completeRouteSet"] == true &&
             summary["expectedRoutes"] == EXPECTED_ROUTES && summary["selectedRoutes"] == EXPECTED_ROUTES &&
             summary["routeCount"] == EXPECTED_ROUTES.length && summary["expectedRouteCount"] == EXPECTED_ROUTES.length &&
             summary["provenanceVerifiedBefore"] == true && summary["provenanceVerifiedAfter"] == true &&
             summary["sourceSha"] == @expected_identity.fetch("sourceSha") &&
             summary["sourceTree"] == @expected_identity.fetch("sourceTree")
        raise Error, "sealed route matrix summary is not a complete exact-source matrix"
      end
      MATRIX_EMPTY_ARRAYS.each do |key|
        raise Error, "sealed route matrix summary #{key} must be empty" unless summary[key] == []
      end

      results_path = require_file_reference!(matrix["results"], files, "matrix results", referenced)
      result_rows = results_path.each_line.map.with_index do |line, index|
        JSON.parse(line)
      rescue JSON::ParserError => error
        raise Error, "sealed matrix results line #{index + 1} is invalid JSON: #{error.message}"
      end
      unless result_rows == summary["routes"] && result_rows.map { |row| row["name"] } == EXPECTED_ROUTES
        raise Error, "sealed matrix results differ from the summary"
      end
      result_rows.each do |row|
        unless row["route"] == EXPECTED_ROUTE_BY_NAME.fetch(row["name"])
          raise Error, "sealed matrix route #{row["name"].inspect} does not use its canonical capture route"
        end
        unless row["status"] == "pass" && row["blocked"] == false && row["missingDesignReview"] == false
          raise Error, "sealed matrix route #{row["name"].inspect} is not passing"
        end
      end

      provenance_path = require_file_reference!(matrix["provenance"], files, "matrix provenance", referenced)
      provenance = TestFlightVisualEvidence.parse_json(provenance_path, "sealed screenshot provenance")
      unless provenance.dig("source", "sha") == @expected_identity.fetch("sourceSha") &&
             provenance.dig("source", "tree") == @expected_identity.fetch("sourceTree") &&
             provenance["manifestSha256"] == summary["provenanceManifestSha256"]
        raise Error, "sealed screenshot provenance identity mismatch"
      end

      routes.each do |route|
        route_name = route["name"]
        unless route["route"] == EXPECTED_ROUTE_BY_NAME.fetch(route_name)
          raise Error, "route #{route_name.inspect} does not use its canonical capture route"
        end
        design_reference = route["designReview"]
        design_path = require_file_reference!(design_reference, files, "route #{route_name} design review", referenced)
        design = TestFlightVisualEvidence.parse_json(design_path, "route #{route_name} design review")
        if TestFlightVisualEvidence.contains_blocked_true?(design)
          raise Error, "route #{route_name} design review contains a blocker"
        end
        raise Error, "route #{route_name} design review blockers must be empty" unless design["blockers"] == []
        raise Error, "route #{route_name} design review route mismatch" unless design["screenshotRoute"] == route["route"]
        screenshots = route["screenshots"]
        unless screenshots.is_a?(Hash) && screenshots.keys.sort == SCREENSHOTS.keys.sort
          raise Error, "route #{route_name} screenshot set is incomplete"
        end
        review_screenshots = design["screenshotArtifacts"]
        unless review_screenshots.is_a?(Hash) && review_screenshots.keys.sort == SCREENSHOTS.keys.sort
          raise Error, "route #{route_name} design-review screenshot set is incomplete"
        end
        screenshots.each do |key, reference|
          path = require_file_reference!(reference, files, "route #{route_name} screenshot #{key}", referenced)
          raise Error, "route #{route_name} screenshot #{key} is not a PNG" unless TestFlightVisualEvidence.png?(path)
          review_record = review_screenshots[key]
          unless review_record.is_a?(Hash)
            raise Error, "route #{route_name} design-review screenshot #{key} must be an object"
          end
          expected_reference = portable_from_design_relative(
            design_reference,
            review_record["path"],
            "route #{route_name} design-review screenshot #{key}"
          )
          unless expected_reference == reference && review_record["bytes"] == path.size &&
                 review_record["sha256"] == Digest::SHA256.file(path).hexdigest
            raise Error, "route #{route_name} design-review screenshot #{key} evidence mismatch"
          end
        end
        proofs = route["proofs"]
        raise Error, "route #{route_name} proof set is incomplete" unless proofs.is_a?(Array) && proofs.length >= 7
        proofs.each do |reference|
          path = require_file_reference!(reference, files, "route #{route_name} proof", referenced)
          proof = TestFlightVisualEvidence.parse_json(path, "route #{route_name} proof")
          raise Error, "route #{route_name} proof contains a blocker" if TestFlightVisualEvidence.contains_blocked_true?(proof)
        end
        expected_proofs = []
        REQUIRED_PROOF_ARRAYS.each do |key, expected_count|
          values = design[key]
          unless values.is_a?(Array) && values.length == expected_count
            raise Error, "route #{route_name} #{key} must contain #{expected_count} proofs"
          end
          expected_proofs.concat(values.map do |value|
            portable_from_design_relative(design_reference, value, "route #{route_name} #{key}")
          end)
        end
        OPTIONAL_PROOF_ARRAYS.each do |key|
          next unless design.key?(key)
          values = design[key]
          raise Error, "route #{route_name} #{key} must be a non-empty proof array" unless values.is_a?(Array) && !values.empty?
          expected_proofs.concat(values.map do |value|
            portable_from_design_relative(design_reference, value, "route #{route_name} #{key}")
          end)
        end
        raise Error, "route #{route_name} proof references differ from its design review" unless proofs.sort == expected_proofs.sort
      end

      extras = files.keys.sort - referenced.keys.sort
      raise Error, "unreferenced allowlisted artifact path(s): #{extras.join(", ")}" unless extras.empty?
    end

    def portable_from_design_relative(design_reference, relative, label)
      safe = TestFlightVisualEvidence.safe_relative_path(relative, label)
      joined = Pathname.new(design_reference).dirname.join(safe).cleanpath.to_s
      TestFlightVisualEvidence.safe_relative_path(joined, label)
    end

    def require_file_reference!(reference, files, label, referenced = nil)
      safe = TestFlightVisualEvidence.safe_relative_path(reference, label)
      raise Error, "#{label} is not allowlisted: #{safe}" unless files.key?(safe)
      referenced[safe] = true if referenced
      @artifact_dir.join(safe)
    end
  end

  def write_github_outputs(path, values)
    return if path.nil? || path.empty?
    File.open(path, "a") do |file|
      values.each do |key, value|
        string = value.to_s
        raise Error, "GitHub output #{key} contains a newline" if string.include?("\n") || string.include?("\r")
        file.puts("#{key}=#{string}")
      end
    end
  end

  def cli(arguments)
    command = arguments.shift
    raise Error, "usage: testflight-visual-evidence.rb <seal|verify> [options]" unless %w[seal verify].include?(command)
    options = {}
    OptionParser.new do |parser|
      parser.on("--artifact-root PATH") { |value| options[:artifact_root] = value }
      parser.on("--matrix-manifest PATH") { |value| options[:matrix_manifest] = value }
      parser.on("--output-dir PATH") { |value| options[:output_dir] = value }
      parser.on("--artifact-dir PATH") { |value| options[:artifact_dir] = value }
      parser.on("--source-sha SHA") { |value| options[:source_sha] = value }
      parser.on("--source-tree TREE") { |value| options[:source_tree] = value }
      parser.on("--workflow-run-id ID") { |value| options[:workflow_run_id] = value }
      parser.on("--workflow-run-attempt ATTEMPT") { |value| options[:workflow_run_attempt] = value }
      parser.on("--workflow-job JOB") { |value| options[:workflow_job] = value }
      parser.on("--manifest-sha256 DIGEST") { |value| options[:manifest_sha256] = value }
      parser.on("--github-output PATH") { |value| options[:github_output] = value }
    end.parse!(arguments)

    identity = {
      "sourceSha" => options.fetch(:source_sha),
      "sourceTree" => options.fetch(:source_tree),
      "workflowRunId" => positive_integer(options.fetch(:workflow_run_id), "workflow run ID"),
      "workflowRunAttempt" => positive_integer(options.fetch(:workflow_run_attempt), "workflow run attempt"),
      "workflowJob" => options.fetch(:workflow_job)
    }
    result = if command == "seal"
               Sealer.new(
                 artifact_root: options.fetch(:artifact_root),
                 matrix_manifest: options.fetch(:matrix_manifest),
                 output_dir: options.fetch(:output_dir),
                 identity: identity
               ).seal
             else
               expected_digest = options[:manifest_sha256]
               if expected_digest && !expected_digest.match?(DIGEST_PATTERN)
                 raise Error, "manifest SHA-256 must be 64 lowercase hexadecimal characters"
               end
               Verifier.new(
                 artifact_dir: options.fetch(:artifact_dir),
                 expected_identity: identity,
                 expected_manifest_sha256: expected_digest
               ).verify
             end
    write_github_outputs(
      options[:github_output],
      "manifest-digest" => result.fetch("manifestSha256"),
      "manifest-path" => result.fetch("manifestPath")
    )
    puts JSON.generate(result)
    0
  rescue KeyError => error
    raise Error, "missing --#{error.key.to_s.tr("_", "-")}"
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    exit TestFlightVisualEvidence.cli(ARGV.dup)
  rescue TestFlightVisualEvidence::Error, OptionParser::ParseError, Errno::ENOENT => error
    warn "testflight-visual-evidence failed: #{error.message}"
    exit 1
  end
end
