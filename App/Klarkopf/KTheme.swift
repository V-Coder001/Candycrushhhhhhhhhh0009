import Match3Core
import SwiftUI
import UIKit

/// Klarkopf: calm, warm and easy to read. Text styles follow Dynamic Type; the app starts at a larger size.
enum KTheme {
    static let backgroundUI = UIColor(hex: 0xF7F3EC)
    static let accentUI = UIColor(hex: 0x1F6F68)

    static let background = Color(uiColor: backgroundUI)
    static let card = Color.white
    static let ink = Color(uiColor: UIColor(hex: 0x23222B))
    static let secondary = Color(uiColor: UIColor(hex: 0x4F4E59))
    static let accent = Color(uiColor: accentUI)
    static let accentSoft = Color(uiColor: UIColor(hex: 0xDCEDEA))
    static let good = Color(uiColor: UIColor(hex: 0x2B7A4B))
    static let goodSoft = Color(uiColor: UIColor(hex: 0xDFF1E5))
    static let hint = Color(uiColor: UIColor(hex: 0x8A5300))
    static let hintSoft = Color(uiColor: UIColor(hex: 0xFBEFD5))
    static let line = Color(uiColor: UIColor(hex: 0xE2DBCF))

    static let title = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let heading = Font.system(.title2, design: .rounded, weight: .semibold)
    static let body = Font.system(.title3, design: .rounded)
    static let bodyBold = Font.system(.title3, design: .rounded, weight: .semibold)
    static let small = Font.system(.body, design: .rounded)
}

extension BrainGame {
    var title: String {
        switch self {
        case .pairs: return "Paare finden"
        case .shoppingList: return "Einkaufsliste"
        case .sequence: return "Reihenfolge nachtippen"
        case .change: return "Wechselgeld"
        }
    }

    var area: String {
        switch self {
        case .pairs: return "Kurzzeitgedächtnis"
        case .shoppingList: return "Merken und Abrufen"
        case .sequence: return "Arbeitsgedächtnis"
        case .change: return "Rechnen im Alltag"
        }
    }

    var symbol: String {
        switch self {
        case .pairs: return "square.grid.2x2.fill"
        case .shoppingList: return "cart.fill"
        case .sequence: return "hand.tap.fill"
        case .change: return "eurosign.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pairs: return Color(uiColor: UIColor(hex: 0x1F6F68))
        case .shoppingList: return Color(uiColor: UIColor(hex: 0x9A4F12))
        case .sequence: return Color(uiColor: UIColor(hex: 0x3E5BA9))
        case .change: return Color(uiColor: UIColor(hex: 0x7A3E8E))
        }
    }
}

/// Large full-width button. Primary is filled, secondary outlined.
struct KButton: View {
    enum Kind { case primary, secondary }

    let title: String
    var systemImage: String?
    var kind: Kind = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(KTheme.bodyBold)
            .foregroundStyle(kind == .primary ? Color.white : KTheme.accent)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(kind == .primary ? KTheme.accent : KTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(KTheme.accent, lineWidth: kind == .primary ? 0 : 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(KPressStyle())
    }
}

struct KPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// White card on the warm background.
struct KCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(KTheme.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(KTheme.line, lineWidth: 1))
    }
}

/// Title and one line of instructions at the top of every game.
struct KGameTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(KTheme.heading)
                .foregroundStyle(KTheme.ink)
            Text(subtitle)
                .font(KTheme.body)
                .foregroundStyle(KTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Round icon in the game's colour.
struct KGameIcon: View {
    let game: BrainGame
    var size: CGFloat = 56

    var body: some View {
        Image(systemName: game.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(game.tint))
            .accessibilityHidden(true)
    }
}
