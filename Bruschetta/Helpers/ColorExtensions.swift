import SwiftUI

extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    /// A color that resolves to a different hex value in dark mode.
    static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }

    /// A color whose light/dark values share one RGB base but differ only in opacity
    /// (e.g. the pillar tints, which stay the same hue and simply grow stronger in dark mode).
    static func dynamic(r: Double, g: Double, b: Double, lightOpacity: Double, darkOpacity: Double) -> Color {
        Color(UIColor { traits in
            let opacity = traits.userInterfaceStyle == .dark ? darkOpacity : lightOpacity
            return UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: opacity)
        })
    }

    /// A color with independent RGB + opacity per mode (e.g. hairlines, which flip from
    /// ink-tinted in light mode to white-tinted in dark mode).
    static func dynamic(lightR: Double, lightG: Double, lightB: Double, lightOpacity: Double,
                         darkR: Double, darkG: Double, darkB: Double, darkOpacity: Double) -> Color {
        Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: darkR / 255, green: darkG / 255, blue: darkB / 255, alpha: darkOpacity)
            } else {
                return UIColor(red: lightR / 255, green: lightG / 255, blue: lightB / 255, alpha: lightOpacity)
            }
        })
    }

    // MARK: - Alfie design tokens

    static let paper = Color.dynamic(light: "#F7F4EE", dark: "#1A1917")
    static let card = Color.dynamic(light: "#FFFFFF", dark: "#24221F")
    /// Selected-segment fill in a segmented control (e.g. Settings > Appearance). Dark-only per design; falls back to `card` in light.
    static let elevated = Color.dynamic(light: "#FFFFFF", dark: "#3A3733")

    static let ink = Color.dynamic(light: "#23211E", dark: "#F2EEE7")
    static let inkSecondary = Color.dynamic(light: "#57534D", dark: "#B8B2A7")
    static let inkTertiary = Color(hex: "#8A847A") // unchanged — reads on both grounds
    static let inkQuaternary = Color.dynamic(light: "#B4ADA0", dark: "#6B655C")

    static let hairline = Color.dynamic(lightR: 35, lightG: 33, lightB: 30, lightOpacity: 0.06,
                                         darkR: 255, darkG: 255, darkB: 255, darkOpacity: 0.08)
    static let cardBorder = Color.dynamic(lightR: 35, lightG: 33, lightB: 30, lightOpacity: 0.07,
                                           darkR: 255, darkG: 255, darkB: 255, darkOpacity: 0.09)
    static let fill = Color.dynamic(lightR: 35, lightG: 33, lightB: 30, lightOpacity: 0.05,
                                     darkR: 255, darkG: 255, darkB: 255, darkOpacity: 0.07)

    // MARK: - Pillar colors

    /// Lifted for legibility on dark surfaces. Use for glyphs, labels, ring strokes, progress fills, and tinted backplates.
    static let money = Color.dynamic(light: "#0E7C6B", dark: "#14A18B")
    static let training = Color.dynamic(light: "#C05E45", dark: "#E0785C")
    static let food = Color.dynamic(light: "#A07A22", dark: "#C9A03A")

    /// Solid brand fills that stay constant across modes: the Finances balance card, the Workouts
    /// start card, both floating action buttons, and primary buttons. Never use these for text,
    /// glyphs, or tints — use `money` / `training` / `food` for those.
    static let moneyFill = Color(hex: "#0E7C6B")
    static let trainingFill = Color(hex: "#C05E45")
    static let foodFill = Color(hex: "#A07A22")

    static let moneyTint = Color.dynamic(r: 14, g: 124, b: 107, lightOpacity: 0.12, darkOpacity: 0.18)
    static let trainingTint = Color.dynamic(r: 192, g: 94, b: 69, lightOpacity: 0.12, darkOpacity: 0.18)
    static let foodTint = Color.dynamic(r: 160, g: 122, b: 34, lightOpacity: 0.12, darkOpacity: 0.18)

    /// Temporary alias kept while the app migrates off the old single-accent scheme.
    /// TODO(remove after redesign): delete once no call sites reference `appAccent`.
    static let appAccent = Color.money

    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
