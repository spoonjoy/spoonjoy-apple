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
DEFAULT_ARTIFACT_ROOT = ROOT.join("tasks/2026-06-16-1754-doing-siri-full-access-parity")
AASA_URL = URI("https://spoonjoy.app/.well-known/apple-app-site-association")
APPLE_TEAM_ID_PATTERN = /\A[A-Z0-9]{10}\z/
APP_BUNDLE_IDS = [
  "app.spoonjoy.Spoonjoy",
  "app.spoonjoy.Spoonjoy.mac"
].freeze

options = {
  artifact_root: DEFAULT_ARTIFACT_ROOT,
  team_id: ENV["SPOONJOY_AASA_TEAM_ID"]
}
original_argv = ARGV.dup
OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/validate-aasa.rb [--artifact-root PATH] [--team-id TEAM_ID]"
  parser.on("--artifact-root PATH", "Directory for aasa-validation.json or aasa-production-blocker.json") do |path|
    options[:artifact_root] = Pathname.new(path).expand_path
  end
  parser.on("--team-id TEAM_ID", "Apple Developer Team ID expected in AASA app IDs") do |team_id|
    options[:team_id] = team_id
  end
end.parse!

def normalized_team_id(raw_team_id)
  return nil if raw_team_id.nil?

  team_id = raw_team_id.to_s.strip.upcase
  return nil if team_id.empty?
  return team_id if team_id.match?(APPLE_TEAM_ID_PATTERN)

  nil
end

def required_app_ids(team_id)
  APP_BUNDLE_IDS.map { |bundle_id| "#{team_id}.#{bundle_id}" }
end

def team_id_validation_error(raw_team_id)
  return nil if raw_team_id.nil? || raw_team_id.to_s.strip.empty?
  return nil if normalized_team_id(raw_team_id)

  "Apple Developer Team ID must be 10 alphanumeric characters."
end

def parsed_app_id(app_id)
  match = app_id.to_s.match(/\A(?<team_id>[A-Z0-9]{10})\.(?<bundle_id>.+)\z/)
  return nil unless match

  [match[:team_id], match[:bundle_id]]
end

def valid_team_ids_by_bundle(app_ids)
  APP_BUNDLE_IDS.to_h do |bundle_id|
    team_ids = app_ids.each_with_object([]) do |app_id, ids|
      parsed = parsed_app_id(app_id)
      ids << parsed[0] if parsed && parsed[1] == bundle_id
    end.uniq.sort
    [bundle_id, team_ids]
  end
end

def common_team_ids(team_ids_by_bundle)
  APP_BUNDLE_IDS.map { |bundle_id| team_ids_by_bundle.fetch(bundle_id) }.reduce(:&) || []
end

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
expected_apple_team_id = normalized_team_id(options[:team_id])
team_id_error = team_id_validation_error(options[:team_id])
routes = manifest_routes
components = expected_components(routes)
fetched = fetch_aasa
redirected = fetched.fetch("status", 0).between?(300, 399)
successful_status = fetched.fetch("status", 0).between?(200, 299)
content_type = fetched["contentType"].to_s.split(";", 2).first.to_s.strip.downcase
valid_content_type = ["application/json", "application/pkcs7-mime"].include?(content_type)
valid_json = fetched["json"].is_a?(Hash)
app_ids = fetched.dig("json", "applinks", "details").to_a.flat_map do |entry|
  Array(entry["appIDs"]) + Array(entry["appID"])
end.compact
team_ids_by_bundle = valid_team_ids_by_bundle(app_ids)
discovered_common_team_ids = common_team_ids(team_ids_by_bundle)
ambiguous_team_ids = discovered_common_team_ids.length > 1 ? discovered_common_team_ids : []
validated_apple_team_id =
  if expected_apple_team_id
    expected_apple_team_id
  elsif discovered_common_team_ids.length == 1
    discovered_common_team_ids.first
  end
required_app_ids = validated_apple_team_id ? required_app_ids(validated_apple_team_id) : []
route_components = valid_json ? discovered_components(fetched.fetch("json")) : []
route_component_keys = route_components.map { |component| canonical_key(component) }.to_set
missing_components = components.reject { |component| route_component_keys.include?(canonical_key(component)) }
missing_app_ids = expected_apple_team_id ? required_app_ids - app_ids : []
missing_app_id_bundles = expected_apple_team_id ? [] : APP_BUNDLE_IDS.select { |bundle_id| team_ids_by_bundle.fetch(bundle_id).empty? }

base = {
  "generatedAt" => Time.now.iso8601,
  "url" => AASA_URL.to_s,
  "httpsNoRedirectExpected" => true,
  "redirected" => redirected,
  "expectedAppleTeamID" => expected_apple_team_id,
  "validatedAppleTeamID" => validated_apple_team_id,
  "appleTeamIDValidationError" => team_id_error,
  "requiredBundleIDs" => APP_BUNDLE_IDS,
  "requiredAppIDs" => required_app_ids,
  "expectedRoutes" => routes,
  "expectedComponents" => components,
  "discoveredComponents" => route_components,
  "missingComponents" => missing_components,
  "fetched" => fetched.reject { |key, _| key == "json" },
  "successfulStatus" => successful_status,
  "validContentType" => valid_content_type,
  "validJSON" => valid_json,
  "discoveredAppIDs" => app_ids,
  "discoveredAppleTeamIDsByBundle" => team_ids_by_bundle,
  "discoveredCommonAppleTeamIDs" => discovered_common_team_ids,
  "ambiguousAppleTeamIDs" => ambiguous_team_ids,
  "missingAppIDBundles" => missing_app_id_bundles
}

if team_id_error.nil? && successful_status && valid_content_type && valid_json && !redirected && missing_app_ids.empty? && missing_app_id_bundles.empty? && ambiguous_team_ids.empty? && !validated_apple_team_id.nil? && missing_components.empty?
  output = artifact_root.join("aasa-validation.json")
  output.write(JSON.pretty_generate(base.merge("ok" => true)) + "\n")
  artifact_root.join("aasa-production-blocker.json").delete if artifact_root.join("aasa-production-blocker.json").file?
  puts "aasa validation ok: #{output.relative_path_from(ROOT)}"
else
  reason =
    if team_id_error
      team_id_error
    elsif fetched["error"]
      "AASA fetch failed: #{fetched["error"]}"
    elsif redirected
      "AASA endpoint redirected; Apple requires HTTPS without redirects."
    elsif !successful_status && fetched["status"]
      "AASA endpoint returned HTTP #{fetched["status"]}; Apple requires a successful 2xx response."
    elsif successful_status && !valid_content_type
      "AASA endpoint returned #{fetched["contentType"] || "no content type"}; Apple requires application/json or application/pkcs7-mime."
    elsif !valid_json
      "AASA endpoint did not return valid JSON."
    elsif !missing_app_ids.empty?
      "AASA endpoint is missing required app IDs: #{missing_app_ids.join(", ")}."
    elsif !missing_app_id_bundles.empty?
      "AASA endpoint is missing valid app IDs for bundle identifiers: #{missing_app_id_bundles.join(", ")}."
    elsif !ambiguous_team_ids.empty?
      "AASA endpoint publishes multiple common valid Apple Team IDs for required bundle identifiers: #{ambiguous_team_ids.join(", ")}."
    elsif validated_apple_team_id.nil?
      "AASA endpoint does not publish one common valid Apple Team ID for every required bundle identifier."
    elsif !missing_components.empty?
      "AASA endpoint is missing required route components."
    else
      "Production AASA validation is blocked by an unknown validation failure."
    end

  output = artifact_root.join("aasa-production-blocker.json")
  relative_output = output.relative_path_from(ROOT).to_s
  output.write(JSON.pretty_generate(base.merge(
    "ok" => false,
    "blocked" => true,
    "capability" => "AASAProductionValidation",
    "reason" => reason,
    "blockerReason" => reason,
    "command" => (["ruby", "scripts/validate-aasa.rb"] + original_argv).join(" "),
    "outputPath" => relative_output,
    "ownerAction" => "Publish a valid AASA file on spoonjoy.app with one common 10-character Apple Team ID for app.spoonjoy.Spoonjoy and app.spoonjoy.Spoonjoy.mac, or rerun with a valid --team-id when the production Apple Team ID changes."
  )) + "\n")
  artifact_root.join("aasa-validation.json").delete if artifact_root.join("aasa-validation.json").file?
  puts "aasa production blocked: #{relative_output}"
end
