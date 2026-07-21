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

  def query_json(endpoint, fields: {}, unreachable_label: nil)
    arguments = [@command, "api", "--method", "GET", endpoint]
    fields.each { |key, value| arguments.concat(["-f", "#{key}=#{value}"]) }
    stdout, stderr, status = Open3.capture3(*arguments)
    unless status.success?
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
  OUTBOUND_REF = "refs/heads/worker/audit-release-train"
  LEDGER_REF = "refs/heads/release-ledger"
  DELIVERY_ACK_REF = "refs/heads/records-r0"
  UPSTREAM_ACK_REF = OUTBOUND_REF
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
    initial_heads = protected_ref_heads(envelopes)
    remote_contents = verify_remote_envelopes(envelopes, initial_heads)
    validate_remote_contents(release_bytes, ack_bytes, ack, remote_contents)
    validate_protected_refs_stable(initial_heads)

    proof = build_proof(release, release_bytes, ack_bytes, ack, envelopes, initial_heads)
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
    receiver = ack.fetch("receiver")
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
    expected_payload_keys = %w[outboundReleaseSHA256 receiverDeskTask receiverTaskID]
    fail_with("ledger event payload fields do not match the ReceiverAcknowledged contract") unless payload.keys.sort == expected_payload_keys
    ledger = ack.fetch("ledgerEvent")
    payload_digest = sha256(CanonicalJSON.generate(payload))
    fail_with("ledger payload SHA-256 does not match") unless payload_digest == ledger.fetch("payloadSHA256")
    fail_with("ledger payload outbound release SHA-256 does not match") unless payload["outboundReleaseSHA256"] == release_digest
    fail_with("ledger payload receiver task ID does not match") unless payload["receiverTaskID"] == RECEIVER_TASK_ID
    fail_with("ledger payload receiver Desk task does not match") unless payload["receiverDeskTask"] == RECEIVER_DESK_TASK
  end

  def validate_protected_refs_stable(initial_heads)
    initial_heads.each do |(repository, ref), initial_head|
      final_head = @remote.ref_head(repository, ref)
      next if final_head == initial_head

      fail_with("protected ref #{repository}:#{ref} changed during verification")
    end
  end

  def build_proof(release, release_bytes, ack_bytes, ack, envelopes, initial_heads)
    envelope_map = envelopes.to_h do |envelope|
      [
        envelope.label.gsub(" ", "_"),
        {
          "repository" => envelope.repository,
          "ref" => envelope.ref,
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
