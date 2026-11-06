// SPIKE (W13, Ouro Reins): Spoonjoy's phone shell over the fixture kitchen, headless, with the network blocked.
//
//   swift run spoonjoy-reins ls 'do openRecipe {"id":"recipe_lemon_pantry_pasta"}' 'do startCooking' 'do nextStep' 'do goBack'
//   printf 'ls\n' | swift run spoonjoy-reins
//
// It exits 3 and lists the requests on stderr when anything tried to reach the network. The one-second settle lets the
// cook session's debounced push (800 ms) start, so a late request is caught too.

import Foundation
import OuroReins
import SpoonjoyReins

await ReinsCommandLine.run(settle: .seconds(1)) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-reins-\(UUID().uuidString)")
    try SpoonjoyFixtureKitchen.copy(to: directory)
    let store = try SpoonjoyFixtureKitchen.store(in: directory)
    await store.bootstrap()
    return ReinsSession(SpoonjoyReinsShell(store: store))
}
