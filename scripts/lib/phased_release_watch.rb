# frozen_string_literal: true

require "time"
require_relative "app_review_watch"

# Watches every App Store version that is rolling out in phases and pauses the rollout when crashes appear, so a bad
# build reaches few people and waits for a fix without anyone asking Apple for an expedited review.
#
# Each ACTIVE phased release gets a GitHub issue "Phased release: <platform> <version>" (label phased-release). The
# first run that sees it records the build's TestFlight crash count and crash feedback count in a hidden marker; a
# later run pauses the rollout (PATCH /v1/appStoreVersionPhasedReleases/{id} phasedReleaseState PAUSED) when
#   - TestFlight counts more crashes on the build than the marker (GET /v1/builds/{id}/metrics/betaBuildUsages), or
#   - testers sent more TestFlight crash feedback for the build than the marker (betaFeedbackCrashSubmissions).
# On first sight, crash feedback sent since the rollout started pauses at once. Only ACTIVE is ever touched, and the
# state is read again just before the PATCH: a rollout someone completed on purpose (COMPLETE), paused or not started
# is never changed, and the watcher never resumes anything. When someone resumes a paused rollout, the marker moves to
# the counts at that moment. The issue closes when the rollout is COMPLETE.
#
# The App Store's own crash counts come from the Analytics Reports API ("App Crashes"); Apple started producing them
# for Spoonjoy on 2026-11-15 (ONGOING report request c29e2ac1-c528-4ad9-ac2f-530d1606f4c9), and reading them is a
# follow-up once their first daily instances exist to record.
module PhasedReleaseWatch
  PLATFORMS = %w[IOS MAC_OS].freeze
  LABEL = "phased-release"
  MARKER = /<!-- phased-release-watch crashes=(\d+) feedback=(\d+) state=([\w-]+) -->/.freeze

  def self.title(platform, version)
    "Phased release: #{platform} #{version}"
  end

  # mark: {"crashes", "feedback", "state" => "watching" | "dry-run" (said it would pause) | "paused"}.
  def self.marker(mark)
    "<!-- phased-release-watch crashes=#{mark['crashes']} feedback=#{mark['feedback']} state=#{mark['state']} -->"
  end

  # The mark in an issue body, or nil when the body has none.
  def self.read_marker(body)
    match = body.to_s.match(MARKER)
    match && { "crashes" => match[1].to_i, "feedback" => match[2].to_i, "state" => match[3] }
  end

  def self.body(platform, version, mark)
    "#{marker(mark)}\nThe phased release watch (`.github/workflows/phased-release-watch.yml`) watches the " \
      "#{platform} #{version} rollout here and pauses it on new crashes. It counts from #{mark['crashes']} TestFlight " \
      "crash(es) and #{mark['feedback']} crash report(s) on the build."
  end

  # Pure decision for one ACTIVE-or-not rollout. signals: {"crashCount", "feedbackTotal", "feedbackSince" (crash
  # feedback created on or after the rollout's startDate)}; mark: from the issue, nil on first sight.
  # Returns {"action" => "none" | "baseline" | "pause", "reasons" => [...], "mark" => the counts to record}.
  def self.decide(phased:, signals:, mark:)
    return { "action" => "none", "reasons" => ["phased release is #{phased['state']}"] } unless phased["state"] == "ACTIVE"

    crashes = signals["crashCount"].to_i
    feedback = signals["feedbackTotal"].to_i
    reasons = []
    if mark.nil?
      if signals["feedbackSince"].to_i.positive?
        reasons << "TestFlight crash reports since the rollout began: #{signals['feedbackSince']}"
      end
      counts = { "crashes" => crashes, "feedback" => feedback, "state" => "watching" }
      return { "action" => reasons.empty? ? "baseline" : "pause", "reasons" => reasons, "mark" => counts }
    end

    reasons << "TestFlight crashes on the build rose from #{mark['crashes']} to #{crashes}" if crashes > mark["crashes"]
    reasons << "TestFlight crash reports on the build rose from #{mark['feedback']} to #{feedback}" if feedback > mark["feedback"]
    { "action" => reasons.empty? ? "none" : "pause", "reasons" => reasons, "mark" => mark }
  end

  class Runner
    def initialize(asc, issues, bundle_id:, apply:, log: $stdout)
      @asc = asc
      @issues = issues
      @bundle_id = bundle_id
      @apply = apply
      @log = log
    end

    def app_id
      @app_id ||= begin
        apps = @asc.get("/v1/apps", "filter[bundleId]" => @bundle_id)["data"]
        raise AppStoreListing::Error, "No App Store Connect app has bundle ID #{@bundle_id}" if apps.empty?

        apps.first["id"]
      end
    end

    # Versions whose phased release exists, with its state.
    def rollouts(platform)
      @asc.get_all("/v1/apps/#{app_id}/appStoreVersions", "filter[platform]" => platform).filter_map do |v|
        phased = phased_release(v["id"])
        next unless phased

        { "versionId" => v["id"], "version" => v.dig("attributes", "versionString"), "phased" => phased }
      end
    end

    def phased_release(version_id)
      data = @asc.get("/v1/appStoreVersions/#{version_id}/appStoreVersionPhasedRelease")["data"]
      data && { "id" => data["id"], "state" => data.dig("attributes", "phasedReleaseState"),
                "startDate" => data.dig("attributes", "startDate") }
    rescue AppStoreListing::Error => e
      raise unless e.message.include?("HTTP 404")

      nil
    end

    # Sums the usage data points Apple returns (one, covering the last year, in every recording so far).
    def signals(version_id, start_date)
      build = @asc.get("/v1/appStoreVersions/#{version_id}/build")["data"]
      return { "crashCount" => 0, "feedbackTotal" => 0, "feedbackSince" => 0, "build" => nil } unless build

      points = Array(@asc.get("/v1/builds/#{build['id']}/metrics/betaBuildUsages")["data"]).flat_map { |d| Array(d["dataPoints"]) }
      feedback = @asc.get_all("/v1/apps/#{app_id}/betaFeedbackCrashSubmissions", "filter[build]" => build["id"])
      since = start_date && Time.iso8601(start_date)
      recent = feedback.count { |f| since.nil? || Time.iso8601(f.dig("attributes", "createdDate")) >= since }
      { "crashCount" => points.sum { |p| p.dig("values", "crashCount").to_i }, "feedbackTotal" => feedback.size,
        "feedbackSince" => recent, "build" => build.dig("attributes", "version") }
    end

    # Returns [[platform, version, action]] for every rollout it looked at. One rollout's error doesn't stop the
    # others; the run raises after them all.
    def run
      acted = []
      errors = []
      PLATFORMS.each do |platform|
        rollouts(platform).each do |r|
          action = case r["phased"]["state"]
                   when "ACTIVE" then watch(platform, r)
                   when "COMPLETE" then close_if_open(platform, r)
                   end
          acted << [platform, r["version"], action] if action
        rescue AppStoreListing::Error => e
          errors << "#{platform} #{r['version']}: #{e.message[0, 300]}"
        end
      end
      raise AppStoreListing::Error, "Phased release watch failed for #{errors.join('; ')}" unless errors.empty?

      acted
    end

    private

    def close_if_open(platform, rollout)
      issue = @issues.open_issue(PhasedReleaseWatch.title(platform, rollout["version"]))
      return nil unless issue

      @issues.comment(issue["number"], "The #{platform} #{rollout['version']} phased release is complete; the watch is done.")
      @issues.update(issue["number"], "state" => "closed")
      "closed"
    end

    def watch(platform, rollout)
      title = PhasedReleaseWatch.title(platform, rollout["version"])
      issue = @issues.open_issue(title)
      mark = issue && PhasedReleaseWatch.read_marker(issue["body"])
      found = signals(rollout["versionId"], rollout["phased"]["startDate"])
      if mark && mark["state"] == "paused"
        # Paused before and ACTIVE again: someone resumed it on purpose. Count from here.
        now = { "crashes" => found["crashCount"], "feedback" => found["feedbackTotal"], "state" => "watching" }
        @issues.comment(issue["number"], "The #{platform} #{rollout['version']} rollout was resumed. Watching again from " \
                                         "#{now['crashes']} TestFlight crash(es) and #{now['feedback']} crash report(s).")
        @issues.update(issue["number"], "body" => PhasedReleaseWatch.body(platform, rollout["version"], now))
        return "rebaseline"
      end

      decision = PhasedReleaseWatch.decide(phased: rollout["phased"], signals: found, mark: mark)
      @log.puts "#{title} (build #{found['build']}): #{decision['action']} #{decision['reasons'].join('; ')}"
      if mark.nil?
        @issues.ensure_label
        # An issue someone opened by hand, or whose marker was edited away, gets the marker now.
        body = PhasedReleaseWatch.body(platform, rollout["version"], decision["mark"])
        if issue
          @issues.update(issue["number"], "body" => body)
        else
          issue = @issues.create(title, body)
        end
      end
      return "baseline" if decision["action"] == "baseline"
      return "none" if decision["action"] == "none" || (!@apply && decision["mark"]["state"] == "dry-run")

      pause(platform, rollout, issue, decision, found)
    end

    def pause(platform, rollout, issue, decision, found)
      name = "#{platform} #{rollout['version']}"
      why = decision["reasons"].map { |r| "- #{r}" }.join("\n")
      unless @apply
        @issues.comment(issue["number"], "**Would pause** the #{name} phased release (dry run: the repository variable " \
                                         "`PHASED_RELEASE_AUTO_PAUSE` is not `on`).\n\n#{why}")
        # Keeps the counts, so turning the switch on acts on this finding.
        @issues.update(issue["number"], "body" => PhasedReleaseWatch.body(platform, rollout["version"],
                                                                          decision["mark"].merge("state" => "dry-run")))
        return "would-pause"
      end

      # Read the state again right before writing: a deliberate COMPLETE or a pause made since must stand.
      current = phased_release(rollout["versionId"])
      unless current && current["state"] == "ACTIVE"
        @log.puts "#{name}: phased release is now #{current && current['state']}; leaving it alone"
        return "none"
      end

      @asc.patch("/v1/appStoreVersionPhasedReleases/#{current['id']}", { "data" => { "type" => "appStoreVersionPhasedReleases",
        "id" => current["id"], "attributes" => { "phasedReleaseState" => "PAUSED" } } })
      @issues.comment(issue["number"], "**Paused** the #{name} phased release: new people stop getting this version " \
                                       "(Apple allows a pause of up to 30 days).\n\n#{why}\n\nShip a fixed build, or resume the rollout " \
                                       "(phasedReleaseState ACTIVE) once the crashes are understood; the watch then counts from there.")
      paused = { "crashes" => found["crashCount"], "feedback" => found["feedbackTotal"], "state" => "paused" }
      @issues.update(issue["number"], "body" => PhasedReleaseWatch.body(platform, rollout["version"], paused))
      "paused"
    end
  end
end
