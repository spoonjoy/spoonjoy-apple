#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

begin
  require "rubygems"
  require "bundler/setup"
  require "xcodeproj"
  XCODEPROJ_LOAD_ERROR = nil
rescue LoadError => e
  XCODEPROJ_LOAD_ERROR = e
end

ROOT = Pathname.new(__dir__).join("..").expand_path

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def uncommented_swift(content)
  output = +""
  chars = content.each_char.to_a
  index = 0
  in_string = false
  escaping = false

  while index < chars.length
    char = chars[index]
    next_char = chars[index + 1]

    if in_string
      output << char
      if escaping
        escaping = false
      elsif char == "\\"
        escaping = true
      elsif char == "\""
        in_string = false
      end
      index += 1
      next
    end

    if char == "\""
      in_string = true
      output << char
      index += 1
      next
    end

    if char == "/" && next_char == "/"
      index += 2
      index += 1 while index < chars.length && chars[index] != "\n"
      if index < chars.length
        output << chars[index]
        index += 1
      end
      next
    end

    if char == "/" && next_char == "*"
      index += 2
      while index < chars.length
        if chars[index - 1] == "*" && chars[index] == "/"
          index += 1
          break
        end
        index += 1
      end
      next
    end

    output << char
    index += 1
  end

  output
end

def relative(path)
  Pathname.new(path).expand_path.relative_path_from(ROOT).to_s
end

domain = "recipe-cookbook"
args = ARGV.dup
until args.empty?
  arg = args.shift
  case arg
  when "--domain"
    domain = args.shift || fail_check("--domain requires a value")
  else
    fail_check("unknown argument #{arg}")
  end
end

supported_domains = ["recipe-cookbook", "shopping", "spoon", "capture-draft", "chef-profile", "spotlight-shortcuts", "open-search-share-cook", "shopping-intents", "recipe-action", "spoon-intents"]
fail_check("unsupported AppIntents contract domain #{domain.inspect}") unless supported_domains.include?(domain)

failures = []

def require_file(path, failures)
  failures << "missing #{relative(path)}" unless path.file?
end

def require_tokens(path, tokens, failures)
  return unless path.file?

  content = uncommented_swift(path.read)
  tokens.each do |token|
    failures << "#{relative(path)} missing #{token}" unless content.include?(token)
  end
end

def require_patterns(path, patterns, failures)
  return unless path.file?

  content = uncommented_swift(path.read)
  patterns.each do |label, pattern|
    failures << "#{relative(path)} missing #{label}" unless content.match?(pattern)
  end
end

def declaration_body(content, pattern)
  match = content.match(pattern)
  return nil unless match

  open_brace = content.index("{", match.end(0))
  return nil unless open_brace

  depth = 0
  index = open_brace
  while index < content.length
    char = content[index]
    depth += 1 if char == "{"
    if char == "}"
      depth -= 1
      return content[(open_brace + 1)...index] if depth.zero?
    end
    index += 1
  end

  nil
end

def require_body_tokens(path, label, pattern, tokens, failures)
  return unless path.file?

  content = uncommented_swift(path.read)
  body = declaration_body(content, pattern)
  unless body
    failures << "#{relative(path)} missing body for #{label}"
    return
  end

  tokens.each do |token|
    failures << "#{relative(path)} #{label} missing #{token}" unless body.include?(token)
  end
end

def require_nested_body_tokens(path, outer_label, outer_pattern, inner_label, inner_pattern, tokens, failures)
  return unless path.file?

  content = uncommented_swift(path.read)
  outer_body = declaration_body(content, outer_pattern)
  unless outer_body
    failures << "#{relative(path)} missing body for #{outer_label}"
    return
  end

  inner_body = declaration_body(outer_body, inner_pattern)
  unless inner_body
    failures << "#{relative(path)} #{outer_label} missing body for #{inner_label}"
    return
  end

  tokens.each do |token|
    failures << "#{relative(path)} #{outer_label} #{inner_label} missing #{token}" unless inner_body.include?(token)
  end
end

def forbid_body_tokens(path, label, pattern, tokens, failures)
  return unless path.file?

  content = uncommented_swift(path.read)
  body = declaration_body(content, pattern)
  unless body
    failures << "#{relative(path)} missing body for #{label}"
    return
  end

  tokens.each do |token|
    failures << "#{relative(path)} #{label} contains forbidden #{token}" if body.include?(token)
  end
end

def forbid_tokens(path, tokens, failures)
  return unless path.file?

  content = uncommented_swift(path.read)
  tokens.each do |token|
    failures << "#{relative(path)} contains forbidden #{token}" if content.include?(token)
  end
end

def require_project_source_membership(project_path, relative_source, target_names, failures)
  if XCODEPROJ_LOAD_ERROR
    failures << "cannot inspect Xcode source membership: #{XCODEPROJ_LOAD_ERROR.message}"
    return
  end

  return unless project_path.directory?

  source_path = ROOT.join(relative_source).expand_path.to_s
  project = Xcodeproj::Project.open(project_path.to_s)
  targets_by_name = project.targets.to_h { |target| [target.name, target] }
  target_names.each do |target_name|
    target = targets_by_name[target_name]
    unless target
      failures << "#{relative(project_path)} missing target #{target_name}"
      next
    end

    source_paths = target.source_build_phase.files.map do |build_file|
      ref = build_file.file_ref
      next unless ref&.path&.end_with?(".swift")

      ref.real_path.expand_path.to_s
    end.compact
    failures << "#{relative(project_path)} target #{target_name} missing #{relative_source}" unless source_paths.include?(source_path)
  end
end

if domain == "recipe-cookbook"
  core_entities = ROOT.join("Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift")
  app_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift")
  app_intents = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift")
  metadata = ROOT.join("Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift")
  verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift")
  project_path = ROOT.join("Spoonjoy.xcodeproj")
  project = project_path.join("project.pbxproj")

  [core_entities, app_entities, app_intents, metadata, verifier, project].each do |path|
    require_file(path, failures)
  end

  require_tokens(
    core_entities,
    [
      "RecipeCookbookEntityCatalog",
      "RecipeEntityDescriptor",
      "CookbookEntityDescriptor",
      "RecipeCookbookEntityTransferValue",
      "RecipeCookbookEntityKind",
      "isPlaceholder",
      "recipeEntity(id:",
      "cookbookEntity(id:",
      "recipeEntities(for identifiers:",
      "cookbookEntities(for identifiers:",
      "recipeEntities(matching string:",
      "cookbookEntities(matching string:",
      "suggestedRecipeEntities",
      "suggestedCookbookEntities",
      "public static func loading(",
      "loadSnapshot()",
      "NativeSyncSnapshot",
      "NativeSyncCachedRecord",
      "NativeSyncEntryKind.recipe",
      "NativeSyncEntryKind.cookbook",
      "tombstones",
      "accountID",
      "environment",
      "AppRoute.recipeDetail",
      "AppRoute.cookbookDetail",
      "NativeSharePayload.publicRoute",
      "disambiguationLabel",
      "transferValue",
      "debugFields"
    ],
    failures
  )

  require_tokens(
    app_entities,
    [
      "#if canImport(AppIntents)",
      "import AppIntents",
      "import CoreTransferable",
      "import SpoonjoyCore",
      "@available(iOS 27.0, macOS 27.0, *)",
      "struct SpoonjoyRecipeEntity: AppEntity",
      "struct SpoonjoyCookbookEntity: AppEntity",
      "struct SpoonjoyRecipeEntityQuery: EntityQuery, EntityStringQuery",
      "struct SpoonjoyCookbookEntityQuery: EntityQuery, EntityStringQuery",
      "typealias DefaultQuery = SpoonjoyRecipeEntityQuery",
      "typealias DefaultQuery = SpoonjoyCookbookEntityQuery",
      "static let typeDisplayRepresentation",
      "var displayRepresentation",
      "DisplayRepresentation",
      "TypeDisplayRepresentation",
      "entities(for identifiers: [String]) async throws",
      "entities(matching string: String) async throws",
      "suggestedEntities() async throws",
      "RecipeCookbookEntityCatalog",
      "RecipeEntityDescriptor",
      "CookbookEntityDescriptor",
      "Transferable",
      "TransferRepresentation",
      "RecipeCookbookEntityTransferValue",
      "resolvedRecipeID() throws",
      "NativeIntentActionError.unresolvedRecipeEntity",
      "descriptor.isPlaceholder",
      "NativeAppStateLocation.defaultFileURL()",
      "FileBackedNativeSyncStore",
      "loadSnapshot()",
      "trustedIntentScope",
      "KeychainTokenVault()",
      "scope.accountID",
      "scope.environment"
    ],
    failures
  )

  require_patterns(
    app_entities,
    {
      "SpoonjoyRecipeEntity AppEntity declaration" => /\bstruct\s+SpoonjoyRecipeEntity\s*:\s*AppEntity\b/,
      "SpoonjoyCookbookEntity AppEntity declaration" => /\bstruct\s+SpoonjoyCookbookEntity\s*:\s*AppEntity\b/,
      "recipe query declaration" => /\bstruct\s+SpoonjoyRecipeEntityQuery\s*:\s*EntityQuery\s*,\s*EntityStringQuery\b/,
      "cookbook query declaration" => /\bstruct\s+SpoonjoyCookbookEntityQuery\s*:\s*EntityQuery\s*,\s*EntityStringQuery\b/
    },
    failures
  )
  require_nested_body_tokens(app_entities, "SpoonjoyRecipeEntityQuery", /\bstruct\s+SpoonjoyRecipeEntityQuery\b/, "identifier query", /func\s+entities\(for identifiers: \[String\]\)/, ["RecipeCookbookEntityCatalog.loading(syncStore:", "recipeEntities(for: identifiers)", "SpoonjoyRecipeEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyRecipeEntityQuery", /\bstruct\s+SpoonjoyRecipeEntityQuery\b/, "string query", /func\s+entities\(matching string: String\)/, ["RecipeCookbookEntityCatalog.loading(syncStore:", "recipeEntities(matching: string)", "SpoonjoyRecipeEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyRecipeEntityQuery", /\bstruct\s+SpoonjoyRecipeEntityQuery\b/, "suggestions query", /func\s+suggestedEntities\(\)/, ["RecipeCookbookEntityCatalog.loading(syncStore:", "suggestedRecipeEntities", "SpoonjoyRecipeEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyCookbookEntityQuery", /\bstruct\s+SpoonjoyCookbookEntityQuery\b/, "identifier query", /func\s+entities\(for identifiers: \[String\]\)/, ["RecipeCookbookEntityCatalog.loading(syncStore:", "cookbookEntities(for: identifiers)", "SpoonjoyCookbookEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyCookbookEntityQuery", /\bstruct\s+SpoonjoyCookbookEntityQuery\b/, "string query", /func\s+entities\(matching string: String\)/, ["RecipeCookbookEntityCatalog.loading(syncStore:", "cookbookEntities(matching: string)", "SpoonjoyCookbookEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyCookbookEntityQuery", /\bstruct\s+SpoonjoyCookbookEntityQuery\b/, "suggestions query", /func\s+suggestedEntities\(\)/, ["RecipeCookbookEntityCatalog.loading(syncStore:", "suggestedCookbookEntities", "SpoonjoyCookbookEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyRecipeEntity", /\bstruct\s+SpoonjoyRecipeEntity\b/, "display representation", /var\s+displayRepresentation:\s+DisplayRepresentation/, ["descriptor.title", "descriptor.subtitle", "descriptor.disambiguationLabel"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyCookbookEntity", /\bstruct\s+SpoonjoyCookbookEntity\b/, "display representation", /var\s+displayRepresentation:\s+DisplayRepresentation/, ["descriptor.title", "descriptor.subtitle", "descriptor.disambiguationLabel"], failures)

  require_tokens(
    app_intents,
    [
      "@Parameter(title: \"Recipe\", requestValueDialog:",
      "var recipe: SpoonjoyRecipeEntity",
      "try recipe.resolvedRecipeID()"
    ],
    failures
  )
  {
    "OpenRecipeIntent" => ["@Parameter(title: \"Recipe\", requestValueDialog:", "var recipe: SpoonjoyRecipeEntity", "try recipe.resolvedRecipeID()"],
    "StartCookModeIntent" => ["@Parameter(title: \"Recipe\", requestValueDialog:", "var recipe: SpoonjoyRecipeEntity", "try recipe.resolvedRecipeID()"],
    "AddRecipeIngredientsToShoppingListIntent" => ["@Parameter(title: \"Recipe\", requestValueDialog:", "var recipe: SpoonjoyRecipeEntity", "try recipe.resolvedRecipeID()"]
  }.each do |intent_name, tokens|
    pattern = /\bstruct\s+#{Regexp.escape(intent_name)}\s*:\s*AppIntent\b/
    require_body_tokens(app_intents, intent_name, pattern, tokens, failures)
    forbid_body_tokens(app_intents, intent_name, pattern, ["var recipeID: String", "@Parameter(title: \"Recipe ID\")", "recipe.descriptor.id"], failures)
  end

  require_tokens(
    metadata,
    [
      "SpoonjoyRecipeEntity",
      "SpoonjoyCookbookEntity",
      "SpoonjoyRecipeEntityQuery",
      "SpoonjoyCookbookEntityQuery"
    ],
    failures
  )

  require_tokens(
    verifier,
    [
      "recipe App Entity",
      "cookbook App Entity",
      "RecipeCookbookEntityCatalog",
      "SpoonjoyRecipeEntity",
      "SpoonjoyCookbookEntity"
    ],
    failures
  )

  if project.file?
    require_project_source_membership(
      project_path,
      "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
      ["Spoonjoy iOS", "Spoonjoy macOS"],
      failures
    )
    require_project_source_membership(
      project_path,
      "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
      ["Spoonjoy iOS", "Spoonjoy macOS"],
      failures
    )
  end

  forbid_tokens(
    app_intents,
    [
      "@Parameter(title: \"Recipe ID\")",
      "@Parameter(title: \"Cookbook ID\")",
      "recipe.descriptor.id",
      "recipe-entity",
      "cookbook-entity",
      "String-only recipe App Intent",
      "TODO AppEntity"
    ],
    failures
  )
end

if domain == "shopping"
  core_entities = ROOT.join("Sources/SpoonjoyCore/Native/ShoppingEntityCatalog.swift")
  app_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift")
  app_intents = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift")
  metadata = ROOT.join("Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift")
  verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift")
  live_store = ROOT.join("Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift")
  sync_engine = ROOT.join("Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift")
  spotlight_indexer = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift")
  project_path = ROOT.join("Spoonjoy.xcodeproj")
  project = project_path.join("project.pbxproj")

  [core_entities, app_entities, app_intents, metadata, verifier, live_store, sync_engine, spotlight_indexer, project].each do |path|
    require_file(path, failures)
  end

  require_tokens(
    core_entities,
    [
      "ShoppingEntityCatalog",
      "ShoppingEntityCatalogError",
      "ShoppingEntityKind",
      "ShoppingEntityTransferValue",
      "ShoppingEntityScope",
      "ShoppingListEntityDescriptor",
      "ShoppingItemEntityDescriptor",
      "ShoppingEntityIndexPurgePlan",
      "isPlaceholder",
      "shoppingListEntity()",
      "shoppingItemEntity(id:",
      "shoppingItemEntities(for identifiers:",
      "shoppingItemEntities(matching string:",
      "suggestedShoppingItemEntities",
      "public static func loading(",
      "loadSnapshot()",
      "NativeSyncSnapshot",
      "NativeSyncCachedRecord",
      "NativeSyncEntryKind.shoppingItem",
      "NativeSyncResourceType.shoppingItem",
      "tombstones",
      "accountID",
      "environment",
      "private static func scopedIdentifier(",
      "public static func shoppingListEntityIdentifier(",
      "public static func shoppingItemEntityIdentifier(",
      "public static func resolvedShoppingItemID(",
      "public static func purgeEntityIdentifiers(",
      "purgeDomainIdentifiers(",
      "SpotlightIndexPlan.shoppingListItemUniqueIdentifier",
      "SpotlightIndexPlan.shoppingListItemDomainIdentifier",
      "public static func accountScopePurge(",
      "public static func tombstonePurge(",
      "public static func cacheDeletePurge(",
      "domainIdentifiers",
      "ShoppingListState",
      "ShoppingListItem",
      "activeItems",
      "deletedAt",
      "checked",
      "displayQuantity",
      "AppRoute.shoppingList",
      "NativeSharePayload.privateShoppingList",
      "NativeSharePayload.privateShoppingItem",
      "privateTransferValue",
      "debugFields"
    ],
    failures
  )

  require_body_tokens(
    live_store,
    "performSettingsSessionOperation",
    /\bfunc\s+performSettingsSessionOperation\(_ operation: SettingsSessionOperation\)/,
    [
      "case .logout, .revokeAndLogout",
      "ShoppingEntityIndexPurgePlan.accountScopePurge",
      "ShoppingEntityCatalog.purgeEntityIdentifiers(",
      "ShoppingEntityCatalog.purgeDomainIdentifiers(",
      "purgeShoppingEntityIdentifiers",
      "cacheEnvironment"
    ],
    failures
  )

  require_body_tokens(
    live_store,
    "bootstrapFromLiveAPI consumes sync purge report",
    /\bfunc\s+bootstrapFromLiveAPI\(\s*session: AuthSession,\s*trigger: NativeSyncTriggerEvent\s*\)/,
    [
      "let report = try await syncTriggerCoordinator.handle(trigger)",
      "report.shoppingEntityPurgeRequests"
    ],
    failures
  )

  require_body_tokens(
    ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"),
    "foreground sync consumes sync purge report",
    /\.task\(id: contentState\.environment\.rawValue\)/,
    [
      "let report = try? await syncTriggerCoordinator.handle(.foreground)",
      "report.shoppingEntityPurgeRequests",
      "purgeShoppingEntityIndexesHandler"
    ],
    failures
  )

  require_body_tokens(
    sync_engine,
    "bootstrapAndDrain scoped tombstone purge",
    /\bpublic\s+func\s+bootstrapAndDrain\(\s*configuration: APIClientConfiguration,\s*trigger: NativeCacheRevalidationTrigger,\s*scope: NativeSyncExecutionScope\s*\)/,
    [
      "case .success(let cursor, let tombstones)",
      "ShoppingEntityIndexPurgePlan.tombstonePurge",
      "shoppingEntityAccountScopePurgePlan",
      "shoppingEntityPurgeIdentifiers",
      "shoppingEntityPurgeDomainIdentifiers",
      "previousSnapshot",
      "ShoppingEntityCatalog.purgeEntityIdentifiers(",
      "ShoppingEntityCatalog.purgeDomainIdentifiers(",
      "NativeSyncResourceType.shoppingItem",
      "removedCacheKeys"
    ],
    failures
  )

  require_tokens(
    spotlight_indexer,
    [
      "accountID: String? = nil",
      "environment: NativeCacheEnvironment? = nil",
      "deleteSearchableItems(withIdentifiers:",
      "deleteSearchableItems(withDomainIdentifiers:"
    ],
    failures
  )

  require_tokens(
    app_entities,
    [
      "#if canImport(AppIntents)",
      "import AppIntents",
      "import CoreTransferable",
      "import SpoonjoyCore",
      "@available(iOS 27.0, macOS 27.0, *)",
      "struct SpoonjoyShoppingListEntity: AppEntity",
      "struct SpoonjoyShoppingItemEntity: AppEntity",
      "struct SpoonjoyShoppingListEntityQuery: EntityQuery",
      "struct SpoonjoyShoppingItemEntityQuery: EntityQuery, EntityStringQuery",
      "typealias DefaultQuery = SpoonjoyShoppingListEntityQuery",
      "typealias DefaultQuery = SpoonjoyShoppingItemEntityQuery",
      "static let typeDisplayRepresentation",
      "var displayRepresentation",
      "DisplayRepresentation",
      "TypeDisplayRepresentation",
      "entities(for identifiers: [String]) async throws",
      "entities(matching string: String) async throws",
      "suggestedEntities() async throws",
      "ShoppingEntityCatalog",
      "ShoppingListEntityDescriptor",
      "ShoppingItemEntityDescriptor",
      "Transferable",
      "TransferRepresentation",
      "ShoppingEntityTransferValue",
      "resolvedShoppingItemID() throws",
      "NativeIntentActionError.unresolvedShoppingItemEntity",
      "descriptor.isPlaceholder",
      "NativeAppStateLocation.defaultFileURL()",
      "FileBackedNativeSyncStore",
      "loadSnapshot()",
      "trustedIntentScope",
      "KeychainTokenVault()",
      "scope.accountID",
      "scope.environment"
    ],
    failures
  )

  require_patterns(
    app_entities,
    {
      "SpoonjoyShoppingListEntity AppEntity declaration" => /\bstruct\s+SpoonjoyShoppingListEntity\s*:\s*AppEntity\b/,
      "SpoonjoyShoppingItemEntity AppEntity declaration" => /\bstruct\s+SpoonjoyShoppingItemEntity\s*:\s*AppEntity\b/,
      "shopping list query declaration" => /\bstruct\s+SpoonjoyShoppingListEntityQuery\s*:\s*EntityQuery\b/,
      "shopping item query declaration" => /\bstruct\s+SpoonjoyShoppingItemEntityQuery\s*:\s*EntityQuery\s*,\s*EntityStringQuery\b/
    },
    failures
  )
  require_nested_body_tokens(app_entities, "SpoonjoyShoppingListEntityQuery", /\bstruct\s+SpoonjoyShoppingListEntityQuery\b/, "identifier query", /func\s+entities\(for identifiers: \[String\]\)/, ["ShoppingEntityCatalog.loading(syncStore:", "shoppingListEntity()", "SpoonjoyShoppingListEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyShoppingListEntityQuery", /\bstruct\s+SpoonjoyShoppingListEntityQuery\b/, "suggestions query", /func\s+suggestedEntities\(\)/, ["ShoppingEntityCatalog.loading(syncStore:", "shoppingListEntity()", "SpoonjoyShoppingListEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyShoppingItemEntityQuery", /\bstruct\s+SpoonjoyShoppingItemEntityQuery\b/, "identifier query", /func\s+entities\(for identifiers: \[String\]\)/, ["ShoppingEntityCatalog.loading(syncStore:", "shoppingItemEntities(for: identifiers)", "SpoonjoyShoppingItemEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyShoppingItemEntityQuery", /\bstruct\s+SpoonjoyShoppingItemEntityQuery\b/, "string query", /func\s+entities\(matching string: String\)/, ["ShoppingEntityCatalog.loading(syncStore:", "shoppingItemEntities(matching: string)", "SpoonjoyShoppingItemEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyShoppingItemEntityQuery", /\bstruct\s+SpoonjoyShoppingItemEntityQuery\b/, "suggestions query", /func\s+suggestedEntities\(\)/, ["ShoppingEntityCatalog.loading(syncStore:", "suggestedShoppingItemEntities", "SpoonjoyShoppingItemEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyShoppingListEntity", /\bstruct\s+SpoonjoyShoppingListEntity\b/, "display representation", /var\s+displayRepresentation:\s+DisplayRepresentation/, ["descriptor.title", "descriptor.subtitle", "descriptor.disambiguationLabel"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyShoppingItemEntity", /\bstruct\s+SpoonjoyShoppingItemEntity\b/, "display representation", /var\s+displayRepresentation:\s+DisplayRepresentation/, ["descriptor.title", "descriptor.subtitle", "descriptor.disambiguationLabel"], failures)

  require_tokens(
    app_intents,
    [
      "@Parameter(title: \"Shopping Item\", requestValueDialog:",
      "var item: SpoonjoyShoppingItemEntity",
      "try item.resolvedShoppingItemID()"
    ],
    failures
  )
  require_body_tokens(
    app_intents,
    "SetShoppingListItemCheckedIntent",
    /\bstruct\s+SetShoppingListItemCheckedIntent\s*:\s*AppIntent\b/,
    [
      "@Parameter(title: \"Shopping Item\", requestValueDialog:",
      "var item: SpoonjoyShoppingItemEntity",
      "try item.resolvedShoppingItemID()"
    ],
    failures
  )
  forbid_body_tokens(
    app_intents,
    "SetShoppingListItemCheckedIntent",
    /\bstruct\s+SetShoppingListItemCheckedIntent\s*:\s*AppIntent\b/,
    [
      "@Parameter(title: \"Item ID\")",
      "var itemID: String"
    ],
    failures
  )

  require_tokens(
    metadata,
    [
      "SpoonjoyShoppingListEntity",
      "SpoonjoyShoppingItemEntity",
      "SpoonjoyShoppingListEntityQuery",
      "SpoonjoyShoppingItemEntityQuery"
    ],
    failures
  )

  require_tokens(
    verifier,
    [
      "shopping list App Entity",
      "shopping item App Entity",
      "ShoppingEntityCatalog",
      "SpoonjoyShoppingListEntity",
      "SpoonjoyShoppingItemEntity"
    ],
    failures
  )

  if project.file?
    require_project_source_membership(
      project_path,
      "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift",
      ["Spoonjoy iOS", "Spoonjoy macOS"],
      failures
    )
    require_project_source_membership(
      project_path,
      "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
      ["Spoonjoy iOS", "Spoonjoy macOS"],
      failures
    )
  end

  forbid_tokens(
    app_intents,
    [
      "@Parameter(title: \"Item ID\")",
      "var itemID: String",
      "String-only shopping App Intent",
      "TODO Shopping AppEntity",
      "eventually add shopping entities"
    ],
    failures
  )
end

if domain == "spoon"
  core_entities = ROOT.join("Sources/SpoonjoyCore/Native/SpoonEntityCatalog.swift")
  app_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift")
  metadata = ROOT.join("Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift")
  verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift")
  live_store = ROOT.join("Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift")
  sync_engine = ROOT.join("Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift")
  platform_navigation = ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift")
  spotlight_indexer = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift")
  project_path = ROOT.join("Spoonjoy.xcodeproj")
  project = project_path.join("project.pbxproj")

  [core_entities, app_entities, metadata, verifier, live_store, sync_engine, platform_navigation, spotlight_indexer, project].each do |path|
    require_file(path, failures)
  end

  require_tokens(
    core_entities,
    [
      "SpoonEntityCatalog",
      "SpoonEntityCatalogError",
      "SpoonEntityKind",
      "SpoonEntityTransferValue",
      "SpoonEntityScope",
      "SpoonEntityDescriptor",
      "SpoonEntityIndexPurgePlan",
      "isPlaceholder",
      "spoonEntity(id:",
      "spoonEntities(for identifiers:",
      "spoonEntities(matching string:",
      "suggestedSpoonEntities",
      "public static func loading(",
      "loadSnapshot()",
      "NativeSyncSnapshot",
      "NativeSyncCachedRecord",
      "NativeSyncEntryKind.recipe",
      "NativeSyncEntryKind.spoon",
      "NativeSyncResourceType.spoon",
      "tombstones",
      "accountID",
      "environment",
      "public static func spoonEntityIdentifier(",
      "public static func resolvedSpoonID(",
      "public static func purgeEntityIdentifiers(",
      "purgeDomainIdentifiers(",
      "public static func accountScopePurge(",
      "public static func tombstonePurge(",
      "public static func cacheDeletePurge(",
      "domainIdentifiers",
      "SpotlightIndexPlan.spoonUniqueIdentifier",
      "SpotlightIndexPlan.spoonDomainIdentifier",
      "Recipe",
      "RecipeDetailRecentSpoon",
      "recentSpoons",
      "deletedAt",
      "cookedAt",
      "note",
      "nextTime",
      "photoURL",
      "AppRoute.recipeDetail",
      "NativeSharePayload.privateSpoon",
      "privateTransferValue",
      "debugFields"
    ],
    failures
  )

  require_body_tokens(
    live_store,
    "performSettingsSessionOperation",
    /\bfunc\s+performSettingsSessionOperation\(_ operation: SettingsSessionOperation\)/,
    [
      "case .logout, .revokeAndLogout",
      "SpoonEntityIndexPurgePlan.accountScopePurge",
      "SpoonEntityCatalog.purgeEntityIdentifiers(",
      "SpoonEntityCatalog.purgeDomainIdentifiers(",
      "purgeSpoonEntityIdentifiers",
      "cacheEnvironment"
    ],
    failures
  )

  require_body_tokens(
    live_store,
    "bootstrapFromLiveAPI consumes spoon sync purge report",
    /\bfunc\s+bootstrapFromLiveAPI\(\s*session: AuthSession,\s*trigger: NativeSyncTriggerEvent\s*\)/,
    [
      "let report = try await syncTriggerCoordinator.handle(trigger)",
      "report.spoonEntityPurgeRequests"
    ],
    failures
  )

  require_body_tokens(
    platform_navigation,
    "foreground sync consumes spoon sync purge report",
    /\.task\(id: contentState\.environment\.rawValue\)/,
    [
      "let report = try? await syncTriggerCoordinator.handle(.foreground)",
      "report.spoonEntityPurgeRequests",
      "purgeSpoonEntityIndexesHandler"
    ],
    failures
  )

  require_body_tokens(
    sync_engine,
    "bootstrapAndDrain scoped spoon tombstone purge",
    /\bpublic\s+func\s+bootstrapAndDrain\(\s*configuration: APIClientConfiguration,\s*trigger: NativeCacheRevalidationTrigger,\s*scope: NativeSyncExecutionScope\s*\)/,
    [
      "case .success(let cursor, let tombstones)",
      "SpoonEntityIndexPurgePlan.tombstonePurge",
      "spoonEntityAccountScopePurgePlan",
      "spoonEntityPurgeIdentifiers",
      "spoonEntityPurgeDomainIdentifiers",
      "previousSnapshot",
      "SpoonEntityCatalog.purgeEntityIdentifiers(",
      "SpoonEntityCatalog.purgeDomainIdentifiers(",
      "NativeSyncResourceType.spoon",
      "removedCacheKeys"
    ],
    failures
  )

  require_tokens(
    spotlight_indexer,
    [
      "accountID: String? = nil",
      "environment: NativeCacheEnvironment? = nil",
      "deleteSearchableItems(withIdentifiers:",
      "deleteSearchableItems(withDomainIdentifiers:"
    ],
    failures
  )

  require_tokens(
    app_entities,
    [
      "#if canImport(AppIntents)",
      "import AppIntents",
      "import CoreTransferable",
      "import SpoonjoyCore",
      "@available(iOS 27.0, macOS 27.0, *)",
      "struct SpoonjoySpoonEntity: AppEntity",
      "struct SpoonjoySpoonEntityQuery: EntityQuery, EntityStringQuery",
      "typealias DefaultQuery = SpoonjoySpoonEntityQuery",
      "static let typeDisplayRepresentation",
      "var displayRepresentation",
      "DisplayRepresentation",
      "TypeDisplayRepresentation",
      "entities(for identifiers: [String]) async throws",
      "entities(matching string: String) async throws",
      "suggestedEntities() async throws",
      "SpoonEntityCatalog",
      "SpoonEntityDescriptor",
      "Transferable",
      "TransferRepresentation",
      "SpoonEntityTransferValue",
      "resolvedSpoonID() throws",
      "NativeIntentActionError.unresolvedSpoonEntity",
      "descriptor.isPlaceholder",
      "DeepLinkURLBuilder.url(for:",
      "NativeAppStateLocation.defaultFileURL()",
      "FileBackedNativeSyncStore",
      "loadSnapshot()",
      "trustedIntentScope",
      "KeychainTokenVault()",
      "scope.accountID",
      "scope.environment"
    ],
    failures
  )

  require_patterns(
    app_entities,
    {
      "SpoonjoySpoonEntity AppEntity declaration" => /\bstruct\s+SpoonjoySpoonEntity\s*:\s*AppEntity\b/,
      "spoon query declaration" => /\bstruct\s+SpoonjoySpoonEntityQuery\s*:\s*EntityQuery\s*,\s*EntityStringQuery\b/
    },
    failures
  )
  require_nested_body_tokens(app_entities, "SpoonjoySpoonEntityQuery", /\bstruct\s+SpoonjoySpoonEntityQuery\b/, "identifier query", /func\s+entities\(for identifiers: \[String\]\)/, ["SpoonEntityCatalog.loading(syncStore:", "spoonEntities(for: identifiers)", "SpoonjoySpoonEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoySpoonEntityQuery", /\bstruct\s+SpoonjoySpoonEntityQuery\b/, "string query", /func\s+entities\(matching string: String\)/, ["SpoonEntityCatalog.loading(syncStore:", "spoonEntities(matching: string)", "SpoonjoySpoonEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoySpoonEntityQuery", /\bstruct\s+SpoonjoySpoonEntityQuery\b/, "suggestions query", /func\s+suggestedEntities\(\)/, ["SpoonEntityCatalog.loading(syncStore:", "suggestedSpoonEntities", "SpoonjoySpoonEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoySpoonEntity", /\bstruct\s+SpoonjoySpoonEntity\b/, "display representation", /var\s+displayRepresentation:\s+DisplayRepresentation/, ["descriptor.title", "descriptor.subtitle", "descriptor.disambiguationLabel"], failures)

  require_tokens(
    metadata,
    [
      "SpoonjoySpoonEntity",
      "SpoonjoySpoonEntityQuery"
    ],
    failures
  )

  require_tokens(
    verifier,
    [
      "spoon cook-log App Entity",
      "SpoonEntityCatalog",
      "SpoonjoySpoonEntity"
    ],
    failures
  )

  if project.file?
    require_project_source_membership(
      project_path,
      "Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift",
      ["Spoonjoy iOS", "Spoonjoy macOS"],
      failures
    )
  end

  forbid_tokens(
    app_entities,
    [
      "ShoppingListState.decodeFromBundle()",
      "comment App Entity",
      "feed App Entity",
      "reaction App Entity",
      "TODO Spoon AppEntity",
      "eventually add spoon entities"
    ],
    failures
  )
end

if domain == "chef-profile"
  core_entities = ROOT.join("Sources/SpoonjoyCore/Native/ChefProfileEntityCatalog.swift")
  app_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift")
  metadata = ROOT.join("Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift")
  verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift")
  intent_action = ROOT.join("Sources/SpoonjoyCore/Native/NativeIntentAction.swift")
  project_path = ROOT.join("Spoonjoy.xcodeproj")
  project = project_path.join("project.pbxproj")

  [core_entities, app_entities, metadata, verifier, intent_action, project].each do |path|
    require_file(path, failures)
  end

  require_tokens(
    core_entities,
    [
      "ChefProfileEntityCatalog",
      "ChefProfileEntityCatalogError",
      "ChefProfileEntityKind",
      "ChefProfileEntityTransferValue",
      "ChefProfileEntityScope",
      "ChefProfileEntityDescriptor",
      "isPlaceholder",
      "chefProfileEntity(id:",
      "chefProfileEntities(for identifiers:",
      "chefProfileEntities(matching string:",
      "suggestedChefProfileEntities",
      "public static func loading(",
      "NativeSyncSnapshot",
      "NativeSyncCachedRecord",
      "NativeSyncEntryKind.profile",
      "NativeSyncEntryKind.recipe",
      "NativeDurableCacheSnapshot",
      "NativeDurableCacheStore",
      "NativeCachePayload.profile",
      "accountID",
      "environment",
      "ProfileSurfaceResult",
      "ProfileSurfaceData",
      "ProfileSummary",
      "ProfileGraphPage",
      "ProfileGraphRow",
      "ProfileGraphDirection.fellowChefs",
      "ProfileGraphDirection.kitchenVisitors",
      "interactionSummary",
      "fellowChefs",
      "kitchenVisitors",
      "public static func resolvedChefProfileID(",
      "AppRoute.profile",
      "DeepLinkURLBuilder.url(for:",
      "canonicalURL",
      "transferValue",
      "debugFields"
    ],
    failures
  )

  require_tokens(
    app_entities,
    [
      "#if canImport(AppIntents)",
      "import AppIntents",
      "import CoreTransferable",
      "import SpoonjoyCore",
      "@available(iOS 27.0, macOS 27.0, *)",
      "struct SpoonjoyChefProfileEntity: AppEntity",
      "struct SpoonjoyChefProfileEntityQuery: EntityQuery, EntityStringQuery",
      "typealias DefaultQuery = SpoonjoyChefProfileEntityQuery",
      "static let typeDisplayRepresentation",
      "var displayRepresentation",
      "DisplayRepresentation",
      "TypeDisplayRepresentation",
      "entities(for identifiers: [String]) async throws",
      "entities(matching string: String) async throws",
      "suggestedEntities() async throws",
      "ChefProfileEntityCatalog",
      "ChefProfileEntityDescriptor",
      "Transferable",
      "TransferRepresentation",
      "ChefProfileEntityTransferValue",
      "resolvedChefProfileID() throws",
      "NativeIntentActionError.unresolvedChefProfileEntity",
      "descriptor.isPlaceholder",
      "DeepLinkURLBuilder.url(for:",
      "NativeAppStateLocation.defaultFileURL()",
      "FileBackedNativeSyncStore",
      "NativeDurableCacheStore",
      "trustedIntentScope",
      "KeychainTokenVault()",
      "scope.accountID",
      "scope.environment"
    ],
    failures
  )

  require_patterns(
    app_entities,
    {
      "SpoonjoyChefProfileEntity AppEntity declaration" => /\bstruct\s+SpoonjoyChefProfileEntity\s*:\s*AppEntity\b/,
      "chef profile query declaration" => /\bstruct\s+SpoonjoyChefProfileEntityQuery\s*:\s*EntityQuery\s*,\s*EntityStringQuery\b/
    },
    failures
  )
  require_nested_body_tokens(app_entities, "SpoonjoyChefProfileEntityQuery", /\bstruct\s+SpoonjoyChefProfileEntityQuery\b/, "identifier query", /func\s+entities\(for identifiers: \[String\]\)/, ["ChefProfileEntityCatalog.loading(", "chefProfileEntities(for: identifiers)", "SpoonjoyChefProfileEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyChefProfileEntityQuery", /\bstruct\s+SpoonjoyChefProfileEntityQuery\b/, "string query", /func\s+entities\(matching string: String\)/, ["ChefProfileEntityCatalog.loading(", "chefProfileEntities(matching: string)", "SpoonjoyChefProfileEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyChefProfileEntityQuery", /\bstruct\s+SpoonjoyChefProfileEntityQuery\b/, "suggestions query", /func\s+suggestedEntities\(\)/, ["ChefProfileEntityCatalog.loading(", "suggestedChefProfileEntities", "SpoonjoyChefProfileEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyChefProfileEntity", /\bstruct\s+SpoonjoyChefProfileEntity\b/, "display representation", /var\s+displayRepresentation:\s+DisplayRepresentation/, ["descriptor.title", "descriptor.subtitle", "descriptor.disambiguationLabel"], failures)

  require_tokens(
    metadata,
    [
      "SpoonjoyChefProfileEntity",
      "SpoonjoyChefProfileEntityQuery"
    ],
    failures
  )

  require_tokens(
    verifier,
    [
      "chef profile App Entity",
      "ChefProfileEntityCatalog",
      "SpoonjoyChefProfileEntity"
    ],
    failures
  )

  require_tokens(
    intent_action,
    [
      "unresolvedChefProfileEntity",
      "Choose a Spoonjoy chef profile before running this Siri action."
    ],
    failures
  )

  if project.file?
    require_project_source_membership(
      project_path,
      "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift",
      ["Spoonjoy iOS", "Spoonjoy macOS"],
      failures
    )
  end

  forbid_tokens(
    app_entities,
    [
      "@Parameter(title: \"Chef ID\")",
      "@Parameter(title: \"Profile ID\")",
      "var chefID: String",
      "var profileID: String",
      "String-only chef profile App Intent",
      "SpoonjoyFollowEntity",
      "FollowEntity",
      "comment App Entity",
      "feed App Entity",
      "message App Entity",
      "mail App Entity",
      "privateTransferValue",
      "TODO ChefProfile AppEntity",
      "eventually add chef profile entities"
    ],
    failures
  )
end

if domain == "capture-draft"
  core_entities = ROOT.join("Sources/SpoonjoyCore/Native/CaptureDraftEntityCatalog.swift")
  app_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift")
  metadata = ROOT.join("Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift")
  verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift")
  intent_action = ROOT.join("Sources/SpoonjoyCore/Native/NativeIntentAction.swift")
  live_store = ROOT.join("Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift")
  navigation = ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift")
  spotlight = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift")
  project_path = ROOT.join("Spoonjoy.xcodeproj")
  project = project_path.join("project.pbxproj")

  [core_entities, app_entities, metadata, verifier, intent_action, live_store, navigation, spotlight, project].each do |path|
    require_file(path, failures)
  end

  require_tokens(
    core_entities,
    [
      "CaptureDraftEntityCatalog",
      "CaptureDraftEntityCatalogError",
      "CaptureDraftEntityKind",
      "CaptureDraftEntityTransferValue",
      "CaptureDraftEntityScope",
      "CaptureDraftEntityDescriptor",
      "CaptureDraftEntityIndexPurgePlan",
      "isPlaceholder",
      "captureDraftEntity(id:",
      "captureDraftEntities(for identifiers:",
      "captureDraftEntities(matching string:",
      "suggestedCaptureDraftEntities",
      "public static func loading(",
      "NativeAppSnapshot",
      "NativeAppStateStore",
      "NativeDurableCacheSnapshot",
      "NativeDurableCacheStore",
      "NativeCachePayload.captureDraft",
      "NativeCacheDomain.captureDraft",
      "accountID",
      "environment",
      "public static func captureDraftEntityIdentifier(",
      "public static func resolvedCaptureDraftID(",
      "public static func purgeEntityIdentifiers(",
      "purgeDomainIdentifiers(",
      "public static func accountScopePurge(",
      "public static func cacheDeletePurge(",
      "public static func draftDiscardPurge(",
      "CaptureDraft",
      "pendingCaptureImport",
      "captureImportProviderBlocker",
      "importReadiness",
      "AppRoute.capture",
      "NativeSharePayload.privateCaptureDraft",
      "privateTransferValue",
      "debugFields"
    ],
    failures
  )

  require_tokens(
    app_entities,
    [
      "#if canImport(AppIntents)",
      "import AppIntents",
      "import CoreTransferable",
      "import SpoonjoyCore",
      "@available(iOS 27.0, macOS 27.0, *)",
      "struct SpoonjoyCaptureDraftEntity: AppEntity",
      "struct SpoonjoyCaptureDraftEntityQuery: EntityQuery, EntityStringQuery",
      "typealias DefaultQuery = SpoonjoyCaptureDraftEntityQuery",
      "static let typeDisplayRepresentation",
      "var displayRepresentation",
      "DisplayRepresentation",
      "TypeDisplayRepresentation",
      "entities(for identifiers: [String]) async throws",
      "entities(matching string: String) async throws",
      "suggestedEntities() async throws",
      "CaptureDraftEntityCatalog",
      "CaptureDraftEntityDescriptor",
      "Transferable",
      "TransferRepresentation",
      "CaptureDraftEntityTransferValue",
      "resolvedCaptureDraftID() throws",
      "NativeIntentActionError.unresolvedCaptureDraftEntity",
      "descriptor.isPlaceholder",
      "NativeAppStateLocation.defaultFileURL()",
      "NativeAppStateStore",
      "NativeDurableCacheStore",
      "trustedIntentScope",
      "KeychainTokenVault()",
      "scope.accountID",
      "scope.environment"
    ],
    failures
  )

  require_patterns(
    app_entities,
    {
      "SpoonjoyCaptureDraftEntity AppEntity declaration" => /\bstruct\s+SpoonjoyCaptureDraftEntity\s*:\s*AppEntity\b/,
      "capture draft query declaration" => /\bstruct\s+SpoonjoyCaptureDraftEntityQuery\s*:\s*EntityQuery\s*,\s*EntityStringQuery\b/
    },
    failures
  )
  require_nested_body_tokens(app_entities, "SpoonjoyCaptureDraftEntityQuery", /\bstruct\s+SpoonjoyCaptureDraftEntityQuery\b/, "identifier query", /func\s+entities\(for identifiers: \[String\]\)/, ["CaptureDraftEntityCatalog.loading(", "captureDraftEntities(for: identifiers)", "SpoonjoyCaptureDraftEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyCaptureDraftEntityQuery", /\bstruct\s+SpoonjoyCaptureDraftEntityQuery\b/, "string query", /func\s+entities\(matching string: String\)/, ["CaptureDraftEntityCatalog.loading(", "captureDraftEntities(matching: string)", "SpoonjoyCaptureDraftEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyCaptureDraftEntityQuery", /\bstruct\s+SpoonjoyCaptureDraftEntityQuery\b/, "suggestions query", /func\s+suggestedEntities\(\)/, ["CaptureDraftEntityCatalog.loading(", "suggestedCaptureDraftEntities", "SpoonjoyCaptureDraftEntity"], failures)
  require_nested_body_tokens(app_entities, "SpoonjoyCaptureDraftEntity", /\bstruct\s+SpoonjoyCaptureDraftEntity\b/, "display representation", /var\s+displayRepresentation:\s+DisplayRepresentation/, ["descriptor.title", "descriptor.subtitle", "descriptor.disambiguationLabel"], failures)

  require_tokens(
    metadata,
    [
      "SpoonjoyCaptureDraftEntity",
      "SpoonjoyCaptureDraftEntityQuery"
    ],
    failures
  )

  require_tokens(
    verifier,
    [
      "capture draft App Entity",
      "CaptureDraftEntityCatalog",
      "SpoonjoyCaptureDraftEntity"
    ],
    failures
  )

  require_tokens(
    intent_action,
    [
      "unresolvedCaptureDraftEntity",
      "Choose a Spoonjoy capture draft before running this Siri action."
    ],
    failures
  )

  require_body_tokens(live_store, "performSettingsSessionOperation", /func\s+performSettingsSessionOperation\(_ operation: SettingsSessionOperation\)/, ["CaptureDraftEntityIndexPurgePlan.accountScopePurge", "CaptureDraftEntityCatalog.purgeEntityIdentifiers(", "CaptureDraftEntityCatalog.purgeDomainIdentifiers(", "purgeCaptureDraftEntityIdentifiers"], failures)
  require_body_tokens(live_store, "restoreFromCache account or environment switch", /func\s+restoreFromCache\(\s*authSessionState: NativeAuthSessionState,\s*optimisticMutations: \[NativeQueuedMutation\] = \[\]\s*\)/, ["preFilterCacheRecord", "preFilterAppStateRecord", "dependencies.cacheStore.loadOrRecover(fallback:", "appStateStore.loadOrCreate(fallback:", "previousCacheSnapshot", "previousAppSnapshot", "preFilterCacheRecord.value", "preFilterAppStateRecord.value", "previousCacheSnapshot.accountID", "previousCacheSnapshot.environment", "previousAppSnapshot.accountID", "previousAppSnapshot.environment", "CaptureDraftEntityIndexPurgePlan.accountScopePurge", "CaptureDraftEntityCatalog.purgeEntityIdentifiers(", "CaptureDraftEntityCatalog.purgeDomainIdentifiers(", "purgeCaptureDraftEntityIdentifiers", "accountID: previousCacheSnapshot.accountID", "environment: previousCacheSnapshot.environment", "accountID: previousAppSnapshot.accountID", "environment: previousAppSnapshot.environment", "!= accountID(for: authSessionState)", "!= cacheEnvironment"], failures)
  require_body_tokens(live_store, "discardCaptureDraft", /func\s+discardCaptureDraft\(id draftID: String\)/, ["CaptureDraftEntityIndexPurgePlan.draftDiscardPurge", "CaptureDraftEntityCatalog.purgeEntityIdentifiers(", "purgeCaptureDraftEntityIdentifiers"], failures)
  require_body_tokens(live_store, "recordCaptureDraft", /func\s+recordCaptureDraft\(_ draft: CaptureDraft\)/, ["CaptureDraftEntityIndexPurgePlan.cacheDeletePurge", "CaptureDraftEntityCatalog.purgeEntityIdentifiers(", "purgeCaptureDraftEntityIdentifiers"], failures)

  require_tokens(
    navigation,
    [
      "NativeCaptureDraftEntityIndexPurgeRequest",
      "purgeCaptureDraftEntityIndexesHandler"
    ],
    failures
  )

  require_tokens(
    spotlight,
    [
      "accountID: String? = nil",
      "environment: NativeCacheEnvironment? = nil",
      "deleteSearchableItems(withIdentifiers:",
      "deleteSearchableItems(withDomainIdentifiers:"
    ],
    failures
  )

  if project.file?
    require_project_source_membership(
      project_path,
      "Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift",
      ["Spoonjoy iOS", "Spoonjoy macOS"],
      failures
    )
  end

  forbid_tokens(
    app_entities,
    [
      "rawText",
      "imageAssetIdentifier",
      "captureImportProviderBlocker",
      "comment App Entity",
      "feed App Entity",
      "message App Entity",
      "mail App Entity",
      "TODO CaptureDraft AppEntity",
      "eventually add capture draft entities"
    ],
    failures
  )
end

if domain == "spotlight-shortcuts"
  spotlight_plan = ROOT.join("Sources/SpoonjoyCore/Native/SpotlightIndexPlan.swift")
  spotlight_indexer = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift")
  app_intents = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift")
  recipe_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift")
  shopping_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift")
  spoon_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift")
  capture_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift")
  chef_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift")
  platform_navigation = ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift")
  root_view = ROOT.join("Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift")
  live_store = ROOT.join("Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift")
  sync_engine = ROOT.join("Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift")
  metadata = ROOT.join("Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift")
  verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift")
  project_path = ROOT.join("Spoonjoy.xcodeproj")
  project = project_path.join("project.pbxproj")

  [
    spotlight_plan,
    spotlight_indexer,
    app_intents,
    recipe_entities,
    shopping_entities,
    spoon_entities,
    capture_entities,
    chef_entities,
    platform_navigation,
    root_view,
    live_store,
    sync_engine,
    metadata,
    verifier,
    project
  ].each do |path|
    require_file(path, failures)
  end

  require_tokens(
    spotlight_plan,
    [
      "case recipe",
      "case cookbook",
      "case spoon",
      "case shoppingListItem = \"shopping-list-item\"",
      "case captureDraft = \"capture-draft\"",
      "case chefProfile = \"chef-profile\"",
      "public static let searchableTypes",
      "public static func documents(",
      "spoons:",
      "captureDrafts:",
      "chefProfiles:",
      "public static func document(recipe:",
      "public static func document(cookbook:",
      "public static func document(shoppingListItem",
      "public static func document(spoon:",
      "public static func document(captureDraft:",
      "public static func document(chefProfile:",
      "public static func shoppingListItemUniqueIdentifier",
      "public static func shoppingListItemDomainIdentifier",
      "public static func spoonUniqueIdentifier",
      "public static func spoonDomainIdentifier",
      "public static func captureDraftUniqueIdentifier",
      "public static func captureDraftDomainIdentifier",
      "public static func chefProfileUniqueIdentifier",
      "public static func chefProfileDomainIdentifier",
      "userVisibleSummary",
      "contentDescription",
      "AppRoute.profile"
    ],
    failures
  )

  require_tokens(
    spotlight_indexer,
    [
      "#if canImport(CoreSpotlight)",
      "import CoreSpotlight",
      "import AppIntents",
      "SpotlightIndexPlan.searchableTypes",
      ".spoon",
      ".captureDraft",
      ".chefProfile",
      "CSSearchableIndex.isIndexingAvailable()",
      "indexAppEntities",
      "deleteAppEntities",
      "deleteSearchableItems(withIdentifiers:",
      "deleteSearchableItems(withDomainIdentifiers:"
    ],
    failures
  )

  require_tokens(
    app_intents,
    [
      "#if canImport(AppIntents)",
      "import AppIntents",
      "struct SpoonjoyAppShortcuts: AppShortcutsProvider",
      "static var appShortcuts",
      "AppShortcut(",
      "\\(.applicationName)",
      "OpenRecipeIntent()",
      "StartCookModeIntent()",
      "AddShoppingListItemIntent()",
      "SetShoppingListItemCheckedIntent()",
      "AddRecipeIngredientsToShoppingListIntent()",
      "ClearCompletedShoppingItemsIntent()",
      "ClearShoppingListIntent()",
      "CaptureRecipeIntent()",
      "struct SpoonjoyInteractionDonor",
      "IntentDonationManager.shared",
      ".donate(intent:",
      "deleteDonations(matching:",
      "IntentDonationMatchingPredicate"
    ],
    failures
  )

  [
    [
      recipe_entities,
      [
        "struct SpoonjoyRecipeEntity",
        "struct SpoonjoyCookbookEntity",
        "AppEntity",
        "IndexedEntity",
        "Transferable",
        "attributeSet",
        "defaultAttributeSet",
        "TransferRepresentation",
        "userVisibleSummary"
      ]
    ],
    [
      shopping_entities,
      [
        "struct SpoonjoyShoppingListEntity",
        "struct SpoonjoyShoppingItemEntity",
        "AppEntity",
        "IndexedEntity",
        "Transferable",
        "attributeSet",
        "defaultAttributeSet",
        "TransferRepresentation",
        "userVisibleSummary"
      ]
    ],
    [
      spoon_entities,
      [
        "struct SpoonjoySpoonEntity",
        "AppEntity",
        "IndexedEntity",
        "Transferable",
        "attributeSet",
        "defaultAttributeSet",
        "TransferRepresentation",
        "userVisibleSummary"
      ]
    ],
    [
      capture_entities,
      [
        "struct SpoonjoyCaptureDraftEntity",
        "AppEntity",
        "IndexedEntity",
        "Transferable",
        "attributeSet",
        "defaultAttributeSet",
        "TransferRepresentation",
        "userVisibleSummary"
      ]
    ],
    [
      chef_entities,
      [
        "struct SpoonjoyChefProfileEntity",
        "AppEntity",
        "IndexedEntity",
        "Transferable",
        "attributeSet",
        "defaultAttributeSet",
        "TransferRepresentation",
        "userVisibleSummary"
      ]
    ]
  ].each do |path, tokens|
    require_tokens(path, tokens, failures)
  end

  require_patterns(
    recipe_entities,
    {
      "recipe IndexedEntity conformance" => /\b(?:struct|extension)\s+SpoonjoyRecipeEntity\s*:\s*[^{\n]*\bIndexedEntity\b/,
      "cookbook IndexedEntity conformance" => /\b(?:struct|extension)\s+SpoonjoyCookbookEntity\s*:\s*[^{\n]*\bIndexedEntity\b/
    },
    failures
  )
  require_patterns(
    shopping_entities,
    {
      "shopping list IndexedEntity conformance" => /\b(?:struct|extension)\s+SpoonjoyShoppingListEntity\s*:\s*[^{\n]*\bIndexedEntity\b/,
      "shopping item IndexedEntity conformance" => /\b(?:struct|extension)\s+SpoonjoyShoppingItemEntity\s*:\s*[^{\n]*\bIndexedEntity\b/
    },
    failures
  )
  require_patterns(spoon_entities, { "spoon IndexedEntity conformance" => /\b(?:struct|extension)\s+SpoonjoySpoonEntity\s*:\s*[^{\n]*\bIndexedEntity\b/ }, failures)
  require_patterns(capture_entities, { "capture draft IndexedEntity conformance" => /\b(?:struct|extension)\s+SpoonjoyCaptureDraftEntity\s*:\s*[^{\n]*\bIndexedEntity\b/ }, failures)
  require_patterns(chef_entities, { "chef profile IndexedEntity conformance" => /\b(?:struct|extension)\s+SpoonjoyChefProfileEntity\s*:\s*[^{\n]*\bIndexedEntity\b/ }, failures)

  require_body_tokens(
    platform_navigation,
    "spotlightIndexPayload",
    /private\s+var\s+spotlightIndexPayload:\s+SpotlightIndexPayload/,
    [
      "contentState.recipes",
      "contentState.cookbooks",
      "contentState.shoppingList",
      "contentState.cachedProfiles",
      "contentState.captureDraft",
      "recentSpoons",
      "SpotlightIndexPlan.documents("
    ],
    failures
  )

  require_body_tokens(
    platform_navigation,
    "routeEntityIdentifier",
    /private\s+var\s+routeEntityIdentifier:\s+EntityIdentifier\?/,
    [
      "chefProfileEntityIdentifier(for:",
      "EntityIdentifier(for: SpoonjoyChefProfileEntity.self, identifier: profileID)"
    ],
    failures
  )

  require_body_tokens(
    platform_navigation,
    "chefProfileEntityIdentifier",
    /private\s+func\s+chefProfileEntityIdentifier\(for routeIdentifier: String\)\s*->\s*String\?/,
    [
      "cachedProfile.profile.id == routeIdentifier || cachedProfile.profile.username == routeIdentifier",
      "?.profile.id"
    ],
    failures
  )

  require_nested_body_tokens(
    root_view,
    "platformNavigation",
    /private\s+func\s+platformNavigation\(contentState:\s+NativeShellContentState\)\s*->\s*some\s+View/,
    "purgeShoppingEntityIndexes",
    /purgeShoppingEntityIndexes:/,
    [
      "accountID: request.accountID",
      "environment: request.environment"
    ],
    failures
  )
  require_nested_body_tokens(
    root_view,
    "platformNavigation",
    /private\s+func\s+platformNavigation\(contentState:\s+NativeShellContentState\)\s*->\s*some\s+View/,
    "purgeSpoonEntityIndexes",
    /purgeSpoonEntityIndexes:/,
    [
      "accountID: request.accountID",
      "environment: request.environment"
    ],
    failures
  )
  require_nested_body_tokens(
    root_view,
    "platformNavigation",
    /private\s+func\s+platformNavigation\(contentState:\s+NativeShellContentState\)\s*->\s*some\s+View/,
    "purgeCaptureDraftEntityIndexes",
    /purgeCaptureDraftEntityIndexes:/,
    [
      "accountID: request.accountID",
      "environment: request.environment"
    ],
    failures
  )
  require_nested_body_tokens(
    root_view,
    "platformNavigation",
    /private\s+func\s+platformNavigation\(contentState:\s+NativeShellContentState\)\s*->\s*some\s+View/,
    "purgeChefProfileEntityIndexes",
    /purgeChefProfileEntityIndexes:/,
    [
      "accountID: request.accountID",
      "environment: request.environment"
    ],
    failures
  )

  shared_source = Dir.glob(ROOT.join("Apps/Spoonjoy/Shared/**/*.swift").to_s).map do |path|
    uncommented_swift(Pathname.new(path).read)
  end.join("\n")
  [
    "appEntityIdentifier",
    "EntityIdentifier"
  ].each do |token|
    failures << "Apps/Spoonjoy/Shared missing on-screen AppEntity annotations token #{token}" unless shared_source.include?(token)
  end

  require_tokens(
    live_store,
    [
      "NativeShoppingEntityIndexPurgeOperation",
      "NativeSpoonEntityIndexPurgeOperation",
      "NativeCaptureDraftEntityIndexPurgeOperation",
      "NativeChefProfileEntityIndexPurgeOperation",
      "ShoppingEntityIndexPurgePlan.accountScopePurge",
      "SpoonEntityIndexPurgePlan.accountScopePurge",
      "CaptureDraftEntityIndexPurgePlan.accountScopePurge",
      "CaptureDraftEntityIndexPurgePlan.cacheDeletePurge",
      "ChefProfileEntityIndexPurgePlan.accountScopePurge",
      "purgeShoppingEntityIdentifiers",
      "purgeSpoonEntityIdentifiers",
      "purgeCaptureDraftEntityIdentifiers",
      "purgeChefProfileEntityIdentifiers",
      "report.captureDraftEntityPurgeRequests"
    ],
    failures
  )

  require_tokens(
    sync_engine,
    [
      "ShoppingEntityIndexPurgePlan.tombstonePurge",
      "SpoonEntityIndexPurgePlan.tombstonePurge",
      "ChefProfileEntityIndexPurgePlan.tombstonePurge",
      "ChefProfileEntityIndexPurgePlan.cacheDeletePurge",
      "shoppingEntityPurgeIdentifiers",
      "spoonEntityPurgeIdentifiers",
      "chefProfileEntityPurgeIdentifiers",
      "removedCacheKeys",
      "tombstones"
    ],
    failures
  )

  require_tokens(
    metadata,
    [
      "\"recipe\"",
      "\"cookbook\"",
      "\"shopping-list-item\"",
      "\"spoon\"",
      "\"capture-draft\"",
      "\"chef-profile\"",
      "SpoonjoyAppShortcuts",
      "SpoonjoyInteractionDonor"
    ],
    failures
  )

  require_tokens(
    verifier,
    [
      "Spotlight semantic App Entities",
      "AppShortcutsProvider",
      "IntentDonationManager",
      "on-screen AppEntity annotations",
      "AppEntityAnnotatable",
      "appEntityIdentifier",
      "IndexedEntity",
      "indexAppEntities"
    ],
    failures
  )

  if project.file?
    [
      "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
      "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift",
      "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift",
      "Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift",
      "Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift",
      "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift",
      "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift"
    ].each do |relative_source|
      require_project_source_membership(project_path, relative_source, ["Spoonjoy iOS", "Spoonjoy macOS"], failures)
    end
  end

  forbid_tokens(
    spotlight_plan,
    [
      "privateTransferValue",
      "debugFields",
      "captureImportProviderBlocker",
      "imageAssetIdentifier",
      "rawText",
      "providerSecret"
    ],
    failures
  )
  forbid_tokens(
    spotlight_indexer,
    [
      "deleteAllSearchableItems",
      "replaceAll(documents: [SpotlightIndexDocument])"
    ],
    failures
  )
  forbid_tokens(
    app_intents,
    [
      "@Parameter(title: \"Recipe ID\")",
      "@Parameter(title: \"Cookbook ID\")",
      "@Parameter(title: \"Shopping Item ID\")",
      "@Parameter(title: \"Spoon ID\")",
      "@Parameter(title: \"Capture Draft ID\")",
      "@Parameter(title: \"Chef ID\")",
      "String-only",
      "eventually"
    ],
    failures
  )
end

if domain == "shopping-intents"
  app_intents = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift")
  shopping_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift")
  recipe_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift")
  intent_action = ROOT.join("Sources/SpoonjoyCore/Native/NativeIntentAction.swift")
  metadata = ROOT.join("Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift")
  verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift")
  project_path = ROOT.join("Spoonjoy.xcodeproj")
  project = project_path.join("project.pbxproj")

  [
    app_intents,
    shopping_entities,
    recipe_entities,
    intent_action,
    metadata,
    verifier,
    project
  ].each do |path|
    require_file(path, failures)
  end

  require_tokens(
    app_intents,
    [
      "#if canImport(AppIntents)",
      "import AppIntents",
      "struct AddShoppingListItemIntent: AppIntent",
      "struct SetShoppingListItemCheckedIntent: AppIntent",
      "struct RemoveShoppingListItemIntent: AppIntent",
      "struct ClearCompletedShoppingItemsIntent: AppIntent",
      "struct ClearShoppingListIntent: AppIntent",
      "struct AddRecipeIngredientsToShoppingListIntent: AppIntent",
      "var item: SpoonjoyShoppingItemEntity",
      "var recipe: SpoonjoyRecipeEntity",
      "SpoonjoyIntentStateWriter",
      "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
      "SpoonjoyIntentClock.timestamp()",
      "SpoonjoyInteractionDonor",
      "throw NativeIntentActionError.authRequired"
    ],
    failures
  )

  {
    "AddShoppingListItemIntent" => {
      required: [
        "@Parameter(title: \"Name\")",
        "@Parameter(title: \"Quantity\")",
        "@Parameter(title: \"Unit\")",
        "NativeIntentActionResolver().addShoppingListItem(",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
        "OpenURLIntent(action.url)"
      ],
      forbidden: ["var itemID: String", "@Parameter(title: \"Item ID\")"]
    },
    "SetShoppingListItemCheckedIntent" => {
      required: [
        "@Parameter(title: \"Shopping Item\", requestValueDialog:",
        "var item: SpoonjoyShoppingItemEntity",
        "@Parameter(title: \"Checked\")",
        "try item.resolvedShoppingItemID()",
        "NativeIntentActionResolver().setShoppingListItemChecked(",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: ["var itemID: String", "@Parameter(title: \"Item ID\")"]
    },
    "RemoveShoppingListItemIntent" => {
      required: [
        "@Parameter(title: \"Shopping Item\", requestValueDialog:",
        "var item: SpoonjoyShoppingItemEntity",
        "try item.resolvedShoppingItemID()",
        "try await requestConfirmation(",
        "NativeIntentActionResolver().removeShoppingListItem(",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: ["var itemID: String", "@Parameter(title: \"Item ID\")"]
    },
    "ClearCompletedShoppingItemsIntent" => {
      required: [
        "try await requestConfirmation(",
        "NativeIntentActionResolver().clearCompletedShoppingItems(",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: []
    },
    "ClearShoppingListIntent" => {
      required: [
        "try await requestConfirmation(",
        "NativeIntentActionResolver().clearShoppingList(",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: []
    },
    "AddRecipeIngredientsToShoppingListIntent" => {
      required: [
        "@Parameter(title: \"Recipe\", requestValueDialog:",
        "var recipe: SpoonjoyRecipeEntity",
        "@Parameter(title: \"Scale Factor\")",
        "try recipe.resolvedRecipeID()",
        "NativeIntentActionResolver().addRecipeIngredientsToShoppingList(",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: ["var recipeID: String", "@Parameter(title: \"Recipe ID\")"]
    }
  }.each do |intent_name, contract|
    pattern = /\bstruct\s+#{Regexp.escape(intent_name)}\s*:\s*AppIntent\b/
    require_body_tokens(app_intents, intent_name, pattern, contract.fetch(:required), failures)
    forbid_body_tokens(app_intents, intent_name, pattern, contract.fetch(:forbidden), failures)
  end

  require_tokens(
    intent_action,
    [
      "public func addShoppingListItem(",
      "public func setShoppingListItemChecked(",
      "public func removeShoppingListItem(",
      "public func clearCompletedShoppingItems(",
      "public func clearShoppingList(",
      "public func addRecipeIngredientsToShoppingList(",
      ".shoppingCheckItem",
      ".shoppingDeleteItem",
      ".shoppingClearCompleted",
      ".shoppingClearAll",
      ".shoppingAddFromRecipe",
      "DeepLinkURLBuilder.url(for: .shoppingList)"
    ],
    failures
  )

  require_tokens(
    metadata,
    [
      "AddShoppingListItemIntent",
      "SetShoppingListItemCheckedIntent",
      "RemoveShoppingListItemIntent",
      "ClearCompletedShoppingItemsIntent",
      "ClearShoppingListIntent",
      "AddRecipeIngredientsToShoppingListIntent"
    ],
    failures
  )

  require_tokens(
    verifier,
    [
      "Shopping Siri intents",
      "AddShoppingListItemIntent",
      "SetShoppingListItemCheckedIntent",
      "RemoveShoppingListItemIntent",
      "ClearCompletedShoppingItemsIntent",
      "ClearShoppingListIntent",
      "AddRecipeIngredientsToShoppingListIntent"
    ],
    failures
  )

  require_tokens(
    shopping_entities,
    [
      "struct SpoonjoyShoppingItemEntity: AppEntity",
      "struct SpoonjoyShoppingItemEntityQuery: EntityQuery, EntityStringQuery",
      "resolvedShoppingItemID() throws",
      "NativeIntentActionError.unresolvedShoppingItemEntity"
    ],
    failures
  )

  require_tokens(
    recipe_entities,
    [
      "struct SpoonjoyRecipeEntity: AppEntity",
      "resolvedRecipeID() throws",
      "NativeIntentActionError.unresolvedRecipeEntity"
    ],
    failures
  )

  if project.file?
    require_project_source_membership(
      project_path,
      "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
      ["Spoonjoy iOS", "Spoonjoy macOS"],
      failures
    )
  end

  [
    app_intents,
    intent_action
  ].each do |path|
    forbid_tokens(
      path,
      [
        "@Parameter(title: \"Shopping Item ID\")",
        "@Parameter(title: \"Recipe ID\")",
        "var itemID: String",
        "var recipeID: String",
        "String-only shopping App Intent",
        "TODO ShoppingIntent",
        "eventually add shopping intents"
      ],
      failures
    )
  end
end

if domain == "recipe-action"
  app_intents = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift")
  recipe_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift")
  entity_catalog = ROOT.join("Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift")
  intent_action = ROOT.join("Sources/SpoonjoyCore/Native/NativeIntentAction.swift")
  metadata = ROOT.join("Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift")
  verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift")
  project_path = ROOT.join("Spoonjoy.xcodeproj")
  project = project_path.join("project.pbxproj")

  [
    app_intents,
    recipe_entities,
    entity_catalog,
    intent_action,
    metadata,
    verifier,
    project
  ].each do |path|
    require_file(path, failures)
  end

  require_tokens(
    app_intents,
    [
      "#if canImport(AppIntents)",
      "import AppIntents",
      "struct ForkRecipeIntent: AppIntent",
      "struct SaveRecipeToCookbookIntent: AppIntent",
      "struct RemoveRecipeFromCookbookIntent: AppIntent",
      "struct DeleteRecipeIntent: AppIntent",
      "struct AddRecipeIngredientsToShoppingListIntent: AppIntent",
      "var recipe: SpoonjoyRecipeEntity",
      "var cookbook: SpoonjoyCookbookEntity",
      "SpoonjoyIntentStateWriter",
      "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
      "SpoonjoyIntentClock.timestamp()",
      "SpoonjoyInteractionDonor",
      "throw NativeIntentActionError.authRequired",
      "String(describing: ForkRecipeIntent())",
      "String(describing: SaveRecipeToCookbookIntent())",
      "String(describing: RemoveRecipeFromCookbookIntent())",
      "String(describing: DeleteRecipeIntent())"
    ],
    failures
  )

  {
    "ForkRecipeIntent" => {
      required: [
        "@Parameter(title: \"Recipe\", requestValueDialog:",
        "var recipe: SpoonjoyRecipeEntity",
        "@Parameter(title: \"Title\")",
        "NativeIntentActionResolver().forkRecipe(recipe: recipe.descriptor",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
        "OpenURLIntent(action.url)"
      ],
      forbidden: ["var recipeID: String", "@Parameter(title: \"Recipe ID\")"]
    },
    "SaveRecipeToCookbookIntent" => {
      required: [
        "@Parameter(title: \"Recipe\", requestValueDialog:",
        "var recipe: SpoonjoyRecipeEntity",
        "@Parameter(title: \"Cookbook\", requestValueDialog:",
        "var cookbook: SpoonjoyCookbookEntity",
        "NativeIntentActionResolver().saveRecipeToCookbook(recipe: recipe.descriptor, cookbook: cookbook.descriptor",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: ["var recipeID: String", "var cookbookID: String", "@Parameter(title: \"Cookbook ID\")"]
    },
    "RemoveRecipeFromCookbookIntent" => {
      required: [
        "@Parameter(title: \"Recipe\", requestValueDialog:",
        "var recipe: SpoonjoyRecipeEntity",
        "@Parameter(title: \"Cookbook\", requestValueDialog:",
        "var cookbook: SpoonjoyCookbookEntity",
        "try await requestConfirmation(",
        "NativeIntentActionResolver().removeRecipeFromCookbook(recipe: recipe.descriptor, cookbook: cookbook.descriptor",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: ["var recipeID: String", "var cookbookID: String", "@Parameter(title: \"Recipe ID\")", "@Parameter(title: \"Cookbook ID\")"]
    },
    "AddRecipeIngredientsToShoppingListIntent" => {
      required: [
        "@Parameter(title: \"Recipe\", requestValueDialog:",
        "var recipe: SpoonjoyRecipeEntity",
        "@Parameter(title: \"Scale Factor\")",
        "try recipe.resolvedRecipeID()",
        "NativeIntentActionResolver().addRecipeIngredientsToShoppingList(",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: ["var recipeID: String", "@Parameter(title: \"Recipe ID\")"]
    },
    "DeleteRecipeIntent" => {
      required: [
        "@Parameter(title: \"Recipe\", requestValueDialog:",
        "var recipe: SpoonjoyRecipeEntity",
        "try await requestConfirmation(",
        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
        "NativeIntentActionResolver().deleteRecipe(recipe: recipe.descriptor",
        "currentChefID: currentChefID",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: ["var recipeID: String", "@Parameter(title: \"Recipe ID\")"]
    }
  }.each do |intent_name, contract|
    pattern = /\bstruct\s+#{Regexp.escape(intent_name)}\s*:\s*AppIntent\b/
    require_body_tokens(app_intents, intent_name, pattern, contract.fetch(:required), failures)
    forbid_body_tokens(app_intents, intent_name, pattern, contract.fetch(:forbidden), failures)
  end

  require_tokens(
    recipe_entities,
    [
      "struct SpoonjoyRecipeEntity: AppEntity",
      "struct SpoonjoyCookbookEntity: AppEntity",
      "resolvedRecipeID() throws",
      "NativeIntentActionError.unresolvedRecipeEntity"
    ],
    failures
  )

  require_tokens(
    entity_catalog,
    [
      "public let chefID: String",
      "chefID: recipe.chef.id",
      "chefID: \"chef-placeholder\""
    ],
    failures
  )

  require_tokens(
    intent_action,
    [
      "public func forkRecipe(",
      "public func saveRecipeToCookbook(",
      "public func removeRecipeFromCookbook(",
      "public func deleteRecipe(",
      "currentChefID: String",
      "NativeIntentActionError.recipeOwnershipRequired",
      ".recipeFork",
      ".cookbookAddRecipe",
      ".cookbookRemoveRecipe",
      ".recipeDelete",
      ".shoppingAddFromRecipe",
      "DeepLinkURLBuilder.url(for:"
    ],
    failures
  )

  require_tokens(
    metadata,
    [
      "ForkRecipeIntent",
      "SaveRecipeToCookbookIntent",
      "RemoveRecipeFromCookbookIntent",
      "DeleteRecipeIntent",
      "AddRecipeIngredientsToShoppingListIntent"
    ],
    failures
  )

  require_tokens(
    verifier,
    [
      "Recipe action Siri intents",
      "ForkRecipeIntent",
      "SaveRecipeToCookbookIntent",
      "RemoveRecipeFromCookbookIntent",
      "DeleteRecipeIntent",
      "AddRecipeIngredientsToShoppingListIntent"
    ],
    failures
  )

  if project.file?
    require_project_source_membership(
      project_path,
      "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
      ["Spoonjoy iOS", "Spoonjoy macOS"],
      failures
    )
  end

  [
    app_intents,
    intent_action
  ].each do |path|
    forbid_tokens(
      path,
      [
        "@Parameter(title: \"Recipe ID\")",
        "@Parameter(title: \"Cookbook ID\")",
        "var recipeID: String",
        "var cookbookID: String",
        "String-only recipe action App Intent",
        "CommentIntent",
        "FeedIntent",
        "MessageIntent",
        "MailIntent",
        "social-feed",
        "/comments",
        "/feeds",
        "/messages",
        "mailto:",
        "MessageUI",
        "TODO RecipeActionIntent",
        "eventually add recipe action"
      ],
      failures
    )
  end
end

if domain == "spoon-intents"
  app_intents = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift")
  spoon_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift")
  recipe_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift")
  spoon_catalog = ROOT.join("Sources/SpoonjoyCore/Native/SpoonEntityCatalog.swift")
  recipe_catalog = ROOT.join("Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift")
  intent_action = ROOT.join("Sources/SpoonjoyCore/Native/NativeIntentAction.swift")
  metadata = ROOT.join("Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift")
  verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift")
  project_path = ROOT.join("Spoonjoy.xcodeproj")
  project = project_path.join("project.pbxproj")

  [
    app_intents,
    spoon_entities,
    recipe_entities,
    spoon_catalog,
    recipe_catalog,
    intent_action,
    metadata,
    verifier,
    project
  ].each do |path|
    require_file(path, failures)
  end

  require_tokens(
    app_intents,
    [
      "#if canImport(AppIntents)",
      "import AppIntents",
      "struct LogCookIntent: AppIntent",
      "struct EditCookLogIntent: AppIntent",
      "struct DeleteCookLogIntent: AppIntent",
      "struct CreateCoverFromSpoonIntent: AppIntent",
      "var recipe: SpoonjoyRecipeEntity",
      "var spoon: SpoonjoySpoonEntity",
      "SpoonjoyIntentStateWriter",
      "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
      "SpoonjoyIntentClock.timestamp()",
      "SpoonjoyInteractionDonor",
      "throw NativeIntentActionError.authRequired",
      "String(describing: LogCookIntent())",
      "String(describing: EditCookLogIntent())",
      "String(describing: DeleteCookLogIntent())",
      "String(describing: CreateCoverFromSpoonIntent())"
    ],
    failures
  )

  if app_intents.file?
    app_intents_content = uncommented_swift(app_intents.read)
    shortcut_count = app_intents_content.scan("AppShortcut(").length
    failures << "#{relative(app_intents)} declares #{shortcut_count} App Shortcuts, above Apple limit 10" if shortcut_count > 10
    shortcuts_body = declaration_body(app_intents_content, /\bstruct\s+SpoonjoyAppShortcuts\s*:\s*AppShortcutsProvider\b/)
    if shortcuts_body
      [
        "LogCookIntent",
        "EditCookLogIntent",
        "DeleteCookLogIntent",
        "CreateCoverFromSpoonIntent"
      ].each do |intent_name|
        failures << "#{relative(app_intents)} promotes library-only #{intent_name} into AppShortcuts" if shortcuts_body.include?("#{intent_name}(")
      end
    else
      failures << "#{relative(app_intents)} missing body for SpoonjoyAppShortcuts"
    end
  end

  require_body_tokens(
    app_intents,
    "SpoonjoyIntentShortcutBudget",
    /\bprivate\s+enum\s+SpoonjoyIntentShortcutBudget\b/,
    [
      "String(describing: LogCookIntent())",
      "String(describing: EditCookLogIntent())",
      "String(describing: DeleteCookLogIntent())",
      "String(describing: CreateCoverFromSpoonIntent())"
    ],
    failures
  )

  {
    "LogCookIntent" => {
      required: [
        "@Parameter(title: \"Recipe\", requestValueDialog:",
        "var recipe: SpoonjoyRecipeEntity",
        "@Parameter(title: \"Note\")",
        "@Parameter(title: \"Next Time\")",
        "@Parameter(title: \"Cooked At\")",
        "NativeIntentActionResolver().logCook(recipe: recipe.descriptor",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)",
        "OpenURLIntent(action.url)"
      ],
      forbidden: ["var recipeID: String", "@Parameter(title: \"Recipe ID\")"]
    },
    "EditCookLogIntent" => {
      required: [
        "@Parameter(title: \"Cook Log\", requestValueDialog:",
        "var spoon: SpoonjoySpoonEntity",
        "@Parameter(title: \"Note\")",
        "@Parameter(title: \"Next Time\")",
        "@Parameter(title: \"Cooked At\")",
        "try await requestConfirmation(",
        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
        "NativeIntentActionResolver().editCookLog(spoon: spoon.descriptor",
        "currentChefID: currentChefID",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: ["var spoonID: String", "@Parameter(title: \"Spoon ID\")"]
    },
    "DeleteCookLogIntent" => {
      required: [
        "@Parameter(title: \"Cook Log\", requestValueDialog:",
        "var spoon: SpoonjoySpoonEntity",
        "try await requestConfirmation(",
        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
        "NativeIntentActionResolver().deleteCookLog(spoon: spoon.descriptor",
        "currentChefID: currentChefID",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: ["var spoonID: String", "@Parameter(title: \"Spoon ID\")"]
    },
    "CreateCoverFromSpoonIntent" => {
      required: [
        "@Parameter(title: \"Recipe\", requestValueDialog:",
        "var recipe: SpoonjoyRecipeEntity",
        "@Parameter(title: \"Cook Log\", requestValueDialog:",
        "var spoon: SpoonjoySpoonEntity",
        "@Parameter(title: \"Activate\")",
        "@Parameter(title: \"Generate Editorial\")",
        "try await requestConfirmation(",
        "let currentChefID = try await SpoonjoyIntentStateWriter().currentAccountID()",
        "NativeIntentActionResolver().createCoverFromSpoon(recipe: recipe.descriptor, spoon: spoon.descriptor",
        "currentChefID: currentChefID",
        "try await SpoonjoyIntentStateWriter().apply(action, savedAt: createdAt)"
      ],
      forbidden: ["var recipeID: String", "var spoonID: String", "@Parameter(title: \"Recipe ID\")", "@Parameter(title: \"Spoon ID\")"]
    }
  }.each do |intent_name, contract|
    pattern = /\bstruct\s+#{Regexp.escape(intent_name)}\s*:\s*AppIntent\b/
    require_body_tokens(app_intents, intent_name, pattern, contract.fetch(:required), failures)
    forbid_body_tokens(app_intents, intent_name, pattern, contract.fetch(:forbidden), failures)
  end

  require_tokens(
    spoon_entities,
    [
      "struct SpoonjoySpoonEntity: AppEntity",
      "struct SpoonjoySpoonEntityQuery: EntityQuery, EntityStringQuery",
      "resolvedSpoonID() throws",
      "NativeIntentActionError.unresolvedSpoonEntity"
    ],
    failures
  )

  require_tokens(
    recipe_entities,
    [
      "struct SpoonjoyRecipeEntity: AppEntity",
      "resolvedRecipeID() throws",
      "NativeIntentActionError.unresolvedRecipeEntity"
    ],
    failures
  )

  require_tokens(
    spoon_catalog,
    [
      "public let chefID: String",
      "chefID: spoon.chefID",
      "chefID: \"chef-placeholder\""
    ],
    failures
  )

  require_tokens(
    recipe_catalog,
    [
      "public let chefID: String",
      "chefID: recipe.chef.id"
    ],
    failures
  )

  require_tokens(
    intent_action,
    [
      "public func logCook(",
      "public func editCookLog(",
      "public func deleteCookLog(",
      "public func createCoverFromSpoon(",
      "currentChefID: String",
      "NativeIntentActionError.spoonOwnershipRequired",
      "NativeIntentActionError.recipeOwnershipRequired",
      ".spoonCreate",
      ".spoonUpdate",
      ".spoonDelete",
      ".coverFromSpoon",
      "DeepLinkURLBuilder.url(for:"
    ],
    failures
  )

  {
    "logCook resolver" => {
      pattern: /\bpublic\s+func\s+logCook\(/,
      required: [
        "let recipeID = try recipeIDForMutation(recipe)",
        ".spoonCreate(",
        "route: .recipeDetail(id: recipeID, presentation: .detail)",
        "DeepLinkURLBuilder.url(for: route)"
      ],
      forbidden: ["recipeID: String"]
    },
    "editCookLog resolver" => {
      pattern: /\bpublic\s+func\s+editCookLog\(/,
      required: [
        "let spoonID = try spoonIDForMutation(spoon)",
        "let chefID = try canonicalObjectID(currentChefID, invalidError: .spoonOwnershipRequired(spoonID: spoonID))",
        "guard spoon.chefID == chefID else",
        "throw NativeIntentActionError.spoonOwnershipRequired(spoonID: spoonID)",
        ".spoonUpdate("
      ],
      forbidden: ["spoonID: String"]
    },
    "deleteCookLog resolver" => {
      pattern: /\bpublic\s+func\s+deleteCookLog\(/,
      required: [
        "let spoonID = try spoonIDForMutation(spoon)",
        "let chefID = try canonicalObjectID(currentChefID, invalidError: .spoonOwnershipRequired(spoonID: spoonID))",
        "guard spoon.chefID == chefID else",
        "throw NativeIntentActionError.spoonOwnershipRequired(spoonID: spoonID)",
        ".spoonDelete("
      ],
      forbidden: ["spoonID: String"]
    },
    "createCoverFromSpoon resolver" => {
      pattern: /\bpublic\s+func\s+createCoverFromSpoon\(/,
      required: [
        "let recipeID = try recipeIDForMutation(recipe)",
        "let spoonID = try spoonIDForMutation(spoon)",
        "let chefID = try canonicalObjectID(currentChefID, invalidError: .recipeOwnershipRequired(recipeID: recipeID))",
        "guard recipe.chefID == chefID else",
        "throw NativeIntentActionError.recipeOwnershipRequired(recipeID: recipeID)",
        "guard spoon.recipeID == recipeID else",
        "throw NativeIntentActionError.invalidRecipeID(spoon.recipeID)",
        ".coverFromSpoon("
      ],
      forbidden: ["recipeID: String", "spoonID: String"]
    },
    "spoonIDForMutation helper" => {
      pattern: /\bprivate\s+func\s+spoonIDForMutation\(/,
      required: [
        "guard !spoon.isPlaceholder else",
        "throw NativeIntentActionError.unresolvedSpoonEntity",
        "let spoonID = try canonicalObjectID(spoon.spoonID, invalidError: .invalidSpoonID(spoon.spoonID))",
        "let recipeID = try canonicalRecipeID(spoon.recipeID)",
        "guard spoon.route == .recipeDetail(id: recipeID, presentation: .detail) else",
        "return spoonID"
      ],
      forbidden: []
    }
  }.each do |label, contract|
    require_body_tokens(intent_action, label, contract.fetch(:pattern), contract.fetch(:required), failures)
    forbid_body_tokens(intent_action, label, contract.fetch(:pattern), contract.fetch(:forbidden), failures)
  end

  require_tokens(
    metadata,
    [
      "LogCookIntent",
      "EditCookLogIntent",
      "DeleteCookLogIntent",
      "CreateCoverFromSpoonIntent"
    ],
    failures
  )

  require_tokens(
    verifier,
    [
      "Spoon cook-log Siri intents",
      "LogCookIntent",
      "EditCookLogIntent",
      "DeleteCookLogIntent",
      "CreateCoverFromSpoonIntent"
    ],
    failures
  )

  if project.file?
    require_project_source_membership(
      project_path,
      "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
      ["Spoonjoy iOS", "Spoonjoy macOS"],
      failures
    )
  end

  [
    app_intents,
    intent_action
  ].each do |path|
    forbid_tokens(
      path,
      [
        "@Parameter(title: \"Spoon ID\")",
        "@Parameter(title: \"Recipe ID\")",
        "var spoonID: String",
        "var recipeID: String",
        "String-only spoon App Intent",
        "CommentIntent",
        "FeedIntent",
        "MessageIntent",
        "MailIntent",
        "social-feed",
        "/comments",
        "/feeds",
        "/messages",
        "mailto:",
        "MessageUI",
        "TODO SpoonIntent",
        "eventually add spoon intents"
      ],
      failures
    )
  end
end

if domain == "open-search-share-cook"
  app_intents = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift")
  recipe_cookbook_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift")
  shopping_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift")
  chef_profile_entities = ROOT.join("Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift")
  intent_action = ROOT.join("Sources/SpoonjoyCore/Native/NativeIntentAction.swift")
  metadata = ROOT.join("Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift")
  verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift")
  sharing = ROOT.join("Sources/SpoonjoyCore/Features/Sharing/NativeSharePayload.swift")
  project_path = ROOT.join("Spoonjoy.xcodeproj")
  project = project_path.join("project.pbxproj")

  [app_intents, recipe_cookbook_entities, shopping_entities, chef_profile_entities, intent_action, metadata, verifier, sharing, project].each do |path|
    require_file(path, failures)
  end

  require_tokens(
    app_intents,
    [
      "#if canImport(AppIntents)",
      "import AppIntents",
      "struct OpenRecipeIntent: AppIntent",
      "struct OpenCookbookIntent: AppIntent",
      "struct OpenProfileIntent: AppIntent",
      "struct SearchSpoonjoyIntent: AppIntent",
      "struct ShareRecipeIntent: AppIntent",
      "struct ShareCookbookIntent: AppIntent",
      "struct ShareShoppingListIntent: AppIntent",
      "struct StartCookModeIntent: AppIntent",
      "struct ContinueCookModeIntent: AppIntent",
      "enum SpoonjoySearchScopeOption: String, AppEnum",
      "var recipe: SpoonjoyRecipeEntity",
      "var cookbook: SpoonjoyCookbookEntity",
      "var profile: SpoonjoyChefProfileEntity",
      "var shoppingList: SpoonjoyShoppingListEntity",
      "var scope: SpoonjoySearchScopeOption",
      "SearchScope.all",
      "SearchScope.recipes",
      "SearchScope.cookbooks",
      "SearchScope.chefs",
      "SearchScope.shoppingList",
      "NativeSharePayload",
      "case .privateTransfer",
      "OpenCookbookIntent()",
      "OpenProfileIntent()",
      "SearchSpoonjoyIntent()",
      "ShareRecipeIntent()",
      "ShareCookbookIntent()",
      "ShareShoppingListIntent()",
      "ContinueCookModeIntent()",
      "SpoonjoyInteractionDonor"
    ],
    failures
  )
  if app_intents.file?
    shortcut_count = uncommented_swift(app_intents.read).scan("AppShortcut(").size
    failures << "#{relative(app_intents)} declares #{shortcut_count} App Shortcuts, above Apple limit 10" if shortcut_count > 10
  end

  {
    recipe_cookbook_entities => [
      ["SpoonjoyRecipeEntity", /\bstruct\s+SpoonjoyRecipeEntity\s*:\s*AppEntity\b/],
      ["SpoonjoyCookbookEntity", /\bstruct\s+SpoonjoyCookbookEntity\s*:\s*AppEntity\b/]
    ],
    shopping_entities => [
      ["SpoonjoyShoppingListEntity", /\bstruct\s+SpoonjoyShoppingListEntity\s*:\s*AppEntity\b/]
    ],
    chef_profile_entities => [
      ["SpoonjoyChefProfileEntity", /\bstruct\s+SpoonjoyChefProfileEntity\s*:\s*AppEntity\b/]
    ]
  }.each do |path, entity_contracts|
    entity_contracts.each do |entity_name, entity_pattern|
      require_nested_body_tokens(
        path,
        entity_name,
        entity_pattern,
        "display representation",
        /var\s+displayRepresentation:\s+DisplayRepresentation/,
        ["descriptor.title", "descriptor.subtitle", "descriptor.disambiguationLabel"],
        failures
      )
    end
  end

  {
    "OpenRecipeIntent" => {
      required: ["@Parameter(title: \"Recipe\", requestValueDialog:", "var recipe: SpoonjoyRecipeEntity", "NativeIntentActionResolver().openRecipe(recipe: recipe.descriptor)", "OpenURLIntent(action.url)"],
      forbidden: ["try recipe.resolvedRecipeID()", "openRecipe(recipeID:"]
    },
    "OpenCookbookIntent" => {
      required: ["@Parameter(title: \"Cookbook\", requestValueDialog:", "var cookbook: SpoonjoyCookbookEntity", "NativeIntentActionResolver().openCookbook(cookbook: cookbook.descriptor)", "OpenURLIntent(action.url)"],
      forbidden: ["var cookbookID: String", "openCookbook(cookbookID:"]
    },
    "OpenProfileIntent" => {
      required: ["@Parameter(title: \"Profile\", requestValueDialog:", "var profile: SpoonjoyChefProfileEntity", "NativeIntentActionResolver().openProfile(profile: profile.descriptor)", "OpenURLIntent(action.url)"],
      forbidden: ["var profileID: String", "var chefID: String", "openProfile(profileID:", "openProfile(chefID:"]
    },
    "SearchSpoonjoyIntent" => {
      required: ["@Parameter(title: \"Query\")", "var scope: SpoonjoySearchScopeOption", "NativeIntentActionResolver().searchSpoonjoy(query: query, scope: scope.searchScope)", "OpenURLIntent(action.url)"],
      forbidden: ["var scope: String", "String-only search intent"]
    },
    "ShareRecipeIntent" => {
      required: ["@Parameter(title: \"Recipe\", requestValueDialog:", "var recipe: SpoonjoyRecipeEntity", "NativeIntentActionResolver().shareRecipe(recipe: recipe.descriptor)", "share.publicURL"],
      forbidden: ["var recipeID: String", "shareRecipe(recipeID:"]
    },
    "ShareCookbookIntent" => {
      required: ["@Parameter(title: \"Cookbook\", requestValueDialog:", "var cookbook: SpoonjoyCookbookEntity", "NativeIntentActionResolver().shareCookbook(cookbook: cookbook.descriptor)", "share.publicURL"],
      forbidden: ["var cookbookID: String", "shareCookbook(cookbookID:"]
    },
    "ShareShoppingListIntent" => {
      required: ["@Parameter(title: \"Shopping List\", requestValueDialog:", "var shoppingList: SpoonjoyShoppingListEntity", "NativeIntentActionResolver().shareShoppingList(shoppingList: shoppingList.descriptor)", "some IntentResult & ReturnsValue<String>", "share.privateTransferValue", "share.publicURL == nil", ".result(value: privateTransferValue"],
      forbidden: ["OpenURLIntent", "_ = privateTransferValue", "https://spoonjoy.app/shopping-list", "NativeSharePayload.publicRoute(.shoppingList"]
    },
    "StartCookModeIntent" => {
      required: ["@Parameter(title: \"Recipe\", requestValueDialog:", "var recipe: SpoonjoyRecipeEntity", "NativeIntentActionResolver().startCookMode(recipe: recipe.descriptor)", "OpenURLIntent(action.url)"],
      forbidden: ["try recipe.resolvedRecipeID()", "startCookMode(recipeID:"]
    },
    "ContinueCookModeIntent" => {
      required: ["@Parameter(title: \"Recipe\", requestValueDialog:", "var recipe: SpoonjoyRecipeEntity", "NativeIntentActionResolver().continueCookMode(recipe: recipe.descriptor)", "OpenURLIntent(action.url)"],
      forbidden: ["var recipeID: String", "continueCookMode(recipeID:"]
    }
  }.each do |intent_name, contract|
    pattern = /\bstruct\s+#{Regexp.escape(intent_name)}\s*:\s*AppIntent\b/
    require_body_tokens(app_intents, intent_name, pattern, contract.fetch(:required), failures)
    forbid_body_tokens(app_intents, intent_name, pattern, contract.fetch(:forbidden), failures)
  end

  require_tokens(
    intent_action,
    [
      "NativeIntentShareValue",
      "public func openRecipe(recipe: RecipeEntityDescriptor)",
      "public func openCookbook(cookbook: CookbookEntityDescriptor)",
      "public func openProfile(profile: ChefProfileEntityDescriptor)",
      "public func searchSpoonjoy(query: String, scope: SearchScope)",
      "public func shareRecipe(recipe: RecipeEntityDescriptor)",
      "public func shareCookbook(cookbook: CookbookEntityDescriptor)",
      "public func shareShoppingList(shoppingList: ShoppingListEntityDescriptor)",
      "public func startCookMode(recipe: RecipeEntityDescriptor)",
      "public func continueCookMode(recipe: RecipeEntityDescriptor)",
      "NativeSharePayloadKind.publicURL",
      "NativeSharePayloadKind.privateTransfer",
      "privateTransferValue",
      "DeepLinkURLBuilder.url(for:"
    ],
    failures
  )

  require_body_tokens(
    intent_action,
    "shareShoppingList",
    /public\s+func\s+shareShoppingList\(shoppingList:\s+ShoppingListEntityDescriptor\)/,
    [
      "domain: .shoppingList",
      "kind: .privateTransfer",
      "publicURL: nil",
      "privateTransferValue: shoppingList.transferValue.privateTransferValue"
    ],
    failures
  )
  forbid_body_tokens(
    intent_action,
    "shareShoppingList",
    /public\s+func\s+shareShoppingList\(shoppingList:\s+ShoppingListEntityDescriptor\)/,
    [
      "NativeSharePayload.publicRoute(.shoppingList",
      "DeepLinkURLBuilder.url(for: .shoppingList)",
      "https://spoonjoy.app/shopping-list"
    ],
    failures
  )

  require_tokens(
    metadata,
    [
      "OpenCookbookIntent",
      "OpenProfileIntent",
      "SearchSpoonjoyIntent",
      "ShareRecipeIntent",
      "ShareCookbookIntent",
      "ShareShoppingListIntent",
      "ContinueCookModeIntent",
      "native-shopping-list-transfer"
    ],
    failures
  )

  require_tokens(
    verifier,
    [
      "Open/search/share/cook Siri intents",
      "OpenCookbookIntent",
      "OpenProfileIntent",
      "SearchSpoonjoyIntent",
      "ShareRecipeIntent",
      "ShareCookbookIntent",
      "ShareShoppingListIntent",
      "ContinueCookModeIntent"
    ],
    failures
  )

  require_tokens(
    sharing,
    [
      "privateShoppingList",
      "publicURL: nil",
      ".privateTransfer("
    ],
    failures
  )

  if project.file?
    require_project_source_membership(
      project_path,
      "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
      ["Spoonjoy iOS", "Spoonjoy macOS"],
      failures
    )
  end

  [
    app_intents,
    intent_action
  ].each do |path|
    forbid_tokens(
      path,
      [
        "@Parameter(title: \"Recipe ID\")",
        "var recipeID: String",
        "@Parameter(title: \"Cookbook ID\")",
        "var cookbookID: String",
        "@Parameter(title: \"Chef ID\")",
        "@Parameter(title: \"Profile ID\")",
        "var chefID: String",
        "var profileID: String",
        "@Parameter(title: \"Shopping List ID\")",
        "var shoppingListID: String",
        "https://spoonjoy.app/shopping-list",
        "NativeSharePayload.publicRoute(.shoppingList)",
        "NativePublicShareRoutePolicy.publicURL(for: .shoppingList)",
        "CommentIntent",
        "FeedIntent",
        "MessageIntent",
        "MailIntent",
        "SpoonjoyCommentEntity",
        "social-feed",
        "/comments",
        "/feeds",
        "/messages",
        "mailto:",
        "MFMailComposeViewController",
        "MessageUI"
      ],
      failures
    )
  end
end

fail_check(failures.join("\n")) unless failures.empty?

puts "app intents contract ok: #{domain}"
