import SpoonjoyCore
import SwiftUI

/// A feature that sends the person's content to an AI service, waiting for their consent.
struct ThirdPartyAIConsentRequest: Identifiable {
    let id = UUID()
    let use: ThirdPartyAIUse
    let proceed: @MainActor () -> Void
}

extension View {
    /// Runs `proceed` straight away when the person already allowed AI features; otherwise asks first and runs it
    /// only if they allow. Declining is remembered and can be changed in Settings.
    func thirdPartyAIConsent(_ request: Binding<ThirdPartyAIConsentRequest?>) -> some View {
        sheet(item: request) { request in
            ThirdPartyAIConsentSheet(use: request.use) { allowed in
                ThirdPartyAIConsentStore().record(allowed ? .granted : .declined)
                if allowed {
                    request.proceed()
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

enum ThirdPartyAIConsentGate {
    /// Runs `proceed` now if consent was given, or returns the request to present.
    @MainActor static func request(_ use: ThirdPartyAIUse, proceed: @escaping @MainActor () -> Void) -> ThirdPartyAIConsentRequest? {
        if ThirdPartyAIConsentStore().consent == .granted {
            proceed()
            return nil
        }
        return ThirdPartyAIConsentRequest(use: use, proceed: proceed)
    }
}

struct ThirdPartyAIConsentSheet: View {
    let use: ThirdPartyAIUse
    let decide: @MainActor (Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(use.title, systemImage: "sparkles")
                .font(KitchenTableTheme.sectionTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text(use.disclosure)
                .font(KitchenTableTheme.instructionBody)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .fixedSize(horizontal: false, vertical: true)
            Text(ThirdPartyAIUse.sharedTerms)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Link("Read Spoonjoy's privacy policy", destination: URL(string: "https://spoonjoy.app/privacy")!)
                .font(KitchenTableTheme.uiLabel)
            Spacer(minLength: 0)
            Button {
                dismiss()
                decide(true)
            } label: {
                Text("Allow AI features").frame(maxWidth: .infinity)
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
            .accessibilityIdentifier("aiConsent.allow")
            Button {
                dismiss()
                decide(false)
            } label: {
                Text("Not now").frame(maxWidth: .infinity)
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
            .accessibilityIdentifier("aiConsent.decline")
        }
        .padding(KitchenTableTheme.pagePadding)
        .background(KitchenTableTheme.bone)
    }
}
