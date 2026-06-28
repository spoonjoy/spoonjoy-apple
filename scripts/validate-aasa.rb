#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "optparse"
require "pathname"
require "set"
require "time"
require "uri"

ROOT = Pathname.new(__dir__).join("..").expand_path
DEFAULT_ARTIFACT_ROOT = ROOT.join("tasks/2026-06-15-2314-doing-native-app-skeleton")
AASA_URL = URI("https://spoonjoy.app/.well-known/apple-app-site-association")
REQUIRED_APP_IDS = [
  "TEAMID.app.spoonjoy.Spoonjoy",
  "TEAMID.app.spoonjoy.Spoonjoy.mac"
].freeze

options = { artifact_root: DEFAULT_ARTIFACT_ROOT }
OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/validate-aasa.rb [--artifact-root PATH]"
  parser.on("--artifact-root PATH", "Directory for aasa-validation.json or aasa-production-blocker.json") do |path|
    options[:artifact_root] = Pathname.new(path).expand_path
  end
end.parse!

def manifest_routes
  source = ROOT.join("Sources/SpoonjoyCore/Native/DeepLinkManifest.swift").read
  source.scan(/"(https:\/\/spoonjoy\.app[^"]+)"/).flatten.uniq
end

def expected_components(routes)
  routes.map do |route|
    has_path_template = route.split("?", 2).first.include?("{")
    normalized_route = route.gsub(/\{[^}]+\}/, "placeholder")
    path = URI(normalized_route).path
    if has_path_template
      { "/" => path.sub(%r{/placeholder.*\z}, "/*") }
    elsif route.include?("?")
      { "/" => path, "?" => { "*" => "*" } }
    else
      { "/" => path }
    end
  end.uniq
end

def canonical(value)
  case value
  when Hash
    value.keys.sort.to_h { |key| [key, canonical(value[key])] }
  when Array
    value.map { |entry| canonical(entry) }
  else
    value
  end
end

def canonical_key(value)
  JSON.generate(canonical(value))
end

def discovered_components(json)
  json.dig("applinks", "details").to_a.flat_map do |entry|
    Array(entry["components"]) + Array(entry["paths"]).map { |path| { "/" => path } }
  end
end

def fetch_aasa
  if ENV["SPOONJOY_AASA_FIXTURE_PATH"]
    fixture = Pathname.new(ENV.fetch("SPOONJOY_AASA_FIXTURE_PATH"))
    body = fixture.read
    return {
      "status" => ENV.fetch("SPOONJOY_AASA_FIXTURE_STATUS", "200").to_i,
      "contentType" => ENV.fetch("SPOONJOY_AASA_FIXTURE_CONTENT_TYPE", "application/json"),
      "location" => ENV["SPOONJOY_AASA_FIXTURE_LOCATION"],
      "bodySHA256" => Digest::SHA256.hexdigest(body),
      "bodyBytes" => body.bytesize,
      "json" => (JSON.parse(body) rescue nil)
    }
  end

  response = Net::HTTP.start(AASA_URL.host, AASA_URL.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
    request = Net::HTTP::Get.new(AASA_URL)
    request["Accept"] = "application/json, application/pkcs7-mime, */*"
    http.request(request)
  end
  {
    "status" => response.code.to_i,
    "contentType" => response["content-type"],
    "location" => response["location"],
    "bodySHA256" => Digest::SHA256.hexdigest(response.body.to_s),
    "bodyBytes" => response.body.to_s.bytesize,
    "json" => (JSON.parse(response.body) rescue nil)
  }
rescue StandardError => error
  {
    "error" => "#{error.class}: #{error.message}"
  }
end

artifact_root = options.fetch(:artifact_root)
artifact_root.mkpath
routes = manifest_routes
components = expected_components(routes)
fetched = fetch_aasa
redirected = fetched.fetch("status", 0).between?(300, 399)
valid_json = fetched["json"].is_a?(Hash)
app_ids = fetched.dig("json", "applinks", "details").to_a.flat_map do |entry|
  Array(entry["appIDs"]) + Array(entry["appID"])
end.compact
route_components = valid_json ? discovered_components(fetched.fetch("json")) : []
route_component_keys = route_components.map { |component| canonical_key(component) }.to_set
missing_components = components.reject { |component| route_component_keys.include?(canonical_key(component)) }
missing_app_ids = REQUIRED_APP_IDS - app_ids

base = {
  "generatedAt" => Time.now.iso8601,
  "url" => AASA_URL.to_s,
  "httpsNoRedirectExpected" => true,
  "redirected" => redirected,
  "requiredAppIDs" => REQUIRED_APP_IDS,
  "expectedRoutes" => routes,
  "expectedComponents" => components,
  "discoveredComponents" => route_components,
  "missingComponents" => missing_components,
  "fetched" => fetched.reject { |key, _| key == "json" },
  "validJSON" => valid_json,
  "discoveredAppIDs" => app_ids
}

if valid_json && !redirected && missing_app_ids.empty? && missing_components.empty?
  output = artifact_root.join("aasa-validation.json")
  output.write(JSON.pretty_generate(base.merge("ok" => true)) + "\n")
  artifact_root.join("aasa-production-blocker.json").delete if artifact_root.join("aasa-production-blocker.json").file?
  puts "aasa validation ok: #{output.relative_path_from(ROOT)}"
else
  reason = "Production universal-link validation is blocked until Apple Developer Team ID and AASA publication are available for Spoonjoy."
  reason = "AASA endpoint redirected; Apple requires HTTPS without redirects." if redirected
  reason = "AASA endpoint is missing required app IDs: #{missing_app_ids.join(", ")}." if valid_json && !missing_app_ids.empty?
  reason = "AASA endpoint is missing required route components." if valid_json && missing_app_ids.empty? && !missing_components.empty?
  reason = "AASA endpoint did not return valid JSON." unless valid_json || fetched["error"]
  reason = "AASA fetch failed: #{fetched["error"]}" if fetched["error"]

  output = artifact_root.join("aasa-production-blocker.json")
  output.write(JSON.pretty_generate(base.merge(
    "ok" => false,
    "blocked" => true,
    "capability" => "AASAProductionValidation",
    "reason" => reason,
    "blockerReason" => reason
  )) + "\n")
  artifact_root.join("aasa-validation.json").delete if artifact_root.join("aasa-validation.json").file?
  puts "aasa production blocked: #{output.relative_path_from(ROOT)}"
end
