import SwiftUI

/// Shared translucent fill for Groups cards and Saved item containers.
struct GroupCardMaterial<SurfaceShape: Shape>: View {
    let shape: SurfaceShape
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            shape.fill(Color(.secondarySystemGroupedBackground))
        } else {
            ZStack {
                shape.fill(.ultraThinMaterial)
                    .opacity(colorScheme == .dark ? 0.55 : 0.85)
                shape.fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.05 : 0.3),
                            .white.opacity(colorScheme == .dark ? 0.015 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
    }
}

struct GroupCardSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background { GroupCardMaterial(shape: shape) }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: borderColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 0.75
                )
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.14 : 0.06), radius: 12, y: 6)
    }

    private var borderColors: [Color] {
        if contrast == .increased {
            return [.primary.opacity(0.65), .primary.opacity(0.45)]
        }
        return colorScheme == .dark
            ? [.white.opacity(0.3), .white.opacity(0.09), .white.opacity(0.17)]
            : [.white.opacity(0.85), .black.opacity(0.08), .white.opacity(0.5)]
    }
}

extension View {
    func groupCardSurface(cornerRadius: CGFloat = 26) -> some View {
        modifier(GroupCardSurface(cornerRadius: cornerRadius))
    }
}
