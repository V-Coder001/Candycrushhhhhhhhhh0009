import Match3Core
import SwiftUI
import UIKit

/// Calm, warm and uncluttered: soft paper background, muted candy colours, rounded type.
enum Theme {
    static let backgroundUI = dynamic(light: 0xF5F1EA, dark: 0x1B1A18)
    static let surfaceUI = dynamic(light: 0xFFFDF9, dark: 0x262522)
    static let tileUI = dynamic(light: 0xECE5DA, dark: 0x2D2B28)
    static let tileAltUI = dynamic(light: 0xE5DDD0, dark: 0x32302C)
    static let inkUI = dynamic(light: 0x2F2B26, dark: 0xEDE8E0)
    static let mutedUI = dynamic(light: 0x8A8279, dark: 0x9C958B)
    static let accentUI = UIColor(hex: 0xC47F68)
    static let jellyUI = UIColor(hex: 0xE3A0B4)
    static let starUI = UIColor(hex: 0xE2B355)

    static let background = Color(uiColor: backgroundUI)
    static let surface = Color(uiColor: surfaceUI)
    static let ink = Color(uiColor: inkUI)
    static let muted = Color(uiColor: mutedUI)
    static let accent = Color(uiColor: accentUI)
    static let star = Color(uiColor: starUI)
    static let jelly = Color(uiColor: jellyUI)

    static func candy(_ color: CandyColor) -> UIColor {
        switch color {
        case .red: return UIColor(hex: 0xDD7466)
        case .orange: return UIColor(hex: 0xE8A15A)
        case .yellow: return UIColor(hex: 0xE8C762)
        case .green: return UIColor(hex: 0x86BA84)
        case .blue: return UIColor(hex: 0x74A2D6)
        case .purple: return UIColor(hex: 0xA68ECB)
        }
    }

    /// Main tint of a piece, used for particles.
    static func tint(for kind: PieceKind) -> UIColor {
        switch kind {
        case let .candy(color, _): return candy(color)
        case .colorBomb: return UIColor(hex: 0x6B4636)
        case .ingredient(.cherry): return UIColor(hex: 0xD2504F)
        case .ingredient(.hazelnut): return UIColor(hex: 0xB07A4A)
        case .chocolate: return UIColor(hex: 0x7A4B37)
        case .blocker: return UIColor(hex: 0xF1E8DA)
        }
    }

    static func title(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
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
