# frozen_string_literal: true

require "json"
require "pathname"

# Judges an accessibility proof's measured layout fields against the checked-in known findings.
#
# By default the capture records layout findings without failing on them. With SPOONJOY_REQUIRE_LAYOUT_AUDIT=1 a
# proof fails when its layout audit is missing, when a measured field is missing or not boolean, or when the audit
# found anything not listed in scripts/layout-audit-known-findings.json. Every listed finding is owned by the
# accessibility polish task (Task 10), which must fix it and remove the entry.
module LayoutAuditGate
  FIELDS = %w[noOverlap textFits controlsOnScreen].freeze
  KINDS = %w[overlap truncated outsideScreen outsideContainer clippedControl].freeze
  OWNER = "Task 10"
  STRICT_VARIABLE = "SPOONJOY_REQUIRE_LAYOUT_AUDIT"
  DEFAULT_KNOWN_FINDINGS = File.expand_path("../layout-audit-known-findings.json", __dir__)

  Result = Struct.new(:errors, :allowed, :unexpected, :stale, keyword_init: true) do
    def passes?
      errors.empty? && unexpected.empty?
    end
  end

  module_function

  def strict?(env = ENV)
    env[STRICT_VARIABLE] == "1"
  end

  # An element is named by its accessibility identifier, or by "label:<label>" when it has none.
  def element_key(reference)
    identifier = reference["identifier"].to_s
    identifier.empty? ? "label:#{reference["label"]}" : identifier
  end

  def findings(audit)
    report = audit.fetch("report")
    overlaps = report.fetch("overlaps").map do |overlap|
      { "kind" => "overlap", "elements" => [element_key(overlap["first"]), element_key(overlap["second"])].sort }
    end
    text = report.fetch("textProblems").map do |problem|
      { "kind" => problem.fetch("kind"), "elements" => [element_key(problem["text"])] }
    end
    controls = report.fetch("clippedControls").map do |clipped|
      { "kind" => "clippedControl", "elements" => [element_key(clipped["control"])] }
    end
    overlaps + text + controls
  end

  # Returns the problems with a known-findings document; an empty list means it is valid.
  def validate_known_findings(document)
    return ["known findings must be an object with a findings array"] unless document.is_a?(Hash) && document["findings"].is_a?(Array)

    document["findings"].each_with_index.flat_map do |entry, index|
      where = "known finding #{index}"
      next ["#{where} must be an object"] unless entry.is_a?(Hash)

      problems = []
      problems << "#{where} must name a route" unless entry["route"].is_a?(String) && !entry["route"].empty?
      problems << "#{where} must name a dynamicType" unless entry["dynamicType"].is_a?(String) && !entry["dynamicType"].empty?
      problems << "#{where} kind must be one of #{KINDS.join(", ")}" unless KINDS.include?(entry["kind"])
      elements = entry["elements"]
      expected_count = entry["kind"] == "overlap" ? 2 : 1
      unless elements.is_a?(Array) && elements.length == expected_count && elements.all? { |element| element.is_a?(String) && !element.empty? }
        problems << "#{where} must list #{expected_count} element identifier(s)"
      end
      problems << "#{where} must be owned by #{OWNER}" unless entry["task"] == OWNER
      problems << "#{where} must give a reason" unless entry["reason"].is_a?(String) && !entry["reason"].strip.empty?
      problems
    end
  end

  def load_known_findings(path = DEFAULT_KNOWN_FINDINGS)
    document = JSON.parse(File.read(path))
    problems = validate_known_findings(document)
    raise ArgumentError, "#{path}: #{problems.join("; ")}" unless problems.empty?

    document["findings"]
  end

  # proof: the accessibility proof; audit: its layout audit, or nil when the proof names none or it is missing.
  def evaluate(proof:, audit:, known:)
    errors = []
    if audit.nil?
      errors << (proof["layoutAudit"] ? "layout audit #{proof["layoutAudit"]} is missing" : "proof has no layout audit")
      return Result.new(errors: errors, allowed: [], unexpected: [], stale: [])
    end

    FIELDS.each do |field|
      errors << "#{field} is missing or not boolean" unless [true, false].include?(proof[field])
    end
    route = audit["route"]
    size = audit["observedDynamicTypeSize"]
    applicable = known.select { |entry| entry["route"] == route && entry["dynamicType"] == size }
    matched = []
    allowed = []
    unexpected = []
    findings(audit).each do |finding|
      entry = applicable.find { |candidate| candidate["kind"] == finding["kind"] && candidate["elements"].sort == finding["elements"] }
      if entry
        matched << entry
        allowed << finding
      else
        unexpected << finding
      end
    end
    Result.new(errors: errors, allowed: allowed, unexpected: unexpected, stale: applicable - matched)
  end

  def describe(finding)
    "#{finding["kind"]} #{finding["elements"].join(" + ")}"
  end
end
