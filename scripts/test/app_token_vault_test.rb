# frozen_string_literal: true

# Run: ruby scripts/test/app_token_vault_test.rb
# App Intents and entity queries run in the app's process and must read the session the app signed in with. Each one
# built a KeychainTokenVault of its own, but a debug build signs in to a file vault, so in every debug build Siri found
# no session and its recipe query answered with nothing (Journeys run 43113155646: sync stored the recipe, the query
# returned 0). SpoonjoyAppTokenVault is the one place the app and its intents get their vault.
require "minitest/autorun"

class AppTokenVaultTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  FACTORY = "Apps/Spoonjoy/Shared/Native/SpoonjoyAppTokenVault.swift"

  def test_a_release_build_keeps_the_session_in_the_keychain
    source = File.read(File.join(ROOT, FACTORY))
    release = source[/^#else\n(.*?)^#endif/m, 1]
    refute_nil release, "#{FACTORY} has no Release branch"
    assert_equal "KeychainTokenVault()", release.strip
  end

  def test_the_app_signs_in_with_the_shared_vault
    root = File.read(File.join(ROOT, "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift"))
    assert_includes root, "let vault: any TokenVault = SpoonjoyAppTokenVault.current(environment: environment)"
    refute_includes root, "KeychainTokenVault()"
  end

  def test_no_intent_or_entity_query_builds_a_vault_of_its_own
    # Journeys and UI tests run in the test runner, not the app, so they are outside this rule.
    offenders = Dir.glob(File.join(ROOT, "Apps/**/*.swift")).filter_map do |path|
      relative = path.delete_prefix("#{ROOT}/")
      next if relative == FACTORY || relative.start_with?("Apps/Spoonjoy/Journeys/", "Apps/Spoonjoy/UITests/")
      lines = File.readlines(path).each_with_index.select { |line, _| line.match?(/\b(KeychainTokenVault|FileBackedTokenVault)\(/) }
      lines.map { |_, index| "#{relative}:#{index + 1}" } unless lines.empty?
    end.flatten
    assert_empty offenders, "use SpoonjoyAppTokenVault.current(), so Siri reads the session the app signed in with"
  end
end
