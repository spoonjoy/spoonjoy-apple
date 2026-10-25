# frozen_string_literal: true

# Run: ruby scripts/test/app_store_listing_test.rb
require "minitest/autorun"
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
    assert_equal %w[patch_app patch_categories patch_age_rating patch_app_info_localization create_version attach_build
                    create_version_localization create_review_detail set_free_price set_availability sync_screenshots], actions
    refute(actions.any? { |a| a.include?("submi") })
    version_localization = steps.find { |s| s["action"] == "create_version_localization" }
    refute version_localization["attributes"].key?("whatsNew"), "a first version cannot carry What's New"
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
        "id" => "v1", "attributes" => listing["version"], "buildId" => "build88",
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
end
