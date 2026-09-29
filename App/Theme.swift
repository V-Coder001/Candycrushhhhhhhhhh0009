import Match3Core
import SwiftUI
import UIKit

/// Bright, glossy candy-shop look: sky backdrop, saturated sweets, blue banners, white rounded type.
enum Theme {
    static let skyTopUI = UIColor(hex: 0x6CCBFF)
    static let skyBottomUI = UIColor(hex: 0xD4F1FF)
    static let seaUI = UIColor(hex: 0xF46CC6)
    static let seaLightUI = UIColor(hex: 0xFFA6E4)
    static let bannerTopUI = UIColor(hex: 0x63CEFF)
    static let bannerBottomUI = UIColor(hex: 0x2485E0)
    static let bannerEdgeUI = UIColor(hex: 0x1664B8)
    static let boardUI = UIColor(hex: 0x1A5A9C, alpha: 0.42)
    static let tileUI = UIColor(hex: 0xDDF2FF, alpha: 0.72)
    static let tileAltUI = UIColor(hex: 0xC4E6FF, alpha: 0.62)
    static let inkUI = UIColor(hex: 0x3A2A5C)
    static let mutedUI = UIColor(hex: 0x7A6E96)
    static let accentUI = UIColor(hex: 0xFF4FA3)
    static let jellyUI = UIColor(hex: 0xFF7EC8)
    static let starUI = UIColor(hex: 0xFFC727)
    static let greenButtonUI = UIColor(hex: 0x3CCB4A)

    static let skyTop = Color(uiColor: skyTopUI)
    static let skyBottom = Color(uiColor: skyBottomUI)
    static let sea = Color(uiColor: seaUI)
    static let seaLight = Color(uiColor: seaLightUI)
    static let bannerTop = Color(uiColor: bannerTopUI)
    static let bannerBottom = Color(uiColor: bannerBottomUI)
    static let bannerEdge = Color(uiColor: bannerEdgeUI)
    static let ink = Color(uiColor: inkUI)
    static let muted = Color(uiColor: mutedUI)
    static let accent = Color(uiColor: accentUI)
    static let star = Color(uiColor: starUI)
    static let jelly = Color(uiColor: jellyUI)
    static let surface = Color.white
    static let greenButton = Color(uiColor: greenButtonUI)

    static var banner: LinearGradient {
        LinearGradient(colors: [bannerTop, bannerBottom], startPoint: .top, endPoint: .bottom)
    }

    static func candy(_ color: CandyColor) -> UIColor {
        switch color {
        case .red: return UIColor(hex: 0xF0303A)
        case .orange: return UIColor(hex: 0xFF8A14)
        case .yellow: return UIColor(hex: 0xFFD21A)
        case .green: return UIColor(hex: 0x2FBF45)
        case .blue: return UIColor(hex: 0x228BF2)
        case .purple: return UIColor(hex: 0xA13FE0)
        }
    }

    /// Main tint of a piece, used for particles.
    static func tint(for kind: PieceKind) -> UIColor {
        switch kind {
        case let .candy(color, _): return candy(color)
        case .colorBomb: return UIColor(hex: 0x6B3A22)
        case .ingredient(.cherry): return UIColor(hex: 0xE3242B)
        case .ingredient(.hazelnut): return UIColor(hex: 0xB0703A)
        case .chocolate: return UIColor(hex: 0x6E3B22)
        case .blocker: return UIColor(hex: 0xFFFFFF)
        case let .mix(a, b): return candy(a).mixed(with: candy(b), amount: 0.5)
        }
    }

    static func title(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    /// White candy-shop lettering with a dark outline, readable on any backdrop.
    func candyText(_ outline: Color = Theme.bannerEdge) -> some View {
        foregroundStyle(.white)
            .shadow(color: outline, radius: 0, x: 1.5, y: 1.5)
            .shadow(color: outline, radius: 0, x: -1, y: -1)
            .shadow(color: outline.opacity(0.6), radius: 2, y: 2)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount, alpha: a1 + (a2 - a1) * amount)
    }

    func lighter(_ amount: CGFloat) -> UIColor { mixed(with: .white, amount: amount) }
    func darker(_ amount: CGFloat) -> UIColor { mixed(with: .black, amount: amount) }

    func resolved(dark: Bool) -> UIColor {
        resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
    }
}
