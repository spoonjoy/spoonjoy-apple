import Foundation
import Testing

@Suite("TestFlight automation contract")
struct TestFlightAutomationContractTests {
    @Test("CI publishes internal TestFlight after Native succeeds on main")
    func ciPublishesInternalTestFlightAfterNativeSucceedsOnMain() throws {
        let workflow = try readTestFlightAutomationRepoFile(".github/workflows/testflight.yml")

        expectTestFlightAutomationContent(
            workflow,
            in: ".github/workflows/testflight.yml",
            contains: [
                "name: TestFlight",
                "workflow_run:",
                "workflows:",
                "- Native",
                "branches:",
                "- main",
                "types:",
                "- completed",
                "workflow_dispatch:",
                "github.event.workflow_run.conclusion == 'success'",
                "github.event.workflow_run.head_branch == 'main'",
                "ref: ${{ github.event.workflow_run.head_sha }}",
                "spoonjoy-testflight-main",
                "ourostack/apple-distribution-kit",
                ".ci/apple-distribution-kit",
                "APP_STORE_CONNECT_API_KEY_ID",
                "APP_STORE_CONNECT_API_ISSUER_ID",
                "APP_STORE_CONNECT_API_KEY_BASE64",
                "scripts/ci-publish-testflight.sh"
            ],
            forbids: [
                "appStoreVersionSubmissions",
                "appStoreReviewSubmissions",
                "betaAppReviewSubmissions"
            ]
        )
    }

    @Test("publish script uploads publishes and verifies the internal group")
    func publishScriptUploadsPublishesAndVerifiesTheInternalGroup() throws {
        let script = try readTestFlightAutomationRepoFile("scripts/ci-publish-testflight.sh")

        expectTestFlightAutomationContent(
            script,
            in: "scripts/ci-publish-testflight.sh",
            contains: [
                "BUNDLE_ID=\"${SPOONJOY_TESTFLIGHT_BUNDLE_ID:-app.spoonjoy}\"",
                "GROUP_NAME=\"${SPOONJOY_TESTFLIGHT_GROUP_NAME:-Spoonjoy Internal}\"",
                "APP_STORE_CONNECT_PROVIDER_PUBLIC_ID",
                "scripts/check-apple-distribution-kit.sh",
                "scripts/package-testflight-ios.sh",
                "altool-upload",
                "SPOONJOY_TESTFLIGHT_BUILD_NUMBER",
                "filter[preReleaseVersion.platform]=IOS",
                "processingState == \"VALID\"",
                "testflight publish",
                "--mode dry-run",
                "--mode apply",
                "/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/builds",
                "/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/betaTesters",
                "/v1/buildBetaDetails/$BUILD_BETA_DETAIL_ID",
                "attempt=%s/20",
                "IN_BETA_TESTING",
                "testerCount",
                "testersNotifiedRequested"
            ],
            forbids: [
                "appStoreVersionSubmissions",
                "appStoreReviewSubmissions"
            ]
        )
    }

    @Test("package script supports CI owned build numbers without source bumps")
    func packageScriptSupportsCIOwnedBuildNumbersWithoutSourceBumps() throws {
        let packageScript = try readTestFlightAutomationRepoFile("scripts/package-testflight-ios.sh")

        expectTestFlightAutomationContent(
            packageScript,
            in: "scripts/package-testflight-ios.sh",
            contains: [
                "BUILD_NUMBER=\"${SPOONJOY_TESTFLIGHT_BUILD_NUMBER:-}\"",
                "CURRENT_PROJECT_VERSION=\"$BUILD_NUMBER\"",
                "SPOONJOY_TESTFLIGHT_BUILD_NUMBER must be numeric"
            ]
        )
    }

    @Test("distribution docs describe automatic internal TestFlight publishing")
    func distributionDocsDescribeAutomaticInternalTestFlightPublishing() throws {
        let docs = try readTestFlightAutomationRepoFile("docs/apple-distribution.md")

        expectTestFlightAutomationContent(
            docs,
            in: "docs/apple-distribution.md",
            contains: [
                "Automatic TestFlight Publishing",
                ".github/workflows/testflight.yml",
                "workflow_run",
                "Native",
                "Spoonjoy Internal",
                "APP_STORE_CONNECT_API_KEY_ID",
                "APP_STORE_CONNECT_API_ISSUER_ID",
                "APP_STORE_CONNECT_API_KEY_BASE64",
                "dynamic build number",
                "scripts/ci-publish-testflight.sh"
            ],
            forbids: [
                "appStoreVersionSubmissions",
                "appStoreReviewSubmissions"
            ]
        )
    }
}

private let testFlightAutomationRepoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private func readTestFlightAutomationRepoFile(_ relativePath: String) throws -> String {
    try String(
        contentsOf: testFlightAutomationRepoURL.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private func expectTestFlightAutomationContent(
    _ content: String,
    in path: String,
    contains requiredTokens: [String] = [],
    forbids forbiddenTokens: [String] = []
) {
    let missing = requiredTokens.filter { !content.contains($0) }
    #expect(missing.isEmpty, "\(path) missing required token(s): \(missing)")

    let presentForbidden = forbiddenTokens.filter { content.contains($0) }
    #expect(presentForbidden.isEmpty, "\(path) contains forbidden token(s): \(presentForbidden)")
}
