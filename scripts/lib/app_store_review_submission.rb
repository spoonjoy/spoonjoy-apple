# frozen_string_literal: true

require_relative "app_store_listing"

# Submits one prepared App Store version for App Review. Kept apart from staging on purpose: staging can never
# submit, and this only submits a version that already has its build and listing in place.
module AppStoreReviewSubmission
  SUBMITTABLE_STATES = %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].freeze

  # Pure decision from what App Store Connect reports. Returns {steps: [...]} or {error: "..."}.
  #   version: {id, state, buildId}|nil   submission: {id, versionIds: [...]}|nil (an open READY_FOR_REVIEW one)
  def self.plan(version:, submission:, platform:, version_string:)
    return { "error" => "No #{platform} version #{version_string} in App Store Connect" } if version.nil?
    unless SUBMITTABLE_STATES.include?(version["state"])
      return { "error" => "#{platform} #{version_string} is #{version['state']}, not ready to submit" }
    end
    return { "error" => "#{platform} #{version_string} has no build attached" } if version["buildId"].nil?

    steps = []
    steps << { "action" => "create_submission", "summary" => "Create a #{platform} review submission" } if submission.nil?
    unless submission && submission["versionIds"].include?(version["id"])
      steps << { "action" => "add_version", "summary" => "Add #{platform} #{version_string} to the submission" }
    end
    steps << { "action" => "submit", "summary" => "Submit #{platform} #{version_string} for App Review" }
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

    def open_submission
      data = @client.get("/v1/reviewSubmissions", "filter[app]" => app_id, "filter[platform]" => @platform,
                                                  "filter[state]" => "READY_FOR_REVIEW")["data"]
      return nil if data.empty?

      sub = data.first
      items = @client.get("/v1/reviewSubmissions/#{sub['id']}/items", "include" => "appStoreVersion")["data"]
      { "id" => sub["id"], "versionIds" => items.map { |item| item.dig("relationships", "appStoreVersion", "data", "id") }.compact }
    end

    def run(apply:)
      v = version
      submission = open_submission
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
