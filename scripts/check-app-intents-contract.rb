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

supported_domains = ["recipe-cookbook"]
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
      "recipeEntity(id:",
      "cookbookEntity(id:",
      "recipeEntities(for:",
      "cookbookEntities(for:",
      "recipeEntities(matching:",
      "cookbookEntities(matching:",
      "suggestedRecipeEntities",
      "suggestedCookbookEntities",
      "loading(syncStore:",
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
      "static var typeDisplayRepresentation",
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
      "OpenRecipeIntent(recipe:",
      "StartCookModeIntent(recipe:",
      "AddRecipeIngredientsToShoppingListIntent(recipe:",
      "recipe.descriptor.id",
      "SpoonjoyRecipeEntityQuery"
    ],
    failures
  )
  {
    "OpenRecipeIntent" => ["@Parameter(title: \"Recipe\", requestValueDialog:", "var recipe: SpoonjoyRecipeEntity", "recipe.descriptor.id"],
    "StartCookModeIntent" => ["@Parameter(title: \"Recipe\", requestValueDialog:", "var recipe: SpoonjoyRecipeEntity", "recipe.descriptor.id"],
    "AddRecipeIngredientsToShoppingListIntent" => ["@Parameter(title: \"Recipe\", requestValueDialog:", "var recipe: SpoonjoyRecipeEntity", "recipe.descriptor.id"]
  }.each do |intent_name, tokens|
    pattern = /\bstruct\s+#{Regexp.escape(intent_name)}\s*:\s*AppIntent\b/
    require_body_tokens(app_intents, intent_name, pattern, tokens, failures)
    forbid_body_tokens(app_intents, intent_name, pattern, ["var recipeID: String", "@Parameter(title: \"Recipe ID\")"], failures)
  end

  require_tokens(
    metadata,
    [
      "SpoonjoyRecipeEntity",
      "SpoonjoyCookbookEntity",
      "SpoonjoyRecipeEntityQuery",
      "SpoonjoyCookbookEntityQuery",
      "recipe-entity",
      "cookbook-entity"
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
      "String-only recipe App Intent",
      "TODO AppEntity"
    ],
    failures
  )
end

fail_check(failures.join("\n")) unless failures.empty?

puts "app intents contract ok: #{domain}"
