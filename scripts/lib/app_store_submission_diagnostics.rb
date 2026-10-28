# frozen_string_literal: true

require_relative "app_store_listing"

# Reads why a version cannot be submitted: the version and its build's processing state, every open or recent
# review submission of the app with its items, and the app infos. App Store Connect answers a refused submit with
# only "the state of another resource", so this lists the resources that state could belong to. Read-only.
module AppStoreSubmissionDiagnostics
  VERSION_FIELDS = %w[appStoreState appVersionState releaseType versionString platform].freeze
  BUILD_FIELDS = %w[version processingState buildAudienceType usesNonExemptEncryption expired uploadedDate].freeze
  SUBMISSION_STATES = "READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES,CANCELING,COMPLETING"

  def self.pick(attributes, fields)
    (attributes || {}).slice(*fields)
  end

  # One line per submission item: its state and what it points at.
  def self.item_line(item)
    relationships = item["relationships"] || {}
    target = relationships.filter_map do |name, value|
      data = value.is_a?(Hash) ? value["data"] : nil
      "#{name}=#{data['id']}" if data.is_a?(Hash)
    end
    "  item #{item['id']}: #{JSON.generate(item['attributes'] || {})} #{target.join(' ')}".rstrip
  end

  class Reader
    def initialize(client, app_id:, platform:, version_string:, log: $stdout)
      @client = client
      @app_id = app_id
      @platform = platform
      @version_string = version_string
      @log = log
    end

    def run
      version = @client.get("/v1/apps/#{@app_id}/appStoreVersions",
                            "filter[platform]" => @platform, "filter[versionString]" => @version_string)["data"].first
      raise AppStoreListing::Error, "No #{@platform} version #{@version_string}" unless version

      @log.puts "Version #{version['id']}: #{JSON.generate(AppStoreSubmissionDiagnostics.pick(version['attributes'], VERSION_FIELDS))}"
      build = @client.get("/v1/appStoreVersions/#{version['id']}/build")["data"]
      if build
        @log.puts "Build #{build['id']}: #{JSON.generate(AppStoreSubmissionDiagnostics.pick(build['attributes'], BUILD_FIELDS))}"
      else
        @log.puts "Build: none attached"
      end
      @client.get("/v1/apps/#{@app_id}/appInfos")["data"].each do |info|
        @log.puts "App info #{info['id']}: #{JSON.generate(AppStoreSubmissionDiagnostics.pick(info['attributes'], %w[state appStoreState]))}"
      end
      @client.get("/v1/reviewSubmissions", "filter[app]" => @app_id, "filter[state]" => SUBMISSION_STATES)["data"].each do |sub|
        attributes = sub["attributes"] || {}
        @log.puts "Submission #{sub['id']}: #{attributes['platform']} #{attributes['state']} submitted #{attributes['submittedDate']}"
        @client.get("/v1/reviewSubmissions/#{sub['id']}/items")["data"].each do |item|
          @log.puts AppStoreSubmissionDiagnostics.item_line(item)
        end
      end
    end
  end
end
