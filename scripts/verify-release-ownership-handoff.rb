#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "pathname"
require "time"
require "uri"

class HandoffVerificationError < StandardError; end
class DuplicateJSONKeyError < StandardError; end

class JSONDuplicateKeyScanner
  WHITESPACE = [0x20, 0x09, 0x0A, 0x0D].freeze

  def initialize(content)
    @content = content.b
    @index = 0
  end

  def scan!
    skip_whitespace
    scan_value
    skip_whitespace
    syntax_error("trailing content") unless eof?
  end

  private

  def scan_value
    case current_byte
    when 0x7B then scan_object
    when 0x5B then scan_array
    when 0x22 then scan_string
    else scan_scalar
    end
  end

  def scan_object
    advance
    skip_whitespace
    return advance if current_byte == 0x7D

    keys = {}
    loop do
      syntax_error("object key must be a string") unless current_byte == 0x22
      token = scan_string
      key = JSON.parse(token.dup.force_encoding(Encoding::UTF_8))
      raise DuplicateJSONKeyError, "duplicate JSON key #{key}" if keys.key?(key)

      keys[key] = true
      skip_whitespace
      syntax_error("missing colon after object key") unless current_byte == 0x3A
      advance
      skip_whitespace
      scan_value
      skip_whitespace
      return advance if current_byte == 0x7D

      syntax_error("missing comma between object members") unless current_byte == 0x2C
      advance
      skip_whitespace
    end
  end

  def scan_array
    advance
    skip_whitespace
    return advance if current_byte == 0x5D

    loop do
      scan_value
      skip_whitespace
      return advance if current_byte == 0x5D

      syntax_error("missing comma between array items") unless current_byte == 0x2C
      advance
      skip_whitespace
    end
  end

  def scan_string
    start = @index
    advance
    escaped = false
    until eof?
      byte = current_byte
      advance
      if escaped
        escaped = false
      elsif byte == 0x5C
        escaped = true
      elsif byte == 0x22
        return @content.byteslice(start...@index)
      end
    end
    syntax_error("unterminated string")
  end

  def scan_scalar
    start = @index
    advance until eof? || WHITESPACE.include?(current_byte) || [0x2C, 0x5D, 0x7D].include?(current_byte)
    syntax_error("missing JSON value") if start == @index
  end

  def skip_whitespace
    advance while !eof? && WHITESPACE.include?(current_byte)
  end

  def current_byte
    @content.getbyte(@index)
  end

  def advance
    @index += 1
  end

  def eof?
    @index >= @content.bytesize
  end

  def syntax_error(message)
    raise JSON::ParserError, "#{message} at byte #{@index}"
  end
end

class DuplicateKeyHash < Hash
  def []=(key, value)
    raise DuplicateJSONKeyError, "duplicate JSON key #{key}" if key?(key)

    super
  end
end

module StrictJSON
  module_function

  def parse(content, label:)
    JSONDuplicateKeyScanner.new(content).scan!
    JSON.parse(content, object_class: DuplicateKeyHash, array_class: Array)
  rescue JSON::ParserError, DuplicateJSONKeyError => error
    raise HandoffVerificationError, "#{label} is not strict JSON: #{error.message}"
  end

  def read(path, label:)
    content = File.binread(path)
    [parse(content, label: label), content]
  rescue Errno::ENOENT
    raise HandoffVerificationError, "#{label} is missing: #{path}"
  end
end

class StrictJSONSchema
  TYPE_CHECKS = {
    "object" => ->(value) { value.is_a?(Hash) },
    "array" => ->(value) { value.is_a?(Array) },
    "string" => ->(value) { value.is_a?(String) },
    "integer" => ->(value) { value.is_a?(Integer) },
    "number" => ->(value) { value.is_a?(Numeric) },
    "boolean" => ->(value) { value == true || value == false },
    "null" => ->(value) { value.nil? }
  }.freeze

  def initialize
    @documents = {}
  end

  def validate!(instance, schema_path, label:)
    path = Pathname.new(schema_path).expand_path
    schema = load_schema(path)
    errors = []
    validate_node(instance, schema, schema, path, "$", errors)
    return if errors.empty?

    raise HandoffVerificationError, "#{label} does not match #{path.basename}: #{errors.first}"
  end

  private

  def load_schema(path)
    @documents[path.to_s] ||= StrictJSON.read(path, label: "schema #{path}").first
  end

  def validate_node(instance, schema, root_schema, schema_path, instance_path, errors)
    if schema.key?("$ref")
      referenced, referenced_root, referenced_path = resolve_reference(
        schema.fetch("$ref"),
        root_schema,
        schema_path
      )
      validate_node(instance, referenced, referenced_root, referenced_path, instance_path, errors)
      return
    end

    validate_type(instance, schema, instance_path, errors)
    validate_const_and_enum(instance, schema, instance_path, errors)
    validate_object(instance, schema, root_schema, schema_path, instance_path, errors) if instance.is_a?(Hash)
    validate_array(instance, schema, root_schema, schema_path, instance_path, errors) if instance.is_a?(Array)
    validate_string(instance, schema, instance_path, errors) if instance.is_a?(String)
  end

  def validate_type(instance, schema, instance_path, errors)
    return unless schema.key?("type")

    expected = schema.fetch("type")
    checks = Array(expected).map { |type| TYPE_CHECKS[type] }.compact
    errors << "#{instance_path} must be #{Array(expected).join(" or ")}" unless checks.any? { |check| check.call(instance) }
  end

  def validate_const_and_enum(instance, schema, instance_path, errors)
    errors << "#{instance_path} must equal #{schema.fetch("const").inspect}" if schema.key?("const") && instance != schema.fetch("const")
    errors << "#{instance_path} is not an allowed value" if schema.key?("enum") && !schema.fetch("enum").include?(instance)
  end

  def validate_object(instance, schema, root_schema, schema_path, instance_path, errors)
    required = schema.fetch("required", [])
    required.each do |key|
      errors << "#{instance_path} is missing required property #{key}" unless instance.key?(key)
    end

    properties = schema.fetch("properties", {})
    if schema["additionalProperties"] == false
      (instance.keys - properties.keys).sort.each do |key|
        errors << "#{instance_path} has unknown property #{key}"
      end
    end

    properties.each do |key, child_schema|
      next unless instance.key?(key)

      validate_node(
        instance.fetch(key),
        child_schema,
        root_schema,
        schema_path,
        "#{instance_path}.#{key}",
        errors
      )
    end
  end

  def validate_array(instance, schema, root_schema, schema_path, instance_path, errors)
    if schema.key?("maxItems") && instance.length > schema.fetch("maxItems")
      errors << "#{instance_path} must contain at most #{schema.fetch("maxItems")} items"
    end
    return unless schema.key?("items")

    instance.each_with_index do |item, index|
      validate_node(item, schema.fetch("items"), root_schema, schema_path, "#{instance_path}[#{index}]", errors)
    end
  end

  def validate_string(instance, schema, instance_path, errors)
    if schema.key?("minLength") && instance.length < schema.fetch("minLength")
      errors << "#{instance_path} is shorter than #{schema.fetch("minLength")} characters"
    end
    if schema.key?("pattern") && !Regexp.new(schema.fetch("pattern")).match?(instance)
      errors << "#{instance_path} must match pattern #{schema.fetch("pattern")}"
    end
    return unless schema["format"] == "date-time"

    Time.iso8601(instance)
  rescue ArgumentError
    errors << "#{instance_path} must be an ISO 8601 date-time"
  end

  def resolve_reference(reference, root_schema, schema_path)
    document_reference, fragment = reference.split("#", 2)
    if document_reference.nil? || document_reference.empty?
      document = root_schema
      path = schema_path
    else
      path = schema_path.dirname.join(document_reference).expand_path
      document = load_schema(path)
    end

    node = document
    unless fragment.nil? || fragment.empty?
      unless fragment.start_with?("/")
        raise HandoffVerificationError, "unsupported schema reference #{reference}"
      end

      fragment.delete_prefix("/").split("/").each do |token|
        decoded = token.gsub("~1", "/").gsub("~0", "~")
        node = node.fetch(decoded)
      rescue KeyError
        raise HandoffVerificationError, "unresolved schema reference #{reference}"
      end
    end

    [node, document, path]
  end
end

module CanonicalJSON
  module_function

  def generate(value)
    case value
    when Hash
      "{" + value.keys.sort.map { |key| "#{JSON.generate(key)}:#{generate(value.fetch(key))}" }.join(",") + "}"
    when Array
      "[" + value.map { |item| generate(item) }.join(",") + "]"
    else
      JSON.generate(value)
    end
  end
end

class GitHubRemote
  Result = Struct.new(:stdout, :stderr, :status, keyword_init: true)
  EXPECTED_MAIN_CHECKS = {
    "spoonjoy/spoonjoy-apple" => {
      "Swift tests" => 15_368,
      "Native scenario verifier" => 15_368,
      "App bundle" => 15_368,
      "Coverage" => 15_368
    },
    "spoonjoy/spoonjoy-delivery" => {
      "CI" => 15_368
    }
  }.freeze

  def initialize(command: "gh")
    @command = command
  end

  def ref_head(repository, ref)
    endpoint = "repos/#{repository}/git/ref/#{encode_path(ref.delete_prefix("refs/"))}"
    response = query_json(endpoint)
    object = response.fetch("object")
    fail_with("remote ref #{repository}:#{ref} does not point to a commit") unless object["type"] == "commit"
    sha = object.fetch("sha")
    validate_sha!(sha, "remote ref #{repository}:#{ref}")
    sha
  rescue KeyError => error
    fail_with("remote ref response is incomplete for #{repository}:#{ref}: #{error.message}")
  end

  def verify_ref_protected(repository, ref, ledger_app_id: nil)
    branch = ref.delete_prefix("refs/heads/")
    fail_with("protected ref must name an exact branch: #{repository}:#{ref}") if branch == ref || branch.empty?
    return verify_release_ledger_protected(repository, ref, branch, ledger_app_id) if branch == "release-ledger"
    fail_with("ProtectedMainV1 applies only to refs/heads/main: #{repository}:#{ref}") unless branch == "main"

    classic = query_json(
      "repos/#{repository}/branches/#{encode_path(branch)}/protection",
      allow_not_found: true
    )
    default_branch = repository_default_branch(repository)
    rulesets = applicable_rulesets(repository, ref, default_branch, predicate: "ProtectedMainV1")
    normalized = {
      "predicate" => "ProtectedMainV1",
      "repository" => repository,
      "ref" => ref,
      "defaultBranch" => default_branch,
      "classic" => normalize_classic_protection(classic),
      "rulesets" => rulesets
    }
    validate_protected_main_v1!(normalized)
    normalized["ruleDigest"] = Digest::SHA256.hexdigest(CanonicalJSON.generate(normalized))
    normalized
  end

  def verify_commit_reachable(repository, commit, ref, ref_head)
    response = query_json("repos/#{repository}/git/commits/#{commit}", unreachable_label: "remote commit is unreachable: #{repository}@#{commit}")
    fail_with("remote commit identity mismatch for #{repository}@#{commit}") unless response["sha"] == commit

    comparison = query_json("repos/#{repository}/compare/#{commit}...#{ref_head}")
    status = comparison["status"]
    merge_base = comparison.dig("merge_base_commit", "sha")
    return if %w[ahead identical].include?(status) && merge_base == commit

    fail_with("commit #{repository}@#{commit} is not reachable from protected ref #{ref}")
  end

  def file_at_commit(repository, commit, path)
    response = query_json(
      "repos/#{repository}/contents/#{encode_path(path)}",
      fields: { "ref" => commit }
    )
    fail_with("remote path #{repository}@#{commit}:#{path} is not a file") unless response["type"] == "file"
    fail_with("remote path mismatch for #{repository}@#{commit}:#{path}") unless response["path"] == path
    fail_with("remote content encoding is not base64 for #{repository}@#{commit}:#{path}") unless response["encoding"] == "base64"

    Base64.strict_decode64(response.fetch("content").gsub(/\s+/, ""))
  rescue ArgumentError
    fail_with("remote content is invalid base64 for #{repository}@#{commit}:#{path}")
  rescue KeyError => error
    fail_with("remote content response is incomplete for #{repository}@#{commit}:#{path}: #{error.message}")
  end

  private

  def verify_release_ledger_protected(repository, ref, branch, ledger_app_id)
    fail_with("ProtectedLedgerV1 requires a positive dedicated ledger App ID") unless ledger_app_id.is_a?(Integer) && ledger_app_id.positive?

    classic = query_json(
      "repos/#{repository}/branches/#{encode_path(branch)}/protection",
      allow_not_found: true
    )
    default_branch = repository_default_branch(repository)
    rulesets = applicable_rulesets(repository, ref, default_branch, predicate: "ProtectedLedgerV1")
    normalized = {
      "predicate" => "ProtectedLedgerV1",
      "repository" => repository,
      "ref" => ref,
      "ledgerAppID" => ledger_app_id,
      "defaultBranch" => default_branch,
      "classic" => normalize_classic_protection(classic),
      "rulesets" => rulesets
    }
    validate_protected_ledger_v1!(normalized)
    normalized["ruleDigest"] = Digest::SHA256.hexdigest(CanonicalJSON.generate(normalized))
    normalized
  end

  def normalize_classic_protection(protection)
    return nil unless protection

    review = protection["required_pull_request_reviews"]
    checks = protection["required_status_checks"]
    {
      "sourceDigest" => Digest::SHA256.hexdigest(CanonicalJSON.generate(protection)),
      "forcePushesAllowed" => protection.dig("allow_force_pushes", "enabled"),
      "deletionsAllowed" => protection.dig("allow_deletions", "enabled"),
      "adminsEnforced" => protection.dig("enforce_admins", "enabled"),
      "pullRequest" => review && {
        "requiredApprovals" => review["required_approving_review_count"],
        "bypassActors" => normalize_classic_bypass(review["bypass_pull_request_allowances"])
      },
      "requiredChecks" => checks && {
        "strict" => checks["strict"],
        "checks" => Array(checks["checks"]).map do |check|
          {
            "context" => check["context"],
            "appID" => check["app_id"]
          }
        end.sort_by { |check| [check["context"].to_s, check["appID"].to_i] }
      },
      "pushRestrictions" => normalize_classic_restrictions(protection["restrictions"])
    }
  end

  def normalize_classic_bypass(allowances)
    return [] unless allowances.is_a?(Hash)

    %w[users teams apps].flat_map do |actor_type|
      Array(allowances[actor_type]).map do |actor|
        {
          "actorType" => actor_type,
          "id" => actor["id"],
          "slug" => actor["slug"] || actor["login"]
        }
      end
    end.sort_by { |actor| [actor["actorType"], actor["id"].to_i, actor["slug"].to_s] }
  end

  def normalize_classic_restrictions(restrictions)
    return [] unless restrictions.is_a?(Hash)

    %w[users teams apps].flat_map do |actor_type|
      Array(restrictions[actor_type]).map do |actor|
        {
          "actorType" => actor_type,
          "id" => actor["id"],
          "slug" => actor["slug"] || actor["login"]
        }
      end
    end.sort_by { |actor| [actor["actorType"], actor["id"].to_i, actor["slug"].to_s] }
  end

  def repository_default_branch(repository)
    metadata = query_json("repos/#{repository}")
    default_branch = metadata["default_branch"]
    unless default_branch.is_a?(String) && !default_branch.empty? && !default_branch.include?("/")
      fail_with("GitHub repository metadata has no provable default branch for #{repository}")
    end
    default_branch
  end

  def applicable_rulesets(repository, ref, default_branch, predicate:)
    summaries = query_json("repos/#{repository}/rulesets", fields: { "includes_parents" => "true" })
    fail_with("GitHub ruleset inventory is not an array for #{repository}") unless summaries.is_a?(Array)

    summaries.each_with_object([]) do |summary, applicable|
      fail_with("GitHub ruleset summary is malformed for #{repository}") unless summary.is_a?(Hash) && summary["id"].is_a?(Integer)

      detail = query_json("repos/#{repository}/rulesets/#{summary.fetch("id")}")
      next unless ruleset_applies_to_ref?(detail, ref, default_branch)

      enforcement = detail["enforcement"]
      fail_with("#{predicate} ruleset #{detail["id"]} for #{repository}:#{ref} is not active") unless enforcement == "active"
      applicable << normalize_ruleset(detail)
    end.sort_by { |ruleset| ruleset["id"] }
  end

  def ruleset_applies_to_ref?(ruleset, ref, default_branch)
    return false unless ruleset["target"] == "branch"

    ref_condition = ruleset.dig("conditions", "ref_name")
    fail_with("ruleset #{ruleset["id"]} has no provable ref_name condition") unless ref_condition.is_a?(Hash)
    included = Array(ref_condition["include"]).any? { |pattern| ref_pattern_matches?(pattern, ref, default_branch) }
    excluded = Array(ref_condition["exclude"]).any? { |pattern| ref_pattern_matches?(pattern, ref, default_branch) }
    included && !excluded
  end

  def ref_pattern_matches?(pattern, ref, default_branch)
    return true if pattern == "~ALL"
    return ref == "refs/heads/#{default_branch}" if pattern == "~DEFAULT_BRANCH"
    return false unless pattern.is_a?(String) && !pattern.start_with?("~")

    File.fnmatch(pattern, ref, File::FNM_PATHNAME | File::FNM_EXTGLOB) || pattern == ref.delete_prefix("refs/heads/")
  end

  def normalize_ruleset(ruleset)
    {
      "id" => ruleset.fetch("id"),
      "name" => ruleset.fetch("name"),
      "source" => ruleset["source"],
      "sourceType" => ruleset["source_type"],
      "target" => ruleset.fetch("target"),
      "enforcement" => ruleset.fetch("enforcement"),
      "conditions" => normalize_ruleset_conditions(ruleset.fetch("conditions")),
      "sourceDigest" => Digest::SHA256.hexdigest(CanonicalJSON.generate(ruleset)),
      "bypassActors" => Array(ruleset["bypass_actors"]).map do |actor|
        {
          "actorID" => actor["actor_id"],
          "actorType" => actor["actor_type"],
          "bypassMode" => actor["bypass_mode"]
        }
      end.sort_by { |actor| [actor["actorType"].to_s, actor["actorID"].to_i, actor["bypassMode"].to_s] },
      "rules" => Array(ruleset["rules"]).map { |rule| normalize_ruleset_rule(rule) }
        .sort_by { |rule| [rule["type"].to_s, CanonicalJSON.generate(rule)] }
    }
  rescue KeyError => error
    fail_with("applicable ruleset is incomplete: #{error.message}")
  end

  def normalize_ruleset_conditions(conditions)
    ref_name = conditions.fetch("ref_name")
    {
      "refName" => {
        "include" => Array(ref_name["include"]).sort,
        "exclude" => Array(ref_name["exclude"]).sort
      }
    }
  rescue KeyError => error
    fail_with("applicable ruleset conditions are incomplete: #{error.message}")
  end

  def normalize_ruleset_rule(rule)
    type = rule["type"]
    normalized = { "type" => type }
    parameters = rule["parameters"]
    return normalized unless parameters.is_a?(Hash)

    case type
    when "pull_request"
      normalized["requiredApprovals"] = parameters["required_approving_review_count"]
    when "required_status_checks"
      normalized["strict"] = parameters["strict_required_status_checks_policy"]
      normalized["checks"] = Array(parameters["required_status_checks"]).map do |check|
        {
          "context" => check["context"],
          "appID" => check["integration_id"]
        }
      end.sort_by { |check| [check["context"].to_s, check["appID"].to_i] }
    end
    normalized
  end

  def validate_protected_main_v1!(protection)
    repository = protection.fetch("repository")
    ref = protection.fetch("ref")
    classic = protection["classic"]
    rulesets = protection.fetch("rulesets")
    fail_with("ref #{repository}:#{ref} has no ProtectedMainV1 protection layer") if classic.nil? && rulesets.empty?

    broad_bypass_types = %w[users teams OrganizationAdmin RepositoryRole Team]
    classic_bypass = classic ? Array(classic.dig("pullRequest", "bypassActors")) : []
    ruleset_bypass = rulesets.flat_map { |ruleset| ruleset.fetch("bypassActors") }
    broad_bypass = (classic_bypass + ruleset_bypass).find do |actor|
      broad_bypass_types.include?(actor["actorType"])
    end
    fail_with("ProtectedMainV1 forbids broad role, team, user, or administrator bypass on #{repository}:#{ref}") if broad_bypass

    classic_blocks_mutation = classic && classic["forcePushesAllowed"] == false && classic["deletionsAllowed"] == false
    ruleset_types = rulesets.flat_map { |ruleset| ruleset.fetch("rules").map { |rule| rule["type"] } }
    rulesets_block_mutation = ruleset_types.include?("non_fast_forward") && ruleset_types.include?("deletion")
    fail_with("ProtectedMainV1 does not block force pushes and deletion on #{repository}:#{ref}") unless classic_blocks_mutation || rulesets_block_mutation
    if classic && classic["adminsEnforced"] != true
      fail_with("ProtectedMainV1 requires administrator enforcement on #{repository}:#{ref}")
    end

    pull_request_layers = []
    pull_request_layers << classic["pullRequest"] if classic && classic["pullRequest"]
    rulesets.each do |ruleset|
      ruleset.fetch("rules").select { |rule| rule["type"] == "pull_request" }.each { |rule| pull_request_layers << rule }
    end
    if pull_request_layers.empty? || pull_request_layers.any? { |layer| !layer["requiredApprovals"].is_a?(Integer) || layer["requiredApprovals"] < 1 }
      fail_with("ProtectedMainV1 requires pull requests with at least one approval on #{repository}:#{ref}")
    end

    check_layers = []
    check_layers << classic["requiredChecks"] if classic && classic["requiredChecks"]
    rulesets.each do |ruleset|
      ruleset.fetch("rules").select { |rule| rule["type"] == "required_status_checks" }.each { |rule| check_layers << rule }
    end
    fail_with("ProtectedMainV1 requires status checks on #{repository}:#{ref}") if check_layers.empty?
    if check_layers.any? { |layer| layer["strict"] != true }
      fail_with("ProtectedMainV1 requires strict required status checks on #{repository}:#{ref}")
    end
    if check_layers.any? { |layer| Array(layer["checks"]).empty? }
      fail_with("ProtectedMainV1 requires at least one named status check in every check layer on #{repository}:#{ref}")
    end
    checks = check_layers.flat_map { |layer| Array(layer["checks"]) }
    invalid_check = checks.find do |check|
      !check["context"].is_a?(String) || check["context"].empty? || !check["appID"].is_a?(Integer) || check["appID"] <= 0
    end
    fail_with("ProtectedMainV1 forbids any-source or missing-source required checks on #{repository}:#{ref}") if invalid_check

    duplicate_context = checks.group_by { |check| check["context"] }.find do |_context, entries|
      entries.map { |entry| entry["appID"] }.uniq.length != 1
    end
    fail_with("ProtectedMainV1 has conflicting App sources for a required check on #{repository}:#{ref}") if duplicate_context

    expected_checks = EXPECTED_MAIN_CHECKS[repository]
    fail_with("ProtectedMainV1 has no repository-specific expected check App allowlist for #{repository}") unless expected_checks
    actual_checks = checks.each_with_object({}) do |check, contexts|
      contexts[check.fetch("context")] = check.fetch("appID")
    end
    unless actual_checks == expected_checks
      fail_with("ProtectedMainV1 required checks do not match the repository-specific expected check App allowlist for #{repository}:#{ref}")
    end
  end

  def validate_protected_ledger_v1!(protection)
    repository = protection.fetch("repository")
    ref = protection.fetch("ref")
    ledger_app_id = protection.fetch("ledgerAppID")
    classic = protection["classic"]
    rulesets = protection.fetch("rulesets")
    fail_with("ref #{repository}:#{ref} has no ProtectedLedgerV1 ruleset") if rulesets.empty?

    broad_types = %w[users teams OrganizationAdmin RepositoryRole Team User]
    classic_bypass = classic ? Array(classic.dig("pullRequest", "bypassActors")) : []
    ruleset_bypass = rulesets.flat_map { |ruleset| ruleset.fetch("bypassActors") }
    if (classic_bypass + ruleset_bypass).any? { |actor| broad_types.include?(actor["actorType"]) }
      fail_with("ProtectedLedgerV1 forbids broad role, team, user, or administrator bypass on #{repository}:#{ref}")
    end

    expected_bypass = {
      "actorID" => ledger_app_id,
      "actorType" => "Integration",
      "bypassMode" => "always"
    }
    unless rulesets.all? { |ruleset| ruleset.fetch("bypassActors") == [expected_bypass] }
      fail_with("ProtectedLedgerV1 requires exactly the dedicated ledger App bypass on #{repository}:#{ref}")
    end

    unless rulesets.all? { |ruleset| ruleset.fetch("rules").any? { |rule| rule["type"] == "update" } }
      fail_with("ProtectedLedgerV1 forbids an ordinary writer or direct update path on #{repository}:#{ref}")
    end

    classic_blocks_mutation = classic && classic["forcePushesAllowed"] == false && classic["deletionsAllowed"] == false
    ruleset_types = rulesets.flat_map { |ruleset| ruleset.fetch("rules").map { |rule| rule["type"] } }
    rulesets_block_mutation = ruleset_types.include?("non_fast_forward") && ruleset_types.include?("deletion")
    fail_with("ProtectedLedgerV1 does not block force pushes and deletion on #{repository}:#{ref}") unless classic_blocks_mutation || rulesets_block_mutation
    if classic && classic["adminsEnforced"] != true
      fail_with("ProtectedLedgerV1 requires administrator enforcement on #{repository}:#{ref}")
    end
  end

  def query_json(endpoint, fields: {}, unreachable_label: nil, allow_not_found: false)
    arguments = [@command, "api", "--method", "GET", endpoint]
    fields.each { |key, value| arguments.concat(["-f", "#{key}=#{value}"]) }
    stdout, stderr, status = Open3.capture3(*arguments)
    unless status.success?
      response = begin
        StrictJSON.parse(stdout, label: "GitHub error response for #{endpoint}")
      rescue HandoffVerificationError
        nil
      end
      return nil if allow_not_found && response.is_a?(Hash) && response["status"].to_i == 404

      detail = [stdout, stderr].reject(&:empty?).join("\n").strip
      fail_with(unreachable_label || "GitHub query failed for #{endpoint}: #{detail}")
    end
    StrictJSON.parse(stdout, label: "GitHub response for #{endpoint}")
  rescue Errno::ENOENT
    fail_with("GitHub CLI is unavailable")
  end

  def encode_path(path)
    path.split("/").map { |segment| URI.encode_www_form_component(segment) }.join("/")
  end

  def validate_sha!(sha, label)
    fail_with("#{label} returned a mutable or malformed commit identity") unless sha.is_a?(String) && sha.match?(/\A[0-9a-f]{40}\z/)
  end

  def fail_with(message)
    raise HandoffVerificationError, message
  end
end

class ReleaseOwnershipHandoffVerifier
  OUTBOUND_REPOSITORY = "spoonjoy/spoonjoy-apple"
  DELIVERY_REPOSITORY = "spoonjoy/spoonjoy-delivery"
  OUTBOUND_REF = "refs/heads/main"
  LEDGER_REF = "refs/heads/release-ledger"
  DELIVERY_ACK_REF = "refs/heads/main"
  UPSTREAM_ACK_REF = "refs/heads/main"
  RECEIVER_TASK_ID = "019f5c80-bbe0-76a1-82eb-b0c715d035e7"
  RECEIVER_DESK_TASK = "spoonjoy/cross-client-delivery"
  RELEASE_RELATIVE_PATH = "worker/tasks/2026-07-16-0856-doing-audit-release-train/outbound-owner-release.json"
  TASK_ROOT = Pathname.new(__dir__).join("../worker/tasks/2026-07-16-0856-doing-audit-release-train").expand_path
  RELEASE_SCHEMA = TASK_ROOT.join("outbound-owner-release.schema.json")
  ACK_SCHEMA = TASK_ROOT.join("receiver-ack.schema.json")

  Envelope = Struct.new(:label, :repository, :ref, :commit, :path, keyword_init: true)

  def initialize(release_path:, ack_path:, delivery_ack_commit:, delivery_ack_path:, upstream_ack_commit:, upstream_ack_path:, output_path:, remote: GitHubRemote.new)
    @release_path = Pathname.new(release_path).expand_path
    @ack_path = Pathname.new(ack_path).expand_path
    @delivery_ack_commit = delivery_ack_commit
    @delivery_ack_path = delivery_ack_path
    @upstream_ack_commit = upstream_ack_commit
    @upstream_ack_path = upstream_ack_path
    @output_path = Pathname.new(output_path).expand_path
    @remote = remote
  end

  def verify
    FileUtils.rm_f(@output_path)
    release, release_bytes = StrictJSON.read(@release_path, label: "outbound release")
    ack, ack_bytes = StrictJSON.read(@ack_path, label: "receiver acknowledgment")
    schema = StrictJSONSchema.new
    schema.validate!(release, RELEASE_SCHEMA, label: "outbound release")
    schema.validate!(ack, ACK_SCHEMA, label: "receiver acknowledgment")
    validate_external_arguments
    validate_acknowledgment(release, release_bytes, ack)

    envelopes = build_envelopes(ack)
    protections = verify_protected_refs(envelopes)
    initial_heads = protected_ref_heads(envelopes)
    remote_contents = verify_remote_envelopes(envelopes, initial_heads)
    validate_remote_contents(release_bytes, ack_bytes, ack, remote_contents)
    validate_protected_refs_stable(initial_heads)
    validate_protected_rules_stable(protections)

    proof = build_proof(release, release_bytes, ack_bytes, ack, envelopes, protections, initial_heads)
    FileUtils.mkdir_p(@output_path.dirname)
    @output_path.write(JSON.pretty_generate(proof) + "\n")
    proof
  end

  private

  def validate_external_arguments
    validate_sha!(@delivery_ack_commit, "delivery acknowledgment containing commit")
    validate_sha!(@upstream_ack_commit, "upstream acknowledgment containing commit")
    validate_repo_path!(@delivery_ack_path, "delivery acknowledgment path")
    validate_repo_path!(@upstream_ack_path, "upstream acknowledgment path")
  end

  def validate_acknowledgment(release, release_bytes, ack)
    outbound = ack.fetch("outboundRelease")
    ledger = ack.fetch("ledgerEvent")
    receiver = ack.fetch("receiver")
    @ledger_app_id = ledger.fetch("appID")
    release_digest = sha256(release_bytes)
    fail_with("outbound release SHA-256 does not match acknowledgment") unless outbound.fetch("sha256") == release_digest
    fail_with("receiver task ID does not match outbound release") unless receiver.fetch("taskID") == release.fetch("receiverTaskID")
    fail_with("receiver Desk task does not match outbound release") unless receiver.fetch("deskTask") == release.fetch("receiverDeskTask")

    protected = ack.fetch("protectedOutbound")
    release.keys.sort.each do |field|
      next if CanonicalJSON.generate(release.fetch(field)) == CanonicalJSON.generate(protected.fetch(field))

      fail_with("protected outbound field #{field} differs")
    end
  end

  def build_envelopes(ack)
    outbound = ack.fetch("outboundRelease")
    ledger = ack.fetch("ledgerEvent")
    [
      Envelope.new(
        label: "outbound release",
        repository: outbound.fetch("repository"),
        ref: OUTBOUND_REF,
        commit: outbound.fetch("commit"),
        path: outbound.fetch("path")
      ),
      Envelope.new(
        label: "ledger event",
        repository: ledger.fetch("repository"),
        ref: ledger.fetch("ref"),
        commit: ledger.fetch("commit"),
        path: ledger.fetch("payloadPath")
      ),
      Envelope.new(
        label: "delivery acknowledgment",
        repository: DELIVERY_REPOSITORY,
        ref: DELIVERY_ACK_REF,
        commit: @delivery_ack_commit,
        path: @delivery_ack_path
      ),
      Envelope.new(
        label: "upstream acknowledgment",
        repository: OUTBOUND_REPOSITORY,
        ref: UPSTREAM_ACK_REF,
        commit: @upstream_ack_commit,
        path: @upstream_ack_path
      )
    ]
  end

  def protected_ref_heads(envelopes)
    envelopes.each_with_object({}) do |envelope, heads|
      key = [envelope.repository, envelope.ref]
      heads[key] ||= @remote.ref_head(envelope.repository, envelope.ref)
    end
  end

  def verify_protected_refs(envelopes)
    envelopes.each_with_object({}) do |envelope, protections|
      key = [envelope.repository, envelope.ref]
      ledger_app_id = envelope.ref == LEDGER_REF ? @ledger_app_id : nil
      protections[key] ||= @remote.verify_ref_protected(envelope.repository, envelope.ref, ledger_app_id: ledger_app_id)
    end
  end

  def verify_remote_envelopes(envelopes, initial_heads)
    envelopes.each_with_object({}) do |envelope, contents|
      ref_head = initial_heads.fetch([envelope.repository, envelope.ref])
      @remote.verify_commit_reachable(envelope.repository, envelope.commit, envelope.ref, ref_head)
      contents[envelope.label] = @remote.file_at_commit(envelope.repository, envelope.commit, envelope.path)
    end
  end

  def validate_remote_contents(release_bytes, ack_bytes, ack, contents)
    release_digest = sha256(release_bytes)
    fail_with("outbound release tree SHA-256 does not match") unless sha256(contents.fetch("outbound release")) == release_digest

    ack_digest = sha256(ack_bytes)
    fail_with("delivery acknowledgment tree SHA-256 does not match") unless sha256(contents.fetch("delivery acknowledgment")) == ack_digest
    fail_with("upstream acknowledgment tree SHA-256 does not match") unless sha256(contents.fetch("upstream acknowledgment")) == ack_digest

    event = StrictJSON.parse(contents.fetch("ledger event"), label: "protected ledger event")
    fail_with("ledger event type must be ReceiverAcknowledged") unless event["eventType"] == "ReceiverAcknowledged"
    payload = event["payload"]
    fail_with("ledger event payload must be an object") unless payload.is_a?(Hash)
    expected_payload_keys = %w[ledgerAppID outboundReleaseSHA256 receiverDeskTask receiverTaskID]
    fail_with("ledger event payload fields do not match the ReceiverAcknowledged contract") unless payload.keys.sort == expected_payload_keys
    ledger = ack.fetch("ledgerEvent")
    payload_digest = sha256(CanonicalJSON.generate(payload))
    fail_with("ledger payload SHA-256 does not match") unless payload_digest == ledger.fetch("payloadSHA256")
    fail_with("ledger payload outbound release SHA-256 does not match") unless payload["outboundReleaseSHA256"] == release_digest
    fail_with("ledger payload receiver task ID does not match") unless payload["receiverTaskID"] == RECEIVER_TASK_ID
    fail_with("ledger payload receiver Desk task does not match") unless payload["receiverDeskTask"] == RECEIVER_DESK_TASK
    fail_with("ledger payload dedicated App ID does not match") unless payload["ledgerAppID"] == ledger.fetch("appID")
  end

  def validate_protected_refs_stable(initial_heads)
    initial_heads.each do |(repository, ref), initial_head|
      final_head = @remote.ref_head(repository, ref)
      next if final_head == initial_head

      fail_with("protected ref #{repository}:#{ref} changed during verification")
    end
  end

  def validate_protected_rules_stable(initial_protections)
    initial_protections.each do |(repository, ref), initial_protection|
      final_protection = @remote.verify_ref_protected(
        repository,
        ref,
        ledger_app_id: initial_protection["ledgerAppID"]
      )
      next if final_protection["ruleDigest"] == initial_protection["ruleDigest"]

      fail_with("#{initial_protection.fetch("predicate")} rule digest changed during verification for #{repository}:#{ref}")
    end
  end

  def build_proof(release, release_bytes, ack_bytes, ack, envelopes, protections, initial_heads)
    envelope_map = envelopes.to_h do |envelope|
      [
        envelope.label.gsub(" ", "_"),
        {
          "repository" => envelope.repository,
          "ref" => envelope.ref,
          "protection" => protections.fetch([envelope.repository, envelope.ref]),
          "refHead" => initial_heads.fetch([envelope.repository, envelope.ref]),
          "commit" => envelope.commit,
          "path" => envelope.path
        }
      ]
    end
    {
      "schemaVersion" => 1,
      "verified" => true,
      "receiver" => ack.fetch("receiver"),
      "outboundReleaseSHA256" => sha256(release_bytes),
      "receiverAckSHA256" => sha256(ack_bytes),
      "ledgerPayloadSHA256" => ack.fetch("ledgerEvent").fetch("payloadSHA256"),
      "protectedOutbound" => release,
      "remoteEnvelopes" => envelope_map
    }
  end

  def validate_sha!(value, label)
    fail_with("#{label} must be an exact immutable commit SHA") unless value.match?(/\A[0-9a-f]{40}\z/)
  end

  def validate_repo_path!(value, label)
    valid = !value.empty? && !value.start_with?("/") && !value.split("/").include?("..") && !value.match?(/\s/)
    fail_with("#{label} must be a repository-relative immutable path") unless valid
  end

  def sha256(content)
    Digest::SHA256.hexdigest(content)
  end

  def fail_with(message)
    raise HandoffVerificationError, message
  end
end

def parse_options(arguments)
  options = {}
  parser = OptionParser.new do |option|
    option.banner = "Usage: verify-release-ownership-handoff.rb --release PATH --ack PATH --delivery-ack-commit SHA --delivery-ack-path PATH --upstream-ack-commit SHA --upstream-ack-path PATH --output PATH"
    option.on("--release PATH", "Canonical outbound-owner-release.json") { |value| options[:release_path] = value }
    option.on("--ack PATH", "Acyclic receiver-ack.json projection") { |value| options[:ack_path] = value }
    option.on("--delivery-ack-commit SHA", "Remote delivery commit containing the acknowledgment") { |value| options[:delivery_ack_commit] = value }
    option.on("--delivery-ack-path PATH", "Acknowledgment path in the delivery commit") { |value| options[:delivery_ack_path] = value }
    option.on("--upstream-ack-commit SHA", "Remote upstream commit containing the acknowledgment") { |value| options[:upstream_ack_commit] = value }
    option.on("--upstream-ack-path PATH", "Acknowledgment path in the upstream commit") { |value| options[:upstream_ack_path] = value }
    option.on("--output PATH", "Deterministic verified ownership proof") { |value| options[:output_path] = value }
  end
  parser.parse!(arguments)
  required = %i[release_path ack_path delivery_ack_commit delivery_ack_path upstream_ack_commit upstream_ack_path output_path]
  missing = required.reject { |key| options.key?(key) }
  raise OptionParser::MissingArgument, missing.join(", ") unless missing.empty?
  raise OptionParser::InvalidOption, arguments.join(" ") unless arguments.empty?

  options
end

if __FILE__ == $PROGRAM_NAME
  begin
    options = parse_options(ARGV)
    proof = ReleaseOwnershipHandoffVerifier.new(**options).verify
    puts "release ownership handoff verified: #{proof.fetch("receiverAckSHA256")}"
  rescue HandoffVerificationError, OptionParser::ParseError => error
    warn "handoff verification failed: #{error.message}"
    exit 1
  end
end
