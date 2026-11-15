# frozen_string_literal: true

require "time"
require_relative "app_review_watch"

# Watches every App Store version that is rolling out in phases and pauses the rollout when crashes appear, so a bad
# build reaches few people and waits for a fix without anyone asking Apple for an expedited review.
#
# Each ACTIVE phased release gets a GitHub issue "Phased release: <platform> <version>" (label phased-release). The
# first run that sees it records the build's TestFlight crash count, crash feedback count and the rollout's
# totalPauseDuration in a hidden marker; a later run pauses the rollout (PATCH /v1/appStoreVersionPhasedReleases/{id} phasedReleaseState PAUSED) when
#   - TestFlight counts more crashes on the build than the marker (GET /v1/builds/{id}/metrics/betaBuildUsages), or
#   - testers sent more TestFlight crash feedback for the build than the marker (betaFeedbackCrashSubmissions).
# On first sight, crash feedback sent since the rollout started pauses at once. Only ACTIVE is ever touched, and the
# state is read again just before the PATCH: a rollout someone completed on purpose (COMPLETE), paused or not started
# is never changed, and the watcher never resumes anything. A rollout seen PAUSED is marked paused; when it is ACTIVE
# again, or its totalPauseDuration grew (someone paused and resumed it between runs), the marker moves to the counts at
# that moment, so a deliberate resume is never paused again on old crashes. The marker is written before any comment,
# so a failed GitHub call can't lose it. The issue closes when the rollout is COMPLETE.
#
# The App Store's own crash counts come from the Analytics Reports API ("App Crashes"); Apple started producing them
# for Spoonjoy on 2026-11-15 (ONGOING report request c29e2ac1-c528-4ad9-ac2f-530d1606f4c9), and reading them is a
# follow-up once their first daily instances exist to record.
module PhasedReleaseWatch
  PLATFORMS = %w[IOS MAC_OS].freeze
  LABEL = "phased-release"
  MARKER = /<!-- phased-release-watch crashes=(\d+) feedback=(\d+) pauses=(\d+) state=([\w-]+) -->/.freeze

  def self.title(platform, version)
    "Phased release: #{platform} #{version}"
  end

  # mark: {"crashes", "feedback", "pauses" (the rollout's totalPauseDuration when recorded),
  #        "state" => "watching" | "dry-run" (said it would pause) | "paused"}.
  def self.marker(mark)
    "<!-- phased-release-watch crashes=#{mark['crashes']} feedback=#{mark['feedback']} pauses=#{mark['pauses'].to_i} " \
      "state=#{mark['state']} -->"
  end

  # The mark in an issue body, or nil when the body has none.
  def self.read_marker(body)
    match = body.to_s.match(MARKER)
    match && { "crashes" => match[1].to_i, "feedback" => match[2].to_i, "pauses" => match[3].to_i, "state" => match[4] }
  end

  def self.body(platform, version, mark)
    "#{marker(mark)}\nThe phased release watch (`.github/workflows/phased-release-watch.yml`) watches the " \
      "#{platform} #{version} rollout here and pauses it on new crashes. It counts from #{mark['crashes']} TestFlight " \
      "crash(es) and #{mark['feedback']} crash report(s) on the build. Closing this issue restarts the watch from " \
      "the counts at that moment."
  end

  # Pure decision for one ACTIVE-or-not rollout. phased: {"state", "totalPauseDuration"}; signals: {"crashCount",
  # "feedbackTotal", "feedbackSince" (crash feedback created on or after the rollout's startDate)}; mark: from the
  # issue, nil on first sight. On first sight, feedback since the start pauses only a rollout never paused before (one
  # that was paused and resumed was resumed on purpose), and the recorded feedback leaves those reports out, so the
  # rise is still there for the next run if this one can't pause (dry run, or a failed write).
  # Returns {"action" => "none" | "baseline" | "pause", "reasons" => [...], "mark" => the counts to record}.
  def self.decide(phased:, signals:, mark:)
    return { "action" => "none", "reasons" => ["phased release is #{phased['state']}"] } unless phased["state"] == "ACTIVE"

    crashes = signals["crashCount"].to_i
    feedback = signals["feedbackTotal"].to_i
    reasons = []
    pauses = phased["totalPauseDuration"].to_i
    if mark.nil?
      since = pauses.zero? ? signals["feedbackSince"].to_i : 0
      reasons << "TestFlight crash reports since the rollout began: #{since}" if since.positive?
      counts = { "crashes" => crashes, "feedback" => feedback - since, "pauses" => pauses, "state" => "watching" }
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

    def versions(platform)
      @asc.get_all("/v1/apps/#{app_id}/appStoreVersions", "filter[platform]" => platform)
    end

    def phased_release(version_id)
      data = @asc.get("/v1/appStoreVersions/#{version_id}/appStoreVersionPhasedRelease")["data"]
      data && { "id" => data["id"], "state" => data.dig("attributes", "phasedReleaseState"),
                "startDate" => data.dig("attributes", "startDate"),
                "totalPauseDuration" => data.dig("attributes", "totalPauseDuration").to_i }
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
        versions(platform).each do |v|
          name = v.dig("attributes", "versionString")
          phased = phased_release(v["id"])
          next unless phased

          r = { "versionId" => v["id"], "version" => name, "phased" => phased }
          action = case phased["state"]
                   when "ACTIVE" then watch(platform, r)
                   when "PAUSED" then mark_paused(platform, r)
                   when "COMPLETE" then close_if_open(platform, r)
                   end
          acted << [platform, name, action] if action
        rescue StandardError => e
          errors << "#{platform} #{name}: #{e.class}: #{e.message[0, 300]}"
        end
      end
      raise AppStoreListing::Error, "Phased release watch failed for #{errors.join('; ')}" unless errors.empty?

      acted
    end

    private

    # A paused rollout (by the watcher or by hand) is marked so its resume is recognised, whatever happened in between.
    def mark_paused(platform, rollout)
      issue = @issues.open_issue(PhasedReleaseWatch.title(platform, rollout["version"]))
      mark = issue && PhasedReleaseWatch.read_marker(issue["body"])
      return nil if mark.nil? || mark["state"] == "paused"

      @issues.update(issue["number"], "body" => PhasedReleaseWatch.body(platform, rollout["version"],
                                                                        mark.merge("state" => "paused")))
      "marked-paused"
    end

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
      pauses = rollout["phased"]["totalPauseDuration"].to_i
      if mark && (mark["state"] == "paused" || pauses > mark["pauses"])
        # Paused before and ACTIVE again: someone resumed it on purpose. Count from here.
        now = { "crashes" => found["crashCount"], "feedback" => found["feedbackTotal"], "pauses" => pauses,
                "state" => "watching" }
        @issues.update(issue["number"], "body" => PhasedReleaseWatch.body(platform, rollout["version"], now))
        @issues.comment(issue["number"], "The #{platform} #{rollout['version']} rollout was resumed. Watching again from " \
                                         "#{now['crashes']} TestFlight crash(es) and #{now['feedback']} crash report(s).")
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
        # Keeps the counts, so turning the switch on acts on this finding. Marker first, so the comment can't repeat.
        @issues.update(issue["number"], "body" => PhasedReleaseWatch.body(platform, rollout["version"],
                                                                          decision["mark"].merge("state" => "dry-run")))
        @issues.comment(issue["number"], "**Would pause** the #{name} phased release (dry run: the repository variable " \
                                         "`PHASED_RELEASE_AUTO_PAUSE` is not `on`).\n\n#{why}")
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
      # Marker first: if the comment fails, the resume is still recognised.
      paused = { "crashes" => found["crashCount"], "feedback" => found["feedbackTotal"],
                 "pauses" => current["totalPauseDuration"], "state" => "paused" }
      @issues.update(issue["number"], "body" => PhasedReleaseWatch.body(platform, rollout["version"], paused))
      @issues.comment(issue["number"], "**Paused** the #{name} phased release: new people stop getting this version " \
                                       "(Apple allows a pause of up to 30 days).\n\n#{why}\n\nShip a fixed build, or resume the rollout " \
                                       "(phasedReleaseState ACTIVE) once the crashes are understood; the watch then counts from there.")
      "paused"
    end
  end
end
