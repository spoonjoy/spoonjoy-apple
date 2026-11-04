import Foundation
import Testing

/// The Siri AI Developer Preview calls only the intents an app marks as tools. Spoonjoy marks them in one file, behind
/// the same 27.3 SDK fence ouro-ui-apple uses for `OuroAXToolIntent`, so builds with Xcode 27.2 and earlier never see
/// `ToolIntent`. These tests read the sources, because no SDK on CI can compile the fenced side yet.
@Suite("Siri tool intents are the cooking and shopping actions, fenced to the 27.3 SDK")
struct SiriToolIntentTests {
    static let toolFile = "Apps/Spoonjoy/Shared/Native/SpoonjoySiriToolIntents.swift"
    static let fence = "#if OURO_SIRI_AI_SDK || canImport(AppIntents, _version: 301.2)"
    static let availability = "@available(iOS 27.3, macOS 27.3, *)"

    /// The actions people ask Siri for while cooking and shopping.
    static let tools: Set<String> = [
        "StartCookModeIntent",
        "ContinueCookModeIntent",
        "NextCookStepIntent",
        "PreviousCookStepIntent",
        "StartCookStepTimerIntent",
        "ReadCookStepIntent",
        "SearchSpoonjoyIntent",
        "OpenRecipeIntent",
        "AddRecipeIngredientsToShoppingListIntent",
        "AddShoppingListItemIntent",
        "SetShoppingListItemCheckedIntent"
    ]

    /// Destructive and account actions stay out of Siri AI's reach, whatever the tool list says.
    static let neverTool = [
        "Delete", "Clear", "Remove", "Discard", "Logout", "Revoke", "Disconnect", "Token", "Passkey", "Password",
        "LinkProvider", "Profile", "Notification", "Account", "Session", "Settings", "Share", "Rename", "Edit",
        // Publish without asking the person to confirm.
        "LogCook", "SaveRecipeToCookbook"
    ]

    static var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    static func read(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Every Swift file the apps and the widget compile.
    static func appSources() throws -> [(path: String, text: String)] {
        let apps = root.appendingPathComponent("Apps")
        let walk = FileManager.default.enumerator(at: apps, includingPropertiesForKeys: nil)
        var found: [(String, String)] = []
        while let url = walk?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let path = String(url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
            found.append((path, try String(contentsOf: url, encoding: .utf8)))
        }
        return found.sorted { $0.0 < $1.0 }
    }

    /// Type names given a `ToolIntent` conformance (`extension X: ToolIntent`, or `ToolIntent` in a struct's list).
    static func toolMarked(in source: String) -> Set<String> {
        let pattern = /(?:extension|struct)\s+([A-Za-z0-9_]+)\s*:\s*[^{]*\bToolIntent\b/
        return Set(source.matches(of: pattern).map { String($0.output.1) })
    }

    /// Every intent struct the apps declare.
    static func declaredIntents(in source: String) -> Set<String> {
        Set(source.matches(of: /struct\s+([A-Za-z0-9_]+Intent)\s*:/).map { String($0.output.1) })
    }

    @Test("the tool marks live in one file, behind ouro-ui-apple's 27.3 fence, each with 27.3 availability")
    func toolsAreFenced() throws {
        let source = try Self.read(Self.toolFile)
        let lines = source.components(separatedBy: "\n")
        let fenceLine = try #require(lines.firstIndex(of: Self.fence), "\(Self.toolFile) must open \(Self.fence)")
        let endifs = lines.indices.filter { lines[$0] == "#endif" }
        let closing = try #require(endifs.first(where: { $0 > fenceLine }))
        for (index, line) in lines.enumerated() where line.contains("ToolIntent") && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
            #expect(index > fenceLine && index < closing, "\(line) is outside the 27.3 fence")
            #expect(index > 0 && lines[index - 1] == Self.availability, "\(line) needs \(Self.availability) above it")
        }
        #expect(Self.toolMarked(in: source) == Self.tools, "tool marks were \(Self.toolMarked(in: source).sorted())")
    }

    @Test("no other source names ToolIntent, so builds before the 27.3 SDK never see it")
    func toolIntentAppearsOnlyBehindTheFence() throws {
        for (path, text) in try Self.appSources() where path != Self.toolFile {
            #expect(!text.contains("ToolIntent"), "\(path) names ToolIntent outside \(Self.toolFile)")
            #expect(!text.contains("@AppIntent(.tool"), "\(path) marks a tool with @AppIntent(.tool), which 27.2 can't compile")
        }
    }

    @Test("every tool is an intent the app declares, and none is destructive or touches the account")
    func toolsAreRealAndSafe() throws {
        let declared = try Self.appSources().reduce(into: Set<String>()) { $0.formUnion(Self.declaredIntents(in: $1.text)) }
        #expect(Self.tools.subtracting(declared).isEmpty, "not declared: \(Self.tools.subtracting(declared).sorted())")
        let marked = try Self.toolMarked(in: Self.read(Self.toolFile))
        for name in marked {
            for word in Self.neverTool {
                #expect(!name.contains(word), "\(name) must never be a tool (\(word))")
            }
        }
        let unsafe = declared.filter { name in Self.neverTool.contains { name.contains($0) } }
        #expect(!unsafe.isEmpty, "the never-tool words should match some of the app's intents")
        #expect(unsafe.isDisjoint(with: marked))
    }

    @Test("no tool adopts an App Intents schema (intent.tool-not-on-schema)")
    func noToolAdoptsASchema() throws {
        // Ouro AX's intent.tool-not-on-schema fails a tool on a schema in a domain Siri reaches. Spoonjoy adopts no
        // schema today, so this holds every tool to the stricter rule: no schema at all. A future schema adoption on
        // a tool must come with a Shortcuts-only domain and a change here.
        let schemaMark = /@(?:AppIntent|AssistantIntent|AppEntity|AppEnum|AssistantEntity|AssistantEnum)\s*\(([^)]*)\)/
        for (path, text) in try Self.appSources() {
            let lines = text.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where line.contains("struct ") || line.contains("extension ") {
                guard let declared = line.firstMatch(of: /(?:struct|extension)\s+([A-Za-z0-9_]+)\s*:([^{]*)/) else { continue }
                let name = String(declared.output.1)
                guard Self.tools.contains(name) else { continue }
                #expect(!declared.output.2.contains("Schema"), "\(path):\(index + 1) \(name) adopts a schema protocol")
                var above = index - 1
                while above >= 0, lines[above].trimmingCharacters(in: .whitespaces).hasPrefix("@") {
                    if let mark = lines[above].firstMatch(of: schemaMark) {
                        #expect(!mark.output.1.contains("schema"), "\(path):\(above + 1) \(name) adopts a schema")
                    }
                    above -= 1
                }
            }
        }
    }

    @Test("the cook-along skill names only tools by their real titles")
    func cookAlongSkillNamesRealTools() throws {
        let skill = try Self.read("Apps/Spoonjoy/Shared/Skills.skillsbundle/Skills/cook-along/SKILL.md")
        #expect(skill.hasPrefix("---\nname: cook-along\ndescription: "))
        let body = try #require(skill.components(separatedBy: "\n---\n").dropFirst().first)
        let titles = try Self.toolTitles()
        let named = Set(body.matches(of: /"([^"]+)" tool/).map { String($0.output.1) })
        #expect(!named.isEmpty, "the skill should name the tools it uses")
        #expect(named.subtracting(titles.values).isEmpty, "not a tool's title: \(named.subtracting(titles.values).sorted())")
        for cooking in ["StartCookModeIntent", "NextCookStepIntent", "StartCookStepTimerIntent", "ReadCookStepIntent"] {
            let title = try #require(titles[cooking])
            #expect(named.contains(title), "the skill should use the \"\(title)\" tool")
        }
        #expect(body.firstMatch(of: /\b[A-Z][A-Za-z0-9]*Intent\b/) == nil, "Siri knows tools by title, not type name")
    }

    /// Each tool's `static let title`.
    static func toolTitles() throws -> [String: String] {
        var titles: [String: String] = [:]
        for (_, text) in try appSources() {
            for match in text.matches(of: /struct\s+([A-Za-z0-9_]+Intent)\s*:[^{]*\{\s*static let title: LocalizedStringResource = "([^"]+)"/) {
                let name = String(match.output.1)
                if tools.contains(name) { titles[name] = String(match.output.2) }
            }
        }
        return titles
    }
}
