#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "psych"

module ShoppingVisualMatrix
  class ValidationError < StandardError; end

  CANONICAL_RELATIVE_PATH = "worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair/shopping-visual-matrix.yaml"
  TOP_LEVEL_KEYS = %w[schemaVersion expectedRows expectedArtifactsPerKind baseCommand rows].freeze
  ARTIFACT_COUNT_KEYS = %w[png visualCellManifest accessibilityProof screenshotLog].freeze
  ROW_KEYS = %w[id platform variant mode category dynamicType orientation window unitSlug artifactRoot args].freeze
  CELL_KEYS = %w[
    schemaVersion rowID unitSlug artifactRoot argv selectedPlatform pngPath
    accessibilityProofPath screenshotLogPath state size
  ].freeze
  STATE_KEYS = %w[variant mode category].freeze
  SIZE_KEYS = %w[dynamicType orientation window].freeze
  EXPECTED_PLATFORM_COUNTS = { "iphone" => 22, "ipad" => 20, "macos" => 20 }.freeze
  EXPECTED_ARTIFACT_COUNTS = ARTIFACT_COUNT_KEYS.to_h { |key| [key, 62] }.freeze
  ALLOWED = {
    "platform" => %w[iphone ipad macos],
    "variant" => %w[normal empty all-complete pending row-error offline-queued conflict duplicate],
    "mode" => %w[need basket all],
    "category" => ["all", "Produce"],
    "dynamicType" => %w[default accessibility5],
    "orientation" => %w[portrait landscape none],
    "window" => %w[none 834x1194 1194x834 900x620 1440x900]
  }.freeze

  module_function

  def load!(path, repository_root:)
    repository_root = Pathname.new(repository_root).expand_path
    path = Pathname.new(path).expand_path
    expected_path = repository_root.join(CANONICAL_RELATIVE_PATH).expand_path
    fail_validation("manifest must be the exact canonical path #{CANONICAL_RELATIVE_PATH}") unless path == expected_path
    fail_validation("canonical manifest must be a regular file, not a symlink") if path.symlink?
    fail_validation("canonical manifest does not exist") unless path.file?

    document = Psych.safe_load(
      path.binread,
      permitted_classes: [],
      permitted_symbols: [],
      aliases: false
    )
    validate_document!(document)
    document
  rescue Psych::Exception => error
    raise ValidationError, "manifest YAML is unsafe or malformed: #{error.message}"
  end

  def validate_document!(document)
    exact_hash!(document, TOP_LEVEL_KEYS, "manifest")
    fail_validation("schemaVersion must be exactly 1") unless document["schemaVersion"] == 1
    fail_validation("expectedRows must be exactly 62") unless document["expectedRows"] == 62
    fail_validation("baseCommand must be scripts/capture-native-screenshots.sh") unless document["baseCommand"] == "scripts/capture-native-screenshots.sh"
    exact_hash!(document["expectedArtifactsPerKind"], ARTIFACT_COUNT_KEYS, "expectedArtifactsPerKind")
    fail_validation("expectedArtifactsPerKind must be exactly #{EXPECTED_ARTIFACT_COUNTS.inspect}") unless document["expectedArtifactsPerKind"] == EXPECTED_ARTIFACT_COUNTS

    rows = document["rows"]
    fail_validation("rows must be an array") unless rows.is_a?(Array)
    fail_validation("rows must contain exactly 62 entries") unless rows.length == 62
    rows.each_with_index { |row, index| validate_row!(row, index) }

    counts = rows.group_by { |row| row["platform"] }.transform_values(&:length)
    fail_validation("platform row counts must be exactly #{EXPECTED_PLATFORM_COUNTS.inspect}") unless counts == EXPECTED_PLATFORM_COUNTS
    unique_field!(rows, "id")
    unique_field!(rows, "unitSlug")
    unique_field!(rows, "artifactRoot")
    document
  end

  def validate_row!(row, index)
    label = "rows[#{index}]"
    exact_hash!(row, ROW_KEYS, label)
    %w[id unitSlug artifactRoot].each do |key|
      value = row[key]
      fail_validation("#{label}.#{key} must be a non-empty string") unless value.is_a?(String) && !value.empty?
    end
    fail_validation("#{label}.id contains unsafe characters") unless row["id"].match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
    fail_validation("#{label}.unitSlug must be derived from id") unless row["unitSlug"] == "shopping-#{row["id"]}"
    fail_validation("#{label}.artifactRoot must be derived from id") unless row["artifactRoot"] == "visual/#{row["id"]}"

    ALLOWED.each do |key, values|
      fail_validation("#{label}.#{key} has unsupported value #{row[key].inspect}") unless values.include?(row[key])
    end
    validate_platform_shape!(row, label)
    expected_args = recompute_args(row)
    fail_validation("#{label}.args must byte-match recomputed argv") unless row["args"] == expected_args
  end

  def validate_platform_shape!(row, label)
    case row["platform"]
    when "iphone"
      fail_validation("#{label} iPhone orientation must be portrait") unless row["orientation"] == "portrait"
      fail_validation("#{label} iPhone window must be none") unless row["window"] == "none"
    when "ipad"
      expected_window = row["orientation"] == "portrait" ? "834x1194" : "1194x834"
      fail_validation("#{label} iPad orientation must be portrait or landscape") unless %w[portrait landscape].include?(row["orientation"])
      fail_validation("#{label} iPad window must match orientation") unless row["window"] == expected_window
      fail_validation("#{label} iPad dynamic type must be default") unless row["dynamicType"] == "default"
    when "macos"
      fail_validation("#{label} macOS orientation must be none") unless row["orientation"] == "none"
      fail_validation("#{label} macOS window is invalid") unless %w[900x620 1440x900].include?(row["window"])
      fail_validation("#{label} macOS dynamic type must be default") unless row["dynamicType"] == "default"
    end
  end

  def recompute_args(row)
    args = [
      "--capture-platform", row.fetch("platform"),
      "--shopping-variant", row.fetch("variant"),
      "--shopping-mode", row.fetch("mode"),
      "--shopping-category", row.fetch("category"),
      "--dynamic-type", row.fetch("dynamicType")
    ]
    if row.fetch("platform") == "macos"
      args + ["--macos-window", row.fetch("window")]
    else
      args + ["--ios-orientation", row.fetch("orientation")]
    end
  end

  def capture_argv(row, matrix:, artifact_base:)
    root = artifact_root(row, artifact_base: artifact_base)
    [
      matrix.fetch("baseCommand"),
      "--artifact-root", root.to_s,
      "--unit-slug", row.fetch("unitSlug"),
      *recompute_args(row)
    ]
  end

  def artifact_root(row, artifact_base:)
    base = Pathname.new(artifact_base).expand_path.cleanpath
    root = base.join(row.fetch("artifactRoot")).cleanpath
    fail_validation("artifact root escapes artifact base") unless root.to_s.start_with?("#{base}/")
    root
  end

  def validate_resolved_artifact_root!(row, artifact_base:)
    base = Pathname.new(artifact_base).expand_path
    root = artifact_root(row, artifact_base: base)
    fail_validation("artifact base must exist for validation") unless base.directory?
    fail_validation("artifact root must exist for validation") unless root.directory?
    resolved_base = base.realpath
    resolved_root = root.realpath
    fail_validation("artifact root resolves outside artifact base") unless resolved_root.to_s.start_with?("#{resolved_base}/")
    resolved_root
  end

  def cell_contract(row, matrix:, artifact_base:)
    root = artifact_root(row, artifact_base: artifact_base)
    slug = row.fetch("unitSlug")
    suffixes = case row.fetch("platform")
               when "iphone"
                 ["screenshots/ios-mobile.png", "apple/#{slug}-accessibility-proof-ios.json"]
               when "ipad"
                 ["screenshots/ios-tablet.png", "apple/#{slug}-accessibility-proof-ipad.json"]
               when "macos"
                 ["screenshots/macos-desktop.png", "apple/#{slug}-accessibility-proof-macos.json"]
               end
    png_path, proof_path = suffixes.map { |suffix| root.join(suffix).to_s }
    log_path = root.join("apple/#{slug}-screenshots.log").to_s
    manifest = {
      "schemaVersion" => 1,
      "rowID" => row.fetch("id"),
      "unitSlug" => slug,
      "artifactRoot" => root.to_s,
      "argv" => capture_argv(row, matrix: matrix, artifact_base: artifact_base),
      "selectedPlatform" => row.fetch("platform"),
      "pngPath" => png_path,
      "accessibilityProofPath" => proof_path,
      "screenshotLogPath" => log_path,
      "state" => row.slice(*STATE_KEYS),
      "size" => row.slice(*SIZE_KEYS)
    }
    {
      "manifest" => manifest,
      "cellManifestPath" => root.join("shopping-visual-cell.json").to_s,
      "artifactPaths" => {
        "png" => png_path,
        "accessibilityProof" => proof_path,
        "screenshotLog" => log_path
      }
    }
  end

  def validate_cell_manifest!(candidate, expected)
    exact_hash!(candidate, CELL_KEYS, "shopping-visual-cell.json")
    exact_hash!(candidate["state"], STATE_KEYS, "shopping-visual-cell.json.state")
    exact_hash!(candidate["size"], SIZE_KEYS, "shopping-visual-cell.json.size")
    CELL_KEYS.each do |key|
      fail_validation("shopping-visual-cell.json #{key} does not byte-match canonical row") unless candidate[key] == expected[key]
    end
    true
  end

  def exact_hash!(value, expected_keys, label)
    fail_validation("#{label} must be a mapping") unless value.is_a?(Hash)
    fail_validation("#{label} keys must be exactly #{expected_keys.inspect}") unless value.keys.sort == expected_keys.sort
  end

  def unique_field!(rows, field)
    values = rows.map { |row| row.fetch(field) }
    fail_validation("row #{field} values must be unique") unless values.uniq.length == values.length
  end

  def fail_validation(message)
    raise ValidationError, message
  end
end
