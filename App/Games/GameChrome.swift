import SwiftUI
import UIKit

/// Top bar shared by the new games: close on the left, the title in the middle, actions on the right.
struct GameTopBar<Trailing: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            CandyIconButton(symbol: "xmark", color: Theme.accentUI, label: "Zurück zur Spielesammlung", size: 46,
                            action: onClose)
            Spacer(minLength: 4)
            Text(title)
                .font(Theme.title(24, weight: .black))
                .candyText()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

/// Blue score capsule ("Punkte 1.240").
struct ScoreBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(Theme.title(12, weight: .heavy))
                .foregroundStyle(.white.opacity(0.9))
            Text(value)
                .font(Theme.title(22, weight: .black))
                .monospacedDigit()
                .candyText()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(minWidth: 96)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.banner)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white, lineWidth: 2.5))
                .shadow(color: Theme.bannerEdge.opacity(0.5), radius: 0, y: 3)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Card shown when a game ends: title, a line of text and the buttons.
struct GameOverCard: View {
    let title: String
    let message: String
    let primary: String
    let onPrimary: () -> Void
    var secondary: String?
    var onSecondary: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            CandyPanel(title: title) {
                VStack(spacing: 18) {
                    Text(message)
                        .font(Theme.title(19, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    CandyCapsuleButton(title: primary, color: Theme.greenButtonUI, icon: "arrow.clockwise",
                                       action: onPrimary)
                    if let secondary, let onSecondary {
                        CandyCapsuleButton(title: secondary, color: Theme.accentUI, action: onSecondary)
                    }
                }
            }
            .padding(24)
        }
        .transition(.opacity)
    }
}

/// Points with a thousands separator, the German way.
func formatPoints(_ value: Int) -> String {
    value.formatted(.number.locale(Locale(identifier: "de_DE")))
}
