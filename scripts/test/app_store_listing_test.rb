# frozen_string_literal: true

# Run: ruby scripts/test/app_store_listing_test.rb
require "minitest/autorun"
require "stringio"
require "tmpdir"
require "zlib"
require_relative "../lib/app_store_listing"

class AppStoreListingTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  LISTING_PATH = File.join(ROOT, "distribution/app-store/listing.json")

  CHANGES_DIR = File.join(ROOT, "changes")

  # The iOS listing as staging sees it, with What's New assembled from changes/.
  def listing
    @listing ||= AppStoreListing.with_whats_new(raw_listing, CHANGES_DIR)
  end

  def raw_listing
    @raw_listing ||= JSON.parse(File.read(LISTING_PATH))
  end

  def png(path, width, height, color_type: 2, trns: false)
    chunk = lambda do |type, data|
      [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
    end
    channels = { 2 => 3, 6 => 4 }.fetch(color_type)
    raw = ("\x00".b + ("\xFF".b * (width * channels))) * height
    bytes = "\x89PNG\r\n\x1A\n".b
    bytes += chunk.call("IHDR", [width, height, 8, color_type, 0, 0, 0].pack("NNCCCCC"))
    bytes += chunk.call("tRNS", "\x00\x00\x00\x00\x00\x00".b) if trns
    bytes += chunk.call("IDAT", Zlib::Deflate.deflate(raw))
    bytes += chunk.call("IEND", "".b)
    File.binwrite(path, bytes)
    path
  end

  def with_screenshots
    Dir.mktmpdir do |dir|
      listing["screenshots"].each_key { |folder| Dir.mkdir(File.join(dir, folder)) }
      yield dir
    end
  end

  def test_checked_in_listing_is_valid_without_screenshots
    with_screenshots { |dir| assert_equal [], AppStoreListing.validate(listing, dir) }
  end

  def test_rejects_overlong_fields_and_keywords
    bad = JSON.parse(JSON.generate(listing))
    bad["localizations"]["en-US"]["subtitle"] = "x" * 31
    bad["localizations"]["en-US"]["keywords"] = ("word," * 30).chomp(",")
    bad["localizations"]["en-US"]["supportUrl"] = "http://spoonjoy.app/support"
    bad["review"]["notes"] = "n" * 4001
    errors = with_screenshots { |dir| AppStoreListing.validate(bad, dir) }
    assert(errors.any? { |e| e.include?("subtitle is 31 characters") })
    assert(errors.any? { |e| e.include?("keywords are 149 bytes") })
    assert(errors.any? { |e| e.include?("supportUrl must be an https URL") })
    assert(errors.any? { |e| e.include?("review notes are 4001 characters") })
  end

  def test_rejects_wrong_sizes_alpha_and_bad_names
    with_screenshots do |dir|
      png(File.join(dir, "iphone-69", "01-kitchen.png"), 1320, 2868)
      png(File.join(dir, "iphone-69", "02-cook.png"), 1000, 2000)
      png(File.join(dir, "iphone-61", "01-kitchen.png"), 1206, 2622, color_type: 6)
      png(File.join(dir, "ipad-13", "01-spread.png"), 2752, 2064, trns: true)
      png(File.join(dir, "ipad-13", "Spread.png"), 2752, 2064)
      errors = AppStoreListing.validate(listing, dir)
      assert_equal 4, errors.length, errors.inspect
      assert(errors.any? { |e| e.include?("iphone-69/02-cook.png is 1000x2000") })
      assert(errors.any? { |e| e.include?("iphone-61/01-kitchen.png has transparency") })
      assert(errors.any? { |e| e.include?("ipad-13/01-spread.png has transparency") })
      assert(errors.any? { |e| e.include?("ipad-13/Spread.png must be named") })
    end
  end

  def test_png_info_reads_dimensions
    Dir.mktmpdir do |dir|
      info = AppStoreListing.png_info(png(File.join(dir, "a.png"), 12, 7))
      assert_equal [12, 7, false], [info.width, info.height, info.alpha]
    end
  end

  def empty_snapshot
    {
      "app" => { "id" => "app1", "contentRightsDeclaration" => nil },
      "appInfo" => { "id" => "info1", "primaryCategory" => nil, "secondaryCategory" => nil, "ageRatingId" => "age1",
                     "ageRating" => {}, "localization" => { "id" => "infoloc1", "attributes" => { "name" => "Spoonjoy" } } },
      "version" => nil,
      "build" => { "id" => "build88", "version" => "88" },
      "price" => { "scheduled" => false, "freePricePointId" => "pp-free" },
      "availability" => { "exists" => false, "territoryIds" => %w[USA GBR] }
    }
  end

  def shots
    { "iphone-69" => [{ "path" => "/x/01-kitchen.png", "checksum" => "c1", "size" => 1 }], "iphone-61" => [], "ipad-13" => [] }
  end

  def test_plan_for_a_fresh_app_covers_every_write_and_never_submits
    steps = AppStoreListing.plan(listing: listing, snapshot: empty_snapshot, screenshots: shots,
                                 secrets: { "demoAccountName" => "johnnyappleseed", "demoAccountPassword" => "s3cret" })
    actions = steps.map { |s| s["action"] }
    assert_equal %w[patch_app patch_categories patch_age_rating patch_app_info_localization create_version create_phased_release
                    attach_build create_version_localization create_review_detail set_free_price set_availability sync_screenshots], actions
    refute(actions.any? { |a| a.include?("submi") })
    create = steps.find { |s| s["action"] == "create_version" }
    refute create["attributes"].key?("phasedRelease"), "phasedRelease is its own App Store Connect object, not a version attribute"
    assert_equal "$version", steps.find { |s| s["action"] == "create_phased_release" }["versionId"]
    version_localization = steps.find { |s| s["action"] == "create_version_localization" }
    assert_equal listing["localizations"]["en-US"]["whatsNew"], version_localization["attributes"]["whatsNew"]
    review = steps.find { |s| s["action"] == "create_review_detail" }
    assert_equal "johnnyappleseed", review["attributes"]["demoAccountName"]
    assert_equal "$version", review["versionId"]
    assert_equal "$version_localization", steps.last["localizationId"]
  end

  def test_describe_redacts_the_demo_password
    steps = AppStoreListing.plan(listing: listing, snapshot: empty_snapshot, screenshots: shots,
                                 secrets: { "demoAccountPassword" => "s3cret" })
    text = AppStoreListing.describe(steps).join("\n")
    refute_includes text, "s3cret"
    assert_includes text, "demo password: redacted"
  end

  def test_plan_is_empty_when_everything_already_matches
    fields = listing["localizations"]["en-US"]
    snapshot = empty_snapshot.merge(
      "app" => { "id" => "app1", "contentRightsDeclaration" => listing["contentRightsDeclaration"] },
      "appInfo" => { "id" => "info1", "primaryCategory" => "FOOD_AND_DRINK", "secondaryCategory" => "LIFESTYLE",
                     "ageRatingId" => "age1", "ageRating" => listing["ageRating"],
                     "localization" => { "id" => "il", "attributes" => fields.slice(*AppStoreListing::APP_INFO_LOCALIZATION_FIELDS) } },
      "version" => {
        "id" => "v1", "attributes" => listing["version"], "buildId" => "build88", "phasedRelease" => { "id" => "pr1" },
        "localization" => { "id" => "vl", "attributes" => fields.slice(*AppStoreListing::VERSION_LOCALIZATION_FIELDS) },
        "reviewDetail" => { "id" => "rd", "attributes" => listing["review"].slice(*AppStoreListing::REVIEW_FIELDS) },
        "screenshotSets" => { "APP_IPHONE_67" => { "id" => "set1", "checksums" => ["c1"] } }
      },
      "price" => { "scheduled" => true },
      "availability" => { "exists" => true, "territoryIds" => [] }
    )
    assert_equal [], AppStoreListing.plan(listing: listing, snapshot: snapshot, screenshots: shots, secrets: {})
  end

  def test_changed_screenshots_replace_the_existing_set
    snapshot = empty_snapshot.merge("version" => {
      "id" => "v1", "attributes" => listing["version"], "buildId" => "build88", "localization" => { "id" => "vl", "attributes" => {} },
      "reviewDetail" => nil, "screenshotSets" => { "APP_IPHONE_67" => { "id" => "set1", "checksums" => ["old"] } }
    })
    step = AppStoreListing.plan(listing: listing, snapshot: snapshot, screenshots: shots, secrets: {}).last
    assert_equal ["sync_screenshots", "set1", "vl"], [step["action"], step["setId"], step["localizationId"]]
  end

  def mac_listing
    AppStoreListing.with_whats_new(AppStoreListing.for_platform(raw_listing, "MAC_OS"), CHANGES_DIR)
  end

  APP_LEVEL_ACTIONS = %w[patch_app patch_categories patch_age_rating create_app_info_localization patch_app_info_localization
                         set_free_price set_availability].freeze

  def test_ios_platform_returns_the_listing_unchanged
    assert_same listing, AppStoreListing.for_platform(listing, "IOS")
    assert_raises(AppStoreListing::Error) { AppStoreListing.for_platform(listing, "TV_OS") }
    assert_raises(AppStoreListing::Error) { AppStoreListing.for_platform(listing.reject { |k, _| k == "mac" }, "MAC_OS") }
  end

  def test_mac_listing_takes_its_section_over_the_ios_copy
    mac = mac_listing
    ios_fields = listing["localizations"]["en-US"]
    mac_fields = mac["localizations"]["en-US"]
    assert_equal "MAC_OS", mac["platform"]
    assert_equal listing["mac"]["localizations"]["en-US"]["description"], mac_fields["description"]
    assert_equal ios_fields.slice("name", "subtitle", "privacyPolicyUrl", "supportUrl", "marketingUrl"),
                 mac_fields.slice("name", "subtitle", "privacyPolicyUrl", "supportUrl", "marketingUrl")
    assert_equal listing["version"], mac["version"]
    assert_equal listing["mac"]["review"]["notes"], mac["review"]["notes"]
    assert_equal listing["review"].reject { |k, _| k == "notes" }, mac["review"].reject { |k, _| k == "notes" }
    assert_equal ["mac"], mac["screenshots"].keys
    assert_equal "APP_DESKTOP", mac["screenshots"]["mac"]["displayType"]
    refute mac.key?("mac")
    assert_equal "IOS", listing["platform"], "resolving the Mac listing must not change the iOS one"
  end

  def test_checked_in_mac_listing_is_valid_and_makes_no_ios_only_claims
    Dir.mktmpdir do |dir|
      Dir.mkdir(File.join(dir, "mac"))
      assert_equal [], AppStoreListing.validate(mac_listing, dir)
      png(File.join(dir, "mac", "01-kitchen.png"), 2880, 1800)
      png(File.join(dir, "mac", "02-spread.png"), 2752, 2064)
      errors = AppStoreListing.validate(mac_listing, dir)
      assert_equal ["mac/02-spread.png is 2752x2064; allowed: 2880x1800, 2560x1600, 1440x900, 1280x800"], errors
    end
    copy = mac_listing["localizations"]["en-US"].values_at("description", "promotionalText", "whatsNew").join("\n") + mac_listing["review"]["notes"]
    ["Lock Screen", "Dynamic Island", "Duo", "hinge", "stays awake", "system timer", "tap", "Command-N", "iPhone Duo"].each do |claim|
      refute_includes copy, claim
    end
  end

  def mac_snapshot(version: nil)
    { "version" => version, "build" => { "id" => "macbuild2", "version" => "2" } }
  end

  def mac_shots
    { "mac" => [{ "path" => "/x/01-kitchen.png", "checksum" => "m1", "size" => 1 }] }
  end

  def test_mac_plan_stages_only_the_mac_version
    steps = AppStoreListing.plan(listing: mac_listing, snapshot: mac_snapshot, screenshots: mac_shots,
                                 secrets: { "demoAccountName" => "johnnyappleseed", "demoAccountPassword" => "s3cret" })
    actions = steps.map { |s| s["action"] }
    assert_equal %w[create_version create_phased_release attach_build create_version_localization create_review_detail sync_screenshots],
                 actions
    assert_empty actions & APP_LEVEL_ACTIONS
    create = steps.first
    assert_equal ["Create macOS version 1.2", "MAC_OS"], [create["summary"], create["platform"]]
    assert_equal "macbuild2", steps[2]["buildId"]
    localization = steps[3]["attributes"]
    assert_equal mac_listing["localizations"]["en-US"]["description"], localization["description"]
    assert_equal "https://spoonjoy.app/support", localization["supportUrl"]
    assert_equal Changelog.whats_new(Changelog.load!(CHANGES_DIR), "mac"), localization["whatsNew"]
    assert_equal listing["mac"]["review"]["notes"], steps[4]["attributes"]["notes"]
    assert_equal "APP_DESKTOP", steps.last["displayType"]
  end

  def test_mac_plan_for_an_existing_version_only_resends_the_password_once_staged
    mac = mac_listing
    fields = mac["localizations"]["en-US"]
    version = {
      "id" => "macv1", "attributes" => { "versionString" => "1.0", "copyright" => nil, "releaseType" => "MANUAL" },
      "buildId" => nil, "localization" => { "id" => "macvl", "attributes" => {} }, "reviewDetail" => nil, "screenshotSets" => {}
    }
    steps = AppStoreListing.plan(listing: mac, snapshot: mac_snapshot(version: version), screenshots: mac_shots,
                                 secrets: { "demoAccountPassword" => "s3cret" })
    assert_equal %w[patch_version create_phased_release attach_build patch_version_localization create_review_detail sync_screenshots],
                 steps.map { |s| s["action"] }
    assert_equal({ "versionString" => "1.2", "copyright" => "2026 Ari Mendelow", "releaseType" => "AFTER_APPROVAL" }, steps.first["attributes"])

    staged = version.merge(
      "attributes" => mac["version"], "buildId" => "macbuild2", "phasedRelease" => { "id" => "macpr" },
      "localization" => { "id" => "macvl", "attributes" => fields.slice(*AppStoreListing::VERSION_LOCALIZATION_FIELDS) },
      "reviewDetail" => { "id" => "macrd", "attributes" => mac["review"].slice(*AppStoreListing::REVIEW_FIELDS) },
      "screenshotSets" => { "APP_DESKTOP" => { "id" => "macset", "checksums" => ["m1"] } }
    )
    steps = AppStoreListing.plan(listing: mac, snapshot: mac_snapshot(version: staged), screenshots: mac_shots,
                                 secrets: { "demoAccountPassword" => "s3cret" })
    assert_equal ["- Update review details: demoAccountPassword (demo password: redacted)"], AppStoreListing.describe(steps)
  end

  # Records every GET so a test can prove which App Store Connect objects the Reader touched.
  class RecordingClient
    attr_reader :paths

    def initialize
      @paths = []
    end

    def get(path, query = {})
      @paths << path
      case path
      when "/v1/apps" then { "data" => [{ "id" => "app1" }] }
      when "/v1/builds"
        raise "wrong platform filter" unless query["filter[preReleaseVersion.platform]"] == "MAC_OS"

        { "data" => [{ "id" => "macbuild2" }] }
      else raise AppStoreListing::Error, "HTTP 404 #{path}"
      end
    end

    def get_all(path, query = {})
      @paths << path
      raise "wrong platform filter" if path.end_with?("/appStoreVersions") && query["filter[platform]"] != "MAC_OS"

      []
    end
  end

  def test_mac_reader_never_reads_app_level_data
    client = RecordingClient.new
    snapshot = AppStoreListing::Reader.new(client, mac_listing).snapshot(build_number: "2")
    assert_equal({ "version" => nil, "build" => { "id" => "macbuild2", "version" => "2" } }, snapshot)
    assert_equal ["/v1/apps", "/v1/apps/app1/appStoreVersions", "/v1/builds"], client.paths
  end

  def test_missing_mac_build_names_the_platform
    client = Class.new(RecordingClient) do
      def get(path, query = {})
        path == "/v1/builds" ? { "data" => [] } : super
      end
    end.new
    error = assert_raises(AppStoreListing::Error) { AppStoreListing::Reader.new(client, mac_listing).build("9") }
    assert_equal "No VALID macOS build 9 in App Store Connect", error.message
  end

  # Answers Reader GETs from a path => body table, so price checks run without the network.
  class FakePriceClient
    def initialize(responses)
      @responses = responses
    end

    def get(path, _query = {})
      @responses.fetch(path) { raise AppStoreListing::Error, "HTTP 404 #{path}" }
    end

    def get_all(path, query = {})
      get(path, query)["data"]
    end
  end

  def price_snapshot(customer_prices)
    responses = {
      "/v1/apps" => { "data" => [{ "id" => "app1" }] },
      "/v1/apps/app1/appPricePoints" => { "data" => [{ "id" => "pp-free", "attributes" => { "customerPrice" => "0.0" } }] }
    }
    unless customer_prices.nil?
      responses["/v1/apps/app1/appPriceSchedule"] = { "data" => { "id" => "sched1" } }
      responses["/v1/appPriceSchedules/sched1/manualPrices"] = {
        "data" => [],
        "included" => customer_prices.map { |price| { "type" => "appPricePoints", "attributes" => { "customerPrice" => price } } }
      }
    end
    AppStoreListing::Reader.new(FakePriceClient.new(responses), listing).send(:price)
  end

  def test_existing_free_schedule_needs_no_price_step
    assert_equal({ "scheduled" => true }, price_snapshot(["0.0"]))
  end

  def test_existing_paid_or_empty_schedule_is_replaced_with_free
    assert_equal({ "scheduled" => false, "freePricePointId" => "pp-free" }, price_snapshot(["4.99"]))
    assert_equal({ "scheduled" => false, "freePricePointId" => "pp-free" }, price_snapshot([]))
    assert_equal({ "scheduled" => false, "freePricePointId" => "pp-free" }, price_snapshot(nil))
  end

  def test_placeholder_schedule_whose_prices_404_is_replaced_with_free
    responses = {
      "/v1/apps" => { "data" => [{ "id" => "app1" }] },
      "/v1/apps/app1/appPricePoints" => { "data" => [{ "id" => "pp-free", "attributes" => { "customerPrice" => "0.0" } }] },
      "/v1/apps/app1/appPriceSchedule" => { "data" => { "id" => "app1" } }
    }
    snapshot = AppStoreListing::Reader.new(FakePriceClient.new(responses), listing).send(:price)
    assert_equal({ "scheduled" => false, "freePricePointId" => "pp-free" }, snapshot)
  end

  # App Store Connect rejects an age rating update that leaves any of these unanswered (HTTP 409).
  REQUIRED_AGE_RATING_ANSWERS = %w[
    advertising ageAssurance alcoholTobaccoOrDrugUseOrReferences contests gambling gamblingSimulated gunsOrOtherWeapons
    healthOrWellnessTopics horrorOrFearThemes lootBox matureOrSuggestiveThemes medicalOrTreatmentInformation messagingAndChat
    parentalControls profanityOrCrudeHumor sexualContentGraphicAndNudity sexualContentOrNudity socialMedia
    socialMediaAgeRestricted unrestrictedWebAccess userGeneratedContent violenceCartoonOrFantasy violenceRealistic
    violenceRealisticProlongedGraphicOrSadistic
  ].freeze

  def test_listing_answers_every_required_age_rating_question
    assert_empty REQUIRED_AGE_RATING_ANSWERS - listing.fetch("ageRating").keys
  end

  def test_der_signature_becomes_64_raw_bytes
    key = OpenSSL::PKey::EC.generate("prime256v1")
    der = key.sign(OpenSSL::Digest.new("SHA256"), "payload")
    raw = AppStoreListing::Client.der_to_raw(der)
    assert_equal 64, raw.bytesize
    r = OpenSSL::BN.new(raw[0, 32], 2)
    s = OpenSSL::BN.new(raw[32, 32], 2)
    rebuilt = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(r), OpenSSL::ASN1::Integer.new(s)]).to_der
    assert key.verify(OpenSSL::Digest.new("SHA256"), rebuilt, "payload")
  end

  def test_staging_code_has_no_review_submission_path
    source = File.read(File.join(ROOT, "scripts/lib/app_store_listing.rb")) + File.read(File.join(ROOT, "scripts/stage-app-store-listing.rb"))
    refute_match(/reviewSubmission/, source)
  end
  def test_whats_new_comes_from_the_changelog_fragments_unless_listing_json_writes_it
    # A whatsNew written in listing.json is the tale a version was submitted with (iOS 1.2); `changelog.rb archive`
    # records and removes it when main moves on. Otherwise What's New comes from changes/.
    fragments = Changelog.load!(CHANGES_DIR)
    { listing => ["ios", raw_listing["localizations"]["en-US"]],
      mac_listing => ["mac", raw_listing["mac"]["localizations"]["en-US"]] }.each do |platform_listing, (platform, raw)|
      expected = raw.key?("whatsNew") ? raw["whatsNew"] : Changelog.whats_new(fragments, platform)
      assert_equal expected, platform_listing["localizations"]["en-US"]["whatsNew"], platform
    end
    refute raw_listing["mac"]["localizations"]["en-US"].key?("whatsNew"), "Mac 1.2's What's New comes from changes/"
    ios_only = JSON.parse(JSON.generate(raw_listing))
    ios_only["localizations"]["en-US"]["whatsNew"] = "iOS only."
    refute_equal "iOS only.", AppStoreListing.with_whats_new(AppStoreListing.for_platform(ios_only, "MAC_OS"), CHANGES_DIR)
                                            .dig("localizations", "en-US", "whatsNew"), "the Mac never inherits the iOS tale"
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "amber.md"), "---\ntestflight: Amber.\n---\nThe button glows amber.\n")
      written = JSON.parse(JSON.generate(raw_listing))
      written["localizations"]["en-US"]["whatsNew"] = "Written by hand."
      assert_equal "Written by hand.", AppStoreListing.with_whats_new(written, dir)["localizations"]["en-US"]["whatsNew"]
      written["localizations"]["en-US"]["whatsNew"] = nil
      first_version = AppStoreListing.with_whats_new(written, dir)
      assert_nil first_version["localizations"]["en-US"]["whatsNew"]
      step = AppStoreListing.plan(listing: first_version, snapshot: empty_snapshot, screenshots: shots, secrets: {})
                            .find { |s| s["action"] == "create_version_localization" }
      refute step["attributes"].key?("whatsNew"), "null leaves What's New out of a first version"
      unwritten = JSON.parse(JSON.generate(raw_listing))
      unwritten["localizations"]["en-US"].delete("whatsNew")
      assert_equal "The button glows amber.", AppStoreListing.with_whats_new(unwritten, dir)["localizations"]["en-US"]["whatsNew"]
      File.write(File.join(dir, "broken.md"), "no front matter")
      error = assert_raises(AppStoreListing::Error) { AppStoreListing.with_whats_new(raw_listing, dir) }
      assert_match(/broken.md/, error.message)
    end
    Dir.mktmpdir do |empty|
      kept = AppStoreListing.with_whats_new(raw_listing, empty)["localizations"]["en-US"]
      assert_equal raw_listing["localizations"]["en-US"].key?("whatsNew"), kept.key?("whatsNew"),
                   "a release branch without changes/ keeps whatever its listing.json says"
      assert_equal raw_listing["localizations"]["en-US"]["whatsNew"], kept["whatsNew"]
    end
  end

  def test_listing_ships_1_2_with_whats_new_and_a_phased_automatic_release
    [listing, mac_listing].each do |platform_listing|
      version = platform_listing["version"]
      assert_equal ["1.2", "AFTER_APPROVAL", true], version.values_at("versionString", "releaseType", "phasedRelease")
      whats_new = platform_listing["localizations"]["en-US"]["whatsNew"].to_s
      refute_empty whats_new
      assert_operator whats_new.length, :<=, AppStoreListing::LIMITS.fetch("whatsNew")
    end
    refute_equal listing["localizations"]["en-US"]["whatsNew"], mac_listing["localizations"]["en-US"]["whatsNew"]
  end

  # The build App Store Connect attaches must carry the listing's version, or the upload lands on the wrong version.
  def test_the_app_and_widget_build_the_listing_version
    generator = File.read(File.join(ROOT, "scripts/generate-xcode-project.rb"))
    versions = generator.scan(/\["MARKETING_VERSION"\] = "([^"]+)"/).flatten.uniq
    assert_equal [listing["version"]["versionString"]], versions
    manifest = JSON.parse(File.read(File.join(ROOT, "distribution/apple-distribution.json")))
    manifest["channels"].each do |channel|
      next unless channel["store"]
      assert_equal listing["version"]["versionString"], channel["store"]["version"], "#{channel["id"]} store.version"
    end
    %w[Apps/Spoonjoy/Shared/Info.plist Apps/Spoonjoy/LiveActivity/Widget/Info.plist].each do |path|
      plist = File.read(File.join(ROOT, path))
      assert_match %r{<key>CFBundleShortVersionString</key>\s*<string>\$\(MARKETING_VERSION\)</string>}, plist, path
    end
  end

  def test_listing_no_longer_promises_adding_a_recipe_in_the_app
    copy = [listing["localizations"]["en-US"]["description"], mac_listing["localizations"]["en-US"]["description"]].join("\n")
    refute_includes copy, "Command-N"
    refute_match(/to add a recipe/i, copy)
  end

  def test_unwanted_or_existing_phased_release_plans_no_step
    unwanted = JSON.parse(JSON.generate(mac_listing))
    unwanted["version"]["phasedRelease"] = false
    steps = AppStoreListing.plan(listing: unwanted, snapshot: mac_snapshot, screenshots: mac_shots, secrets: {})
    refute_includes steps.map { |s| s["action"] }, "create_phased_release"
  end

  class FakeVersionClient
    def get(path, _query = {})
      case path
      when "/v1/apps" then { "data" => [{ "id" => "app1" }] }
      when "/v1/appStoreVersions/v1/appStoreVersionPhasedRelease"
        { "data" => { "id" => "pr1", "attributes" => { "phasedReleaseState" => "INACTIVE" } } }
      else { "data" => nil }
      end
    end

    def get_all(path, _query = {})
      return [] unless path == "/v1/apps/app1/appStoreVersions"

      [{ "id" => "v1", "attributes" => { "appStoreState" => "PREPARE_FOR_SUBMISSION", "versionString" => "1.1",
                                          "copyright" => "2026 Ari Mendelow", "releaseType" => "AFTER_APPROVAL" } }]
    end
  end

  def test_reader_reads_the_versions_phased_release
    version = AppStoreListing::Reader.new(FakeVersionClient.new, listing).send(:version)
    assert_equal({ "id" => "pr1", "state" => "INACTIVE" }, version["phasedRelease"])
  end

  def test_reader_treats_a_missing_phased_release_as_none
    client = Class.new(FakeVersionClient) do
      def get(path, query = {})
        raise AppStoreListing::Error, "HTTP 404 #{path}" if path.end_with?("/appStoreVersionPhasedRelease")

        super
      end
    end.new
    assert_nil AppStoreListing::Reader.new(client, listing).send(:version)["phasedRelease"]
  end

  def test_executor_creates_an_inactive_phased_release_for_the_new_version
    posts = []
    client = Object.new
    client.define_singleton_method(:post) do |path, body|
      posts << [path, body]
      { "data" => { "id" => path == "/v1/appStoreVersions" ? "newv" : "newpr" } }
    end
    client.define_singleton_method(:get_all) { |_path, _query = {}| [{ "id" => "newvl" }] }
    steps = [{ "action" => "create_version", "attributes" => { "versionString" => "1.1" }, "platform" => "IOS" },
             { "action" => "create_phased_release", "versionId" => "$version" }]
    AppStoreListing::Executor.new(client, "app1", log: StringIO.new).run(steps)
    path, body = posts.last
    assert_equal "/v1/appStoreVersionPhasedReleases", path
    assert_equal({ data: { type: "appStoreVersionPhasedReleases", attributes: { phasedReleaseState: "INACTIVE" },
                           relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: "newv" } } } } }, body)
  end

  def test_api_errors_include_associated_errors
    body = JSON.generate("errors" => [{ "title" => "not in valid state", "detail" => "check associated errors",
                                        "meta" => { "associatedErrors" => { "/v1/appStoreVersions/x" => [
                                          { "code" => "ENTITY_ERROR.ATTRIBUTE.REQUIRED", "title" => "missing", "detail" => "whatsNew is required" }
                                        ] } } }])
    detail = AppStoreListing::Client.error_detail(body)
    assert_includes detail, "not in valid state: check associated errors"
    assert_includes detail, "/v1/appStoreVersions/x: ENTITY_ERROR.ATTRIBUTE.REQUIRED missing whatsNew is required"
    assert_equal "plain", AppStoreListing::Client.error_detail("plain")
  end
end
