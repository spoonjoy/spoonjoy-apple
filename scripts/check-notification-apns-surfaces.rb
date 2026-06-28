#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_CONTRACT = ROOT.join("scripts/check-xcode-project-contract.rb")

REQUIRED_FILES = [
  "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceRepository.swift",
  "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift",
  "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift",
  "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
  "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
  "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
].freeze

REQUIRED_TOKENS = {
  "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceRepository.swift" => [
    "NotificationAPNsSurfaceRepository",
    "LiveNotificationAPNsSurfaceRepository",
    "SnapshotNotificationAPNsSurfaceRepository",
    "FallbackNotificationAPNsSurfaceRepository",
    "NotificationAPNsSurfaceData",
    "APNsRegistrationSummary",
    "APNsPermissionState",
    "APNsDeliveryCapability",
    "AppleDeveloperProgramBlocker",
    "SettingsNotificationPreferences",
    "PrivateAccountRequests.notificationPreferences",
    "PrivateAccountRequests.registerAPNSDevice",
    "PrivateAccountRequests.revokeAPNSDevice",
    "NativeCacheDomain.notificationPreferences",
    "NativeCacheDomain.apnsStatus",
    "NativeCachePayload.notificationPreferenceState",
    "NativeCachePayload.apnsStatus"
  ],
  "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift" => [
    "NotificationAPNsSurfaceViewModel",
    "NotificationAPNsActionPlanner",
    "NotificationAPNsActionPlan",
    "case updatePreferences",
    "case requestPermission",
    "case registerDevice",
    "case revokeDevice",
    "case denied",
    "NativeQueuedMutation.notificationPreferenceUpdate",
    "NativeQueuedMutation.apnsDeviceRegister",
    "NativeQueuedMutation.apnsDeviceRevoke",
    "NativeOfflineMutationPolicy.decision",
    "NativeOfflineAction.apnsPermissionPrompt",
    "NativeOfflineAction.apnsDeviceTokenAcquisition",
    "OfflineIndicatorState",
    "OfflineIndicatorDisplay.blocker",
    "APNsDeliveryBlockerState"
  ],
  "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift" => [
    "NotificationAPNsSettingsView",
    "NotificationAPNsSurfaceViewModel",
    "SettingsNotificationPreferences",
    "Toggle",
    "Button",
    "APNsRegistrationSummary",
    "AppleDeveloperProgram",
    "OfflineStatusView",
    "confirmationDialog(",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift" => [
    "NotificationAPNsSettingsView(",
    "notificationAPNsSurfaceViewModel",
    "performNotificationAPNsAction",
    "queueNotificationAPNsMutationIfNeeded",
    "recordNotificationAPNsBlocker"
  ],
  "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift" => [
    "notificationAPNsSurfaceViewModel",
    "NotificationAPNsSurfaceViewModel",
    "LiveNotificationAPNsSurfaceRepository",
    "FallbackNotificationAPNsSurfaceRepository",
    "restoreNotificationAPNsSnapshot"
  ],
  "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift" => [
    "notification APNs surface",
    "notification preferences",
    "APNs registration",
    "permission denied",
    "AppleDeveloperProgram",
    "NotificationAPNsSettingsView.swift"
  ]
}.freeze

STRING_ALLOWED_TOKENS = {
  "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift" => [
    "apple-developer-program-blocker-apns.json"
  ],
  "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift" => [
    "permissionDenied",
    "Notifications are off in System Settings",
    "Open System Settings"
  ]
}.freeze

OFFLINE_CACHE_TOKENS = {
  "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceRepository.swift" => [
    "SnapshotNotificationAPNsSurfaceRepository",
    "NotificationAPNsSurfaceData",
    "NativeDurableCache",
    "record(for: .notificationPreferences)",
    "record(for: .apnsStatus)",
    "case .notificationPreferenceState",
    "case .apnsStatus",
    "registrationState",
    "lastValidatedAt"
  ],
  "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift" => [
    "notificationDraft",
    "apnsRegistration",
    "offlineIndicator",
    "stale(domain: .notificationPreferences)",
    "permissionDenied",
    "registered"
  ]
}.freeze

BLOCKER_CONSUMER_TOKENS = {
  "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceRepository.swift" => [
    "AppleDeveloperProgramBlocker",
    "APNsDeliveryBlockerState",
    "ownerAction",
    "blocked",
    "capability"
  ],
  "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift" => [
    "AppleDeveloperProgramBlocker",
    "APNsDeliveryBlockerState",
    "ownerAction",
    "blocked",
    "capability"
  ],
  "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift" => [
    "AppleDeveloperProgramBlocker",
    "APNsDeliveryBlockerState",
    "ownerAction",
    "blocked",
    "capability"
  ]
}.freeze

BLOCKER_CONSUMER_STRING_TOKENS = {
  "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceRepository.swift" => [
    "apple-developer-program-blocker-apns.json"
  ],
  "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift" => [
    "apple-developer-program-blocker-apns.json"
  ],
  "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift" => [
    "apple-developer-program-blocker-apns.json"
  ]
}.freeze

FORBIDDEN_TOKENS = [
  "RecipeComments",
  "SocialFeed",
  "MessageComposer",
  "MailCompose",
  "productionAPNsAvailable = true",
  "fakeAPNsDelivery",
  "sendTestPushNotification",
  "TestFlightAvailable",
  "APNsProductionDeliveryAvailable",
  "productionDeliveryReady",
  "deliverPushNotification",
  "sendPushNotification",
  "TestFlight upload available"
].freeze

def uncommented_swift(content)
  scan_swift_source(content, strip_strings: false)
end

def swift_contract_source(content)
  scan_swift_source(content, strip_strings: true)
end

def scan_swift_source(content, strip_strings:)
  output = +""
  index = 0

  while index < content.bytesize
    if content.byteslice(index, 2) == "//"
      index = copy_newlines_while_skipping_line_comment(content, index, output)
      next
    end

    if content.byteslice(index, 2) == "/*"
      index = copy_newlines_while_skipping_block_comment(content, index, output)
      next
    end

    if (literal_end = swift_string_literal_end(content, index))
      segment = content.byteslice(index, literal_end - index)
      if strip_strings
        output << "\"\""
        segment.each_byte { |byte| output << byte.chr if byte == 10 || byte == 13 }
      else
        output << segment
      end
      index = literal_end
      next
    end

    output << content.byteslice(index, 1)
    index += 1
  end

  output
end

def copy_newlines_while_skipping_line_comment(content, index, output)
  while index < content.bytesize
    byte = content.getbyte(index)
    if byte == 10 || byte == 13
      output << byte.chr
      index += 1
      break
    end
    index += 1
  end
  index
end

def copy_newlines_while_skipping_block_comment(content, index, output)
  index += 2
  depth = 1

  while index < content.bytesize && depth.positive?
    if content.byteslice(index, 2) == "/*"
      depth += 1
      index += 2
    elsif content.byteslice(index, 2) == "*/"
      depth -= 1
      index += 2
    else
      byte = content.getbyte(index)
      output << byte.chr if byte == 10 || byte == 13
      index += 1
    end
  end

  index
end

def swift_string_literal_end(content, index)
  cursor = index
  hash_count = 0

  while cursor < content.bytesize && content.getbyte(cursor) == 35
    hash_count += 1
    cursor += 1
  end

  return nil unless cursor < content.bytesize && content.getbyte(cursor) == 34

  quote_count = content.byteslice(cursor, 3) == '"""' ? 3 : 1
  cursor += quote_count

  if quote_count == 1
    while cursor < content.bytesize
      byte = content.getbyte(cursor)
      if hash_count.zero? && byte == 92
        cursor += 2
        next
      end

      if byte == 34 && (ending = index_after_hashes(content, cursor + 1, hash_count))
        return ending
      end

      cursor += 1
    end
  else
    while cursor < content.bytesize
      if content.byteslice(cursor, 3) == '"""' && (ending = index_after_hashes(content, cursor + 3, hash_count))
        return ending
      end

      cursor += 1
    end
  end

  content.bytesize
end

def index_after_hashes(content, index, count)
  cursor = index
  count.times do
    return nil unless cursor < content.bytesize && content.getbyte(cursor) == 35

    cursor += 1
  end
  cursor
end

def required_token_source(relative_path, content)
  if relative_path == "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
    uncommented_swift(content)
  else
    swift_contract_source(content)
  end
end

failures = []

scanner_fixture = <<~SWIFT
  // AppleDeveloperProgramBlocker should disappear from comments.
  let blockerPath = "apple-developer-program-blocker-apns.json"
  let url = "https://example.test/sendPushNotification"
  /*
   APNsDeliveryBlockerState should disappear from block comments.
   */
  let state = APNsDeliveryBlockerState.blocked
  let multiline = """
  AppleDeveloperProgramBlocker inside a multiline string should not satisfy typed scans.
  """
  let raw = #"APNsDeliveryBlockerState inside a raw string should not satisfy typed scans."#
SWIFT
scanner_uncommented = uncommented_swift(scanner_fixture)
scanner_contract = swift_contract_source(scanner_fixture)
failures << "scanner self-check failed to strip line comments" if scanner_uncommented.include?("should disappear from comments")
failures << "scanner self-check failed to strip block comments" if scanner_uncommented.include?("should disappear from block comments")
failures << "scanner self-check lost URL-like string contents" unless scanner_uncommented.include?('"https://example.test/sendPushNotification"')
failures << "scanner self-check lost real typed code token" unless scanner_uncommented.include?("APNsDeliveryBlockerState.blocked")
failures << "scanner self-check leaked typed token from comment/string" if scanner_contract.include?("AppleDeveloperProgramBlocker")
failures << "scanner self-check leaked string-only fake delivery token" if scanner_contract.include?("sendPushNotification")
failures << "scanner self-check stripped real typed code token" unless scanner_contract.include?("APNsDeliveryBlockerState.blocked")

REQUIRED_FILES.each do |relative_path|
  failures << "missing notification/APNs surface file: #{relative_path}" unless ROOT.join(relative_path).file?
end

REQUIRED_TOKENS.each do |relative_path, tokens|
  path = ROOT.join(relative_path)
  next unless path.file?

  content = required_token_source(relative_path, path.read)
  missing = tokens.reject { |token| content.include?(token) }
  failures << "#{relative_path} missing required notification/APNs tokens: #{missing.join(", ")}" unless missing.empty?
end

STRING_ALLOWED_TOKENS.each do |relative_path, tokens|
  path = ROOT.join(relative_path)
  next unless path.file?

  content = uncommented_swift(path.read)
  missing = tokens.reject { |token| content.include?(token) }
  failures << "#{relative_path} missing required string-allowed notification/APNs tokens: #{missing.join(", ")}" unless missing.empty?
end

OFFLINE_CACHE_TOKENS.each do |relative_path, tokens|
  path = ROOT.join(relative_path)
  next unless path.file?

  content = swift_contract_source(path.read)
  missing = tokens.reject { |token| content.include?(token) }
  failures << "#{relative_path} missing required offline cached notification/APNs tokens: #{missing.join(", ")}" unless missing.empty?
end

BLOCKER_CONSUMER_TOKENS.each do |relative_path, tokens|
  path = ROOT.join(relative_path)
  next unless path.file?

  content = swift_contract_source(path.read)
  missing = tokens.reject { |token| content.include?(token) }
  failures << "#{relative_path} missing required typed AppleDeveloperProgram blocker tokens: #{missing.join(", ")}" unless missing.empty?
end

BLOCKER_CONSUMER_STRING_TOKENS.each do |relative_path, tokens|
  path = ROOT.join(relative_path)
  next unless path.file?

  content = uncommented_swift(path.read)
  missing = tokens.reject { |token| content.include?(token) }
  failures << "#{relative_path} missing required AppleDeveloperProgram blocker path tokens: #{missing.join(", ")}" unless missing.empty?
end

REQUIRED_FILES.each do |relative_path|
  path = ROOT.join(relative_path)
  next unless path.file?

  content = uncommented_swift(path.read)
  forbidden = FORBIDDEN_TOKENS.select { |token| content.include?(token) }
  failures << "#{relative_path} contains forbidden notification/APNs tokens: #{forbidden.join(", ")}" unless forbidden.empty?
end

Dir.glob(ROOT.join("{Sources,Apps}/**/*.swift")).sort.each do |path_string|
  path = Pathname.new(path_string)
  relative_path = path.relative_path_from(ROOT).to_s
  content = uncommented_swift(path.read)
  forbidden = FORBIDDEN_TOKENS.select { |token| content.include?(token) }
  failures << "#{relative_path} contains forbidden notification/APNs delivery token(s): #{forbidden.join(", ")}" unless forbidden.empty?
end

blocker_path = Pathname.new(ENV.fetch("ARTIFACT_ROOT", ROOT.join("tasks/2026-06-16-1754-doing-siri-full-access-parity").to_s))
                       .join("apple/apple-developer-program-blocker-apns.json")
unless blocker_path.file?
  failures << "missing canonical Apple Developer Program APNs blocker artifact: #{blocker_path}"
else
  blocker = JSON.parse(blocker_path.read)
  required_pairs = {
    "blocked" => true,
    "capability" => "AppleDeveloperProgram"
  }
  required_pairs.each do |key, value|
    failures << "#{blocker_path} expected #{key}=#{value.inspect}" unless blocker[key] == value
  end
  %w[command outputPath reason ownerAction].each do |key|
    failures << "#{blocker_path} missing #{key}" if blocker[key].to_s.strip.empty?
  end
end

if failures.empty?
  puts "notification/APNs surfaces contract ok"
else
  warn failures.map { |failure| "FAIL: #{failure}" }.join("\n")
  exit 1
end
