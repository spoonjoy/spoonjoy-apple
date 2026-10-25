# frozen_string_literal: true

require_relative "app_store_listing"

# Reads a version's release state and age rating, sets how it releases, and releases an approved version.
# Kept apart from staging because staging only sees editable versions, and these work on versions in review.
module AppStoreRelease
  RELEASE_TYPES = %w[MANUAL AFTER_APPROVAL SCHEDULED].freeze

  # Pure decision. version: {id, state, releaseType}|nil. Returns {steps: [...]} or {error: "..."}.
  def self.plan(action:, version:, platform:, version_string:, release_type: nil)
    return { "error" => "No #{platform} version #{version_string} in App Store Connect" } if version.nil?

    case action
    when "status"
      { "steps" => [] }
    when "set-release-type"
      return { "error" => "Unknown release type #{release_type.inspect}" } unless RELEASE_TYPES.include?(release_type)
      return { "steps" => [] } if version["releaseType"] == release_type

      { "steps" => [{ "action" => "patch_release_type", "releaseType" => release_type,
                      "summary" => "Change #{platform} #{version_string} release from #{version['releaseType']} to #{release_type}" }] }
    when "release"
      unless version["state"] == "PENDING_DEVELOPER_RELEASE"
        return { "error" => "#{platform} #{version_string} is #{version['state']}; only PENDING_DEVELOPER_RELEASE can be released" }
      end

      { "steps" => [{ "action" => "release", "summary" => "Release #{platform} #{version_string} to the App Store" }] }
    else
      { "error" => "Unknown action #{action.inspect}" }
    end
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
      { "id" => v["id"], "state" => v.dig("attributes", "appStoreState") || v.dig("attributes", "appVersionState"),
        "releaseType" => v.dig("attributes", "releaseType") }
    end

    def age_ratings
      @client.get("/v1/apps/#{app_id}/appInfos")["data"].map do |info|
        "#{info.dig('attributes', 'state') || info.dig('attributes', 'appStoreState')}: #{info.dig('attributes', 'appStoreAgeRating').inspect}"
      end
    end

    def report(v)
      @log.puts "#{@platform} #{@version_string}: state #{v['state']}, release #{v['releaseType']}"
      age_ratings.each { |line| @log.puts "Age rating (app info #{line})" }
    end

    def run(action:, apply:, release_type: nil)
      v = version
      result = AppStoreRelease.plan(action: action, version: v, platform: @platform, version_string: @version_string,
                                    release_type: release_type)
      raise AppStoreListing::Error, result["error"] if result["error"]

      report(v)
      result["steps"].each { |step| @log.puts "- #{step['summary']}" }
      return result["steps"] if result["steps"].empty?

      unless apply
        @log.puts "Dry run: nothing was changed."
        return result["steps"]
      end

      result["steps"].each do |step|
        case step["action"]
        when "patch_release_type"
          @client.patch("/v1/appStoreVersions/#{v['id']}", { "data" => { "type" => "appStoreVersions", "id" => v["id"],
            "attributes" => { "releaseType" => step["releaseType"] } } })
        when "release"
          @client.post("/v1/appStoreVersionReleaseRequests", { "data" => { "type" => "appStoreVersionReleaseRequests",
            "relationships" => { "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => v["id"] } } } } })
        end
      end
      @log.puts "After:"
      report(version)
      result["steps"]
    end
  end
end
