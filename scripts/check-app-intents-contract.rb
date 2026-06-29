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
  content
    .gsub(%r{/\*.*?\*/}m, "")
    .gsub(%r{//.*$}, "")
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

supported_domains = ["recipe-cookbook", "shopping", "spoon", "capture-draft"]
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
      "report.shoppingEntityPurgeIdentifiers",
      "report.shoppingEntityPurgeDomainIdentifiers"
    ],
    failures
  )

  require_body_tokens(
    ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"),
    "foreground sync consumes sync purge report",
    /\.task\(id: contentState\.environment\.rawValue\)/,
    [
      "let report = try? await syncTriggerCoordinator.handle(.foreground)",
      "NativeShoppingEntityIndexPurgeRequest",
      "report.shoppingEntityPurgeIdentifiers",
      "report.shoppingEntityPurgeDomainIdentifiers",
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
      "func delete(identifiers: [String], domainIdentifiers: [String])",
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
      "report.spoonEntityPurgeIdentifiers",
      "report.spoonEntityPurgeDomainIdentifiers"
    ],
    failures
  )

  require_body_tokens(
    platform_navigation,
    "foreground sync consumes spoon sync purge report",
    /\.task\(id: contentState\.environment\.rawValue\)/,
    [
      "let report = try? await syncTriggerCoordinator.handle(.foreground)",
      "NativeSpoonEntityIndexPurgeRequest",
      "report.spoonEntityPurgeIdentifiers",
      "report.spoonEntityPurgeDomainIdentifiers",
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
      "func delete(identifiers: [String], domainIdentifiers: [String])",
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
      "func delete(identifiers: [String], domainIdentifiers: [String])",
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

fail_check(failures.join("\n")) unless failures.empty?

puts "app intents contract ok: #{domain}"
