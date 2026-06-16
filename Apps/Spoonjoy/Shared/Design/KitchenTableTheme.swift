import SwiftUI

enum KitchenTableTheme {
    static let bone = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let charcoal = Color(red: 0.13, green: 0.12, blue: 0.10)
    static let brass = Color(red: 0.62, green: 0.45, blue: 0.20)
    static let tomato = Color(red: 0.75, green: 0.18, blue: 0.12)
    static let herb = Color(red: 0.24, green: 0.38, blue: 0.22)
    static let photoOverlay = Color.black.opacity(0.28)

    enum Radius {
        static let edge: CGFloat = 0
        static let media: CGFloat = 4
        static let panel: CGFloat = 8
        static let control: CGFloat = 999
    }

    static let displayTitle = Font.largeTitle
    static let bodyNote = Font.body
    static let uiLabel = Font.caption
}
