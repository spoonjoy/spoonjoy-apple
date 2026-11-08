/// Names the device in a parity shot (`parity-<screen>-<device>-<scheme>`).
///
/// The journeys runner is an iPhone-only bundle, so on an iPad it runs in compatibility mode and UIKit reports the
/// phone idiom. The simulator's model identifier (`SIMULATOR_MODEL_IDENTIFIER`, for example `iPad16,3`) is not
/// affected, so it decides when present; the idiom is the fallback on a real device.
public enum ParityShotDevice {
    public static func name(simulatorModelIdentifier: String?, idiomIsPad: Bool) -> String {
        if let model = simulatorModelIdentifier, !model.isEmpty {
            return model.hasPrefix("iPad") ? "ipad" : "iphone"
        }
        return idiomIsPad ? "ipad" : "iphone"
    }
}
