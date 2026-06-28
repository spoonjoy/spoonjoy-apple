import SpoonjoyCore
import SwiftUI

struct ShareActions: View {
    let route: AppRoute

    @ViewBuilder
    var body: some View {
        if let publicURL = NativeSharePayload.publicRoute(route)?.publicURL {
            ShareLink(item: publicURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}
