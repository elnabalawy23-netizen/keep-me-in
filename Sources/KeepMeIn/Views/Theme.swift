import SwiftUI

/// Warm dark palette shared by the menu panel.
enum Theme {
    static let background = Color(red: 0.133, green: 0.118, blue: 0.106)   // #221E1B
    static let card = Color.white.opacity(0.06)
    static let control = Color.white.opacity(0.09)
    static let separator = Color.white.opacity(0.08)
    static let accent = Color(red: 0.914, green: 0.796, blue: 0.635)       // #E9CBA2
    static let onAccent = Color(red: 0.17, green: 0.14, blue: 0.12)
    static let text = Color(red: 0.95, green: 0.92, blue: 0.88)
    static let muted = Color(red: 0.62, green: 0.58, blue: 0.54)
    static let icon = Color(red: 0.74, green: 0.70, blue: 0.66)
    static let warning = Color(red: 0.95, green: 0.62, blue: 0.32)
    static let danger = Color(red: 0.93, green: 0.42, blue: 0.38)
}
