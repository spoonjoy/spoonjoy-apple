#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks that docs/source/spoonjoy-v2-api-recordings matches the response recordings on spoonjoy-v2's main
# branch (test/fixtures/native-api-recordings). spoonjoy-v2 records them from its real route handlers, and
# V2APIRecordingContractTests decodes them with the app's models, so a stale copy would hide an API change.
#
#   ruby scripts/check-v2-api-recordings.rb            # fail if the copy differs from v2 main
#   ruby scripts/check-v2-api-recordings.rb --update   # replace the copy with v2 main's recordings
#   ruby scripts/check-v2-api-recordings.rb --source ~/Projects/spoonjoy-v2/test/fixtures/native-api-recordings
#
# --ref picks another v2 branch or tag. --source reads a local v2 checkout instead of GitHub.

require "fileutils"
require "json"
require "net/http"
require "optparse"
require "uri"

ROOT = File.expand_path("..", __dir__)
LOCAL_DIRECTORY = File.join(ROOT, "docs/source/spoonjoy-v2-api-recordings")
REMOTE_BASE = "https://raw.githubusercontent.com/spoonjoy/spoonjoy-v2/%<ref>s/test/fixtures/native-api-recordings/%<file>s"

options = { ref: "main", update: false, source: nil }
OptionParser.new do |parser|
  parser.on("--update", "Write v2's recordings into the local copy") { options[:update] = true }
  parser.on("--ref REF", "spoonjoy-v2 branch, tag or commit to compare against (default: main)") { |ref| options[:ref] = ref }
  parser.on("--source DIR", "Read recordings from a local spoonjoy-v2 directory instead of GitHub") { |dir| options[:source] = File.expand_path(dir) }
end.parse!

def fetch(url, attempts: 3)
  uri = URI(url)
  attempts.times do |attempt|
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
      http.get(uri.request_uri, "User-Agent" => "spoonjoy-apple-recording-check")
    end
    return response.body if response.is_a?(Net::HTTPSuccess)
    raise "#{url} answered #{response.code}" if response.is_a?(Net::HTTPNotFound) || attempt == attempts - 1
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, SocketError
    raise if attempt == attempts - 1
  end
end

def read_source(options, file)
  if options[:source]
    File.read(File.join(options[:source], file))
  else
    fetch(format(REMOTE_BASE, ref: options[:ref], file: file))
  end
end

index_text = read_source(options, "index.json")
names = JSON.parse(index_text).map { |entry| entry.fetch("name") }
remote = { "index.json" => index_text }
names.each { |name| remote["#{name}.json"] = read_source(options, "#{name}.json") }

local_files = Dir.glob(File.join(LOCAL_DIRECTORY, "*.json")).map { |path| File.basename(path) }
missing = remote.keys.reject { |file| local_files.include?(file) }
extra = local_files - remote.keys
changed = remote.keys.select do |file|
  local_files.include?(file) && File.read(File.join(LOCAL_DIRECTORY, file)) != remote[file]
end

if options[:update]
  FileUtils.mkdir_p(LOCAL_DIRECTORY)
  remote.each { |file, text| File.write(File.join(LOCAL_DIRECTORY, file), text) }
  extra.each { |file| File.delete(File.join(LOCAL_DIRECTORY, file)) }
  puts "Updated #{LOCAL_DIRECTORY}: #{changed.size} changed, #{missing.size} added, #{extra.size} removed."
  exit 0
end

source_label = options[:source] || "spoonjoy-v2 #{options[:ref]}"
if missing.empty? && extra.empty? && changed.empty?
  puts "The #{remote.size - 1} spoonjoy-v2 API recordings match #{source_label}."
  exit 0
end

warn "The spoonjoy-v2 API recordings in docs/source/spoonjoy-v2-api-recordings differ from #{source_label}:"
changed.sort.each { |file| warn "  changed: #{file}" }
missing.sort.each { |file| warn "  missing here: #{file}" }
extra.sort.each { |file| warn "  not in v2: #{file}" }
warn "Run `ruby scripts/check-v2-api-recordings.rb --update`, then fix any model the V2APIRecordingContractTests suite reports."
exit 1
