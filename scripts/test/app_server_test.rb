# frozen_string_literal: true

# Run: ruby scripts/test/app_server_test.rb
# App Intents run in the app's process and must talk to the server the app signed in to. They always used
# spoonjoy.app, so a debug build pointed at QA sent QA's session to production: Siri's shopping item never reached QA's
# list (Journeys run 43201022926). SpoonjoyAppServer is the one place the app and its intents get their server.
require "minitest/autorun"

class AppServerTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  FACTORY = "Apps/Spoonjoy/Shared/Native/SpoonjoyAppTokenVault.swift"

  def server_source
    File.read(File.join(ROOT, FACTORY))[/^enum SpoonjoyAppServer \{.*?^\}/m]
  end

  def test_a_release_build_always_talks_to_spoonjoy_app
    refute_nil server_source, "#{FACTORY} has no SpoonjoyAppServer"
    release = server_source[/^#endif\n(.*?)^    \}/m, 1]
    refute_nil release, "SpoonjoyAppServer.configuration has no code after its DEBUG override"
    assert_equal "return .spoonjoyProduction", release.strip
    debug = server_source[/^#if DEBUG\n(.*?)^#endif/m, 1]
    assert_includes debug, %(environment["SPOONJOY_API_BASE_URL"])
  end

  def test_the_app_signs_in_to_the_shared_server
    root = File.read(File.join(ROOT, "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift"))
    assert root.include?("SpoonjoyAppServer.configuration(environment: environment)"), "the root view does not use SpoonjoyAppServer"
    refute root.include?(%(environment["SPOONJOY_API_BASE_URL"])), "the root view still reads SPOONJOY_API_BASE_URL itself"
  end

  def test_no_intent_names_a_server_of_its_own
    offenders = Dir.glob(File.join(ROOT, "Apps/Spoonjoy/Shared/Native/*.swift")).filter_map do |path|
      relative = path.delete_prefix("#{ROOT}/")
      next if relative == FACTORY
      lines = File.readlines(path).each_with_index.select { |line, _| line.include?("spoonjoyProduction") }
      lines.map { |_, index| "#{relative}:#{index + 1}" } unless lines.empty?
    end.flatten
    assert_empty offenders, "use SpoonjoyAppServer.configuration(), so Siri talks to the server the app signed in to"
  end
end
