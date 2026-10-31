# frozen_string_literal: true

# Run: ruby scripts/test/layout_audit_gate_test.rb
require "minitest/autorun"
require "open3"
require "tmpdir"
require_relative "../lib/layout_audit_gate"

class LayoutAuditGateTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def reference(identifier, label = "")
    { "type" => "button", "identifier" => identifier, "label" => label, "frame" => {} }
  end

  def audit(overlaps: [], text_problems: [], clipped: [])
    {
      "emittedBy" => "SpoonjoyLayoutAuditUITests",
      "route" => "cook-mode",
      "observedDynamicTypeSize" => "accessibility5",
      "report" => {
        "noOverlap" => overlaps.empty?,
        "textFits" => text_problems.empty?,
        "controlsOnScreen" => clipped.empty?,
        "interactiveCount" => 4,
        "textCount" => 6,
        "drawnTextCount" => 8,
        "overlaps" => overlaps,
        "textProblems" => text_problems,
        "clippedControls" => clipped
      }
    }
  end

  def proof_for(audit)
    report = audit["report"]
    { "platform" => "ios", "route" => "cook-mode", "layoutAudit" => "apple/audit.json" }
      .merge(LayoutAuditGate::FIELDS.to_h { |field| [field, report[field]] })
  end

  def known(kind, elements, route: "cook-mode")
    { "route" => route, "dynamicType" => "accessibility5", "kind" => kind, "elements" => elements, "task" => "Task 10", "reason" => "Known." }
  end

  def ring_overlap
    { "first" => reference("cook.timer.ring"), "second" => reference("cookMode.coverGlance.next"), "intersection" => {} }
  end

  # Task 10 fixed every known finding; strict captures now pass with nothing excused.
  def test_checked_in_known_findings_are_valid_and_empty
    assert_empty LayoutAuditGate.load_known_findings
  end

  def test_one_entry_excuses_one_finding
    dock = ->(first, second) { { "first" => reference("", first), "second" => reference("", second), "intersection" => {} } }
    found = audit(overlaps: [dock.call("Kitchen", "Recipes"), dock.call("Kitchen", "Recipes")])
    result = LayoutAuditGate.evaluate(proof: proof_for(found), audit: found, known: [known("overlap", ["label:Kitchen", "label:Recipes"])])

    refute result.passes?
    assert_equal 1, result.allowed.length
    assert_equal ["overlap label:Kitchen + label:Recipes"], result.unexpected.map { |finding| LayoutAuditGate.describe(finding) }
  end

  def test_duplicate_known_findings_are_rejected
    entry = known("overlap", ["a", "b"])
    swapped = known("overlap", ["b", "a"])

    assert_equal ["known finding 1 repeats known finding 0"], LayoutAuditGate.validate_known_findings({ "findings" => [entry, swapped] })
  end

  def test_a_clean_audit_passes
    clean = audit
    result = LayoutAuditGate.evaluate(proof: proof_for(clean), audit: clean, known: [])

    assert result.passes?
  end

  def test_a_listed_finding_passes_and_an_unlisted_one_fails
    found = audit(
      overlaps: [ring_overlap],
      text_problems: [{ "kind" => "truncated", "text" => reference("", "Saved kitchen may be out of date") }],
      clipped: [{ "control" => reference("cook.timer.ring"), "visibleFraction" => 0.7 }]
    )
    listed = [known("overlap", ["cookMode.coverGlance.next", "cook.timer.ring"]), known("clippedControl", ["cook.timer.ring"])]
    result = LayoutAuditGate.evaluate(proof: proof_for(found), audit: found, known: listed)

    refute result.passes?
    assert_equal ["overlap cook.timer.ring + cookMode.coverGlance.next", "clippedControl cook.timer.ring"], result.allowed.map { |finding| LayoutAuditGate.describe(finding) }
    assert_equal ["truncated label:Saved kitchen may be out of date"], result.unexpected.map { |finding| LayoutAuditGate.describe(finding) }
  end

  def test_an_entry_naming_an_element_by_label_matches_it_when_it_has_an_identifier
    dock = { "first" => reference("house", "Kitchen"), "second" => reference("book.closed", "Recipes"), "intersection" => {} }
    found = audit(overlaps: [dock])
    by_label = known("overlap", ["label:Recipes", "label:Kitchen"])
    mixed = known("overlap", ["house", "label:Recipes"])
    wrong = known("overlap", ["label:Kitchen", "label:Cookbooks"])

    assert LayoutAuditGate.evaluate(proof: proof_for(found), audit: found, known: [by_label]).passes?
    assert LayoutAuditGate.evaluate(proof: proof_for(found), audit: found, known: [mixed]).passes?
    result = LayoutAuditGate.evaluate(proof: proof_for(found), audit: found, known: [wrong])
    refute result.passes?
    assert_equal ["overlap book.closed + house"], result.unexpected.map { |finding| LayoutAuditGate.describe(finding) }
  end

  def test_an_entry_for_another_route_or_size_does_not_excuse_a_finding
    found = audit(overlaps: [ring_overlap])
    other_route = known("overlap", ["cook.timer.ring", "cookMode.coverGlance.next"], route: "recipe-detail")
    other_size = known("overlap", ["cook.timer.ring", "cookMode.coverGlance.next"]).merge("dynamicType" => "large")
    result = LayoutAuditGate.evaluate(proof: proof_for(found), audit: found, known: [other_route, other_size])

    refute result.passes?
    assert_empty result.stale
  end

  def test_a_listed_finding_no_longer_seen_is_reported_stale
    clean = audit
    listed = known("clippedControl", ["cook.timer.ring"])
    result = LayoutAuditGate.evaluate(proof: proof_for(clean), audit: clean, known: [listed])

    assert result.passes?
    assert_equal [listed], result.stale
  end

  def test_a_missing_audit_or_field_fails
    assert_equal ["proof has no layout audit"], LayoutAuditGate.evaluate(proof: {}, audit: nil, known: []).errors
    assert_equal ["layout audit apple/a.json is missing"], LayoutAuditGate.evaluate(proof: { "layoutAudit" => "apple/a.json" }, audit: nil, known: []).errors
    clean = audit
    result = LayoutAuditGate.evaluate(proof: proof_for(clean).reject { |key, _| key == "controlsOnScreen" }, audit: clean, known: [])
    refute result.passes?
    assert_equal ["controlsOnScreen is missing or not boolean"], result.errors
  end

  def test_an_audit_that_measured_nothing_fails
    empty = audit
    empty["report"].merge!("interactiveCount" => 0, "textCount" => 0)
    result = LayoutAuditGate.evaluate(proof: proof_for(empty), audit: empty, known: [])
    refute result.passes?
    assert_equal ["layout audit measured no controls or text"], result.errors

    unread = audit
    unread["report"]["drawnTextCount"] = 0
    result = LayoutAuditGate.evaluate(proof: proof_for(unread), audit: unread, known: [])
    refute result.passes?
    assert_equal ["layout audit read no drawn text"], result.errors

    uncounted = audit
    uncounted["report"] = uncounted["report"].reject { |key, _| key.end_with?("Count") }
    result = LayoutAuditGate.evaluate(proof: proof_for(uncounted), audit: uncounted, known: [])
    assert_equal ["layout audit measured no controls or text", "layout audit read no drawn text"], result.errors

    texts_only = audit
    texts_only["report"]["interactiveCount"] = 0
    assert LayoutAuditGate.evaluate(proof: proof_for(texts_only), audit: texts_only, known: []).passes?
  end

  def test_known_findings_must_name_route_size_kind_elements_owner_and_reason
    good = known("overlap", ["a", "b"])

    assert_empty LayoutAuditGate.validate_known_findings({ "findings" => [good] })
    assert_equal ["known findings must be an object with a findings array"], LayoutAuditGate.validate_known_findings([])
    assert_equal ["known finding 0 must be an object"], LayoutAuditGate.validate_known_findings({ "findings" => ["x"] })
    problems = LayoutAuditGate.validate_known_findings({ "findings" => [{ "kind" => "overlap", "elements" => ["a"], "task" => "Task 9" }] })
    assert_equal [
      "known finding 0 must name a route",
      "known finding 0 must name a dynamicType",
      "known finding 0 must list 2 element identifier(s)",
      "known finding 0 must be owned by Task 10",
      "known finding 0 must give a reason"
    ], problems
    assert_includes LayoutAuditGate.validate_known_findings({ "findings" => [good.merge("kind" => "wobble")] }), "known finding 0 kind must be one of overlap, truncated, outsideScreen, outsideContainer, clippedControl"
  end

  def test_strict_mode_comes_from_the_environment
    assert LayoutAuditGate.strict?({ "SPOONJOY_REQUIRE_LAYOUT_AUDIT" => "1" })
    refute LayoutAuditGate.strict?({})
  end

  def test_the_command_reports_without_failing_by_default_and_fails_in_strict_mode
    Dir.mktmpdir do |dir|
      found = audit(overlaps: [ring_overlap])
      Dir.mkdir(File.join(dir, "apple"))
      File.write(File.join(dir, "apple/audit.json"), JSON.generate(found))
      proof_path = File.join(dir, "proof.json")
      File.write(proof_path, JSON.generate(proof_for(found)))
      known_path = File.join(dir, "known.json")
      File.write(known_path, JSON.generate({ "findings" => [] }))
      command = ["ruby", File.join(ROOT, "scripts/check-layout-audit.rb"), "--artifact-root", dir, "--proof", proof_path, "--known-findings", known_path]
      environment = { "SPOONJOY_REQUIRE_LAYOUT_AUDIT" => nil }

      output, status = Open3.capture2e(environment, *command)
      assert status.success?, output
      assert_includes output, "NEW overlap cook.timer.ring + cookMode.coverGlance.next"
      assert_includes output, "fail (not gating)"

      output, status = Open3.capture2e(environment.merge("SPOONJOY_REQUIRE_LAYOUT_AUDIT" => "1"), *command)
      refute status.success?, output
      assert_includes output, "fail (strict)"

      File.write(known_path, JSON.generate({ "findings" => [known("overlap", ["cook.timer.ring", "cookMode.coverGlance.next"])] }))
      output, status = Open3.capture2e(environment, *command, "--strict")
      assert status.success?, output
      assert_includes output, "known (Task 10) overlap"
    end
  end
end
