import SwiftUI

extension Font {
    /// Screen headline — 27pt bold, replaces the large title.
    static let screenHeadline = Font.system(size: 27, weight: .bold)

    /// Hero numeral used at screen level (Finances balance, Workouts timer).
    static let heroNumeralScreen = Font.system(size: 52, weight: .bold, design: .rounded)
    /// Hero numeral used inside a card row (Overview pillar rows).
    static let heroNumeralCard = Font.system(size: 24, weight: .bold, design: .rounded)
    /// Card-level numeral (stat tiles, set weights).
    static let cardNumeral = Font.system(size: 23, weight: .bold, design: .rounded)

    static let rowTitle = Font.system(size: 15, weight: .semibold)
    static let rowDetail = Font.system(size: 12, weight: .regular)
}

extension Text {
    /// 13pt semibold uppercase, tracking 0.06em — colored by pillar (or inkTertiary on Overview).
    /// Uppercases eagerly since `Text` (unlike `View`) has no `.textCase` modifier.
    func eyebrowStyle(color: Color = .inkTertiary) -> Text {
        self
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(color)
            .tracking(0.6)
    }

    /// 12pt semibold uppercase, tracking 0.08em, inkTertiary — card headers, settings groups.
    func sectionLabelStyle() -> Text {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.inkTertiary)
            .tracking(0.8)
    }
}
