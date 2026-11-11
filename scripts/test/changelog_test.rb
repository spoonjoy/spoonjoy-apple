# frozen_string_literal: true

# Run: ruby scripts/test/changelog_test.rb
require "minitest/autorun"
require "open3"
require "tmpdir"
require_relative "../lib/changelog"

class ChangelogTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def fragment(dir, name, meta, body = "The pale button glowed amber at last.")
    File.write(File.join(dir, name), "---\n#{meta}\n---\n#{body}\n")
  end

  def errors_for(meta, body = "A tale.", name: "a-tale.md")
    Dir.mktmpdir do |dir|
      fragment(dir, name, meta, body)
      Changelog.load(dir).last
    end
  end

  def test_checked_in_fragments_are_valid
    fragments, errors = Changelog.load(File.join(ROOT, "changes"))
    assert_equal [], errors
    refute_empty fragments
  end

  def test_a_tale_needs_one_plain_testflight_line
    assert_equal ["a-tale.md: testflight needs one plain line saying what changed"], errors_for("order: 1")
    assert_match(/at most 160/, errors_for("testflight: #{'x' * 161}").first)
    assert_match(/testflight is plain text/, errors_for("testflight: '**Bold** claim'").first)
  end

  def test_the_body_is_plain_text_for_the_app_store
    { "# Heading" => "heading", "Some **bold**" => "bold", "Run `x`" => "backtick", "See [it](https://x)" => "link",
      "- item" => "list marker", "<b>hi</b>" => "HTML" }.each do |body, what|
      assert_match(/#{what}/, errors_for("testflight: ok", body).join, body)
    end
    assert_equal [], errors_for("testflight: ok", "• A bullet is fine.\n• So is a second.")
  end

  def test_front_matter_is_checked
    assert_match(/unknown front matter colour/, errors_for("testflight: ok\ncolour: red").join)
    assert_match(/platforms must list/, errors_for("testflight: ok\nplatforms: [watch]").join)
    assert_match(/order must be a whole number/, errors_for("testflight: ok\norder: soon").join)
    assert_match(/kind is "saga"/, errors_for("testflight: ok\nkind: saga").join)
    assert_match(/a prologue has no testflight line/, errors_for("testflight: ok\nkind: prologue").join)
    assert_match(/name it like/, errors_for("testflight: ok", name: "Big_Change.md").join)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "bare.md"), "No front matter here.\n")
      assert_match(/start with a --- front matter block/, Changelog.load(dir).last.join)
    end
  end

  # Front matter is read literally, so a PR number or a colon in the TestFlight line is never cut short.
  def test_front_matter_is_read_literally
    Dir.mktmpdir do |dir|
      fragment(dir, "hash.md", "testflight: Fixes the crash in the #270 flow: shopping stays checked\nplatforms: ios, mac", "Fixed.")
      fragment(dir, "quoted.md", "testflight: \"Quoted: still fine\"\nplatforms: [mac]\norder: -3", "Mac.")
      fragments = Changelog.load!(dir)
      assert_equal "Fixes the crash in the #270 flow: shopping stays checked", fragments.find { |f| f.slug == "hash" }.testflight
      assert_equal %w[ios mac], fragments.find { |f| f.slug == "hash" }.platforms
      quoted = fragments.find { |f| f.slug == "quoted" }
      assert_equal ["Quoted: still fine", ["mac"], -3], [quoted.testflight, quoted.platforms, quoted.order]
    end
    assert_match(/look like key: value/, errors_for("testflight: ok\njust words").join)
    assert_match(/testflight is set twice/, errors_for("testflight: ok\ntestflight: again").join)
  end

  def test_a_tale_the_mac_shows_uses_no_iphone_only_words
    ["Tap Next.", "It shows on the Lock Screen.", "In the Dynamic Island.", "On iPhone Duo.", "Follows the hinge."].each do |body|
      assert_match(/the Mac shows this tale/, errors_for("testflight: ok", body).join, body)
      assert_equal [], errors_for("testflight: ok\nplatforms: [ios]", body), body
    end
    assert_equal [], errors_for("testflight: ok", "A tapestry of flavours.")
  end

  def test_dotfiles_in_changes_are_ignored
    Dir.mktmpdir do |dir|
      fragment(dir, "amber.md", "testflight: a")
      File.write(File.join(dir, ".DS_Store"), "\x00\x01")
      assert_equal [[], 1], [Changelog.load(dir).last, Changelog.load(dir).first.length]
    end
  end

  def test_whats_new_reads_prologue_tales_by_order_then_name_then_epilogue
    Dir.mktmpdir do |dir|
      fragment(dir, "zeta.md", "testflight: z\norder: 10", "Zeta.")
      fragment(dir, "alpha.md", "testflight: a\norder: 10", "Alpha.")
      fragment(dir, "first.md", "testflight: f\norder: 1", "First.")
      fragment(dir, "default.md", "testflight: d", "Default order.")
      fragment(dir, "mac-only.md", "testflight: m\nplatforms: [mac]", "Mac.")
      fragment(dir, "aaa-end.md", "kind: epilogue", "The end.")
      fragment(dir, "zzz-start.md", "kind: prologue", "Once upon a time.")
      Dir.mkdir(File.join(dir, "released"))
      fragment(File.join(dir, "released"), "old.md", "testflight: old", "Old news.")
      fragments = Changelog.load!(dir)
      assert_equal "Once upon a time.\n\nFirst.\n\nAlpha.\n\nZeta.\n\nDefault order.\n\nThe end.", Changelog.whats_new(fragments, "ios")
      assert_includes Changelog.whats_new(fragments, "mac"), "Mac."
      # Same input, same text: nothing depends on file system order or the clock.
      assert_equal Changelog.whats_new(fragments.reverse, "ios"), Changelog.whats_new(fragments, "ios")
    end
  end

  def test_whats_new_over_the_app_store_limit_fails_validation
    Dir.mktmpdir do |dir|
      fragment(dir, "one.md", "testflight: one", "a" * 2500)
      fragment(dir, "two.md", "testflight: two\nplatforms: [ios]", "b" * 2500)
      errors = Changelog.load(dir).last
      assert_equal 1, errors.length
      assert_match(/ios What's New is 5002 characters/, errors.first)
    end
  end

  def test_one_prologue_per_platform
    Dir.mktmpdir do |dir|
      fragment(dir, "p1.md", "kind: prologue", "One.")
      fragment(dir, "p2.md", "kind: prologue\nplatforms: [mac]", "Two.")
      assert_equal ["mac has 2 prologues (p1, p2); a release tells one"], Changelog.load(dir).last
    end
  end

  def test_testflight_notes_lead_with_this_build
    Dir.mktmpdir do |dir|
      fragment(dir, "amber.md", "testflight: Buttons fill amber at night.\norder: 30")
      fragment(dir, "wrap.md", "testflight: Titles wrap.\norder: 20")
      fragment(dir, "ipad.md", "testflight: Titles use the display serif.\nplatforms: [ios]")
      fragment(dir, "intro.md", "kind: prologue")
      fragments = Changelog.load!(dir)
      notes = Changelog.testflight_notes(fragments, added_slugs: ["amber"], version: "1.2", subject: "Amber (#270)")
      assert_equal "New in this build:\n• Buttons fill amber at night.\n\nAlso new in 1.2 so far:\n• Titles wrap.\n" \
                   "• Titles use the display serif. (iPhone and iPad only)", notes
      quiet = Changelog.testflight_notes(fragments, added_slugs: [], version: "1.2", subject: "Faster CI (#1)")
      assert quiet.start_with?("No change you can see in this build: Faster CI (#1)\n\nAlso new in 1.2 so far:")
    end
  end

  def check(changes, labels: [], base_version: "1.2", head_version: "1.2", base_fragments: [], head_fragments: [])
    Changelog.check_pull_request(changes: changes, labels: labels, base_version: base_version, head_version: head_version,
                                 base_fragments: base_fragments, head_fragments: head_fragments)
  end

  def test_an_app_change_needs_a_fragment_or_the_skip_label
    app = [%w[M Apps/Spoonjoy/Shared/Views/Recipe.swift]]
    assert_match(/adds no fragment in changes/, check(app).join)
    assert_equal [], check(app + [%w[A changes/amber.md]])
    assert_equal [], check(app + [%w[M changes/amber.md]]), "amending a waiting tale counts"
    assert_equal [], check(app, labels: ["no-user-facing-change"])
    assert_match(/adds no fragment/, check(app + [%w[A changes/README.md]]).join)
    assert_match(/adds no fragment/, check(app + [%w[A changes/released/1.1/old.md]]).join)
    assert_match(/adds no fragment/, check(app + [%w[D changes/amber.md]]).join)
    assert_match(/adds no fragment/, check([%w[M Sources/SpoonjoyCore/Sync.swift]]).join)
    assert_match(/adds no fragment/, check([%w[M Package.resolved]]).join)
    assert_match(/adds no fragment/, check([%w[M Spoonjoy.xcodeproj/project.pbxproj]]).join)
  end

  def test_changes_outside_the_app_need_nothing
    ["Tests/SpoonjoyCoreTests/X.swift", "Apps/Spoonjoy/Journeys/CookJourney.swift", "Apps/Spoonjoy/UITests/A.swift",
     ".github/workflows/native.yml", "scripts/changelog.rb", "docs/apple-distribution.md", "Sources/SpoonjoyReins/R.swift",
     "distribution/app-store/listing.json"].each do |path|
      assert_equal [], check([["M", path]]), path
    end
  end

  def test_a_version_change_must_archive_the_old_fragments
    errors = check([%w[M distribution/app-store/listing.json]], base_version: "1.2", head_version: "1.3",
                                                                 base_fragments: %w[amber wrap], head_fragments: %w[amber wrap])
    assert_match(/archive --version 1.2 \(still waiting: amber, wrap\)/, errors.join)
    assert_equal [], check([%w[M distribution/app-store/listing.json]], base_version: "1.2", head_version: "1.3",
                                                                         base_fragments: %w[amber wrap], head_fragments: [])
    # In the merge queue only the version rule runs.
    queue = Changelog.check_pull_request(changes: [%w[M Apps/Spoonjoy/Shared/A.swift]], labels: [], base_version: "1.2",
                                         head_version: "1.3", base_fragments: %w[late], head_fragments: %w[late],
                                         require_fragment: false)
    assert_equal 1, queue.length
    assert_match(/still waiting: late/, queue.first)
  end

  def test_archive_moves_fragments_beside_the_text_each_platform_shipped
    Dir.mktmpdir do |dir|
      fragment(dir, "amber.md", "testflight: a", "Amber.")
      fragment(dir, "ipad.md", "testflight: i\nplatforms: [ios]", "iPad.")
      File.write(File.join(dir, "README.md"), "Readme stays.")
      target = Changelog.archive(dir, "1.2")
      assert_equal File.join(dir, "released", "1.2"), target
      assert_equal %w[README.md released], Dir.children(dir).sort
      assert_equal %w[amber.md ipad.md whats-new-ios.txt whats-new-mac.txt], Dir.children(target).sort
      assert_equal "Amber.\n\niPad.\n", File.read(File.join(target, "whats-new-ios.txt"))
      assert_equal "Amber.\n", File.read(File.join(target, "whats-new-mac.txt"))
      assert_equal [], Changelog.load!(dir)
      assert_raises(Changelog::Error) { Changelog.archive(dir, "1.2") }
      assert_raises(Changelog::Error) { Changelog.archive(dir, "next") }
    end
  end

  def test_the_command_line_validates_and_prints
    out, status = Open3.capture2e(RbConfig.ruby, File.join(ROOT, "scripts/changelog.rb"), "validate")
    assert status.success?, out
    assert_match(/ios: \d+ fragment\(s\), \d+\/4000 characters/, out)
    out, status = Open3.capture2e(RbConfig.ruby, File.join(ROOT, "scripts/changelog.rb"), "whats-new", "--platform", "MAC_OS")
    assert status.success?, out
    refute_empty out.strip
  end
end
