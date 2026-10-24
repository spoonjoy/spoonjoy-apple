import SpoonjoyCore
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Opens a page in a window of its own. Present in the environment only where the device can show two windows of
/// the app at once (the iPhone Duo open in landscape, an iPad), so a menu item reading it hides everywhere else.
struct OpenInNewWindowAction {
    let open: (AppRoute) -> Void

    func callAsFunction(_ route: AppRoute) {
        open(route)
    }
}

private struct OpenInNewWindowKey: EnvironmentKey {
    static let defaultValue: OpenInNewWindowAction? = nil
}

extension EnvironmentValues {
    var openInNewWindow: OpenInNewWindowAction? {
        get { self[OpenInNewWindowKey.self] }
        set { self[OpenInNewWindowKey.self] = newValue }
    }
}

extension View {
    /// Adds "Open in New Window" to this view's context menu when the device can show another window.
    func openInNewWindowMenu(_ route: AppRoute) -> some View {
        modifier(OpenInNewWindowMenu(route: route))
    }
}

private struct OpenInNewWindowMenu: ViewModifier {
    let route: AppRoute
    @Environment(\.openInNewWindow) private var openInNewWindow

    func body(content: Content) -> some View {
        if let openInNewWindow {
            content.contextMenu {
                Button {
                    openInNewWindow(route)
                } label: {
                    Label("Open in New Window", systemImage: "rectangle.split.2x1")
                }
                .accessibilityIdentifier("window.openNew")
            }
        } else {
            content
        }
    }
}

/// The book of where each window was, in the app's state directory.
@MainActor
enum SceneRouteBookLocation {
    static let store = SceneRouteBookStore(
        directory: NativeAppStateLocation.defaultFileURL().deletingLastPathComponent()
    )
}

#if os(iOS)
extension View {
    /// Reports the system's identifier for the window this view is in, which stays the same when the app is killed
    /// and the system brings the window back.
    func readingSceneIdentifier(_ identifier: Binding<String?>) -> some View {
        background(SceneIdentifierProbe(identifier: identifier).allowsHitTesting(false).accessibilityHidden(true))
    }
}

private struct SceneIdentifierProbe: UIViewRepresentable {
    @Binding var identifier: String?

    func makeUIView(context: Context) -> SceneIdentifierView {
        let view = SceneIdentifierView()
        view.onChange = { [binding = $identifier] new in binding.wrappedValue = new }
        return view
    }

    func updateUIView(_ view: SceneIdentifierView, context: Context) {
        view.onChange = { [binding = $identifier] new in binding.wrappedValue = new }
    }
}

private final class SceneIdentifierView: UIView {
    var onChange: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        fatalError("SceneIdentifierView is created in code only")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let identifier = window?.windowScene?.session.persistentIdentifier else {
            return
        }
        // Reported after this layout pass: SwiftUI state must not change while it is updating views.
        DispatchQueue.main.async { [onChange] in
            onChange?(identifier)
        }
    }
}

enum SceneWindowCount {
    /// True when this is the app's only window, so it may take the app's last page.
    @MainActor static var isOnlyWindow: Bool {
        UIApplication.shared.connectedScenes.filter { $0 is UIWindowScene }.count <= 1
    }
}
#endif
