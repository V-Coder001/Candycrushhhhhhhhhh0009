import Match3Core
import SwiftUI

/// Prototype corner for mixed candies: explains the rule and lists the lab levels.
struct MixLabView: View {
    @EnvironmentObject private var progress: ProgressStore
    let onSelect: (Level) -> Void

    init(onSelect: @escaping (Level) -> Void) {
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    rule
                    ForEach(Level.mixLab) { level in
                        row(level)
                    }
                    Text("Prototyp: Die Mischbonbons gibt es vorerst nur hier im Labor.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .background(CandyBackdrop(accent: Theme.neonViolet))
            .navigationTitle("Mischlabor")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var rule: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                candy(.plain(.red))
                Image(systemName: "plus").font(.system(size: 16, weight: .black)).foregroundStyle(Theme.muted)
                candy(.plain(.yellow))
                Image(systemName: "arrow.right").font(.system(size: 16, weight: .black)).foregroundStyle(Theme.muted)
                candy(.mix(.red, .yellow))
            }
            .frame(maxWidth: .infinity)
            Text("Bildet dein Tausch gleichzeitig zwei Reihen in verschiedenen Farben, die sich berühren, "
                + "entsteht dort ein Mischbonbon.")
            Text("Es passt zu beiden Farben. Bring es in eine Reihe, um es zu servieren.")
        }
        .font(Theme.title(16, weight: .bold))
        .foregroundStyle(Theme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func candy(_ kind: PieceKind) -> some View {
        Image(uiImage: CandyArt.shared.image(for: kind, size: 44))
    }

    private func row(_ level: Level) -> some View {
        let stars = progress.stars[level.id] ?? 0
        return Button { onSelect(level) } label: {
            HStack(spacing: 12) {
                Text("\(level.id - Level.mixLabFirstID + 1)")
                    .font(Theme.title(22, weight: .black))
                    .candyText(Color(uiColor: Theme.candy(.purple).darker(0.4)))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(uiColor: Theme.candy(.purple))))
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.name)
                        .font(Theme.title(17, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(level.goals.map(\.summary).joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(i < stars ? Theme.star : Color.white.opacity(0.2))
                    }
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 18, glow: 0.2)
        }
        .buttonStyle(CandyPressStyle())
    }
}

/// Small pill on the map that opens the Mischlabor.
struct MixLabButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(uiImage: CandyArt.shared.image(for: .mix(.red, .yellow), size: 28))
                Text("Mischlabor")
                    .font(Theme.title(17, weight: .black))
                    .candyText(Color(uiColor: Theme.candy(.purple).darker(0.45)))
                Text("NEU")
                    .font(Theme.title(11, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accent))
            }
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [Color(uiColor: Theme.candy(.purple).lighter(0.3)),
                                                  Color(uiColor: Theme.candy(.purple))],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().stroke(.white, lineWidth: 2.5))
                    .shadow(color: Color(uiColor: Theme.candy(.purple).darker(0.4)), radius: 0, y: 3)
            )
        }
        .buttonStyle(CandyPressStyle())
        .accessibilityLabel("Mischlabor öffnen")
    }
}
