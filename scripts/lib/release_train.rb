# frozen_string_literal: true

require "json"
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
end
