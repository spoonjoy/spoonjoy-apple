# frozen_string_literal: true

# Holds the built app's App Shortcuts (Metadata.appintents/extract.actionsdata) to config/app-shortcuts.json, the
# list of phrases a cook can say to Siri. What it checks is what Siri needs to reach a phrase:
# - at most 10 App Shortcuts, Apple's limit;
# - every phrase names the app (${applicationName}), or Siri never offers it;
# - every shortcut runs an intent the app declares;
# - a phrase's only other placeholder is a parameter of that intent whose value is an entity, since Siri can list
#   entities ahead of time but never free text;
# - the phrases are exactly the ones the config lists, so the device checklist and the app never drift apart.
module AppShortcuts
  LIMIT = 10
  APP_NAME = "${applicationName}"
  PLACEHOLDER = /\$\{([A-Za-z0-9_]+)\}/

  module_function

  # The built shortcuts as { intent => [phrase, ...] }, in the order the provider declares them.
  def built(metadata)
    Array(metadata["autoShortcuts"]).to_h do |shortcut|
      [shortcut.fetch("actionIdentifier"), Array(shortcut["phraseTemplates"]).map { |phrase| phrase.fetch("key") }]
    end
  end

  def check(metadata, expected)
    problems = []
    shortcuts = Array(metadata["autoShortcuts"])
    actions = metadata["actions"] || {}
    problems << "the app declares #{shortcuts.length} App Shortcuts; Apple allows at most #{LIMIT}" if shortcuts.length > LIMIT

    built(metadata).each do |intent, phrases|
      action = actions[intent]
      if action.nil?
        problems << "#{intent} has App Shortcut phrases but the app declares no such intent"
        next
      end
      problems << "#{intent} has an App Shortcut with no phrases" if phrases.empty?
      phrases.each do |phrase|
        problems << "#{intent}: \"#{phrase}\" does not name the app" unless phrase.include?(APP_NAME)
        phrase.scan(PLACEHOLDER).flatten.reject { |name| name == "applicationName" }.each do |name|
          parameter = Array(action["parameters"]).find { |candidate| candidate["name"] == name }
          if parameter.nil?
            problems << "#{intent}: \"#{phrase}\" names ${#{name}}, which is not one of its parameters"
          elsif parameter.dig("valueType", "entity").nil?
            problems << "#{intent}: \"#{phrase}\" puts ${#{name}} in a phrase, but only an entity can ride in one"
          end
        end
      end
    end

    want = expected.fetch("shortcuts").to_h { |entry| [entry.fetch("intent"), entry.fetch("phrases")] }
    have = built(metadata)
    (want.keys - have.keys).each { |intent| problems << "config lists #{intent}, but the app has no App Shortcut for it" }
    (have.keys - want.keys).each { |intent| problems << "the app has an App Shortcut for #{intent} that config/app-shortcuts.json does not list" }
    (want.keys & have.keys).each do |intent|
      (want[intent] - have[intent]).each { |phrase| problems << "#{intent}: config lists \"#{phrase}\", which the app does not offer" }
      (have[intent] - want[intent]).each { |phrase| problems << "#{intent}: the app offers \"#{phrase}\", which config/app-shortcuts.json does not list" }
    end
    problems
  end
end
