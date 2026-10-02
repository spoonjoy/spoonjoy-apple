#!/usr/bin/env ruby
# frozen_string_literal: true

# Revokes development certificates that Xcode automatic signing created through
# the App Store Connect API key. Ephemeral CI runners start with an empty
# keychain, so every `xcodebuild -allowProvisioningUpdates` run mints a new
# "Created via API" Apple Development certificate until the account hits its cap.
#
# Only development certificates whose name is exactly "Created via API" are
# revoked. Distribution certificates and certificates made by people or Macs are
# never touched.

require "base64"
require "json"
require "net/http"
require "openssl"
require "optparse"
require "time"
require "uri"

module CiSigningCertificates
  API_BASE = "https://api.appstoreconnect.apple.com"
  DEVELOPMENT_TYPES = %w[DEVELOPMENT IOS_DEVELOPMENT MAC_APP_DEVELOPMENT].freeze
  API_CREATED_NAME = "created via api"

  class Error < StandardError; end

  # Pure filter: returns the certificate resources that are safe to revoke.
  def self.revocable(certificates)
    certificates.select do |certificate|
      attributes = certificate["attributes"] || {}
      next false unless DEVELOPMENT_TYPES.include?(attributes["certificateType"])

      [attributes["name"], attributes["displayName"]].any? do |label|
        label.is_a?(String) && label.strip.downcase == API_CREATED_NAME
      end
    end
  end

  def self.describe(certificate)
    attributes = certificate["attributes"] || {}
    "id=#{certificate["id"]} type=#{attributes["certificateType"]} " \
      "name=#{attributes["name"].inspect} expires=#{attributes["expirationDate"]}"
  end

  class Client
    def initialize(key_id:, issuer_id:, private_key_path:)
      @key_id = key_id
      @issuer_id = issuer_id
      @key = OpenSSL::PKey.read(File.read(private_key_path))
    end

    def token
      b64 = ->(bytes) { Base64.urlsafe_encode64(bytes, padding: false) }
      header = { alg: "ES256", kid: @key_id, typ: "JWT" }
      payload = { iss: @issuer_id, exp: Time.now.to_i + 600, aud: "appstoreconnect-v1" }
      signing_input = "#{b64.call(JSON.generate(header))}.#{b64.call(JSON.generate(payload))}"
      der = @key.sign(OpenSSL::Digest.new("SHA256"), signing_input)
      sequence = OpenSSL::ASN1.decode(der)
      raw = sequence.value.map { |integer| integer.value.to_s(2).rjust(32, "\0") }.join
      "#{signing_input}.#{b64.call(raw)}"
    end

    def list_certificates
      certificates = []
      url = "#{API_BASE}/v1/certificates?limit=200"
      while url
        body = JSON.parse(request(Net::HTTP::Get, url).body)
        certificates.concat(body.fetch("data"))
        url = body.dig("links", "next")
      end
      certificates
    end

    def revoke(id)
      request(Net::HTTP::Delete, "#{API_BASE}/v1/certificates/#{URI.encode_www_form_component(id)}")
    end

    private

    def request(klass, url)
      uri = URI(url)
      request = klass.new(uri)
      request["Authorization"] = "Bearer #{token}"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 60) do |http|
        http.request(request)
      end
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "App Store Connect #{klass::METHOD} #{uri.path} returned HTTP #{response.code}"
      end

      response
    end
  end

  def self.run(options, client:)
    certificates = options[:fixture] ? JSON.parse(File.read(options[:fixture])).fetch("data") : client.list_certificates
    targets = revocable(certificates)
    puts "Found #{certificates.length} certificate(s); #{targets.length} created via API and eligible for revocation."
    (certificates - targets).each { |certificate| puts "keep: #{describe(certificate)}" }
    revoked = 0
    targets.each do |certificate|
      if options[:dry_run]
        puts "would revoke: #{describe(certificate)}"
      else
        client.revoke(certificate.fetch("id"))
        revoked += 1
        puts "revoked: #{describe(certificate)}"
      end
    end
    puts "Revoked #{revoked} certificate(s)#{options[:dry_run] ? " (dry run)" : ""}."
  end
end

if $PROGRAM_NAME == __FILE__
  options = { dry_run: false, best_effort: false }
  begin
    OptionParser.new do |parser|
      parser.banner = "Usage: revoke-ci-signing-certificates.rb [--dry-run] [--best-effort] [--config PATH]"
      parser.on("--dry-run") { options[:dry_run] = true }
      parser.on("--best-effort", "Log failures and exit 0 (post-publish cleanup)") { options[:best_effort] = true }
      parser.on("--config PATH") { |value| options[:config] = value }
      parser.on("--fixture PATH", "Offline JSON of GET /v1/certificates (testing)") { |value| options[:fixture] = value }
    end.parse!

    client = nil
    unless options[:fixture]
      config_path = options[:config] || ENV["APPLE_DISTRIBUTION_KIT_CONFIG"]
      raise CiSigningCertificates::Error, "missing --config or APPLE_DISTRIBUTION_KIT_CONFIG" if config_path.to_s.empty?

      config = JSON.parse(File.read(config_path))
      client = CiSigningCertificates::Client.new(
        key_id: config.fetch("keyId"),
        issuer_id: config.fetch("issuerId"),
        private_key_path: config.fetch("privateKeyPath")
      )
    end
    CiSigningCertificates.run(options, client: client)
  rescue StandardError => error
    warn "revoke-ci-signing-certificates #{options[:best_effort] ? "warning" : "failed"}: #{error.class}: #{error.message}"
    exit(options[:best_effort] ? 0 : 1)
  end
end
