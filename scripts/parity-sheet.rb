# frozen_string_literal: true

# Usage: ruby scripts/parity-sheet.rb --web-run <spoonjoy-v2 Journeys run id> --native-run <spoonjoy-apple Journeys run id> --out <dir>
#        ruby scripts/parity-sheet.rb --web-dir <dir> --native-dir <dir> --out <dir>
#        ruby scripts/parity-sheet.rb --export-xcresult <bundle> --out <dir>
#
# Builds the web/native parity contact sheet in <dir>: one <screen>-<device>-<scheme>.jpg per canonical pair (web
# left, native right, a grey panel for a missing side) and an index.html that labels every pair and gap. With run ids
# it downloads both runs' parity-shots artifacts (parity-shots on web; parity-shots-iphone, -ipad and -duo on native)
# with `gh run download` into <dir>/downloads. Any .xcresult under the native folder is exported with
# `xcrun xcresulttool export attachments` too. Needs gh, Xcode and ImageMagick (`magick`).
#
# --export-xcresult copies a result bundle's parity shots into <dir> under their canonical names; the Journeys
# workflow uploads that folder as a parity-shots artifact.
require "fileutils"
require "optparse"
require "tmpdir"
require_relative "lib/parity_sheet"

WEB_REPO = "spoonjoy/spoonjoy-v2"
NATIVE_REPO = "spoonjoy/spoonjoy-apple"

options = { title: "Spoonjoy web/native parity" }
OptionParser.new do |parser|
  parser.on("--web-run ID") { |value| options[:web_run] = value }
  parser.on("--native-run ID") { |value| options[:native_run] = value }
  parser.on("--web-dir DIR") { |value| options[:web_dir] = value }
  parser.on("--native-dir DIR") { |value| options[:native_dir] = value }
  parser.on("--out DIR") { |value| options[:out] = value }
  parser.on("--title TEXT") { |value| options[:title] = value }
  parser.on("--export-xcresult BUNDLE") { |value| options[:export_xcresult] = value }
end.parse!
usage = "usage: parity-sheet.rb (--web-run ID | --web-dir DIR) (--native-run ID | --native-dir DIR) --out DIR, " \
        "or --export-xcresult BUNDLE --out DIR"
abort(usage) unless options[:out]

out = File.expand_path(options[:out])

def run!(*argv)
  system(*argv) || abort("failed: #{argv.first(4).join(" ")}")
end

def export(bundle, folder)
  FileUtils.mkdir_p(folder)
  run!("xcrun", "xcresulttool", "export", "attachments", "--path", bundle, "--output-path", folder)
  ParitySheet.index_export(folder)
end

if options[:export_xcresult]
  Dir.mktmpdir("parity-export") do |folder|
    copied = ParitySheet.collect(export(options[:export_xcresult], folder), out)
    puts "parity shots: #{copied.size} copied into #{out}"
  end
  exit
end

abort(usage) unless (options[:web_run] || options[:web_dir]) && (options[:native_run] || options[:native_dir])
FileUtils.mkdir_p(out)

web_dir = options[:web_dir] || File.join(out, "downloads", "web")
if options[:web_run]
  FileUtils.mkdir_p(web_dir)
  run!("gh", "run", "download", options[:web_run], "-R", WEB_REPO, "-p", "parity-shots*", "-D", web_dir)
end

native_dir = options[:native_dir] || File.join(out, "downloads", "native")
if options[:native_run]
  FileUtils.mkdir_p(native_dir)
  run!("gh", "run", "download", options[:native_run], "-R", NATIVE_REPO, "-p", "parity-shots*", "-D", native_dir)
end

web = ParitySheet.index(Dir.glob(File.join(web_dir, "**", "parity-*.png")))
native = ParitySheet.index(Dir.glob(File.join(native_dir, "**", "parity-*.png")))
Dir.glob(File.join(native_dir, "**", "*.xcresult")).sort.each_with_index do |bundle, number|
  native.merge!(export(bundle, File.join(out, "exports", "#{number}-#{File.basename(bundle, ".xcresult")}")))
end

pairs = ParitySheet.pairs(web: web, native: native)
pairs.each { |pair| run!(*ParitySheet.compose_command(pair, File.join(out, pair.file_name))) }
File.write(File.join(out, "index.html"), ParitySheet.index_html(pairs, title: options[:title]))

complete = pairs.count(&:complete?)
puts "parity sheet: #{complete} of #{pairs.size} pairs complete (web #{web.size}, native #{native.size} shots)"
pairs.reject(&:complete?).each do |pair|
  missing = [pair.web ? nil : "web", pair.native ? nil : "native"].compact.join(" and ")
  puts "  #{pair.key}: no #{missing}"
end
puts File.join(out, "index.html")
