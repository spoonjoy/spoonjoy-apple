# Unit 21e Shopping App Entities

Shopping App Entities use the native sync cache as their source of truth. The core catalog resolves only records scoped to the signed-in account and cache environment, filters deleted/tombstoned shopping items, and exposes private native transfer values without public URLs.

The App Intents layer resolves shopping items through `SpoonjoyShoppingItemEntity` instead of raw string IDs. Logout, revoke-and-logout, previous-account sync resets, sync tombstones, and cache deletions now compute shopping entity purge plans that target the exact CoreSpotlight shopping-item unique identifiers (`<environment>|<account>|shopping-list-item|<item>`) and, for account-scope purges, the matching shopping-item domain identifier. App Entity identifiers remain private to Siri/App Intents resolution and are not reused as Spotlight delete keys.
