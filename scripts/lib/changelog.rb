# frozen_string_literal: true

require "fileutils"
require "json"

# Changelog fragments: every pull request that changes what someone sees in the app adds one file to changes/,
# written as a short harrowing tale (changes/README.md has the format, docs/whats-new-voice.md the voice). At
# release the fragments are assembled, with no judgement and no model, into the App Store's What's New for each
# platform and into TestFlight's What to Test. When main moves to the next version they are archived under
# changes/released/<version>/.
module Changelog
  PLATFORMS = %w[ios mac].freeze
  # App Store Connect platform names, as the staging script and listing.json use them.
  STORE_PLATFORMS = { "IOS" => "ios", "MAC_OS" => "mac" }.freeze
  KINDS = %w[tale prologue epilogue].freeze
  KEYS = %w[testflight platforms order kind].freeze
  NAME = /\A[a-z0-9][a-z0-9-]*\.md\z/.freeze
  WHATS_NEW_LIMIT = 4000
  TESTFLIGHT_LIMIT = 4000
  TESTFLIGHT_LINE_LIMIT = 160
  DEFAULT_ORDER = 50
  SKIP_LABEL = "no-user-facing-change"
  # What ships in the app. A change under these paths needs a fragment, or the skip label.
  APP_PATHS = [
    "Apps/Spoonjoy/iOS/",
    "Apps/Spoonjoy/macOS/",
    "Apps/Spoonjoy/Shared/",
    "Apps/Spoonjoy/LiveActivity/",
    "Sources/SpoonjoyCore/",
    "Package.swift",
    "Package.resolved",
    # Build settings and package pins live in the project file too.
    "Spoonjoy.xcodeproj/"
  ].freeze
  # The App Store shows What's New as plain text, so Markdown would show up as stray symbols.
  MARKDOWN = [
    [/^\s*#/, "a Markdown heading"],
    [/\*\*|__/, "Markdown bold"],
    [/`/, "a backtick"],
    [/\[[^\]]*\]\([^)]*\)/, "a Markdown link"],
    [/<[a-z\/][^>]*>/i, "HTML"],
    [/^\s*[-*+] /, "a Markdown list marker (use • for a bullet)"]
  ].freeze

  class Error < StandardError; end

  Fragment = Struct.new(:slug, :path, :testflight, :platforms, :order, :kind, :body, keyword_init: true) do
    def for?(platform)
      platforms.include?(platform)
    end
  end

  # The fragment at path, or an Error naming every problem with it.
  def self.parse(path, text = File.read(path))
    name = File.basename(path)
    errors = []
    errors << "#{name}: name it like good-apron.md (lowercase letters, digits and hyphens)" unless name.match?(NAME)
    match = text.match(/\A---\n(.*?)\n---\n(.*)\z/m)
    raise Error, "#{name}: start with a --- front matter block (changes/README.md shows one)" unless match

    meta, line_errors = front_matter(name, match[1])
    errors.concat(line_errors)
    unknown = meta.keys - KEYS
    errors << "#{name}: unknown front matter #{unknown.join(', ')}; use #{KEYS.join(', ')}" unless unknown.empty?
    kind = meta.fetch("kind", "tale")
    errors << "#{name}: kind is #{kind.inspect}; use #{KINDS.join(', ')}" unless KINDS.include?(kind)
    platforms = meta.fetch("platforms", PLATFORMS)
    platforms = [platforms] if platforms.is_a?(String)
    if !platforms.is_a?(Array) || platforms.empty? || !(platforms - PLATFORMS).empty?
      errors << "#{name}: platforms must list some of #{PLATFORMS.join(', ')}"
      platforms = []
    end
    order = meta.fetch("order", DEFAULT_ORDER)
    errors << "#{name}: order must be a whole number" unless order.is_a?(Integer)
    testflight = meta["testflight"]
    if kind == "tale"
      if !testflight.is_a?(String) || testflight.strip.empty?
        errors << "#{name}: testflight needs one plain line saying what changed"
      elsif testflight.include?("\n") || testflight.strip.length > TESTFLIGHT_LINE_LIMIT
        errors << "#{name}: testflight is one line of at most #{TESTFLIGHT_LINE_LIMIT} characters"
      end
    elsif !testflight.nil?
      errors << "#{name}: a #{kind} has no testflight line; only tales reach TestFlight"
    end
    body = match[2].strip
    errors << "#{name}: the tale is empty" if body.empty?
    MARKDOWN.each { |pattern, what| errors << "#{name}: the App Store shows plain text, so drop #{what}" if body.match?(pattern) }
    if platforms.include?("mac") && (word = body[IOS_ONLY_WORDS])
      errors << "#{name}: the Mac shows this tale, so it can't say #{word.inspect}; give iPhone and iPad their own fragment (platforms: [ios])"
    end
    errors.concat(Array(testflight).flat_map { |line| MARKDOWN.select { |pattern, _| line.to_s.match?(pattern) }.map { |_, what| "#{name}: testflight is plain text, so drop #{what}" } })
    raise Error, errors.join("\n") unless errors.empty?

    Fragment.new(slug: name.delete_suffix(".md"), path: path, testflight: testflight&.strip, platforms: platforms.uniq,
                 order: order, kind: kind, body: body)
  end

  # Front matter is plain "key: value" lines, read literally: a # or a colon in the TestFlight line is text, never
  # YAML syntax that would quietly cut the line short. Quotes around a value are optional. platforms reads
  # [ios, mac] or ios, mac; order is a whole number.
  def self.front_matter(name, text)
    meta = {}
    errors = []
    text.each_line do |line|
      next if line.strip.empty?

      key, value = line.chomp.split(":", 2)
      if value.nil? || !key.match?(/\A[a-z]+\z/)
        errors << "#{name}: front matter lines look like key: value, not #{line.strip.inspect}"
        next
      end
      errors << "#{name}: #{key} is set twice" if meta.key?(key)
      value = value.strip
      value = value[1..-2] if value.length >= 2 && value[0] == value[-1] && %w[" '].include?(value[0])
      meta[key] = case key
                  when "platforms" then value.delete_prefix("[").delete_suffix("]").split(",").map(&:strip).reject(&:empty?)
                  when "order" then value.match?(/\A-?\d+\z/) ? value.to_i : value
                  else value
                  end
    end
    [meta, errors]
  end

  # Words that are true only on iPhone and iPad, so a tale the Mac shows can't use them.
  IOS_ONLY_WORDS = /\b(Lock Screen|Dynamic Island|Duo|hinge|tap|taps|tapped|iPhone|iPad|Home Screen|swipe)\b/i.freeze

  # The fragments waiting in dir (top level only; released/ holds archived ones), and every problem with them.
  def self.load(dir)
    fragments = []
    errors = []
    return [fragments, errors] unless Dir.exist?(dir)

    Dir.children(dir).sort.each do |name|
      path = File.join(dir, name)
      next if File.directory?(path) || name == "README.md" || name.start_with?(".")

      begin
        fragments << parse(path)
      rescue Error => e
        errors.concat(e.message.lines.map(&:chomp))
      end
    end
    PLATFORMS.each do |platform|
      %w[prologue epilogue].each do |kind|
        found = fragments.select { |f| f.kind == kind && f.for?(platform) }
        errors << "#{platform} has #{found.length} #{kind}s (#{found.map(&:slug).join(', ')}); a release tells one" if found.length > 1
      end
      text = whats_new(fragments, platform)
      if text.length > WHATS_NEW_LIMIT
        errors << "#{platform} What's New is #{text.length} characters; the App Store allows #{WHATS_NEW_LIMIT}. Tighten a tale."
      end
    end
    [fragments, errors]
  end

  def self.load!(dir)
    fragments, errors = load(dir)
    raise Error, errors.join("\n") unless errors.empty?

    fragments
  end

  def self.sorted(fragments)
    fragments.sort_by { |f| [f.order, f.slug] }
  end

  # The App Store What's New for a platform: the prologue, every tale by order then name, then the epilogue.
  def self.whats_new(fragments, platform)
    mine = fragments.select { |f| f.for?(platform) }
    parts = mine.select { |f| f.kind == "prologue" } + sorted(mine.select { |f| f.kind == "tale" }) +
            mine.select { |f| f.kind == "epilogue" }
    parts.map(&:body).join("\n\n")
  end

  # TestFlight's What to Test, one note for the iPhone and Mac builds of a commit. Tales added by this build come
  # first; the rest of the version's tales follow, so a tester who skipped a build still sees everything new.
  def self.testflight_notes(fragments, added_slugs:, version:, subject:)
    tales = sorted(fragments.select { |f| f.kind == "tale" })
    fresh, earlier = tales.partition { |f| added_slugs.include?(f.slug) }
    line = ->(f) { "• #{f.testflight}#{f.platforms == PLATFORMS ? '' : " (#{f.platforms.map { |p| p == 'ios' ? 'iPhone and iPad' : 'Mac' }.join(', ')} only)"}" }
    out = []
    if fresh.empty?
      out << "No change you can see in this build: #{subject.strip}"
    else
      out << "New in this build:"
      out.concat(fresh.map(&line))
    end
    unless earlier.empty?
      out << ""
      out << "Also new in #{version} so far:"
      out.concat(earlier.map(&line))
    end
    text = out.join("\n")
    text.length > TESTFLIGHT_LIMIT ? "#{text[0, TESTFLIGHT_LIMIT - 1]}…" : text
  end

  def self.app_path?(path)
    APP_PATHS.any? { |prefix| prefix.end_with?("/") ? path.start_with?(prefix) : path == prefix }
  end

  def self.fragment_path?(path)
    path.start_with?("changes/") && path.count("/") == 1 && path.end_with?(".md") && path != "changes/README.md"
  end

  # Problems with a pull request's change set. changes is [[status, path], ...] from git diff --name-status
  # (renames already split into a delete and an add). base_fragments are the fragments waiting on the base.
  # require_fragment is false in the merge queue, where only the version rule is checked again against the real base.
  def self.check_pull_request(changes:, labels:, base_version:, head_version:, base_fragments:, head_fragments:,
                              require_fragment: true)
    errors = []
    touched = changes.map(&:last)
    app = touched.select { |path| app_path?(path) }
    added = changes.select { |status, path| %w[A M].include?(status) && fragment_path?(path) }.map(&:last)
    if require_fragment && !app.empty? && added.empty? && !labels.include?(SKIP_LABEL)
      errors << "This pull request changes the app (#{app.first(3).join(', ')}#{app.length > 3 ? ', …' : ''}) but adds no " \
                "fragment in changes/. Add one (changes/README.md), or label the pull request #{SKIP_LABEL} if nobody " \
                "using the app could notice."
    end
    if base_version != head_version
      left = base_fragments & head_fragments
      unless left.empty?
        errors << "The version moves from #{base_version} to #{head_version}, so #{base_version}'s fragments must be " \
                  "archived first: ruby scripts/changelog.rb archive --version #{base_version} (still waiting: #{left.join(', ')})"
      end
    end
    errors
  end

  # Moves every waiting fragment to changes/released/<version>/ beside the What's New each platform shipped.
  # Where each platform's en-US What's New sits in listing.json.
  LISTING_WHATS_NEW = { "ios" => %w[localizations en-US], "mac" => %w[mac localizations en-US] }.freeze

  # Moves the waiting fragments to released/<version>/ beside the What's New each platform shipped. A whatsNew
  # written in the listing (listing_path) is what that platform shipped, since it wins over the fragments; it is
  # recorded instead of the assembled text and removed from the listing, so it never carries into the next version.
  def self.archive(dir, version, listing_path: nil)
    raise Error, "version looks like 1.2, not #{version.inspect}" unless version.match?(/\A\d+(\.\d+)*\z/)

    fragments = load!(dir)
    listing = listing_path && JSON.parse(File.read(listing_path))
    written = PLATFORMS.to_h { |platform| [platform, listing&.dig(*LISTING_WHATS_NEW.fetch(platform), "whatsNew")] }
    raise Error, "No fragments are waiting in #{dir}" if fragments.empty? && written.values.none?(String)

    target = File.join(dir, "released", version)
    FileUtils.mkdir_p(target)
    PLATFORMS.each do |platform|
      text = written[platform].is_a?(String) ? written[platform] : whats_new(fragments, platform)
      File.write(File.join(target, "whats-new-#{platform}.txt"), "#{text}\n") unless text.empty?
    end
    fragments.each { |f| FileUtils.mv(f.path, File.join(target, File.basename(f.path))) }
    if written.values.any?(String)
      written.each { |platform, text| listing.dig(*LISTING_WHATS_NEW.fetch(platform)).delete("whatsNew") if text.is_a?(String) }
      File.write(listing_path, "#{JSON.pretty_generate(listing)}\n")
    end
    target
  end
end
