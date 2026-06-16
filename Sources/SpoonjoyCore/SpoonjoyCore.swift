import Foundation

public enum SpoonjoyCore {
    public static let productName = "Spoonjoy"
}

public enum SpoonjoyFixture {
    public static let names = [
        "kitchen-fixture",
        "recipes-fixture",
        "cookbooks-fixture",
        "shopping-list-fixture",
        "offline-snapshot-fixture"
    ]

    public static func data(named name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile)
        }

        return try Data(contentsOf: url)
    }
}
