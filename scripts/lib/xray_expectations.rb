# frozen_string_literal: true

# Holds an Ouro AX X-ray report (ouro-ax-xray's report.json) to config/xray-expected.json.
#
# The expected file sorts every claim into one of three lists:
# - "hold": the claim must hold (every check on it passes).
# - "failing": a known gap, with the reason and who owns it. It may fail or skip; once it holds, move it to hold.
# - "open": the claim can't be settled in this lane (it needs the behaviour stage, SiriEvaluations, a person or a newer
#   SDK), with the reason. It must not fail; once it holds, move it to hold. The report may leave it out.
# A claim the report has that no list names is a problem too, so the file always says what the app proves.
# Ported from Ouro MD's scripts/check-xray.py, with the failing list added.
module XrayExpectations
  module_function

  # claim id -> "hold", "fail" or "open" (skipped or not checked).
  def statuses(report)
    verdicts = Hash.new { |hash, key| hash[key] = [] }
    report.fetch("results").each { |result| verdicts[result.fetch("claim")] << result.fetch("verdict") }
    report.fetch("claims").to_h do |claim|
      found = verdicts[claim.fetch("id")]
      status = if found.include?("fail")
        "fail"
      elsif !found.empty? && found.all?("pass")
        "hold"
      else
        "open"
      end
      [claim.fetch("id"), status]
    end
  end

  # The problems, one line each, each ending in its fix; empty when the report is as expected.
  def check(report, expected)
    problems = []
    hold = expected.fetch("hold")
    failing = expected.fetch("failing", {})
    open = expected.fetch("open")
    { "failing" => failing, "open" => open }.each do |list, reasons|
      reasons.each do |claim, reason|
        problems << "#{claim}: listed under #{list} with no reason. Fix: say why in config/xray-expected.json." if reason.to_s.strip.empty?
      end
    end
    listed = hold + failing.keys + open.keys
    listed.group_by(&:itself).select { |_, copies| copies.length > 1 }.each_key do |claim|
      problems << "#{claim}: listed more than once. Fix: keep it in one list in config/xray-expected.json."
    end

    found = statuses(report)
    (hold - found.keys).each do |claim|
      problems << "#{claim}: expected to hold but is not in the report (claim set #{report.dig("claimSet", "version")}). Fix: check the app still has what it covers, or move it to open with the reason."
    end
    found.each do |claim, status|
      notes = report.fetch("results").select { |r| r["claim"] == claim && r["verdict"] != "pass" }.map { |r| r["note"] }.first(3).join("; ")
      if hold.include?(claim)
        problems << "#{claim}: fails (#{notes}). Fix: the report's fix for #{claim}, then run the X-ray again." if status == "fail"
        problems << "#{claim}: expected to hold but is open (#{notes}). Fix: restore it, or move it to open with the reason." if status == "open"
      elsif failing.key?(claim) || open.key?(claim)
        list = failing.key?(claim) ? "failing" : "open"
        problems << "#{claim}: holds now but is listed under #{list}. Fix: move it to hold in config/xray-expected.json." if status == "hold"
        problems << "#{claim}: fails (#{notes}) but is listed as open. Fix: the report's fix for #{claim}, or list it under failing with the reason and owner." if status == "fail" && list == "open"
      else
        problems << "#{claim}: #{status} and not listed. Fix: add it to config/xray-expected.json with the reason."
      end
    end
    problems
  end

  def summary(report)
    found = statuses(report)
    held = found.count { |_, status| status == "hold" }
    "X-ray: #{held} of #{found.length} claims hold (claim set #{report.dig("claimSet", "version")}, ax-xray #{report.dig("checker", "version")})."
  end
end
