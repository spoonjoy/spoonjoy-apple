# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../lib/parity_sheet"

class ParitySheetTest < Minitest::Test
  def test_canonical_keys_cover_every_screen_device_and_scheme
    keys = ParitySheet.canonical_keys
    assert_equal 10 * 5 * 2, keys.size
    assert_equal "kitchen-iphone-light", keys.first
    assert_includes keys, "sheet-add-to-list-duo-open-dark"
    assert_includes keys, "kitchen-empty-desktop-light"
    assert_includes keys, "cook-step-ipad-landscape-dark"
  end

  def test_shot_key_reads_web_xcresult_and_duo_names
    assert_equal ["cook-step-iphone-dark", :plain], ParitySheet.shot_key("parity-cook-step-iphone-dark.png")
    # xcresulttool's suggested name carries the attachment index and a UUID.
    assert_equal ["kitchen-empty-ipad-light", :plain],
                 ParitySheet.shot_key("parity-kitchen-empty-ipad-light_0_25CA8CA8-B5AB-447F-87FD-299F1B826922.png")
    # The Duo posture driver saves the inner display with -inner.
    assert_equal ["chef-duo-open-light", :inner], ParitySheet.shot_key("parity-chef-duo-open-light-inner.png")
    # The iPad on its side is a device of its own, not the screen "kitchen-ipad".
    assert_equal ["kitchen-ipad-landscape-light", :plain],
                 ParitySheet.shot_key("parity-kitchen-ipad-landscape-light_3_25CA8CA8-B5AB-447F-87FD-299F1B826922.png")
    assert_nil ParitySheet.shot_key("05-open-landscape-kitchen.png")
    assert_nil ParitySheet.shot_key("parity-kitchen-watch-light.png")
    assert_nil ParitySheet.shot_key("parity-kitchen-iphone-sepia.png")
  end

  def test_index_uses_the_inner_display_for_the_open_duo_and_ignores_it_elsewhere
    index = ParitySheet.index([
      "/a/parity-kitchen-duo-open-light.png",
      "/a/parity-kitchen-duo-open-light-inner.png",
      "/a/parity-recipe-iphone-light.png",
      "/a/parity-recipe-iphone-light-inner.png",
      "/a/parity-shopping-duo-open-dark.png"
    ])
    assert_equal "/a/parity-kitchen-duo-open-light-inner.png", index["kitchen-duo-open-light"]
    assert_equal "/a/parity-recipe-iphone-light.png", index["recipe-iphone-light"]
    # The outer display is off while the Duo is open, so only an inner shot counts.
    refute index.key?("shopping-duo-open-dark")
  end

  def test_web_open_duo_shots_are_plain_and_pair_with_the_native_inner_display
    web = ParitySheet.index([
      "/w/parity-kitchen-duo-open-light.png",
      "/w/parity-kitchen-duo-open-light-inner.png",
      "/w/parity-recipe-iphone-dark.png"
    ], side: :web)
    native = ParitySheet.index(["/n/parity-kitchen-duo-open-light-inner.png"])
    assert_equal "/w/parity-kitchen-duo-open-light.png", web["kitchen-duo-open-light"]
    assert_equal "/w/parity-recipe-iphone-dark.png", web["recipe-iphone-dark"]
    pair = ParitySheet.pairs(web: web, native: native).find { |candidate| candidate.key == "kitchen-duo-open-light" }
    assert pair.complete?
  end

  def test_index_rejects_an_unknown_side
    assert_raises(ArgumentError) { ParitySheet.index(["/a/parity-chef-iphone-dark.png"], side: :desktop) }
  end

  def test_pairs_keep_every_canonical_key_and_mark_missing_sides
    web = { "kitchen-iphone-light" => "/w/k.png", "recipe-desktop-dark" => "/w/r.png" }
    native = { "kitchen-iphone-light" => "/n/k.png" }
    pairs = ParitySheet.pairs(web: web, native: native)
    assert_equal ParitySheet.canonical_keys, pairs.map(&:key)
    kitchen = pairs.find { |pair| pair.key == "kitchen-iphone-light" }
    assert_equal ["/w/k.png", "/n/k.png"], [kitchen.web, kitchen.native]
    assert kitchen.complete?
    recipe = pairs.find { |pair| pair.key == "recipe-desktop-dark" }
    assert_nil recipe.native
    refute recipe.complete?
    assert_equal "recipe-desktop-dark.jpg", recipe.file_name
  end

  def test_missing_side_is_a_grey_panel_never_skipped
    pair = ParitySheet::Pair.new("recipe", "desktop", "dark", "/w/r.png", nil)
    argv = ParitySheet.compose_command(pair, "/out/recipe-desktop-dark.jpg")
    assert_equal "magick", argv.first
    assert_includes argv, "/w/r.png"
    assert_equal 1, argv.count { |arg| arg.start_with?("xc:") }, "the missing native side has no grey panel"
    # No text in the image: the local ImageMagick may have no font support. index.html carries the labels.
    refute_includes argv, "-annotate"
    assert_equal "/out/recipe-desktop-dark.jpg", argv.last
  end
  
  def test_both_sides_missing_still_draws_two_panels
    pair = ParitySheet::Pair.new("chef", "ipad", "light", nil, nil)
    argv = ParitySheet.compose_command(pair, "/out/chef-ipad-light.jpg")
    assert_equal 2, argv.count { |arg| arg.start_with?("xc:") }
  end
  
  def test_gap_labels_say_which_side_is_missing_and_why
    assert_equal "native: not captured", ParitySheet.gap_label("native", "recipe")
    assert_equal "web: Add to list is one tap, no sheet", ParitySheet.gap_label("web", "sheet-add-to-list", "iphone")
    assert_equal "native: Mac capture comes with the Mac store frames (Task 10)", ParitySheet.gap_label("native", "kitchen", "desktop")
  end
  
  def test_index_html_lists_every_pair_and_labels_each_gap
    pairs = ParitySheet.pairs(web: { "kitchen-iphone-light" => "/w/k.png" }, native: { "kitchen-iphone-light" => "/n/k.png" })
    html = ParitySheet.index_html(pairs, title: "Baseline")
    assert_includes html, "<title>Baseline</title>"
    assert_includes html, %(src="kitchen-iphone-light.jpg")
    assert_equal ParitySheet.canonical_keys.size, html.scan("<figure").size
    assert_includes html, "1 of 100 pairs complete"
    assert_includes html, "web: Add to list is one tap, no sheet"
    assert_includes html, "native: not captured"
    assert_includes html, "web: Web has no landscape iPad viewport"
  end
  
  def test_shot_file_name_round_trips_through_the_index
    assert_equal "parity-chef-ipad-dark.png", ParitySheet.shot_file_name("chef-ipad-dark")
    assert_equal "parity-chef-duo-open-dark-inner.png", ParitySheet.shot_file_name("chef-duo-open-dark")
    index = ParitySheet.index(["/x/#{ParitySheet.shot_file_name("chef-ipad-dark")}", "/x/#{ParitySheet.shot_file_name("chef-duo-open-dark")}"])
    assert_equal %w[chef-duo-open-dark chef-ipad-dark], index.keys.sort
  end

  def test_collect_copies_shots_under_their_canonical_names
    Dir.mktmpdir do |dir|
      source = File.join(dir, "AAA.png")
      File.write(source, "png")
      out = File.join(dir, "shots")
      copied = ParitySheet.collect({ "chef-iphone-dark" => source }, out)
      assert_equal [File.join(out, "parity-chef-iphone-dark.png")], copied
      assert_equal "png", File.read(copied.first)
    end
  end

  def test_export_names_map_xcresult_attachments_to_their_suggested_names
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "AAA.png"), "png")
      File.write(File.join(dir, "BBB.txt"), "log")
      manifest = [{ "attachments" => [
        { "exportedFileName" => "AAA.png", "suggestedHumanReadableName" => "parity-chef-iphone-dark_0_1234.png" },
        { "exportedFileName" => "BBB.txt", "suggestedHumanReadableName" => "parity-chef-iphone-dark-log_0_99.txt" }
      ] }]
      File.write(File.join(dir, "manifest.json"), JSON.generate(manifest))
      assert_equal({ "chef-iphone-dark" => File.join(dir, "AAA.png") }, ParitySheet.index_export(dir))
    end
  end

  def test_unswitched_schemes_finds_a_dark_shot_identical_to_its_light_shot
    Dir.mktmpdir do |dir|
      write = ->(name, bytes) { File.join(dir, name).tap { |path| File.binwrite(path, bytes) } }
      index = {
        "recipe-iphone-light" => write.("a.png", "same"),
        "recipe-iphone-dark" => write.("b.png", "same"),
        "chef-iphone-light" => write.("c.png", "light"),
        "chef-iphone-dark" => write.("d.png", "dark"),
        "shopping-iphone-light" => write.("e.png", "only light")
      }
      assert_equal ["recipe-iphone-light", "shopping-iphone-light"], ParitySheet.unswitched_schemes(index)
      assert_match(/never switched: recipe-iphone-light, shopping-iphone-light\z/, ParitySheet.scheme_failure(index))
      assert_nil ParitySheet.scheme_failure(index.slice("chef-iphone-light", "chef-iphone-dark"))
    end
  end

  SCRIPT = File.expand_path("../parity-sheet.rb", __dir__)

  def check_shots(dir)
    output = IO.popen([RbConfig.ruby, SCRIPT, "--check-shots", dir], err: %i[child out], &:read)
    [$?.success?, output]
  end

  def test_check_shots_fails_on_an_unswitched_duo_pair_and_passes_a_switched_one
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, "parity-recipe-duo-open-light-inner.png"), "same")
      File.binwrite(File.join(dir, "parity-recipe-duo-open-dark-inner.png"), "same")
      ok, output = check_shots(dir)
      refute ok
      assert_includes output, "never switched: recipe-duo-open-light"

      File.binwrite(File.join(dir, "parity-recipe-duo-open-dark-inner.png"), "dark")
      ok, output = check_shots(dir)
      assert ok, output
      assert_includes output, "2 checked"
    end
  end

  def test_check_shots_fails_on_an_empty_folder
    Dir.mktmpdir do |dir|
      ok, output = check_shots(dir)
      refute ok
      assert_includes output, "no parity shots"
    end
  end
end
