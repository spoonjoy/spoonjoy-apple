// SPIKE (W13, Ouro Reins): Spoonjoy's phone shell over the fixture kitchen, headless, with the network blocked.
//
//   swift run spoonjoy-reins ls 'do openRecipe {"id":"recipe_lemon_pantry_pasta"}' 'do startCooking' 'do nextStep' 'do goBack'
//   printf 'ls\n' | swift run spoonjoy-reins
//
// It exits 3 and prints the requests when anything tried to reach the network.

import Foundation
import OuroReins
import SpoonjoyReins

let directory = FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-reins-\(UUID().uuidString)")
let guardrail = ReinsNetworkGuard.begin()
do {
    try SpoonjoyFixtureKitchen.copy(to: directory)
    let store = try SpoonjoyFixtureKitchen.store(in: directory)
    await store.bootstrap()
    let shell = SpoonjoyReinsShell(store: store)
    let session = ReinsSession(shell)
    let arguments = Array(CommandLine.arguments.dropFirst())
    var worst: Int32 = 0
    func run(_ line: String) async {
        guard let reply = await ReinsWire.handle(line, session: session) else { return }
        print(reply)
        if let value = try? ReinsValue(json: reply), value["ok"] == false { worst = value["error"]?["exit"]?.intValue == 1 ? 1 : max(worst, 2) }
    }
    if arguments.isEmpty {
        for try await line in FileHandle.standardInput.bytes.lines { await run(line) }
    } else {
        for line in arguments { await run(line) }
    }
    // Let a debounced push (the cook session's 800 ms) fire, so a late request is caught too.
    try await Task.sleep(for: .seconds(1))
    let attempts = guardrail.end()
    if !attempts.isEmpty {
        FileHandle.standardError.write(Data("spoonjoy-reins: network attempted: \(attempts.map(\.description).joined(separator: ", "))\n".utf8))
        exit(3)
    }
    exit(worst)
} catch {
    guardrail.end()
    FileHandle.standardError.write(Data("spoonjoy-reins: \(error)\n".utf8))
    exit(1)
}
