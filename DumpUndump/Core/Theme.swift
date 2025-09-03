import SwiftUI

enum Theme {
    static let accent = Color.accentColor
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let cardStroke = Color.gray.opacity(0.15)
}

struct FormCard: ViewModifier {
    var padding: CGFloat = 12
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

extension View {
    func formCard(padding: CGFloat = 12) -> some View {
        modifier(FormCard(padding: padding))
    }
}

