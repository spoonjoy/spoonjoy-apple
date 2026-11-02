import Foundation

/// What a failed QA response says about where it came from. A Cloudflare edge or platform error
/// can carry no body and no request id, so the response headers (above all `cf-ray`) are the only
/// way to find the request in Cloudflare's logs.
public enum QAResponseTrace {
    private static let withheld: Set<String> = ["set-cookie", "authorization", "proxy-authorization", "cookie"]
    private static let valueLimit = 120

    /// " [cf-ray <id>; name: value; ...]", or " [no cf-ray; ...]" when the response had none.
    public static func describe(headers: [String: String]) -> String {
        let lowered = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { first, _ in first })
        let rest = lowered
            .filter { $0.key != "cf-ray" && !withheld.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value.prefix(valueLimit))" }
        let ray = lowered["cf-ray"].map { "cf-ray \($0.prefix(valueLimit))" } ?? "no cf-ray"
        return " [" + ([ray] + rest).joined(separator: "; ") + "]"
    }

    public static func describe(_ response: HTTPURLResponse?) -> String {
        guard let response else { return "" }
        let pairs = response.allHeaderFields.compactMap { key, value -> (String, String)? in
            guard let key = key as? String, let value = value as? String else { return nil }
            return (key, value)
        }
        return describe(headers: Dictionary(pairs, uniquingKeysWith: { first, _ in first }))
    }
}
