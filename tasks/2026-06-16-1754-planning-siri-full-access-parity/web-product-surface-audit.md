# Spoonjoy Web Product Surface Audit

Date: 2026-06-16

This audit records the current `spoonjoy-v2` product model so the native Apple app can target reality rather than imagined future surfaces.

## Current Routes

Source: `/Users/arimendelow/Projects/spoonjoy-v2/app/routes.ts`

- Kitchen/home: `/`
- Auth: `/login`, `/signup`, `/logout`, Google/GitHub/Apple OAuth, WebAuthn/passkeys
- Agent approval: `/agent/connect`, `/agent/connect/:requestId`
- Recipes: `/recipes`, `/recipes/new`, `/recipes/:id`, `/recipes/:id/edit`, `/recipes/:id/fork`, `/recipes/:id/steps/new`, `/recipes/:id/steps/:stepId/edit`
- Cookbooks: `/cookbooks`, `/cookbooks/new`, `/cookbooks/:id`
- Shopping: `/shopping-list`
- Search: `/search`
- Profiles: `/users/:identifier`, `/users/:identifier/fellow-chefs`, `/users/:identifier/kitchen-visitors`
- Account: `/account/settings`
- Developer/API: `/developers`, `/developers/playground`, `/api`, `/api/playground`, `/api/v1/*`, OAuth metadata, MCP
- Platform: push endpoints, photo proxy, OG images, privacy, terms, health, catch-all

## Domain Model

Source: `/Users/arimendelow/Projects/spoonjoy-v2/prisma/schema.prisma`

- Identity and access: `User`, `UserCredential`, `OAuth`, `ApiCredential`, `ApiIdempotencyKey`, `AgentConnectionRequest`, OAuth server records.
- Recipe authoring: `Recipe`, `RecipeStep`, `StepOutputUse`, `Ingredient`, `IngredientRef`, `Unit`.
- Collections: `Cookbook`, `RecipeInCookbook`.
- Shopping: `ShoppingList`, `ShoppingListItem`.
- Cook logs: `RecipeSpoon`.
- Imagery: `RecipeCover`, `ImageGenLedger`.
- Notifications: `PushSubscription`, `NotificationEvent`, `NotificationPreference`.

## Current Product Surfaces

### Kitchen And Landing

`/` is both public marketing landing and signed-in/public kitchen view. A kitchen can be opened for a specific chef by id or username. It shows recipes and cookbooks with Kitchen Table design language, owner affordances, public share/open links, and profile entry points.

### Recipes

Recipes are public-by-default authored objects with title, description, servings, chef, cover/provenance, source URL/source recipe attribution, steps, ingredients, step-output dependencies, cookbooks, spoons, and cover history.

Current recipe read actions:

- Browse/search public recipes.
- Open detail with rich metadata, OG image metadata, cover provenance, chef profile link, steps, ingredients, step dependencies, cook logs, owner tools, and save/share/cook actions.
- Scale ingredients.
- Check off ingredients and step-output dependencies.
- Enter cook mode with active step and local progress persistence.

Current recipe mutations:

- Create recipe with metadata, image upload, parsed/manual ingredients and steps.
- Edit metadata and image.
- Create, edit, delete, and reorder steps.
- Add/delete ingredients.
- Add/remove step-output dependencies.
- Fork a recipe.
- Soft-delete recipe.
- Save/remove recipe in cookbooks, including creating a cookbook from recipe detail.
- Add all recipe ingredients to shopping list at a scale factor.
- Set/remove/regenerate/archive covers and create covers from spoon photos.

### Spoons / Cook Logs

Spoons are current product, not future reactions or comments. A spoon is a cook log with `photoUrl`, `note`, `nextTime`, `cookedAt`, chef, recipe, soft delete, and optional cover-image relationship.

Current spoon behavior:

- Log a cook from recipe detail.
- Require at least one of photo, note, or next-time.
- Optional cooked-at date.
- Optional origin-cook cover prompt.
- Notify recipe owner on another chef's cook.
- Fan out fellow-chef origin-cook notifications when applicable.
- Delete owned active spoon.
- Show spoons on recipe detail and profile recent cooks.

### Cookbooks

Cookbooks are authored collections with public detail pages, OG images, a cookbook-cover collage, ordered recipe contents, owner tools, and share.

Current cookbook mutations:

- Create cookbook.
- Rename cookbook.
- Delete cookbook.
- Add a recipe.
- Remove a recipe.
- Notify recipe owner when another chef saves their recipe to a cookbook.

### Shopping List

Shopping list is owner-private. The web UI supports aisle-like grouping, category filters, need/basket/all views, optimistic checkoff, swipe delete, clear checked/all, manual add, and add-from-recipe.

Current shopping mutations:

- Add item from natural text or manual parsed fields.
- Add all ingredients from an owned/public recipe at a scale factor.
- Check/uncheck item.
- Remove item.
- Clear completed.
- Clear all.

### Search

Search scopes are `all`, `recipes`, `cookbooks`, `chefs`, and `shopping-list`. Shopping-list search is private to the signed-in chef. Results include recipes, cookbooks, chefs, and shopping-list items.

### Profiles And Activity-Derived Social

Profiles show a chef's recipes, cookbooks, recent spoons, fellow-chef count, and kitchen-visitor count. Fellow chefs and kitchen visitors are derived from spoons, forks, and cookbook saves. There are no explicit follows.

### Account, Auth, Notifications, And Developer Access

Account settings include profile email/username/photo, linked Google/GitHub/Apple OAuth accounts, passkeys, password set/change/remove, bearer credentials, OAuth app connections, and notification preferences.

Developer surfaces include REST API v1 docs/playground/OpenAPI, OAuth/PKCE, delegated approval, and remote MCP.

### Capture And Import

Recipe import/capture exists in server/tool code, including URL import and video extraction helpers. There is no registered `/capture` or `/import` web route. Native capture should therefore create local drafts and/or use future REST/tool-backed import deliberately, not pretend a web capture page exists.

## Explicitly Not Present

- Recipe comments, reply threads, mentions, or comment notifications.
- A social feed/event feed route.
- Generic reactions/likes. Spoons are cook logs.
- Meal planning, calendars, nutrition, macros, fitness, or today's recipes.
- Pantry stock/inventory. Existing `pantry` components are profile/kitchen presentation components, not inventory.
- General media library or uploaded video object.

## Current Offline Reality

The web app has local cook-progress persistence in recipe detail and PWA/install affordances, but the product does not have a complete offline-first cache/sync model. The native app should exceed web parity here: offline access, freshness indicators, queued safe mutations, and conflict-aware sync are native product value.
