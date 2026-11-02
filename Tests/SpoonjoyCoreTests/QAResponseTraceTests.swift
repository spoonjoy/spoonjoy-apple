import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("QA response trace")
struct QAResponseTraceTests {
    @Test("names cf-ray first, then the other response headers sorted by name")
    func namesCfRayFirstThenOtherHeaders() {
        let trace = QAResponseTrace.describe(headers: [
            "Server": "cloudflare",
            "CF-Ray": "9a1b2c3d4e5f-EWR",
            "Content-Length": "0"
        ])
        #expect(trace == " [cf-ray 9a1b2c3d4e5f-EWR; content-length: 0; server: cloudflare]")
    }

    @Test("says so when the response carried no cf-ray, so a request that never reached Cloudflare is visible")
    func saysWhenThereIsNoCfRay() {
        #expect(QAResponseTrace.describe(headers: ["Content-Length": "0"]) == " [no cf-ray; content-length: 0]")
    }

    @Test("leaves out cookies and credentials")
    func leavesOutSecrets() {
        let trace = QAResponseTrace.describe(headers: [
            "Set-Cookie": "session=abc",
            "Authorization": "Bearer abc",
            "cf-ray": "r-1"
        ])
        #expect(trace == " [cf-ray r-1]")
    }

    @Test("quotes header values briefly")
    func clipsLongValues() {
        let trace = QAResponseTrace.describe(headers: ["cf-ray": "r-1", "x-long": String(repeating: "a", count: 300)])
        #expect(trace == " [cf-ray r-1; x-long: " + String(repeating: "a", count: 120) + "]")
    }

    @Test("reads headers from an HTTPURLResponse")
    func readsHTTPURLResponse() throws {
        let response = try #require(HTTPURLResponse(
            url: URL(string: "https://qa.example/api/v1/recipes")!,
            statusCode: 500,
            httpVersion: "HTTP/2",
            headerFields: ["cf-ray": "r-2", "Content-Length": "0"]
        ))
        #expect(QAResponseTrace.describe(response) == " [cf-ray r-2; content-length: 0]")
        #expect(QAResponseTrace.describe(nil) == "")
    }
}
