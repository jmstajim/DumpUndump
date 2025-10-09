import SwiftUI

enum Theme {
    static let accent = Color.accentColor

    static var windowBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0.1),
                Color.black.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FormCard: ViewModifier {
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return content
            .padding(padding)
            .background(
                Group {
                    shape.fill(.ultraThinMaterial)
                }
            )
            .overlay(
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                shape
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                    .blendMode(.overlay)
            )
    }
}

extension View {
    func formCard(padding: CGFloat = 12) -> some View {
        modifier(FormCard(padding: padding))
    }
}
