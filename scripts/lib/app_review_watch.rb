# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require_relative "app_store_listing"

# Watches App Review for every App Store version of the app and announces state changes on a GitHub issue per
# platform and version, so a rejection or an approval is seen within one run instead of when someone next looks.
# The last announced state lives in a hidden marker in the issue body, not in the repo.
module AppReviewWatch
  PLATFORMS = %w[IOS MAC_OS].freeze
  LABEL = "app-review"
  REJECTED = %w[REJECTED METADATA_REJECTED INVALID_BINARY].freeze
  # States that need no issue unless one is already open (a finished, removed or not-yet-submitted version).
  QUIET = %w[PREPARE_FOR_SUBMISSION READY_FOR_SALE READY_FOR_DISTRIBUTION REPLACED_WITH_NEW_VERSION
             DEVELOPER_REMOVED_FROM_SALE REMOVED_FROM_SALE].freeze
  LIVE = %w[READY_FOR_SALE READY_FOR_DISTRIBUTION].freeze
  MARKER = /<!-- app-review-watch state=([A-Z_]+) -->/.freeze

  READ_REASON = <<~TEXT.strip
    To read App Review's reason:
    - Run the App Store release workflow with action `review-messages` for this platform and version. It lists the review submission and tries every Resolution Center route; with only the API key, Apple answers 404 or 401.
    - The reason text needs a signed-in Apple ID web session: from a signed-in App Store Connect page, fetch `/iris/v1/resolutionCenterThreads?filter[reviewSubmission]=<submission id>` and then `/iris/v1/resolutionCenterThreads/<thread id>/resolutionCenterMessages?include=fromActor,rejections`. Never print or store the session cookies.
    - Apple also emails the account holder "There's an issue with your … submission", without the reason.
  TEXT

  def self.title(platform, version)
    "App Review: #{platform} #{version}"
  end

  def self.marker(state)
    "<!-- app-review-watch state=#{state} -->"
  end

  def self.last_state(body)
    body.to_s[MARKER, 1]
  end

  def self.body(platform, version, state)
    "#{marker(state)}\nThe App Review watch (`.github/workflows/app-review-watch.yml`) tracks #{platform} #{version} here. " \
      "It comments when the state changes and closes this issue when the version is live.\n\nCurrent state: `#{state}`"
  end

  # Whether a version is worth looking at this run.
  def self.watch?(state, open_issue:)
    open_issue || !QUIET.include?(state)
  end

  # Pure decision: what to announce when a version moves from previous (nil when never announced) to current.
  # Returns nil for no change, else {"comment" => text, "close" => bool}.
  def self.transition(previous, current, platform:, version:)
    return nil if previous == current

    name = "#{platform} #{version}"
    comment =
      if REJECTED.include?(current)
        "**Rejected.** App Review returned #{name} (`#{current}`). Fix the issue and resubmit.\n\n#{READ_REASON}"
      elsif current == "PENDING_DEVELOPER_RELEASE"
        "**Approved.** #{name} passed App Review and waits for a manual release (App Store release workflow, action `release`)."
      elsif %w[PENDING_APPLE_RELEASE PROCESSING_FOR_APP_STORE ACCEPTED].include?(current)
        "**Approved.** #{name} passed App Review and Apple is releasing it (`#{current}`)."
      elsif LIVE.include?(current)
        "**Live.** #{name} is on the App Store (`#{current}`)."
      elsif current == "IN_REVIEW"
        "#{name} is in review."
      elsif current == "WAITING_FOR_REVIEW"
        "#{name} is waiting for review#{previous && REJECTED.include?(previous) ? ' again after a resubmission' : ''}."
      else
        "#{name} changed from `#{previous || 'unknown'}` to `#{current}`."
      end
    { "comment" => comment, "close" => LIVE.include?(current) }
  end

  # Minimal GitHub issues client for one repository.
  class GitHubIssues
    def initialize(repo:, token:)
      @repo = repo
      @token = token
    end

    def open_issue(title)
      query = URI.encode_www_form("state" => "open", "labels" => LABEL, "per_page" => 100)
      request(Net::HTTP::Get, "/repos/#{@repo}/issues?#{query}").find { |i| i["title"] == title && !i["pull_request"] }
    end

    def ensure_label
      request(Net::HTTP::Get, "/repos/#{@repo}/labels/#{LABEL}")
    rescue AppStoreListing::Error
      request(Net::HTTP::Post, "/repos/#{@repo}/labels",
              { "name" => LABEL, "color" => "d93f0b", "description" => "App Store review state, kept by the App Review watch" })
    end

    def create(title, body)
      request(Net::HTTP::Post, "/repos/#{@repo}/issues", { "title" => title, "body" => body, "labels" => [LABEL] })
    end

    def comment(number, text)
      request(Net::HTTP::Post, "/repos/#{@repo}/issues/#{number}/comments", { "body" => text })
    end

    def update(number, fields)
      request(Net::HTTP::Patch, "/repos/#{@repo}/issues/#{number}", fields)
    end

    private

    def request(klass, path, body = nil)
      uri = URI("https://api.github.com#{path}")
      req = klass.new(uri)
      req["Authorization"] = "Bearer #{@token}"
      req["Accept"] = "application/vnd.github+json"
      if body
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body)
      end
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
      raise AppStoreListing::Error, "GitHub #{klass::METHOD} #{path} answered HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body.to_s.empty? ? {} : JSON.parse(response.body)
    end
  end

  class Runner
    def initialize(asc, issues, bundle_id:, log: $stdout)
      @asc = asc
      @issues = issues
      @bundle_id = bundle_id
      @log = log
    end

    def app_id
      apps = @asc.get("/v1/apps", "filter[bundleId]" => @bundle_id)["data"]
      raise AppStoreListing::Error, "No App Store Connect app has bundle ID #{@bundle_id}" if apps.empty?

      apps.first["id"]
    end

    def versions(id, platform)
      @asc.get_all("/v1/apps/#{id}/appStoreVersions", "filter[platform]" => platform).map do |v|
        { "version" => v.dig("attributes", "versionString"),
          "state" => v.dig("attributes", "appStoreState") || v.dig("attributes", "appVersionState") }
      end
    end

    # Returns the announcements made, as [platform, version, state] triples.
    def run
      id = app_id
      label_ready = false
      announced = []
      PLATFORMS.each do |platform|
        versions(id, platform).each do |v|
          title = AppReviewWatch.title(platform, v["version"])
          issue = @issues.open_issue(title)
          next unless AppReviewWatch.watch?(v["state"], open_issue: !issue.nil?)

          previous = issue && AppReviewWatch.last_state(issue["body"])
          change = AppReviewWatch.transition(previous, v["state"], platform: platform, version: v["version"])
          @log.puts "#{title}: #{v['state']}#{change ? ' (announcing)' : ' (no change)'}"
          next unless change

          unless label_ready
            @issues.ensure_label
            label_ready = true
          end
          issue ||= @issues.create(title, AppReviewWatch.body(platform, v["version"], previous || "UNKNOWN"))
          @issues.comment(issue["number"], change["comment"])
          fields = { "body" => AppReviewWatch.body(platform, v["version"], v["state"]) }
          fields["state"] = "closed" if change["close"]
          @issues.update(issue["number"], fields)
          announced << [platform, v["version"], v["state"]]
        end
      end
      announced
    end
  end
end
