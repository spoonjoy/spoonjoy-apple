# frozen_string_literal: true

require "json"
require "pathname"

# Judges an accessibility proof's measured layout fields against the checked-in known findings.
#
# By default the capture records layout findings without failing on them. With SPOONJOY_REQUIRE_LAYOUT_AUDIT=1 a
# proof fails when its layout audit is missing, when a measured field is missing or not boolean, when the audit
# measured no elements or read no drawn text (an empty screen proves nothing), or when the audit found anything not
# listed in scripts/layout-audit-known-findings.json. Every listed finding is owned by the
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

  # Every name a known finding may use for an element: its identifier, if any, and "label:<label>". XCUITest can
  # report an SF Symbol's name as a button's identifier on one run and none on the next, so the label still matches.
  def element_keys(reference)
    [element_key(reference), "label:#{reference["label"]}"].uniq
  end

  def finding(kind, references)
    pairs = references.map { |reference| [element_key(reference), element_keys(reference)] }.sort_by(&:first)
    { "kind" => kind, "elements" => pairs.map(&:first), "keys" => pairs.map(&:last) }
  end

  def findings(audit)
    report = audit.fetch("report")
    overlaps = report.fetch("overlaps").map { |overlap| finding("overlap", [overlap["first"], overlap["second"]]) }
    text = report.fetch("textProblems").map { |problem| finding(problem.fetch("kind"), [problem["text"]]) }
    controls = report.fetch("clippedControls").map { |clipped| finding("clippedControl", [clipped["control"]]) }
    overlaps + text + controls
  end

  def matches?(entry, finding)
    return false unless entry["kind"] == finding["kind"] && entry["elements"].length == finding["keys"].length

    entry["elements"].permutation.any? { |order| order.zip(finding["keys"]).all? { |name, keys| keys.include?(name) } }
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
      earlier = document["findings"].first(index).index { |other| same_entry?(other, entry) }
      problems << "#{where} repeats known finding #{earlier}" if earlier
      problems
    end
  end

  def same_entry?(first, second)
    return false unless first.is_a?(Hash) && second.is_a?(Hash)

    %w[route dynamicType kind].all? { |key| first[key] == second[key] } &&
      Array(first["elements"]).sort == Array(second["elements"]).sort
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
    report = audit["report"].is_a?(Hash) ? audit["report"] : {}
    count = ->(key) { report[key].is_a?(Integer) ? report[key] : 0 }
    errors << "layout audit measured no controls or text" if count.call("interactiveCount") + count.call("textCount") == 0
    errors << "layout audit read no drawn text" if count.call("drawnTextCount") == 0
    route = audit["route"]
    size = audit["observedDynamicTypeSize"]
    applicable = known.select { |entry| entry["route"] == route && entry["dynamicType"] == size }
    matched = []
    allowed = []
    unexpected = []
    findings(audit).each do |finding|
      # Each entry excuses one finding: a second overlap between two same-labelled elements is a new problem.
      entry = applicable.find { |candidate| !matched.any? { |used| used.equal?(candidate) } && matches?(candidate, finding) }
      if entry
        matched << entry
        allowed << finding
      else
        unexpected << finding
      end
    end
    Result.new(errors: errors, allowed: allowed, unexpected: unexpected, stale: applicable.reject { |entry| matched.any? { |used| used.equal?(entry) } })
  end

  def describe(finding)
    "#{finding["kind"]} #{finding["elements"].join(" + ")}"
  end
end
