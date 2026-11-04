# frozen_string_literal: true

# Run: ruby scripts/test/xray_expectations_test.rb
require "minitest/autorun"
require "json"
require "open3"
require "tmpdir"
require_relative "../lib/xray_expectations"

class XrayExpectationsTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def report(results, claims)
    {
      "claimSet" => { "version" => "0.1.0" },
      "checker" => { "version" => "0.2.0" },
      "claims" => claims.map { |id| { "id" => id } },
      "results" => results.map { |claim, verdict| { "claim" => claim, "verdict" => verdict, "note" => "#{claim} note", "surface" => "app" } }
    }
  end

  def expected(hold: ["a"], failing: { "f" => "known gap, owned by PR 3" }, open: { "b" => "needs a person", "c" => "needs the 27.3 SDK" })
    { "hold" => hold, "failing" => failing, "open" => open }
  end

  CLAIMS = %w[a b c f].freeze

  def good
    report([%w[a pass], %w[a pass], %w[b skip], %w[c skip], %w[f fail]], CLAIMS)
  end

  def problems(report, expectation = expected)
    XrayExpectations.check(report, expectation)
  end

  def test_as_expected
    assert_empty problems(good)
  end

  def test_a_held_claim_that_fails
    assert_equal 1, problems(report([%w[a pass], %w[a fail], %w[b skip], %w[c skip], %w[f fail]], CLAIMS)).length
  end

  def test_a_held_claim_that_only_skips
    assert_equal 1, problems(report([%w[a skip], %w[b skip], %w[c skip], %w[f fail]], CLAIMS)).length
  end

  def test_an_open_claim_that_fails
    assert_equal 1, problems(report([%w[a pass], %w[b fail], %w[c skip], %w[f fail]], CLAIMS)).length
  end

  def test_an_open_claim_that_starts_holding
    assert_match(/move it to hold/, problems(report([%w[a pass], %w[b pass], %w[c skip], %w[f fail]], CLAIMS)).join)
  end

  def test_a_failing_claim_that_starts_holding
    assert_match(/move it to hold/, problems(report([%w[a pass], %w[b skip], %w[c skip], %w[f pass]], CLAIMS)).join)
  end

  def test_a_failing_claim_may_also_skip
    assert_empty problems(report([%w[a pass], %w[b skip], %w[c skip], %w[f skip]], CLAIMS))
  end

  def test_an_unlisted_claim
    assert_equal 1, problems(good, expected(open: { "b" => "needs a person" })).length
  end

  def test_a_reason_is_required
    assert_equal 1, problems(good, expected(open: { "b" => " ", "c" => "x" })).length
    assert_equal 1, problems(good, expected(failing: { "f" => "" })).length
  end

  def test_a_claim_listed_twice
    assert_equal 1, problems(good, expected(open: { "a" => "x", "b" => "y", "c" => "z" })).length
  end

  def test_a_held_claim_missing_from_the_report
    assert_equal 1, problems(good, expected(hold: %w[a z])).length
  end

  def test_an_open_claim_the_report_leaves_out_is_fine
    # The X-ray omits claims that do not apply yet (entity.property-description with no properties).
    assert_empty problems(good, expected(open: { "b" => "x", "c" => "y", "z" => "not applicable yet" }))
  end

  def test_summary_counts_held_claims
    assert_equal "X-ray: 1 of 4 claims hold (claim set 0.1.0, ax-xray 0.2.0).", XrayExpectations.summary(good)
  end

  def test_the_command_exits_one_on_a_problem_and_zero_otherwise
    Dir.mktmpdir do |dir|
      expected_path = File.join(dir, "expected.json")
      File.write(expected_path, JSON.generate(expected))
      good_path = File.join(dir, "good.json")
      File.write(good_path, JSON.generate(good))
      bad_path = File.join(dir, "bad.json")
      File.write(bad_path, JSON.generate(report([%w[a fail], %w[b skip], %w[c skip], %w[f fail]], CLAIMS)))
      script = File.join(ROOT, "scripts/check-xray.rb")
      _out, _err, status = Open3.capture3(RbConfig.ruby, script, good_path, "--expected", expected_path)
      assert_equal 0, status.exitstatus
      _out, err, status = Open3.capture3(RbConfig.ruby, script, bad_path, "--expected", expected_path)
      assert_equal 1, status.exitstatus
      assert_match(/a: fails/, err)
      _out, _err, status = Open3.capture3(RbConfig.ruby, script)
      assert_equal 2, status.exitstatus
    end
  end

  def test_the_checked_in_expectations_name_a_reason_for_every_open_and_failing_claim
    expectation = JSON.parse(File.read(File.join(ROOT, "config/xray-expected.json")))
    (expectation.fetch("open").merge(expectation.fetch("failing"))).each do |claim, reason|
      refute_empty reason.strip, "#{claim} has no reason"
    end
  end
end
