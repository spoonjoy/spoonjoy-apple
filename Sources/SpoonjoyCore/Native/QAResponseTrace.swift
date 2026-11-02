import Foundation

/// What a failed QA response says about where it came from. A Cloudflare edge or platform error
/// can carry no body and no request id, so the response headers (above all `cf-ray`) are the only
/// way to find the request in Cloudflare's logs.
public enum QAResponseTrace {
    private static let withheld: Set<String> = ["set-cookie", "authorization", "proxy-authorization", "cookie"]
    private static let valueLimit = 120

    /// " [cf-ray <id>; name: value; ...]", or " [no cf-ray; ...]" when the response had none.
    public static func describe(headers: [String: String]) -> String {
        // Two spellings of one header keep the smaller value, so the trace doesn't depend on dictionary order.
        let lowered = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: min)
        let rest = lowered
            .filter { $0.key != "cf-ray" && !withheld.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value.prefix(valueLimit))" }
        let ray = lowered["cf-ray"].map { "cf-ray \($0.prefix(valueLimit))" } ?? "no cf-ray"
        return " [" + ([ray] + rest).joined(separator: "; ") + "]"
    }

    public static func describe(_ response: HTTPURLResponse?) -> String {
        guard let response else { return "" }
        var headers: [String: String] = [:]
        for case let (key as String, value as String) in response.allHeaderFields {
            headers[key] = value
        }
        return describe(headers: headers)
    }
}
