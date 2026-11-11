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

  def listing
    @listing ||= JSON.parse(File.read(LISTING_PATH))
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
    AppStoreListing.for_platform(listing, "MAC_OS")
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
    assert_equal listing["mac"]["localizations"]["en-US"]["whatsNew"], localization["whatsNew"]
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

  # Product page header and search results art (iOS 27 creative assets) go through the Asset Library API, not the web.
  def with_creative(names)
    with_screenshots do |dir|
      Dir.mkdir(File.join(dir, "creative"))
      creative = JSON.parse(JSON.generate(listing))
      creative["creativeAssets"] = names.transform_values { |name| "creative/#{name}" }
      yield creative, dir
    end
  end

  def test_creative_assets_accept_only_apple_sizes_without_alpha
    with_creative("PRODUCT_PAGE_HEADER_ASSET" => "header.png", "APP_STORE_SEARCH_RESULTS_ASSET" => "search.png") do |creative, dir|
      png(File.join(dir, "creative", "header.png"), 3840, 1646)
      png(File.join(dir, "creative", "search.png"), 2400, 1600)
      assert_equal [], AppStoreListing.validate(creative, dir)
      png(File.join(dir, "creative", "header.png"), 3840, 2160)
      png(File.join(dir, "creative", "search.png"), 5244, 2950, color_type: 6)
      errors = AppStoreListing.validate(creative, dir)
      assert(errors.any? { |e| e.include?("PRODUCT_PAGE_HEADER_ASSET creative/header.png is 3840x2160") }, errors.inspect)
      assert(errors.any? { |e| e.include?("search.png has transparency") }, errors.inspect)
    end
  end

  def test_creative_assets_reject_unknown_types_and_missing_files
    with_creative("PRODUCT_PAGE_HEADER_ASSET" => "absent.png", "HEADER" => "x.png") do |creative, dir|
      errors = AppStoreListing.validate(creative, dir)
      assert(errors.any? { |e| e.include?("creative/absent.png does not exist") }, errors.inspect)
      assert(errors.any? { |e| e.include?("unknown creative asset type HEADER") }, errors.inspect)
    end
  end

  def test_listing_without_creative_assets_plans_no_creative_step
    assert_equal({}, AppStoreListing.local_creative_assets(listing, "/nonexistent"))
    steps = AppStoreListing.plan(listing: listing, snapshot: empty_snapshot, screenshots: shots, secrets: {})
    refute(steps.any? { |s| s["action"] == "sync_creative_asset" })
  end

  def test_mac_listing_does_not_inherit_the_ios_creative_assets
    creative = JSON.parse(JSON.generate(listing))
    creative["creativeAssets"] = { "PRODUCT_PAGE_HEADER_ASSET" => "creative/header.png" }
    assert_equal({}, AppStoreListing.for_platform(creative, "MAC_OS")["creativeAssets"])
  end

  def creative_version(placements)
    { "id" => "v1", "attributes" => listing["version"], "buildId" => "build88", "localization" => { "id" => "vl", "attributes" => {} },
      "reviewDetail" => nil, "screenshotSets" => {}, "creativePlacements" => placements }
  end

  def test_creative_asset_is_placed_once_and_replaced_only_when_the_file_changes
    with_creative("PRODUCT_PAGE_HEADER_ASSET" => "header.png") do |creative, dir|
      png(File.join(dir, "creative", "header.png"), 3840, 1646)
      local = AppStoreListing.local_creative_assets(creative, dir)
      wanted = local.fetch("PRODUCT_PAGE_HEADER_ASSET")
      assert_match(/\A[0-9a-f]{32}-header\.png\z/, wanted["referenceName"])

      fresh = AppStoreListing.plan(listing: creative, snapshot: empty_snapshot.merge("version" => creative_version({})),
                                   screenshots: shots, secrets: {}, creative_assets: local)
      step = fresh.find { |s| s["action"] == "sync_creative_asset" }
      assert_equal ["PRODUCT_PAGE_HEADER_ASSET", nil, "vl"], [step["placementType"], step["placementId"], step["localizationId"]]

      same = { "PRODUCT_PAGE_HEADER_ASSET" => { "id" => "pl1", "referenceName" => wanted["referenceName"] } }
      unchanged = AppStoreListing.plan(listing: creative, snapshot: empty_snapshot.merge("version" => creative_version(same)),
                                       screenshots: shots, secrets: {}, creative_assets: local)
      refute(unchanged.any? { |s| s["action"] == "sync_creative_asset" })

      old = { "PRODUCT_PAGE_HEADER_ASSET" => { "id" => "pl1", "referenceName" => "web-upload.png" } }
      replaced = AppStoreListing.plan(listing: creative, snapshot: empty_snapshot.merge("version" => creative_version(old)),
                                      screenshots: shots, secrets: {}, creative_assets: local)
      assert_equal "pl1", replaced.find { |s| s["action"] == "sync_creative_asset" }["placementId"]
    end
  end

  class FakeCreativeClient
    attr_reader :calls

    def initialize(image_state: "APPROVED")
      @calls = []
      @image_state = image_state
    end

    def get(path, query = {})
      @calls << [:get, path, query]
      { "data" => [{ "id" => "pl1", "attributes" => { "placementType" => "PRODUCT_PAGE_HEADER_ASSET", "state" => "ACTIVE" },
                     "relationships" => { "image" => { "data" => { "type" => "appAssetLibraryImages", "id" => "img1" } } } },
                   { "id" => "pl2", "attributes" => { "placementType" => "APP_SCREENSHOT" }, "relationships" => {} }],
        "included" => [{ "type" => "appAssetLibraryImages", "id" => "img1",
                         "attributes" => { "referenceName" => "abc-header.png", "state" => @image_state } }] }
    end

    def delete(path)
      @calls << [:delete, path]
    end

    def post(path, body)
      @calls << [:post, path, body]
      return { "data" => { "id" => "newpl" } } if path == "/v1/appAssetLibraryPlacements"

      { "data" => { "id" => "newimg", "attributes" => { "uploadOperations" => [{ "method" => "PUT", "url" => "https://upload", "offset" => 0, "length" => 3 }] } } }
    end

    def patch(path, body)
      @calls << [:patch, path, body]
    end

    def upload(operation, bytes)
      @calls << [:upload, operation["url"], bytes.bytesize]
    end
  end

  def creative_listing
    JSON.parse(JSON.generate(listing)).merge("creativeAssets" => { "PRODUCT_PAGE_HEADER_ASSET" => "creative/header.png" })
  end

  def test_reader_maps_creative_placements_to_their_image_reference_names_in_one_request
    client = FakeCreativeClient.new
    placements = AppStoreListing::Reader.new(client, creative_listing).send(:creative_placements, "vl")
    assert_equal({ "PRODUCT_PAGE_HEADER_ASSET" => { "id" => "pl1", "referenceName" => "abc-header.png", "failed" => false } }, placements)
    assert_equal 1, client.calls.length
    assert_equal "/v1/appStoreVersionLocalizations/vl/placements", client.calls.first[1]
    assert_equal "image", client.calls.first[2]["include"]
  end

  def test_reader_makes_no_placement_request_without_creative_assets
    client = FakeCreativeClient.new
    assert_equal({}, AppStoreListing::Reader.new(client, listing).send(:creative_placements, "vl"))
    assert_equal({}, AppStoreListing::Reader.new(client, creative_listing).send(:creative_placements, nil))
    assert_equal [], client.calls
  end

  def test_a_failed_creative_asset_is_placed_again_even_when_unchanged
    client = FakeCreativeClient.new(image_state: "FAILED")
    existing = AppStoreListing::Reader.new(client, creative_listing).send(:creative_placements, "vl")
    file = { "path" => "/x/header.png", "checksum" => "abc", "size" => 1, "referenceName" => "abc-header.png" }
    steps = AppStoreListing.plan(listing: creative_listing, snapshot: empty_snapshot.merge("version" => creative_version(existing)),
                                 screenshots: shots, secrets: {}, creative_assets: { "PRODUCT_PAGE_HEADER_ASSET" => file })
    assert_equal "pl1", steps.find { |s| s["action"] == "sync_creative_asset" }["placementId"]
  end

  def test_creative_asset_on_a_new_version_targets_the_new_localization
    file = { "path" => "/x/header.png", "checksum" => "abc", "size" => 1, "referenceName" => "abc-header.png" }
    steps = AppStoreListing.plan(listing: creative_listing, snapshot: empty_snapshot, screenshots: shots, secrets: {},
                                 creative_assets: { "PRODUCT_PAGE_HEADER_ASSET" => file })
    step = steps.find { |s| s["action"] == "sync_creative_asset" }
    assert_equal ["$version_localization", nil], [step["localizationId"], step["placementId"]]
  end

  def test_a_placement_404_fails_the_run_instead_of_planning_a_new_version
    client = Class.new(FakeVersionClient) do
      def get_all(path, query = {})
        return [{ "id" => "vl", "attributes" => { "locale" => "en-US" } }] if path.end_with?("/appStoreVersionLocalizations")

        super
      end

      def get(path, query = {})
        raise AppStoreListing::Error, "HTTP 404 #{path}" if path.end_with?("/placements")

        super
      end
    end.new
    mac_creative = mac_listing.merge("creativeAssets" => { "PRODUCT_PAGE_HEADER_ASSET" => "creative/header.png" })
    assert_raises(AppStoreListing::Error) { AppStoreListing::Reader.new(client, mac_creative).snapshot }
    version = AppStoreListing::Reader.new(client, mac_listing).snapshot["version"]
    assert_equal ["v1", {}], [version["id"], version["creativePlacements"]]
  end

  def test_non_object_creative_assets_is_a_validation_error
    bad = JSON.parse(JSON.generate(listing)).merge("creativeAssets" => nil)
    errors = with_screenshots { |dir| AppStoreListing.validate(bad, dir) }
    assert_includes errors, "creativeAssets must be an object of placement type to file"
    assert_equal({}, AppStoreListing.local_creative_assets(bad, "/nonexistent"))
  end

  def test_executor_replaces_the_placement_with_a_newly_uploaded_library_image
    client = FakeCreativeClient.new
    Dir.mktmpdir do |dir|
      path = File.join(dir, "header.png")
      File.binwrite(path, "abc")
      step = { "action" => "sync_creative_asset", "summary" => "Set header", "placementType" => "PRODUCT_PAGE_HEADER_ASSET",
               "placementId" => "pl1", "localizationId" => "vl",
               "file" => { "path" => path, "checksum" => "c", "size" => 3, "referenceName" => "c-header.png" } }
      AppStoreListing::Executor.new(client, "app1", log: StringIO.new).run([step])
    end
    kinds = client.calls.map { |c| [c[0], c[1]] }
    assert_equal [[:post, "/v1/appAssetLibraryImages"], [:upload, "https://upload"], [:patch, "/v1/appAssetLibraryImages/newimg"],
                  [:delete, "/v1/appAssetLibraryPlacements/pl1"], [:post, "/v1/appAssetLibraryPlacements"]], kinds
    image = client.calls[0][2][:data]
    assert_equal({ category: "CREATIVE_ASSETS", fileName: "header.png", fileSize: 3, referenceName: "c-header.png" }, image[:attributes])
    assert_equal({ data: { type: "appAssetLibraries", id: "app1" } }, image[:relationships][:assetLibrary])
    placement = client.calls.last[2][:data]
    assert_equal({ placementType: "PRODUCT_PAGE_HEADER_ASSET", placementGroup: "DEFAULT_PROFILE" }, placement[:attributes])
    assert_equal "newimg", placement[:relationships][:image][:data][:id]
    assert_equal "vl", placement[:relationships][:appStoreVersionLocalization][:data][:id]
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
