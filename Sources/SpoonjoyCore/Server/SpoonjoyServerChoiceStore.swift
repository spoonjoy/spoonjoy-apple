import Foundation

/// The server the cook chose on the sign-in screen, kept on this device. Nothing saved means the app's own server
/// (spoonjoy.app), so a device that never opened the picker behaves exactly as before it existed.
public struct SpoonjoyServerChoiceStore: @unchecked Sendable {
    public static let key = "SpoonjoyServerBaseURL"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The chosen server, or nil for the app's own; a saved value the app can no longer read counts as nil.
    public func load() -> SpoonjoyServerAddress? {
        guard let saved = defaults.string(forKey: Self.key), let url = URL(string: saved) else {
            return nil
        }
        return SpoonjoyServerAddress(baseURL: url)
    }

    /// Saves `address`, or forgets the choice when it is nil.
    public func save(_ address: SpoonjoyServerAddress?) {
        if let address {
            defaults.set(address.baseURL.absoluteString, forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
    }
}
