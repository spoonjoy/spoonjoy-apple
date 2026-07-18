#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "optparse"
require "time"

class ReleaseOwnershipHandoffError < StandardError; end

class ReleaseOwnershipHandoffVerifier
  SHA_PATTERN = /\A[0-9a-f]{40}\z/
  REPO_PATTERN = %r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z}
  THREAD_PATTERN = /\A[0-9A-Za-z_.:@\/-]{8,}\z/
  GITHUB_URL_PATTERN = %r{\Ahttps://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/(pull|actions/runs)/[0-9]+\z}
  SECRET_LIKE_PATTERNS = [
    /gh[pousr]_[A-Za-z0-9_]{20,}/,
    /xox[baprs]-[A-Za-z0-9-]+/,
    /Bearer\s+[A-Za-z0-9._~+\/=-]+/i,
    /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
    /\b(password|passwd|token|api[_-]?key|authorization)\s*[:=]\s*[^,\s]+/i
  ].freeze

  SHARED_FIELDS = %w[
    final_web_sha
    final_native_sha
    merged_prs
    ci_runs
    deployments
    residual_work
    zero_in_flight_web_merges
    zero_in_flight_web_deploys
    web_cleanup_owner
    testflight_owners
  ].freeze

  RELEASE_FIELDS = (["schema_version", "handoff_id"] + SHARED_FIELDS + %w[
    releasing_thread_id
    releasing_pushed_commit_sha
    released_at
  ]).freeze

  ACK_FIELDS = (["schema_version", "handoff_id"] + SHARED_FIELDS + %w[
    receiver_thread_id
    receiver_pushed_commit_sha
    acknowledged_at
    cleanup_scope_acknowledged
  ]).freeze

  def initialize(release_path:, ack_path:, output_path:)
    @release_path = release_path
    @ack_path = ack_path
    @output_path = output_path
  end

  def verify
    release = load_json(@release_path, "owner-release")
    ack = load_json(@ack_path, "receiver-ack")

    validate_no_sensitive_values!(release, "owner-release")
    validate_no_sensitive_values!(ack, "receiver-ack")
    validate_required_fields!(release, "owner-release", RELEASE_FIELDS)
    validate_required_fields!(ack, "receiver-ack", ACK_FIELDS)
    validate_version!(release, "owner-release")
    validate_version!(ack, "receiver-ack")
    validate_handoff_identity!(release, ack)
    validate_shared_fields_match!(release, ack)
    validate_release_shape!(release)
    validate_ack_shape!(ack)
    validate_shared_shape!(release)
    validate_cleanup_acknowledgement!(release, ack)

    proof = proof_for(release, ack)
    write_output(proof)
    proof
  end

  private

  def load_json(path, label)
    fail_with("#{label} path is required") if path.nil? || path.strip.empty?
    JSON.parse(File.read(path))
  rescue Errno::ENOENT
    fail_with("#{label} file not found")
  rescue JSON::ParserError => error
    fail_with("#{label} is not valid JSON: #{error.message}")
  end

  def validate_no_sensitive_values!(value, path)
    case value
    when Hash
      value.each { |key, child| validate_no_sensitive_values!(child, "#{path}.#{key}") }
    when Array
      value.each_with_index { |child, index| validate_no_sensitive_values!(child, "#{path}[#{index}]") }
    when String
      return unless SECRET_LIKE_PATTERNS.any? { |pattern| value.match?(pattern) }

      fail_with("secret-like value detected at #{relative_path(path)}")
    end
  end

  def validate_required_fields!(record, label, fields)
    fail_with("#{label} must be a JSON object") unless record.is_a?(Hash)

    fields.each do |field|
      fail_with("#{label} missing required field #{field}") unless record.key?(field)
    end
  end

  def validate_version!(record, label)
    fail_with("#{label} schema_version must be 1") unless record["schema_version"] == 1
  end

  def validate_handoff_identity!(release, ack)
    validate_non_empty_string!(release["handoff_id"], "handoff_id")
    validate_non_empty_string!(ack["handoff_id"], "handoff_id")
    fail_with("handoff_id mismatch") unless release["handoff_id"] == ack["handoff_id"]
  end

  def validate_shared_fields_match!(release, ack)
    SHARED_FIELDS.each do |field|
      fail_with("handoff field #{field} mismatch") unless release[field] == ack[field]
    end
  end

  def validate_release_shape!(release)
    validate_thread_id!(release["releasing_thread_id"], "releasing_thread_id")
    validate_sha!(release["releasing_pushed_commit_sha"], "releasing_pushed_commit_sha")
    validate_time!(release["released_at"], "released_at")
  end

  def validate_ack_shape!(ack)
    validate_thread_id!(ack["receiver_thread_id"], "receiver_thread_id")
    validate_sha!(ack["receiver_pushed_commit_sha"], "receiver_pushed_commit_sha")
    validate_time!(ack["acknowledged_at"], "acknowledged_at")
    fail_with("receiver cleanup scope is not acknowledged") unless ack["cleanup_scope_acknowledged"] == true
  end

  def validate_shared_shape!(record)
    final_web_sha = record["final_web_sha"]
    final_native_sha = record["final_native_sha"]
    validate_sha!(final_web_sha, "final_web_sha")
    validate_sha!(final_native_sha, "final_native_sha")

    fail_with("zero_in_flight_web_merges must be true") unless record["zero_in_flight_web_merges"] == true
    fail_with("zero_in_flight_web_deploys must be true") unless record["zero_in_flight_web_deploys"] == true
    validate_thread_id!(record["web_cleanup_owner"], "web_cleanup_owner")

    validate_testflight_owners!(record["testflight_owners"])
    validate_pr_inventory!(record["merged_prs"], final_web_sha, final_native_sha)
    validate_run_inventory!(record["ci_runs"], final_web_sha, final_native_sha)
    validate_deployments!(record["deployments"], final_web_sha)
    validate_residual_work!(record["residual_work"])
  end

  def validate_cleanup_acknowledgement!(release, ack)
    if release["releasing_pushed_commit_sha"] == ack["receiver_pushed_commit_sha"]
      fail_with("releasing and receiver pushed commit SHAs must be distinct")
    end

    owner = release.fetch("testflight_owners").first
    unless owner["thread_id"] == ack["receiver_thread_id"]
      fail_with("TestFlight owner must match receiver_thread_id")
    end
  end

  def validate_testflight_owners!(owners)
    fail_with("testflight_owners must be an array") unless owners.is_a?(Array)
    fail_with("duplicate TestFlight owner") unless owners.length == 1

    owner = owners.first
    fail_with("testflight_owners[0] must be an object") unless owner.is_a?(Hash)
    validate_thread_id!(owner["thread_id"], "testflight_owners[0].thread_id")
    validate_non_empty_string!(owner["scope"], "testflight_owners[0].scope")
    fail_with("testflight_owners[0].exclusive must be true") unless owner["exclusive"] == true
  end

  def validate_pr_inventory!(prs, final_web_sha, final_native_sha)
    fail_with("merged_prs must be a non-empty array") unless prs.is_a?(Array) && prs.any?

    seen = {}
    web_seen = false
    native_seen = false
    prs.each_with_index do |pr, index|
      path = "merged_prs[#{index}]"
      fail_with("#{path} must be an object") unless pr.is_a?(Hash)
      %w[repo number url merge_sha].each do |field|
        fail_with("#{path} missing required field #{field}") unless pr.key?(field)
      end

      validate_repo!(pr["repo"], "#{path}.repo")
      validate_positive_integer!(pr["number"], "#{path}.number")
      validate_github_url!(pr["url"], "#{path}.url")
      validate_sha!(pr["merge_sha"], "#{path}.merge_sha")
      identity = "#{pr["repo"]}##{pr["number"]}"
      fail_with("duplicate PR inventory entry #{identity}") if seen[identity]

      seen[identity] = true
      web_seen ||= pr["repo"] == "spoonjoy/spoonjoy-v2" && pr["merge_sha"] == final_web_sha
      native_seen ||= pr["repo"] == "spoonjoy/spoonjoy-apple" && pr["merge_sha"] == final_native_sha
    end

    fail_with("merged_prs must include the final web SHA") unless web_seen
    fail_with("merged_prs must include the final native SHA") unless native_seen
  end

  def validate_run_inventory!(runs, final_web_sha, final_native_sha)
    fail_with("ci_runs must be a non-empty array") unless runs.is_a?(Array) && runs.any?

    web_seen = false
    native_seen = false
    runs.each_with_index do |run, index|
      path = "ci_runs[#{index}]"
      fail_with("#{path} must be an object") unless run.is_a?(Hash)
      %w[repo workflow run_id url head_sha status conclusion].each do |field|
        fail_with("#{path} missing required field #{field}") unless run.key?(field)
      end

      validate_repo!(run["repo"], "#{path}.repo")
      validate_non_empty_string!(run["workflow"], "#{path}.workflow")
      validate_run_id!(run["run_id"], "#{path}.run_id")
      validate_github_url!(run["url"], "#{path}.url")
      validate_sha!(run["head_sha"], "#{path}.head_sha")
      fail_with("#{path}.status must be completed") unless run["status"] == "completed"
      fail_with("#{path}.conclusion must be success") unless run["conclusion"] == "success"

      case run["head_sha"]
      when final_web_sha
        web_seen = true
      when final_native_sha
        native_seen = true
      else
        fail_with("#{path}.head_sha must match final web or native SHA")
      end
    end

    fail_with("ci_runs must include final web SHA evidence") unless web_seen
    fail_with("ci_runs must include final native SHA evidence") unless native_seen
  end

  def validate_deployments!(deployments, final_web_sha)
    fail_with("deployments must be a non-empty array") unless deployments.is_a?(Array) && deployments.any?

    deployments.each_with_index do |deployment, index|
      path = "deployments[#{index}]"
      fail_with("#{path} must be an object") unless deployment.is_a?(Hash)
      %w[repo environment run_id url source_sha status].each do |field|
        fail_with("#{path} missing required field #{field}") unless deployment.key?(field)
      end

      validate_repo!(deployment["repo"], "#{path}.repo")
      validate_non_empty_string!(deployment["environment"], "#{path}.environment")
      validate_run_id!(deployment["run_id"], "#{path}.run_id")
      validate_github_url!(deployment["url"], "#{path}.url")
      validate_sha!(deployment["source_sha"], "#{path}.source_sha")
      fail_with("#{path}.source_sha must match final_web_sha") unless deployment["source_sha"] == final_web_sha
      fail_with("#{path}.status must be success") unless deployment["status"] == "success"
    end
  end

  def validate_residual_work!(items)
    fail_with("residual_work must be an array") unless items.is_a?(Array)

    items.each_with_index do |item, index|
      path = "residual_work[#{index}]"
      fail_with("#{path} must be an object") unless item.is_a?(Hash)
      %w[owner_thread_id scope status description].each do |field|
        fail_with("#{path} missing required field #{field}") unless item.key?(field)
      end

      validate_thread_id!(item["owner_thread_id"], "#{path}.owner_thread_id")
      validate_non_empty_string!(item["scope"], "#{path}.scope")
      validate_non_empty_string!(item["status"], "#{path}.status")
      validate_non_empty_string!(item["description"], "#{path}.description")
    end
  end

  def validate_sha!(value, path)
    return if value.is_a?(String) && value.match?(SHA_PATTERN)

    fail_with("stale or non-40-character SHA at #{path}")
  end

  def validate_thread_id!(value, path)
    validate_non_empty_string!(value, path)
    fail_with("#{path} is not a valid thread id") unless value.match?(THREAD_PATTERN)
  end

  def validate_non_empty_string!(value, path)
    fail_with("#{path} must be a non-empty string") unless value.is_a?(String) && !value.strip.empty?
    fail_with("#{path} must not contain control characters") if value.match?(/[\r\n\t\0]/)
  end

  def validate_repo!(value, path)
    validate_non_empty_string!(value, path)
    fail_with("#{path} must be an owner/name repository") unless value.match?(REPO_PATTERN)
  end

  def validate_github_url!(value, path)
    validate_non_empty_string!(value, path)
    fail_with("#{path} must be a GitHub PR or run URL") unless value.match?(GITHUB_URL_PATTERN)
  end

  def validate_positive_integer!(value, path)
    fail_with("#{path} must be a positive integer") unless value.is_a?(Integer) && value.positive?
  end

  def validate_run_id!(value, path)
    return if value.is_a?(Integer) && value.positive?
    return if value.is_a?(String) && value.match?(/\A[1-9][0-9]*\z/)

    fail_with("#{path} must be a positive run id")
  end

  def validate_time!(value, path)
    validate_non_empty_string!(value, path)
    Time.iso8601(value)
  rescue ArgumentError
    fail_with("#{path} must be ISO-8601 UTC")
  end

  def proof_for(release, ack)
    {
      "schema_version" => 1,
      "ok" => true,
      "handoff_id" => release.fetch("handoff_id"),
      "final_web_sha" => release.fetch("final_web_sha"),
      "final_native_sha" => release.fetch("final_native_sha"),
      "web_cleanup_owner" => release.fetch("web_cleanup_owner"),
      "testflight_owner_thread_id" => release.fetch("testflight_owners").first.fetch("thread_id"),
      "release" => {
        "thread_id" => release.fetch("releasing_thread_id"),
        "pushed_commit_sha" => release.fetch("releasing_pushed_commit_sha"),
        "released_at" => release.fetch("released_at")
      },
      "receiver" => {
        "thread_id" => ack.fetch("receiver_thread_id"),
        "pushed_commit_sha" => ack.fetch("receiver_pushed_commit_sha"),
        "acknowledged_at" => ack.fetch("acknowledged_at"),
        "cleanup_scope_acknowledged" => true
      },
      "counts" => {
        "merged_prs" => release.fetch("merged_prs").length,
        "ci_runs" => release.fetch("ci_runs").length,
        "deployments" => release.fetch("deployments").length,
        "residual_work" => release.fetch("residual_work").length
      },
      "inventory_sha256" => {
        "merged_prs" => digest_for(release.fetch("merged_prs")),
        "ci_runs" => digest_for(release.fetch("ci_runs")),
        "deployments" => digest_for(release.fetch("deployments")),
        "residual_work" => digest_for(release.fetch("residual_work"))
      }
    }
  end

  def write_output(proof)
    return if @output_path.nil? || @output_path.strip.empty?

    FileUtils.mkdir_p(File.dirname(@output_path))
    File.write(@output_path, JSON.pretty_generate(proof) + "\n")
  end

  def digest_for(value)
    Digest::SHA256.hexdigest(canonical_json(value))
  end

  def canonical_json(value)
    JSON.generate(deep_sort(value))
  end

  def deep_sort(value)
    case value
    when Hash
      value.keys.sort.each_with_object({}) { |key, result| result[key] = deep_sort(value[key]) }
    when Array
      value.map { |child| deep_sort(child) }
    else
      value
    end
  end

  def relative_path(path)
    path.sub(/\A(owner-release|receiver-ack)\./, "")
  end

  def fail_with(message)
    raise ReleaseOwnershipHandoffError, message
  end
end

options = {}
OptionParser.new do |parser|
  parser.banner = "Usage: verify-release-ownership-handoff.rb --release owner-release.json --ack receiver-ack.json [--output ownership.json]"
  parser.on("--release PATH", "Owner-release JSON path") { |value| options[:release_path] = value }
  parser.on("--ack PATH", "Receiver acknowledgement JSON path") { |value| options[:ack_path] = value }
  parser.on("--output PATH", "Write redacted proof JSON") { |value| options[:output_path] = value }
end.parse!

begin
  verifier = ReleaseOwnershipHandoffVerifier.new(
    release_path: options[:release_path],
    ack_path: options[:ack_path],
    output_path: options[:output_path]
  )
  verifier.verify
  puts "release ownership handoff ok"
rescue ReleaseOwnershipHandoffError => error
  warn "verify-release-ownership-handoff failed: #{error.message}"
  exit 1
end
