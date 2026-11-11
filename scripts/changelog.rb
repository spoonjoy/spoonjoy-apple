#!/usr/bin/env ruby
# frozen_string_literal: true

# Changelog fragments (changes/README.md). Deterministic: the same commit always gives the same text.
#
#   ruby scripts/changelog.rb validate                     every fragment, and each platform's What's New, fit the rules
#   ruby scripts/changelog.rb whats-new --platform IOS     print What's New for IOS or MAC_OS
#   ruby scripts/changelog.rb check-pr --base SHA --head SHA [--labels a,b] [--version-only]
#                                                          the pull request carries a fragment if it changes the app,
#                                                          and a version change archives the old version's fragments
#   ruby scripts/changelog.rb testflight-notes [--since REV]
#                                                          print TestFlight's What to Test for HEAD (REV defaults to HEAD^)
#   ruby scripts/changelog.rb archive --version 1.2        move the waiting fragments to changes/released/1.2/

require "json"
require "open3"
require "optparse"
require_relative "lib/changelog"

ROOT = File.expand_path("..", __dir__)
DIR = File.join(ROOT, "changes")
LISTING = "distribution/app-store/listing.json"

def git(*args)
  out, err, status = Open3.capture3("git", "-C", ROOT, *args)
  abort "git #{args.join(' ')} failed: #{err.strip}" unless status.success?
  out
end

def version_at(rev)
  JSON.parse(git("show", "#{rev}:#{LISTING}")).dig("version", "versionString")
end

def fragments_at(rev)
  git("ls-tree", "--name-only", rev, "changes/").lines.map(&:strip)
                                              .select { |path| Changelog.fragment_path?(path) }
                                              .map { |path| File.basename(path, ".md") }
end

def name_status(from, to)
  git("diff", "--name-status", "--no-renames", from, to).lines.map { |line| line.chomp.split("\t", 2) }
end

command = ARGV.shift
options = { labels: [], since: "HEAD^" }
OptionParser.new do |opts|
  opts.on("--platform P") { |v| options[:platform] = v }
  opts.on("--base SHA") { |v| options[:base] = v }
  opts.on("--head SHA") { |v| options[:head] = v }
  opts.on("--labels LIST") { |v| options[:labels] = v.split(",").map(&:strip) }
  opts.on("--since REV") { |v| options[:since] = v }
  opts.on("--version V") { |v| options[:version] = v }
  opts.on("--subject TEXT") { |v| options[:subject] = v }
  opts.on("--version-only") { options[:version_only] = true }
end.parse!

begin
  case command
  when "validate"
    fragments = Changelog.load!(DIR)
    Changelog::PLATFORMS.each do |platform|
      text = Changelog.whats_new(fragments, platform)
      puts "#{platform}: #{fragments.count { |f| f.for?(platform) }} fragment(s), #{text.length}/#{Changelog::WHATS_NEW_LIMIT} characters"
    end
  when "whats-new"
    platform = Changelog::STORE_PLATFORMS.fetch(options[:platform]) { abort "--platform is IOS or MAC_OS" }
    puts Changelog.whats_new(Changelog.load!(DIR), platform)
  when "check-pr"
    abort "check-pr needs --base and --head" unless options[:base] && options[:head]
    base = git("merge-base", options[:base], options[:head]).strip
    errors = Changelog.load(DIR).last
    errors += Changelog.check_pull_request(
      changes: name_status(base, options[:head]), labels: options[:labels],
      base_version: version_at(base), head_version: version_at(options[:head]),
      base_fragments: fragments_at(base), head_fragments: fragments_at(options[:head]),
      require_fragment: !options[:version_only]
    )
    if errors.empty?
      puts "Changelog: fine."
    else
      errors.each { |error| puts "::error::#{error}" }
      exit 1
    end
  when "testflight-notes"
    added = name_status(options[:since], "HEAD").select { |status, path| %w[A M].include?(status) && Changelog.fragment_path?(path) }
                                               .map { |_, path| File.basename(path, ".md") }
    subject = options[:subject] || git("log", "-1", "--format=%s", "HEAD").strip
    puts Changelog.testflight_notes(Changelog.load!(DIR), added_slugs: added,
                                    version: options[:version] || version_at("HEAD"), subject: subject)
  when "archive"
    abort "archive needs --version" unless options[:version]
    puts "Archived into #{Changelog.archive(DIR, options[:version])}"
  else
    abort File.read(__FILE__).lines.grep(/^#   /).join
  end
rescue Changelog::Error => e
  e.message.lines.each { |line| warn "::error::#{line.chomp}" }
  exit 1
end
