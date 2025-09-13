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
            .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
}

extension View {
    func formCard(padding: CGFloat = 12) -> some View {
        modifier(FormCard(padding: padding))
    }
}

