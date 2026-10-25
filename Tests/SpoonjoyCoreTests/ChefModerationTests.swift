import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Report and block")
struct ChefModerationTests {
    private static let configuration = APIClientConfiguration(baseURL: URL(string: "https://spoonjoy.app")!, bearerToken: "sj_access")

    private static func body(_ request: APIRequest) throws -> [String: String]? {
        try request.body.map { try JSONSerialization.jsonObject(with: $0) as? [String: String] } ?? nil
    }

    @Test("a report posts the target, the reason and trimmed details, with the bearer token")
    func reportRequest() throws {
        let request = try ModerationRequests.report(
            target: ContentReportTarget(type: .recipe, id: "recipe_1"),
            reason: .offensive,
            details: "  Rude title  "
        ).urlRequest(configuration: Self.configuration)

        #expect(request.method == .post)
        #expect(request.url.path == "/api/v1/reports")
        #expect(request.headers["Authorization"] == "Bearer sj_access")
        #expect(try Self.body(request) == ["targetType": "recipe", "targetId": "recipe_1", "reason": "offensive", "details": "Rude title"])
    }

    @Test("a report leaves out blank or missing details")
    func reportWithoutDetails() throws {
        let blank = try ModerationRequests.report(target: ContentReportTarget(type: .chef, id: "chef_2"), reason: .spam, details: "   ")
            .urlRequest(configuration: Self.configuration)
        let missing = try ModerationRequests.report(target: ContentReportTarget(type: .spoon, id: "spoon_3"), reason: .other, details: nil)
            .urlRequest(configuration: Self.configuration)

        #expect(try Self.body(blank) == ["targetType": "chef", "targetId": "chef_2", "reason": "spam"])
        #expect(try Self.body(missing) == ["targetType": "spoon", "targetId": "spoon_3", "reason": "other"])
    }

    @Test("blocks are listed, added and removed at /api/v1/blocks")
    func blockRequests() throws {
        let list = try ModerationRequests.blocks().urlRequest(configuration: Self.configuration)
        let block = try ModerationRequests.block(chefID: "chef_2").urlRequest(configuration: Self.configuration)
        let unblock = try ModerationRequests.unblock(chefID: "chef_2").urlRequest(configuration: Self.configuration)

        #expect(list.method == .get)
        #expect(list.url.path == "/api/v1/blocks")
        #expect(block.method == .post)
        #expect(block.url.path == "/api/v1/blocks")
        #expect(try Self.body(block) == ["chefId": "chef_2"])
        #expect(unblock.method == .delete)
        #expect(unblock.url.path == "/api/v1/blocks/chef_2")
        #expect(unblock.headers["Authorization"] == "Bearer sj_access")
    }

    @Test("every reason has a person-readable title and a stable ID")
    func reasonTitles() {
        #expect(ContentReportReason.allCases.map(\.title) == [
            "Spam or misleading",
            "Offensive or inappropriate",
            "Harassment or hate",
            "Copied without permission",
            "Something else"
        ])
        #expect(ContentReportReason.allCases.map(\.id) == ["spam", "offensive", "harassment", "copyright", "other"])
        #expect(ContentReportTargetType.allCases.map(\.rawValue) == ["recipe", "chef", "spoon", "cookbook"])
    }

    @Test("a blocked chef is named by display name, falling back to the handle")
    func blockedChefName() {
        #expect(BlockedChef(id: "c1", username: "maya", displayName: "Maya Okafor").name == "Maya Okafor")
        #expect(BlockedChef(id: "c1", username: "maya", displayName: "").name == "@maya")
        #expect(BlockedChef(id: "c1", username: "maya").name == "@maya")
    }

    @Test("the server's report, block, list and unblock answers decode")
    func responsesDecode() throws {
        let report = try JSONDecoder().decode(ContentReportResponse.self, from: Data(#"{"report":{"id":"rep_1","status":"open"}}"#.utf8))
        let block = try JSONDecoder().decode(ChefBlockResponse.self, from: Data(#"{"block":{"chef":{"id":"c2","username":"sam","displayName":null},"createdAt":"2026-10-24T00:00:00.000Z"}}"#.utf8))
        let list = try JSONDecoder().decode(ChefBlockListResponse.self, from: Data(#"{"blocks":[{"chef":{"id":"c2","username":"sam","photoUrl":"https://spoonjoy.app/p.jpg"},"createdAt":"2026-10-24T00:00:00.000Z"}]}"#.utf8))
        let unblock = try JSONDecoder().decode(ChefUnblockResponse.self, from: Data(#"{"unblocked":true}"#.utf8))

        #expect(report.report == ContentReportReceipt(id: "rep_1", status: "open"))
        #expect(block.block == ChefBlock(chef: BlockedChef(id: "c2", username: "sam"), createdAt: "2026-10-24T00:00:00.000Z"))
        #expect(list.blocks.map(\.chef.photoURL) == [URL(string: "https://spoonjoy.app/p.jpg")])
        #expect(list.blocks.map(\.chef.id) == [block.block.chef.id])
        #expect(unblock.unblocked)
    }

    @Test("the ledger hides reported things and everything by a blocked chef until unblocked")
    func ledger() {
        var ledger = ChefModerationLedger()
        let recipe = ContentReportTarget(type: .recipe, id: "r1")
        ledger.hide(recipe)
        ledger.block(BlockedChef(id: "c2", username: "sam"))
        ledger.block(BlockedChef(id: "c2", username: "sam", displayName: "Sam"))

        #expect(ledger.isHidden(recipe))
        #expect(ledger.hidesRecipe(id: "r1", chefID: "c9"))
        #expect(ledger.hidesRecipe(id: "r5", chefID: "c2"))
        #expect(!ledger.hidesRecipe(id: "r5", chefID: "c9"))
        #expect(ledger.blockedChefs == [BlockedChef(id: "c2", username: "sam", displayName: "Sam")])

        ledger.unblock(chefID: "c2")
        #expect(!ledger.isBlocked(chefID: "c2"))
        #expect(ledger.isHidden(recipe))

        ledger.replaceBlocks(with: [ChefBlock(chef: BlockedChef(id: "c3", username: "lee"), createdAt: "x")])
        #expect(ledger.blockedChefs == [BlockedChef(id: "c3", username: "lee")])
    }

    private static func result(_ type: SearchSurfaceResultType, id: String, ownerID: String?) -> SearchSurfaceResult {
        SearchSurfaceResult(
            type: type,
            id: id,
            ownerID: ownerID,
            ownerUsername: nil,
            title: id,
            subtitle: nil,
            snippet: nil,
            href: "/\(id)",
            canonicalURL: URL(string: "https://spoonjoy.app/\(id)")!,
            imageURL: nil,
            score: 1,
            metadata: [:]
        )
    }

    @Test("search leaves out reported results, blocked chefs and everything they own")
    func searchFiltering() {
        var ledger = ChefModerationLedger()
        ledger.block(BlockedChef(id: "c2", username: "sam"))
        ledger.hide(ContentReportTarget(type: .recipe, id: "r1"))
        ledger.hide(ContentReportTarget(type: .cookbook, id: "cb1"))
        ledger.hide(ContentReportTarget(type: .chef, id: "c4"))

        #expect(ledger.hidesSearchResult(Self.result(.recipe, id: "r9", ownerID: "c2")))
        #expect(ledger.hidesSearchResult(Self.result(.recipe, id: "r1", ownerID: "c9")))
        #expect(!ledger.hidesSearchResult(Self.result(.recipe, id: "r9", ownerID: "c9")))
        #expect(ledger.hidesSearchResult(Self.result(.cookbook, id: "cb1", ownerID: nil)))
        #expect(!ledger.hidesSearchResult(Self.result(.cookbook, id: "cb2", ownerID: nil)))
        #expect(ledger.hidesSearchResult(Self.result(.chef, id: "c2", ownerID: nil)))
        #expect(ledger.hidesSearchResult(Self.result(.chef, id: "c4", ownerID: nil)))
        #expect(!ledger.hidesSearchResult(Self.result(.chef, id: "c5", ownerID: nil)))
        #expect(!ledger.hidesSearchResult(Self.result(.shoppingListItem, id: "i1", ownerID: nil)))
    }

    @Test("ledgers are saved per account and survive a reload; a missing or damaged file reads as empty")
    func ledgerStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("spoonjoy-moderation-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ChefModerationLedgerStore(directoryURL: directory)
        #expect(store.fileURL(accountID: "chef/ari_1-x").lastPathComponent == "moderation-chef_ari_1-x.json")
        #expect(store.load(accountID: "chef_ari") == ChefModerationLedger())

        var ledger = ChefModerationLedger()
        ledger.block(BlockedChef(id: "c2", username: "sam"))
        ledger.hide(ContentReportTarget(type: .cookbook, id: "cb1"))
        try store.save(ledger, accountID: "chef_ari")

        #expect(store.load(accountID: "chef_ari") == ledger)
        #expect(store.load(accountID: "chef_other") == ChefModerationLedger())

        try Data("not json".utf8).write(to: store.fileURL(accountID: "chef_ari"))
        #expect(store.load(accountID: "chef_ari") == ChefModerationLedger())
    }
}
