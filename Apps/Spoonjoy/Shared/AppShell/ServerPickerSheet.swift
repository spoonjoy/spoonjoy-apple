import OuroHX
import SpoonjoyCore
import SwiftUI

/// Where the cook chooses the server they sign in to: the app's own (spoonjoy.app) or a Spoonjoy server they run.
/// An address they type is checked before anything changes, and a problem stays in the sheet, in words.
struct ServerPickerSheet: View {
    static let builtInIdentifier = "server.builtIn"
    static let ownServerIdentifier = "server.own"
    static let addressIdentifier = "server.address"
    static let problemIdentifier = "server.problem"
    static let useIdentifier = "server.use"
    static let cancelIdentifier = "server.cancel"

    private enum Choice: Equatable {
        case builtIn
        case own
    }

    let builtIn: SpoonjoyServerAddress
    let current: SpoonjoyServerAddress
    /// Called with the checked server, or nil for the app's own, once the cook confirms; the sheet then closes.
    let onChoose: @MainActor (SpoonjoyServerAddress?) async -> Void
    let cancel: @MainActor () -> Void

    @State private var choice: Choice
    @State private var address: String
    @State private var problem: String?
    @State private var isChecking = false
    @FocusState private var addressFocused: Bool

    init(
        builtIn: SpoonjoyServerAddress,
        current: SpoonjoyServerAddress,
        onChoose: @escaping @MainActor (SpoonjoyServerAddress?) async -> Void,
        cancel: @escaping @MainActor () -> Void
    ) {
        self.builtIn = builtIn
        self.current = current
        self.onChoose = onChoose
        self.cancel = cancel
        let usesOwn = current != builtIn
        _choice = State(initialValue: usesOwn ? .own : .builtIn)
        _address = State(initialValue: usesOwn ? current.displayName : "")
    }

    var body: some View {
        KitchenTablePage(maxContentWidth: 560, bottomReserve: 32) {
            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                    .font(KitchenTableTheme.bodyNote.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.ink)
                    .disabled(isChecking)
                    .accessibilityIdentifier(Self.cancelIdentifier)
            }

            KitchenTableHeader(
                eyebrow: "Sign in",
                title: "Your server",
                subtitle: "Your recipes live on a Spoonjoy server. Use \(builtIn.displayName), or one you run yourself."
            )

            OuroCard {
                choiceRow(
                    .builtIn,
                    title: builtIn.displayName,
                    detail: "Spoonjoy's own server.",
                    identifier: Self.builtInIdentifier
                )
                Divider().overlay(KitchenTableTheme.hairline)
                choiceRow(
                    .own,
                    title: "Your own server",
                    detail: "A Spoonjoy server at home or on the web.",
                    identifier: Self.ownServerIdentifier
                )
                if choice == .own {
                    addressField
                }
            }
            .settingsCardText()

            if let problem {
                Label {
                    Text(problem)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(KitchenTableTheme.meta)
                .foregroundStyle(KitchenTableTheme.tomato)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(Self.problemIdentifier)
            }

            useButton
        }
        .interactiveDismissDisabled(isChecking)
    }

    private func choiceRow(_ row: Choice, title: String, detail: String, identifier: String) -> some View {
        Button {
            choice = row
            problem = nil
            addressFocused = row == .own
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(KitchenTableTheme.bodyNote.weight(.semibold))
                        .foregroundStyle(KitchenTableTheme.ink)
                    Text(detail)
                        .font(KitchenTableTheme.meta)
                        .foregroundStyle(KitchenTableTheme.ink2)
                }
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(KitchenTableTheme.bodyNote.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.herb)
                    .opacity(choice == row ? 1 : 0)
            }
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isChecking)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(choice == row ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private var addressField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Address")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
            TextField("Address", text: $address, prompt: Text("recipes.example.com or 192.168.1.20:8080").foregroundStyle(KitchenTableTheme.ink2))
                .textFieldStyle(.plain)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.ink)
                .autocorrectionDisabled()
                .serverAddressEntry()
                .focused($addressFocused)
                .submitLabel(.go)
                .onSubmit {
                    Task { await use() }
                }
                .disabled(isChecking)
                .padding(.horizontal, 12)
                .frame(minHeight: 46)
                .background(KitchenTableTheme.page.opacity(0.45), in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel, style: .continuous)
                        .strokeBorder(KitchenTableTheme.hairline.opacity(0.55), lineWidth: 1)
                }
                .accessibilityIdentifier(Self.addressIdentifier)
            Text("Type it as you'd open it in a browser. A server on your home network can use plain http://.")
                .font(KitchenTableTheme.meta)
                .foregroundStyle(KitchenTableTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canUse: Bool {
        choice == .builtIn || !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var useButton: some View {
        Button {
            Task { await use() }
        } label: {
            HStack(spacing: 10) {
                if isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(isChecking ? "Checking the server" : "Use This Server")
                    .font(KitchenTableTheme.control)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(canUse && !isChecking ? KitchenTableTheme.onInk : KitchenTableTheme.ink.opacity(0.46))
        .background(canUse ? KitchenTableTheme.action : KitchenTableTheme.ink.opacity(0.08), in: Capsule(style: .continuous))
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .disabled(isChecking || !canUse)
        .accessibilityIdentifier(Self.useIdentifier)
    }

    private func use() async {
        guard !isChecking, canUse else {
            return
        }
        problem = nil
        guard choice == .own else {
            await onChoose(nil)
            return
        }
        let parsed: SpoonjoyServerAddress
        do {
            parsed = try SpoonjoyServerAddress.parse(address)
        } catch {
            problem = error.message
            return
        }
        isChecking = true
        defer { isChecking = false }
        do {
            try await SpoonjoyServerCheck.check(parsed)
        } catch {
            problem = error.message
            AccessibilityNotification.Announcement(error.message).post()
            return
        }
        await onChoose(parsed == builtIn ? nil : parsed)
    }
}

private extension View {
    @ViewBuilder func serverAddressEntry() -> some View {
#if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .textContentType(.URL)
#else
        self
#endif
    }
}
