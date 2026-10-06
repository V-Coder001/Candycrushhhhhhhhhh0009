import Match3Core
import SwiftUI
import UIKit

/// Neon candy: a deep violet night with pink, cyan and violet glow, glass panels and glossy sweets.
enum Theme {
    static let nightTopUI = UIColor(hex: 0x0C0522)
    static let nightMidUI = UIColor(hex: 0x1D0C48)
    static let nightBottomUI = UIColor(hex: 0x36105E)
    static let neonPinkUI = UIColor(hex: 0xFF3DA5)
    static let neonCyanUI = UIColor(hex: 0x2DE2FF)
    static let neonVioletUI = UIColor(hex: 0x8A5CFF)
    static let neonMintUI = UIColor(hex: 0x2EE6A6)
    static let neonAmberUI = UIColor(hex: 0xFFB347)
    static let bannerTopUI = UIColor(hex: 0x9B6BFF)
    static let bannerBottomUI = UIColor(hex: 0x5A2FD8)
    static let bannerEdgeUI = UIColor(hex: 0x2A1172)
    static let boardUI = UIColor(hex: 0x150A36, alpha: 0.72)
    static let tileUI = UIColor(white: 1, alpha: 0.08)
    static let tileAltUI = UIColor(white: 1, alpha: 0.05)
    static let inkUI = UIColor(hex: 0xF7F2FF)
    static let mutedUI = UIColor(hex: 0xB4A4E4)
    /// Dark text for light surfaces such as pale number tiles.
    static let darkInkUI = UIColor(hex: 0x2A1A4E)
    static let accentUI = UIColor(hex: 0xFF3DA5)
    static let jellyUI = UIColor(hex: 0xFF7EC8)
    static let starUI = UIColor(hex: 0xFFC727)
    static let greenButtonUI = UIColor(hex: 0x22D88F)
    static let lockedUI = UIColor(hex: 0x4A3F7A)

    static let nightTop = Color(uiColor: nightTopUI)
    static let nightMid = Color(uiColor: nightMidUI)
    static let nightBottom = Color(uiColor: nightBottomUI)
    static let neonPink = Color(uiColor: neonPinkUI)
    static let neonCyan = Color(uiColor: neonCyanUI)
    static let neonViolet = Color(uiColor: neonVioletUI)
    static let neonMint = Color(uiColor: neonMintUI)
    static let neonAmber = Color(uiColor: neonAmberUI)
    static let darkInk = Color(uiColor: darkInkUI)
    static let bannerTop = Color(uiColor: bannerTopUI)
    static let bannerBottom = Color(uiColor: bannerBottomUI)
    static let bannerEdge = Color(uiColor: bannerEdgeUI)
    static let ink = Color(uiColor: inkUI)
    static let muted = Color(uiColor: mutedUI)
    static let accent = Color(uiColor: accentUI)
    static let star = Color(uiColor: starUI)
    static let jelly = Color(uiColor: jellyUI)
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
    /// White lettering with a soft coloured glow, readable on the night backdrop and on candy buttons.
    func candyText(_ glow: Color = Theme.neonViolet) -> some View {
        foregroundStyle(.white)
            .shadow(color: glow.opacity(0.9), radius: 0, y: 1.5)
            .shadow(color: glow.opacity(0.7), radius: 6)
    }

    /// Frosted dark glass with a neon rim and a soft glow in `tint`.
    func glassCard(cornerRadius: CGFloat = 24, tint: Color = Theme.neonViolet, glow: Double = 0.35) -> some View {
        background(GlassShape(cornerRadius: cornerRadius, tint: tint, glow: glow))
    }
}

/// Background of `glassCard`, also usable on its own.
struct GlassShape: View {
    var cornerRadius: CGFloat = 24
    var tint: Color = Theme.neonViolet
    var glow: Double = 0.35

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(Color(uiColor: UIColor(hex: 0x1A0C42, alpha: 0.62)))
            .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.03)],
                                               startPoint: .top, endPoint: .bottom)))
            .overlay(shape.strokeBorder(LinearGradient(colors: [tint.opacity(0.95), Theme.neonCyan.opacity(0.35),
                                                                tint.opacity(0.5)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 1.5))
            .shadow(color: tint.opacity(glow), radius: 16)
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
