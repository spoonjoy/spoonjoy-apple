# frozen_string_literal: true

# Run: ruby scripts/test/release_train_test.rb
#
# iOS and Mac ship as one release train: one version, one What's New decision, one set of shared URLs.
require "fileutils"
require "json"
require "minitest/autorun"
require "tmpdir"
require_relative "../lib/release_train"

class ReleaseTrainTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def listing(ios: {}, mac: {}, mac_section: {})
    {
      "platform" => "IOS",
      "version" => { "versionString" => "1.3" },
      "review" => { "notes" => "n" },
      "localizations" => {
        "en-US" => {
          "name" => "Spoonjoy", "keywords" => "a,b", "promotionalText" => "iOS promo",
          "supportUrl" => "https://spoonjoy.app/support", "marketingUrl" => "https://spoonjoy.app",
          "privacyPolicyUrl" => "https://spoonjoy.app/privacy"
        }.merge(ios)
      },
      "screenshots" => {},
      "mac" => { "platform" => "MAC_OS", "localizations" => { "en-US" => mac }, "screenshots" => {} }.merge(mac_section)
    }
  end

  def test_the_repository_is_on_one_train
    assert_equal [], ReleaseTrain.static_errors(ROOT)
  end

  def test_a_listing_on_one_train_has_no_errors
    assert_equal [], ReleaseTrain.listing_errors(listing)
  end

  def test_a_mac_version_override_is_refused
    errors = ReleaseTrain.listing_errors(listing(mac_section: { "version" => { "versionString" => "1.2" } }))
    assert_equal ["listing.json mac.version.versionString (1.2) must not be set: the Mac ships the shared version 1.3"], errors
  end

  def test_other_mac_version_fields_are_allowed
    assert_equal [], ReleaseTrain.listing_errors(listing(mac_section: { "version" => { "releaseType" => "MANUAL" } }))
  end

  def test_whats_new_written_for_one_platform_only_is_refused
    errors = ReleaseTrain.listing_errors(listing(ios: { "whatsNew" => "iOS tale" }))
    assert_equal ["en-US whatsNew is written for iOS but not for macOS; write it for both, for neither, or null for a " \
                  "platform's first version"], errors
    errors = ReleaseTrain.listing_errors(listing(mac: { "whatsNew" => "Mac tale" }))
    assert_equal ["en-US whatsNew is written for macOS but not for iOS; write it for both, for neither, or null for a " \
                  "platform's first version"], errors
  end

  def test_whats_new_written_for_both_or_neither_is_allowed
    assert_equal [], ReleaseTrain.listing_errors(listing(ios: { "whatsNew" => "iOS" }, mac: { "whatsNew" => "Mac" }))
    assert_equal [], ReleaseTrain.listing_errors(listing)
  end

  def test_null_whats_new_marks_a_first_version
    assert_equal [], ReleaseTrain.listing_errors(listing(ios: { "whatsNew" => "iOS" }, mac: { "whatsNew" => nil }))
    assert_equal [], ReleaseTrain.listing_errors(listing(ios: { "whatsNew" => nil }, mac: { "whatsNew" => "Mac" }))
  end

  def test_shared_urls_must_match
    errors = ReleaseTrain.listing_errors(listing(mac: { "supportUrl" => "https://spoonjoy.app/mac-support",
                                                        "marketingUrl" => "https://spoonjoy.app" }))
    assert_equal ["en-US supportUrl differs between iOS (https://spoonjoy.app/support) and macOS " \
                  "(https://spoonjoy.app/mac-support); both platforms share it"], errors
  end

  # Keywords and promotional text match unless the Mac section gives its own on purpose (Mac search terms, a Mac
  # promo line). The drift job compares the live copy for every field the Mac section does not override.
  def test_platform_copy_may_be_given_on_purpose
    assert_equal [], ReleaseTrain.listing_errors(listing(mac: { "keywords" => "mac,words", "promotionalText" => "Mac" }))
    assert_equal %w[privacyPolicyUrl supportUrl marketingUrl keywords promotionalText], ReleaseTrain.matching_fields(listing)
    assert_equal %w[privacyPolicyUrl supportUrl marketingUrl],
                 ReleaseTrain.matching_fields(listing(mac: { "keywords" => "mac", "promotionalText" => "Mac" }))
  end

  def test_versions_come_from_every_source
    Dir.mktmpdir do |dir|
      fixture(dir, pbxproj: %w[1.3 1.3], generator: %w[1.3 1.3], distribution: %w[1.3], listing_version: "1.3")
      assert_equal [], ReleaseTrain.static_errors(dir)
    end
  end

  def test_a_drifting_version_is_named_by_source
    Dir.mktmpdir do |dir|
      fixture(dir, pbxproj: %w[1.3 1.2], generator: %w[1.3 1.3], distribution: %w[1.4], listing_version: "1.3")
      assert_equal ["The release train has more than one version: Spoonjoy.xcodeproj/project.pbxproj MARKETING_VERSION " \
                    "1.2, 1.3; scripts/generate-xcode-project.rb MARKETING_VERSION 1.3; distribution/app-store/listing.json " \
                    "version.versionString 1.3; distribution/apple-distribution.json ios-testflight store.version 1.4"],
                   ReleaseTrain.static_errors(dir)
    end
  end

  def test_a_missing_version_is_an_error
    Dir.mktmpdir do |dir|
      fixture(dir, pbxproj: [], generator: %w[1.3], distribution: %w[1.3], listing_version: "1.3")
      assert_includes ReleaseTrain.static_errors(dir), "Spoonjoy.xcodeproj/project.pbxproj has no MARKETING_VERSION"
    end
  end

  def test_a_quoted_marketing_version_is_read
    Dir.mktmpdir do |dir|
      fixture(dir, pbxproj: %w[1.3], generator: %w[1.3], distribution: %w[1.3], listing_version: "1.3")
      File.write(File.join(dir, "Spoonjoy.xcodeproj/project.pbxproj"), "\t\t\t\tMARKETING_VERSION = \"1.4\";\n")
      assert_match(/project.pbxproj MARKETING_VERSION 1.4;/, ReleaseTrain.static_errors(dir).first)
    end
  end

  def test_a_missing_listing_version_reads_as_missing
    Dir.mktmpdir do |dir|
      fixture(dir, pbxproj: %w[1.3], generator: %w[1.3], distribution: %w[1.3], listing_version: nil)
      assert_match(/listing.json version.versionString \(missing\)/, ReleaseTrain.static_errors(dir).first)
    end
  end

  def test_unreadable_inputs_are_errors_not_crashes
    Dir.mktmpdir do |dir|
      fixture(dir, pbxproj: %w[1.3], generator: %w[1.3], distribution: %w[1.3], listing_version: "1.3")
      data = JSON.parse(File.read(File.join(dir, "distribution/app-store/listing.json")))
      data.delete("mac")
      File.write(File.join(dir, "distribution/app-store/listing.json"), JSON.generate(data))
      assert_equal ["Cannot read the release train: listing.json has no \"mac\" section for MAC_OS"], ReleaseTrain.static_errors(dir)
    end
    Dir.mktmpdir do |dir|
      assert_match(/\ACannot read the release train: No such file/, ReleaseTrain.static_errors(dir).first)
    end
  end

  def fixture(dir, pbxproj:, generator:, distribution:, listing_version:)
    FileUtils.mkdir_p(File.join(dir, "Spoonjoy.xcodeproj"))
    FileUtils.mkdir_p(File.join(dir, "scripts"))
    FileUtils.mkdir_p(File.join(dir, "distribution/app-store"))
    File.write(File.join(dir, "Spoonjoy.xcodeproj/project.pbxproj"),
               pbxproj.map { |v| "\t\t\t\tMARKETING_VERSION = #{v};\n" }.join)
    File.write(File.join(dir, "scripts/generate-xcode-project.rb"),
               generator.map { |v| "    build_configuration.build_settings[\"MARKETING_VERSION\"] = \"#{v}\"\n" }.join)
    channels = distribution.map { |v| { "id" => "ios-testflight", "store" => { "version" => v } } }
    File.write(File.join(dir, "distribution/apple-distribution.json"), JSON.generate("channels" => channels))
    data = listing
    data["version"]["versionString"] = listing_version
    File.write(File.join(dir, "distribution/app-store/listing.json"), JSON.generate(data))
  end
end
