# frozen_string_literal: true

# Run: ruby scripts/test/app_shortcuts_test.rb
require "minitest/autorun"
require "json"
require "open3"
require "tmpdir"
require_relative "../lib/app_shortcuts"

class AppShortcutsTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def action(*parameters)
    { "parameters" => parameters }
  end

  def entity(name)
    { "name" => name, "valueType" => { "entity" => { "wrapper" => { "typeName" => "SpoonjoyRecipeEntity" } } } }
  end

  def string(name)
    { "name" => name, "valueType" => { "primitive" => { "wrapper" => { "typeIdentifier" => 0 } } } }
  end

  def metadata(shortcuts, actions = { "StartCookModeIntent" => action(entity("recipe")), "AddShoppingListItemIntent" => action(string("name")) })
    {
      "actions" => actions,
      "autoShortcuts" => shortcuts.map do |intent, phrases|
        { "actionIdentifier" => intent, "phraseTemplates" => phrases.map { |key| { "key" => key, "alternatives" => [] } } }
      end
    }
  end

  def expected(shortcuts)
    { "shortcuts" => shortcuts.map { |intent, phrases| { "intent" => intent, "phrases" => phrases } } }
  end

  GOOD = {
    "StartCookModeIntent" => ["Start cooking in ${applicationName}", "Cook ${recipe} with ${applicationName}"],
    "AddShoppingListItemIntent" => ["Add to my ${applicationName} shopping list"]
  }.freeze

  def test_matching_shortcuts_pass
    assert_empty AppShortcuts.check(metadata(GOOD), expected(GOOD))
  end

  def test_a_phrase_without_the_app_name_fails
    shortcuts = GOOD.merge("AddShoppingListItemIntent" => ["Add to my shopping list"])
    problems = AppShortcuts.check(metadata(shortcuts), expected(shortcuts))
    assert_includes problems, "AddShoppingListItemIntent: \"Add to my shopping list\" does not name the app"
  end

  def test_free_text_in_a_phrase_fails
    shortcuts = GOOD.merge("AddShoppingListItemIntent" => ["Add ${name} to ${applicationName}"])
    problems = AppShortcuts.check(metadata(shortcuts), expected(shortcuts))
    assert_includes problems, "AddShoppingListItemIntent: \"Add ${name} to ${applicationName}\" puts ${name} in a phrase, but only an entity can ride in one"
  end

  def test_a_placeholder_that_is_not_a_parameter_fails
    shortcuts = GOOD.merge("StartCookModeIntent" => ["Cook ${dish} with ${applicationName}"])
    problems = AppShortcuts.check(metadata(shortcuts), expected(shortcuts))
    assert_includes problems, "StartCookModeIntent: \"Cook ${dish} with ${applicationName}\" names ${dish}, which is not one of its parameters"
  end

  def test_a_shortcut_for_an_undeclared_intent_fails
    shortcuts = GOOD.merge("GhostIntent" => ["Haunt ${applicationName}"])
    problems = AppShortcuts.check(metadata(shortcuts), expected(shortcuts))
    assert_includes problems, "GhostIntent has App Shortcut phrases but the app declares no such intent"
  end

  def test_one_phrase_under_two_shortcuts_fails
    shortcuts = GOOD.merge("AddShoppingListItemIntent" => ["Start cooking in ${applicationName}"])
    problems = AppShortcuts.check(metadata(shortcuts), expected(shortcuts))
    assert_includes problems, "\"Start cooking in ${applicationName}\" is offered by AddShoppingListItemIntent and StartCookModeIntent, so Siri cannot tell which to run"
  end

  def test_more_than_ten_shortcuts_fails
    actions = (1..11).to_h { |n| ["Intent#{n}", action] }
    shortcuts = (1..11).to_h { |n| ["Intent#{n}", ["Do #{n} in ${applicationName}"]] }
    problems = AppShortcuts.check(metadata(shortcuts, actions), expected(shortcuts))
    assert_includes problems, "the app declares 11 App Shortcuts; Apple allows at most 10"
  end

  def test_drift_from_the_config_fails_both_ways
    built = GOOD.merge("AddShoppingListItemIntent" => ["Add to my ${applicationName} list"])
    problems = AppShortcuts.check(metadata(built), expected(GOOD))
    assert_includes problems, "AddShoppingListItemIntent: config lists \"Add to my ${applicationName} shopping list\", which the app does not offer"
    assert_includes problems, "AddShoppingListItemIntent: the app offers \"Add to my ${applicationName} list\", which config/app-shortcuts.json does not list"
  end

  def test_a_missing_or_extra_shortcut_fails
    problems = AppShortcuts.check(metadata(GOOD.slice("StartCookModeIntent")), expected(GOOD))
    assert_includes problems, "config lists AddShoppingListItemIntent, but the app has no App Shortcut for it"
    problems = AppShortcuts.check(metadata(GOOD), expected(GOOD.slice("StartCookModeIntent")))
    assert_includes problems, "the app has an App Shortcut for AddShoppingListItemIntent that config/app-shortcuts.json does not list"
  end

  def test_the_command_reads_the_built_metadata_and_the_config
    Dir.mktmpdir do |dir|
      data = File.join(dir, "extract.actionsdata")
      config = File.join(dir, "app-shortcuts.json")
      File.write(data, JSON.generate(metadata(GOOD)))
      File.write(config, JSON.generate(expected(GOOD)))
      out, status = Open3.capture2e("ruby", File.join(ROOT, "scripts/check-app-shortcuts.rb"), data, config)
      assert status.success?, out
      assert_includes out, "3 phrases across 2 App Shortcuts"
      File.write(config, JSON.generate(expected(GOOD.slice("StartCookModeIntent"))))
      out, status = Open3.capture2e("ruby", File.join(ROOT, "scripts/check-app-shortcuts.rb"), data, config)
      refute status.success?
      assert_includes out, "FAIL"
    end
  end

  def test_the_checked_in_config_is_well_formed
    config = JSON.parse(File.read(File.join(ROOT, "config/app-shortcuts.json")))
    assert_operator config.fetch("shortcuts").length, :<=, AppShortcuts::LIMIT
    config.fetch("shortcuts").each do |entry|
      refute_empty entry.fetch("phrases"), "#{entry['intent']} lists no phrases"
      entry.fetch("phrases").each { |phrase| assert_includes phrase, AppShortcuts::APP_NAME, "#{entry['intent']}: #{phrase}" }
    end
  end
end
