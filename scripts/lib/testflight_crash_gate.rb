# frozen_string_literal: true

require "time"
require_relative "app_store_listing"

# The TestFlight crash gate in front of "Submit for App Review": a build goes to App Review only after its TestFlight
# copy has been on a tester's device for a soak window with no crash Apple knows of.
#
# iOS 1.2 and 1.2.1 crashed at launch on every iPhone, and the fix had to wait in App Review because only the Account
# Holder can ask for an expedited review. TestFlight already knew: builds 171 and 174 reported 4 and 3 crashes
# (GET /v1/builds/{id}/metrics/betaBuildUsages) and Ari sent crash feedback from 150, 171 and 174. So a build is
# refused when
#   - TestFlight counted a crash on it (betaBuildUsages crashCount), or a tester sent crash feedback for it
#     (GET /v1/apps/{id}/betaFeedbackCrashSubmissions?filter[build]=...), or
#   - nobody has installed it from TestFlight yet (installCount 0): an unopened build has proven nothing, or
#   - it was uploaded less than SOAK_HOURS ago, so crash reports may not have arrived yet.
# Xcode Organizer diagnostic signatures (hangs, disk writes, launch time) are reported but never refuse a build;
# Apple has them only for some builds and answers 404 for others.
#
# An override is an explicit reason given to the workflow (input crash_gate_override). It never hides the findings:
# the run summary records them and the reason.
module TestflightCrashGate
  # 12 hours covers an evening and a morning of a tester's use, and TestFlight's usage metrics showed 174's crashes
  # within hours of its upload. Longer would hold urgent fixes back; phased release and safe mode cover the rest.
  SOAK_HOURS = 12

  # Pure decision. facts: {"buildNumber", "uploadedDate" (ISO 8601), "usage" => {installCount, crashCount,
  # sessionCount} or nil when Apple had no metrics, "crashFeedback" => n, "signatures" => [{type, weight, signature}]}.
  # Returns {"pass" => bool, "refusals" => [...], "notes" => [...]}.
  def self.evaluate(facts, now:, soak_hours: SOAK_HOURS)
    refusals = []
    notes = []
    build = "build #{facts['buildNumber']}"
    usage = facts["usage"]
    if usage.nil?
      refusals << "TestFlight has no usage metrics for #{build}, so nothing shows it ran on a device"
    else
      crashes = usage["crashCount"].to_i
      refusals << "TestFlight counted #{crashes} crash(es) on #{build}" if crashes.positive?
      if usage["installCount"].to_i.zero?
        refusals << "Nobody has installed #{build} from TestFlight yet; install it on an iPhone (or Mac) and use it first"
      end
      notes << "#{build}: #{usage['installCount'].to_i} install(s), #{usage['sessionCount'].to_i} session(s), #{crashes} crash(es) in TestFlight"
    end
    feedback = facts["crashFeedback"].to_i
    refusals << "Testers sent #{feedback} TestFlight crash report(s) for #{build}" if feedback.positive?

    uploaded = Time.iso8601(facts.fetch("uploadedDate"))
    hours = ((now - uploaded) / 3600.0).floor(1)
    if hours < soak_hours
      ready = (uploaded + (soak_hours * 3600)).utc.iso8601
      refusals << "#{build} was uploaded #{hours} hour(s) ago; the soak window is #{soak_hours} hours (ready at #{ready})"
    end
    Array(facts["signatures"]).each do |s|
      notes << "Organizer diagnostic for #{build}: #{s['type']} weight #{s['weight']}: #{s['signature']}"
    end
    { "pass" => refusals.empty?, "refusals" => refusals, "notes" => notes }
  end

  # Reads one build's facts from App Store Connect.
  class Reader
    def initialize(client, app_id:)
      @client = client
      @app_id = app_id
    end

    def facts(build_id)
      build = @client.get("/v1/builds/#{build_id}")["data"]
      { "buildId" => build_id, "buildNumber" => build.dig("attributes", "version"),
        "uploadedDate" => build.dig("attributes", "uploadedDate"), "usage" => usage(build_id),
        "crashFeedback" => crash_feedback(build_id), "signatures" => signatures(build_id) }
    end

    private

    def usage(build_id)
      points = Array(@client.get("/v1/builds/#{build_id}/metrics/betaBuildUsages")["data"]).flat_map { |d| Array(d["dataPoints"]) }
      return nil if points.empty?

      %w[installCount crashCount sessionCount].to_h { |key| [key, points.sum { |p| p.dig("values", key).to_i }] }
    end

    def crash_feedback(build_id)
      @client.get_all("/v1/apps/#{@app_id}/betaFeedbackCrashSubmissions", "filter[build]" => build_id).size
    end

    # Apple answers 404 for a build it has no Organizer data for.
    def signatures(build_id)
      @client.get("/v1/builds/#{build_id}/diagnosticSignatures").fetch("data", []).map do |s|
        a = s["attributes"] || {}
        { "type" => a["diagnosticType"], "weight" => a["weight"], "signature" => a["signature"] }
      end
    rescue AppStoreListing::Error => e
      raise unless e.message.include?("HTTP 404")

      []
    end
  end

  # The launch-on-device-size check: Launch smoke (launch-smoke.yml) installs the Release app on a simulator, which
  # since #355 links with the iPhone's 1 MB main-thread stack, and launches it three times. A submission's iOS source
  # commit must have a run where every device family's Launch smoke job passed. runs: [{"id", "jobs" => [...]}] from
  # the Actions API for that commit, any workflow (Native on a pull request, After TestFlight on main, or a dispatch).
  FAMILY_JOB = /(\A|\/ )Launch smoke \((?!build)[^)]+\)\z/.freeze

  def self.launch_smoke(runs, sha:)
    with_smoke = Array(runs).filter_map do |run|
      jobs = Array(run["jobs"]).select { |job| job["name"].to_s.match?(FAMILY_JOB) }
      [run, jobs] unless jobs.empty?
    end
    if with_smoke.empty?
      return { "pass" => false, "refusals" => ["#{sha} has no Launch smoke run; dispatch launch-smoke.yml on the branch whose head is #{sha}"],
               "notes" => [] }
    end

    run, jobs = with_smoke.max_by { |r, _| r["id"].to_i }
    failed = jobs.reject { |job| job["status"] == "completed" && job["conclusion"] == "success" }
    names = jobs.map { |job| job["name"].sub(%r{\A.*/ }, "") }
    if failed.empty?
      { "pass" => true, "refusals" => [], "notes" => ["Launch smoke passed for #{sha} in run #{run['id']}: #{names.join(', ')}"] }
    else
      { "pass" => false, "notes" => [],
        "refusals" => failed.map { |job| "#{job['name']} is #{job['conclusion'] || job['status']} in run #{run['id']} for #{sha}" } }
    end
  end

  # Markdown for the run summary: the verdict, every finding, and the override when one was used.
  def self.summary(platform, version_string, result, override: nil)
    verdict = if result["pass"] then "passed"
              elsif override then "refused, overridden"
              else "refused"
              end
    lines = ["### TestFlight crash gate: #{platform} #{version_string} #{verdict}", ""]
    result["refusals"].each { |r| lines << "- Refused: #{r}" }
    result["notes"].each { |n| lines << "- #{n}" }
    lines << "- Override reason: #{override}" if override && !result["pass"]
    lines.join("\n") + "\n"
  end
end
