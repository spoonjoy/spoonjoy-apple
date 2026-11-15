# frozen_string_literal: true

require "time"
require_relative "app_review_watch"

# Watches every App Store version that is rolling out in phases and pauses the rollout when crashes appear, so a bad
# build reaches few people and waits for a fix without anyone asking Apple for an expedited review.
#
# Each ACTIVE phased release gets a GitHub issue "Phased release: <platform> <version>" (label phased-release). The
# first run that sees it records the build's TestFlight crash count as the baseline in a hidden marker; a later run
# pauses the rollout (PATCH /v1/appStoreVersionPhasedReleases/{id} phasedReleaseState PAUSED) when
#   - TestFlight counts more crashes on the build than the baseline (GET /v1/builds/{id}/metrics/betaBuildUsages), or
#   - a tester sends TestFlight crash feedback for the build after the rollout started (betaFeedbackCrashSubmissions).
# Only ACTIVE is ever touched, and the state is read again just before the PATCH: a rollout someone completed on
# purpose (COMPLETE), paused or not started is never changed, and the watcher never resumes anything.
#
# The App Store's own crash counts come from the Analytics Reports API ("App Crashes"); Apple started producing them
# for Spoonjoy on 2026-11-15 (ONGOING report request c29e2ac1-c528-4ad9-ac2f-530d1606f4c9), and reading them is a
# follow-up once their first daily instances exist to record.
module PhasedReleaseWatch
  PLATFORMS = %w[IOS MAC_OS].freeze
  LABEL = "phased-release"
  MARKER = /<!-- phased-release-watch baseline=(\d+)(?: paused=([\w-]+))? -->/.freeze

  def self.title(platform, version)
    "Phased release: #{platform} #{version}"
  end

  def self.marker(baseline, paused)
    "<!-- phased-release-watch baseline=#{baseline} paused=#{paused} -->"
  end

  # [baseline, paused] from an issue body, or nil when the body has no marker.
  def self.read_marker(body)
    match = body.to_s.match(MARKER)
    match && [match[1].to_i, match[2].to_s]
  end

  def self.body(platform, version, baseline, paused)
    "#{marker(baseline, paused)}\nThe phased release watch (`.github/workflows/phased-release-watch.yml`) watches the " \
      "#{platform} #{version} rollout here and pauses it on new crashes. Baseline: #{baseline} TestFlight crash(es) on " \
      "the build when the watch began."
  end

  # Pure decision for one version. phased: {"id", "state", "startDate"}; signals: {"crashCount", "feedbackSince"
  # (crash feedback created on or after startDate)}; baseline: from the issue marker, nil on first sight.
  # Returns {"action" => "none" | "baseline" | "pause", "reasons" => [...]}.
  def self.decide(phased:, signals:, baseline:)
    return { "action" => "none", "reasons" => ["phased release is #{phased['state']}"] } unless phased["state"] == "ACTIVE"

    reasons = []
    crashes = signals["crashCount"].to_i
    if baseline.nil?
      reasons << "TestFlight crash feedback since the rollout began: #{signals['feedbackSince']}" if signals["feedbackSince"].to_i.positive?
      return { "action" => reasons.empty? ? "baseline" : "pause", "reasons" => reasons, "baseline" => crashes }
    end

    reasons << "TestFlight crashes on the build rose from #{baseline} to #{crashes}" if crashes > baseline
    reasons << "TestFlight crash feedback since the rollout began: #{signals['feedbackSince']}" if signals["feedbackSince"].to_i.positive?
    { "action" => reasons.empty? ? "none" : "pause", "reasons" => reasons, "baseline" => baseline }
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

    def signals(version_id, start_date)
      build = @asc.get("/v1/appStoreVersions/#{version_id}/build")["data"]
      return { "crashCount" => 0, "feedbackSince" => 0, "build" => nil } unless build

      points = Array(@asc.get("/v1/builds/#{build['id']}/metrics/betaBuildUsages")["data"]).flat_map { |d| Array(d["dataPoints"]) }
      feedback = @asc.get_all("/v1/apps/#{app_id}/betaFeedbackCrashSubmissions", "filter[build]" => build["id"])
      since = start_date && Time.iso8601(start_date)
      recent = feedback.count { |f| since.nil? || Time.iso8601(f.dig("attributes", "createdDate")) >= since }
      { "crashCount" => points.sum { |p| p.dig("values", "crashCount").to_i }, "feedbackSince" => recent,
        "build" => build.dig("attributes", "version") }
    end

    # Returns [[platform, version, action]] for every version it acted on.
    def run
      acted = []
      PLATFORMS.each do |platform|
        rollouts(platform).each do |r|
          next unless r["phased"]["state"] == "ACTIVE"

          acted << [platform, r["version"], watch(platform, r)]
        end
      end
      acted
    end

    private

    def watch(platform, rollout)
      title = PhasedReleaseWatch.title(platform, rollout["version"])
      issue = @issues.open_issue(title)
      baseline, paused = issue && PhasedReleaseWatch.read_marker(issue["body"])
      found = signals(rollout["versionId"], rollout["phased"]["startDate"])
      if paused == "true"
        # Paused before and ACTIVE again: someone resumed it on purpose. Start counting from here.
        @issues.comment(issue["number"], "The #{platform} #{rollout['version']} rollout was resumed. Watching again from " \
                                         "#{found['crashCount']} TestFlight crash(es).")
        @issues.update(issue["number"], "body" => PhasedReleaseWatch.body(platform, rollout["version"], found["crashCount"], "false"))
        return "rebaseline"
      end

      decision = PhasedReleaseWatch.decide(phased: rollout["phased"], signals: found, baseline: baseline)
      @log.puts "#{title} (build #{found['build']}): #{decision['action']} #{decision['reasons'].join('; ')}"
      @issues.ensure_label
      issue ||= @issues.create(title, PhasedReleaseWatch.body(platform, rollout["version"], decision["baseline"], "false"))
      return "baseline" if decision["action"] == "baseline"
      return "none" if decision["action"] == "none" || (!@apply && paused == "dry-run")

      pause(platform, rollout, issue, decision)
    end

    def pause(platform, rollout, issue, decision)
      name = "#{platform} #{rollout['version']}"
      why = decision["reasons"].map { |r| "- #{r}" }.join("\n")
      unless @apply
        @issues.comment(issue["number"], "**Would pause** the #{name} phased release (dry run: the repository variable " \
                                         "`PHASED_RELEASE_AUTO_PAUSE` is not `on`).\n\n#{why}")
        @issues.update(issue["number"], "body" => PhasedReleaseWatch.body(platform, rollout["version"], decision["baseline"], "dry-run"))
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
      @issues.update(issue["number"], "body" => PhasedReleaseWatch.body(platform, rollout["version"], decision["baseline"], "true"))
      "paused"
    end
  end
end
