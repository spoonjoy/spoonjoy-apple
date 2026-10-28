# frozen_string_literal: true

require_relative "app_store_listing"

# Submits one prepared App Store version for App Review. Kept apart from staging on purpose: staging can never
# submit, and this only submits a version that already has its build and listing in place.
module AppStoreReviewSubmission
  SUBMITTABLE_STATES = %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].freeze

  # Pure decision from what App Store Connect reports. Returns {steps: [...]} or {error: "..."}.
  #   version: {id, state, buildId}|nil
  #   submission: {id, state, versionIds: [...], otherItems: n}|nil — the open submission (READY_FOR_REVIEW, or
  #   UNRESOLVED_ISSUES after a rejection) that holds this version, else an empty-handed READY_FOR_REVIEW one.
  def self.plan(version:, submission:, platform:, version_string:)
    return { "error" => "No #{platform} version #{version_string} in App Store Connect" } if version.nil?
    unless SUBMITTABLE_STATES.include?(version["state"])
      return { "error" => "#{platform} #{version_string} is #{version['state']}, not ready to submit" }
    end
    return { "error" => "#{platform} #{version_string} has no build attached" } if version["buildId"].nil?
    if submission && submission["otherItems"].to_i.positive?
      return { "error" => "Review submission #{submission['id']} also holds #{submission['otherItems']} other item(s); " \
                          "submitting it would send them too. Remove them in App Store Connect first." }
    end

    steps = []
    steps << { "action" => "create_submission", "summary" => "Create a #{platform} review submission" } if submission.nil?
    unless submission && submission["versionIds"].include?(version["id"])
      steps << { "action" => "add_version", "summary" => "Add #{platform} #{version_string} to the submission" }
    end
    # After a rejection the version's item stays REJECTED, and App Store Connect refuses to resubmit the submission
    # ("Version is not ready to be submitted yet") until the item is marked resolved.
    rejected = submission ? Array(submission["rejectedItemIds"]) : []
    unless rejected.empty?
      steps << { "action" => "resolve_items", "itemIds" => rejected,
                 "summary" => "Mark the rejected #{platform} #{version_string} item resolved (#{rejected.join(', ')})" }
    end
    steps << { "action" => "submit", "summary" => "Submit #{platform} #{version_string} for App Review" \
                                                  "#{submission ? " (submission #{submission['id']}, #{submission['state']})" : ''}" }
    { "steps" => steps }
  end

  class Runner
    def initialize(client, bundle_id:, platform:, version_string:, log: $stdout)
      @client = client
      @bundle_id = bundle_id
      @platform = platform
      @version_string = version_string
      @log = log
    end

    def app_id
      @app_id ||= begin
        apps = @client.get("/v1/apps", "filter[bundleId]" => @bundle_id)["data"]
        raise AppStoreListing::Error, "No App Store Connect app has bundle ID #{@bundle_id}" if apps.empty?

        apps.first["id"]
      end
    end

    def version
      data = @client.get("/v1/apps/#{app_id}/appStoreVersions",
                         "filter[platform]" => @platform, "filter[versionString]" => @version_string)["data"]
      return nil if data.empty?

      v = data.first
      build = @client.get("/v1/appStoreVersions/#{v['id']}/build")["data"]
      { "id" => v["id"], "state" => v.dig("attributes", "appStoreState") || v.dig("attributes", "appVersionState"),
        "buildId" => build && build["id"] }
    end

    # Open submissions are matched by the version they hold, not by platform: a submission may carry no platform.
    def open_submission(version_id)
      subs = @client.get("/v1/reviewSubmissions", "filter[app]" => app_id,
                                                  "filter[state]" => "READY_FOR_REVIEW,UNRESOLVED_ISSUES")["data"]
      described = subs.map do |sub|
        items = @client.get("/v1/reviewSubmissions/#{sub['id']}/items", "include" => "appStoreVersion")["data"]
        ids = items.map { |item| item.dig("relationships", "appStoreVersion", "data", "id") }
        rejected = items.select do |item|
          item.dig("attributes", "state") == "REJECTED" && item.dig("relationships", "appStoreVersion", "data", "id") == version_id
        end
        { "id" => sub["id"], "state" => sub.dig("attributes", "state"), "platform" => sub.dig("attributes", "platform"),
          "versionIds" => ids.compact, "rejectedItemIds" => rejected.map { |item| item["id"] },
          "otherItems" => ids.count { |id| id != version_id } }
      end
      described.find { |sub| sub["versionIds"].include?(version_id) } ||
        described.find { |sub| sub["state"] == "READY_FOR_REVIEW" && [nil, @platform].include?(sub["platform"]) }
    end

    def run(apply:)
      v = version
      submission = v && open_submission(v["id"])
      result = AppStoreReviewSubmission.plan(version: v, submission: submission, platform: @platform, version_string: @version_string)
      raise AppStoreListing::Error, result["error"] if result["error"]

      result["steps"].each { |step| @log.puts "- #{step['summary']}" }
      unless apply
        @log.puts "Dry run: nothing was submitted."
        return result["steps"]
      end

      sub_id = submission && submission["id"]
      result["steps"].each do |step|
        case step["action"]
        when "create_submission"
          sub_id = @client.post("/v1/reviewSubmissions", { "data" => { "type" => "reviewSubmissions",
            "attributes" => { "platform" => @platform },
            "relationships" => { "app" => { "data" => { "type" => "apps", "id" => app_id } } } } })["data"]["id"]
        when "add_version"
          @client.post("/v1/reviewSubmissionItems", { "data" => { "type" => "reviewSubmissionItems",
            "relationships" => { "reviewSubmission" => { "data" => { "type" => "reviewSubmissions", "id" => sub_id } },
                                 "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => v["id"] } } } } })
        when "resolve_items"
          step["itemIds"].each do |item_id|
            @client.patch("/v1/reviewSubmissionItems/#{item_id}", { "data" => { "type" => "reviewSubmissionItems", "id" => item_id,
              "attributes" => { "resolved" => true } } })
          end
        when "submit"
          state = @client.patch("/v1/reviewSubmissions/#{sub_id}", { "data" => { "type" => "reviewSubmissions", "id" => sub_id,
            "attributes" => { "submitted" => true } } }).dig("data", "attributes", "state")
          @log.puts "Submitted: review submission #{sub_id} is #{state}"
        end
      end
      result["steps"]
    end
  end
end
