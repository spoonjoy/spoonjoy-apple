# frozen_string_literal: true

require "digest"
require "json"
require "time"
require_relative "app_store_listing"

# iOS and Mac move as one release train: one version, one What's New decision and one set of shared URLs. The
# static check reads the repository; the drift check compares what App Store Connect holds for both platforms.
module ReleaseTrain
  PBXPROJ = "Spoonjoy.xcodeproj/project.pbxproj"
  GENERATOR = "scripts/generate-xcode-project.rb"
  LISTING = "distribution/app-store/listing.json"
  DISTRIBUTION = "distribution/apple-distribution.json"
  PLATFORMS = %w[IOS MAC_OS].freeze
  # Always the same on both platforms.
  SHARED_FIELDS = %w[privacyPolicyUrl supportUrl marketingUrl].freeze
  # The same on both platforms unless listing.json's Mac section gives its own on purpose.
  PLATFORM_COPY_FIELDS = %w[keywords promotionalText].freeze

  # Every way the repository leaves the train, as human-readable strings. Empty means one train.
  def self.static_errors(root)
    errors = []
    versions = {}
    pbxproj = File.read(File.join(root, PBXPROJ)).scan(/^\s*MARKETING_VERSION = "?([^";\s]+)"?;/).flatten
    generator = File.read(File.join(root, GENERATOR)).scan(/\["MARKETING_VERSION"\]\s*=\s*"([^"]+)"/).flatten
    listing = JSON.parse(File.read(File.join(root, LISTING)))
    distribution = JSON.parse(File.read(File.join(root, DISTRIBUTION)))
    { "#{PBXPROJ} MARKETING_VERSION" => [PBXPROJ, pbxproj],
      "#{GENERATOR} MARKETING_VERSION" => [GENERATOR, generator] }.each do |label, (path, found)|
      found.empty? ? errors << "#{path} has no MARKETING_VERSION" : versions[label] = found.uniq.sort
    end
    versions["#{LISTING} version.versionString"] = [listing.dig("version", "versionString")]
    distribution.fetch("channels", []).each do |channel|
      versions["#{DISTRIBUTION} #{channel['id']} store.version"] = [channel.dig("store", "version")]
    end
    if versions.values.flatten.uniq.length > 1
      errors << "The release train has more than one version: " +
                versions.map { |label, found| "#{label} #{found.map { |v| v || '(missing)' }.join(', ')}" }.join("; ")
    end
    errors.concat(listing_errors(listing))
  rescue Errno::ENOENT, JSON::ParserError, KeyError, AppStoreListing::Error => e
    errors << "Cannot read the release train: #{e.message}"
  end

  # The listing's own train rules: no Mac version, What's New written for both or neither, shared URLs shared.
  def self.listing_errors(listing)
    errors = []
    version = listing.dig("version", "versionString")
    mac = listing.fetch("mac", {})
    if (override = mac.dig("version", "versionString"))
      errors << "listing.json mac.version.versionString (#{override}) must not be set: the Mac ships the shared version #{version}"
    end
    ios_locales = listing.fetch("localizations", {})
    mac_locales = mac.fetch("localizations", {})
    (ios_locales.keys | mac_locales.keys).each do |locale|
      written = { "iOS" => ios_locales.fetch(locale, {}), "macOS" => mac_locales.fetch(locale, {}) }
                .transform_values { |fields| whats_new_state(fields) }
      next unless written.values.include?(:written) && written.values.include?(:absent)

      with, without = written.key(:written), written.key(:absent)
      errors << "#{locale} whatsNew is written for #{with} but not for #{without}; write it for both, for neither, or " \
                "null for a platform's first version"
    end
    effective = PLATFORMS.to_h { |platform| [platform, AppStoreListing.for_platform(listing, platform)] }
    effective.fetch("IOS").fetch("localizations").each do |locale, ios_fields|
      mac_fields = effective.fetch("MAC_OS").fetch("localizations").fetch(locale, {})
      SHARED_FIELDS.each do |field|
        next if ios_fields[field] == mac_fields[field]

        errors << "#{locale} #{field} differs between iOS (#{ios_fields[field]}) and macOS (#{mac_fields[field]}); both " \
                  "platforms share it"
      end
    end
    errors
  end

  def self.whats_new_state(fields)
    return :absent unless fields.key?("whatsNew")

    fields["whatsNew"].nil? ? :first_version : :written
  end

  # The copy fields both platforms' live versions must agree on: the shared URLs, plus keywords and promotional
  # text wherever the Mac section does not give its own.
  def self.matching_fields(listing, locale: "en-US")
    mac = listing.dig("mac", "localizations", locale) || {}
    SHARED_FIELDS + PLATFORM_COPY_FIELDS.reject { |field| mac.key?(field) }
  end

  PLATFORM_NAMES = AppStoreListing::PLATFORM_NAMES
  # privacyPolicyUrl is app-level in App Store Connect (one appInfo for both platforms), so only version copy is read.
  COPY_FIELDS = (SHARED_FIELDS - %w[privacyPolicyUrl]) + PLATFORM_COPY_FIELDS
  LABEL = "release-train"
  ISSUE_TITLE = "Release train: iOS and Mac have drifted"
  MARKER = /<!-- release-train differences=([0-9a-f]{64}) -->/.freeze

  # The ways two platforms' latest live versions differ, as "field: iOS x, macOS y" lines. Empty means in line.
  # fields are the copy fields that should match (matching_fields).
  def self.drift(ios, mac, fields)
    missing = { "IOS" => ios, "MAC_OS" => mac }.select { |_, version| version.nil? }.keys
    return missing.map { |platform| "#{PLATFORM_NAMES.fetch(platform)} has no App Store version" } unless missing.empty?

    differences = %w[versionString state].reject { |key| ios[key] == mac[key] }
                                         .map { |key| "#{key}: iOS #{ios[key]}, macOS #{mac[key]}" }
    fields.each do |field|
      a = ios.fetch("copy", {})[field]
      b = mac.fetch("copy", {})[field]
      differences << "#{field}: iOS #{a}, macOS #{b}" unless a == b
    end
    differences
  end

  # App Store Connect dates carry a Pacific offset, so they compare as times, never as text.
  def self.created_at(version)
    Time.iso8601(version.dig("attributes", "createdDate").to_s)
  rescue ArgumentError
    Time.at(0)
  end

  # Only reads: the drift job can never write to App Store Connect, whatever it calls.
  class ReadOnly
    def initialize(client)
      @client = client
    end

    def get(path, query = {})
      @client.get(path, query)
    end

    def get_all(path, query = {})
      @client.get_all(path, query)
    end
  end

  # Each platform's newest App Store version as {platform, versionString, state, build, copy}, or nil.
  class LiveReader
    def initialize(asc, bundle_id:, locale: "en-US")
      @asc = ReadOnly.new(asc)
      @bundle_id = bundle_id
      @locale = locale
    end

    def app_id
      @app_id ||= begin
        apps = @asc.get("/v1/apps", "filter[bundleId]" => @bundle_id)["data"]
        raise AppStoreListing::Error, "No App Store Connect app has bundle ID #{@bundle_id}" if apps.empty?

        apps.first["id"]
      end
    end

    def latest(platform)
      versions = @asc.get_all("/v1/apps/#{app_id}/appStoreVersions", "filter[platform]" => platform)
      newest = versions.max_by { |v| ReleaseTrain.created_at(v) }
      return nil unless newest

      attributes = newest["attributes"]
      build = @asc.get("/v1/appStoreVersions/#{newest['id']}/build")["data"]
      localization = @asc.get_all("/v1/appStoreVersions/#{newest['id']}/appStoreVersionLocalizations")
                         .find { |l| l.dig("attributes", "locale") == @locale }
      { "platform" => platform, "versionString" => attributes["versionString"],
        "state" => attributes["appStoreState"] || attributes["appVersionState"],
        "build" => build && build.dig("attributes", "version"),
        "copy" => (localization ? localization["attributes"] : {}).slice(*COPY_FIELDS) }
    end
  end

  # Keeps one GitHub issue labelled release-train: opened on drift, updated with a comment when the differences
  # change, closed when the platforms are back in line. issues is AppReviewWatch::GitHubIssues with this label.
  class DriftIssue
    def initialize(issues, log: $stdout)
      @issues = issues
      @log = log
    end

    def self.body(differences, ios:, mac:)
      digest = Digest::SHA256.hexdigest(differences.join("\n"))
      rows = [ios, mac].compact.map do |v|
        "| #{PLATFORM_NAMES.fetch(v['platform'])} | #{v['versionString']} | `#{v['state']}` | #{v['build'] || 'none'} |"
      end
      <<~BODY
        <!-- release-train differences=#{digest} -->
        The release train drift job (`.github/workflows/release-train-drift.yml`) found iOS and Mac out of line in App Store Connect. It reads App Store Connect only, updates this issue when the differences change and closes it when they are back in line. See `docs/apple-distribution.md#release-train`.

        | Platform | Latest version | State | Build |
        | --- | --- | --- | --- |
        #{rows.join("\n")}

        Differences:
        #{differences.map { |d| "- #{d}" }.join("\n")}
      BODY
    end

    # Returns :quiet, :opened, :unchanged, :updated or :closed.
    def keep(differences, ios:, mac:)
      issue = @issues.open_issue(ISSUE_TITLE)
      if differences.empty?
        return log(:quiet) unless issue

        @issues.comment(issue["number"], "iOS and Mac are back in line: both are #{ios['versionString']} (`#{ios['state']}`).")
        @issues.update(issue["number"], "state" => "closed")
        return log(:closed)
      end

      body = DriftIssue.body(differences, ios: ios, mac: mac)
      unless issue
        @issues.ensure_label
        @issues.create(ISSUE_TITLE, body)
        return log(:opened)
      end
      return log(:unchanged) if issue["body"].to_s[MARKER, 1] == body[MARKER, 1]

      @issues.update(issue["number"], "body" => body)
      @issues.comment(issue["number"], "The differences changed:\n#{differences.map { |d| "- #{d}" }.join("\n")}")
      log(:updated)
    end

    private

    def log(outcome)
      @log.puts "Release train issue: #{outcome}"
      outcome
    end
  end
end
