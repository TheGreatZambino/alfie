import SwiftUI

private let inkShadow = Color(red: 35 / 255, green: 33 / 255, blue: 30 / 255)

struct CardBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.45) : inkShadow.opacity(0.05),
                radius: colorScheme == .dark ? 13 : 11,
                y: colorScheme == .dark ? 10 : 8
            )
    }
}

/// Full-bleed hero card filled with a pillar color (e.g. Finances balance, Workouts start).
/// `pillar` should be one of the constant `*Fill` tokens — these cards keep their light-mode
/// hue in dark mode rather than shifting to the lifted pillar color.
struct HeroCardBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var pillar: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(pillar)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: pillar.opacity(colorScheme == .dark ? 0.34 : 0.24), radius: colorScheme == .dark ? 15 : 13, y: 10)
    }
}

extension View {
    /// Standard white card: 1pt border, soft shadow. Default radius 26 for primary cards;
    /// pass 18-22 for sub-cards/tiles.
    func cardStyle(radius: CGFloat = 26) -> some View {
        modifier(CardBackground(radius: radius))
    }

    /// Full-bleed pillar-colored card (Finances balance, Workouts start, ActiveWorkout header).
    func heroCardStyle(pillar: Color, radius: CGFloat = 26) -> some View {
        modifier(HeroCardBackground(pillar: pillar, radius: radius))
    }
}

enum BackplateShape {
    case circle
    case roundedSquare(radius: CGFloat)
}

/// A small icon badge, used for bill/category/pillar glyphs.
struct IconBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    let color: Color
    var size: CGFloat = 36
    var shape: BackplateShape = .circle

    var body: some View {
        ZStack {
            backplateShape
                .fill(color.opacity(colorScheme == .dark ? 0.18 : 0.12))
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }

    private var backplateShape: AnyShape {
        switch shape {
        case .circle:
            AnyShape(Circle())
        case .roundedSquare(let radius):
            AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}
