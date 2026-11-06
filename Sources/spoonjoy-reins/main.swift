// Spoonjoy's phone shell over the fixture kitchen, headless, with the network blocked.
//
//   swift run spoonjoy-reins ls 'do openRecipe {"id":"recipe_lemon_pantry_pasta"}' 'do startCooking' 'do nextStep' 'do goBack'
//   printf 'ls\n' | swift run spoonjoy-reins
//
// Exit codes: 0 every step ran, 1 an action failed, 2 a step was refused, 3 something tried to reach the network (the
// requests are listed on stderr). The one-second settle lets the cook session's debounced push (800 ms) start, so a
// late request is caught too.

import Foundation
import OuroReins
import SpoonjoyReins

await ReinsCommandLine.run(settle: .seconds(1)) {
    ReinsSession(try await SpoonjoyReinsLaunch.launch(in: try SpoonjoyReinsLaunch.freshDirectory()))
}
