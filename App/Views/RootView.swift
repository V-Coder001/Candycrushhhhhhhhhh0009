import Match3Core
import SwiftUI

/// Level overview: a quiet grid of levels with their stars.
struct RootView: View {
    @EnvironmentObject private var progress: ProgressStore
    @State private var playing: Level?
    @State private var showSettings = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 3)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(Level.campaign) { level in
                            LevelTile(level: level,
                                      stars: progress.stars[level.id] ?? 0,
                                      unlocked: progress.isUnlocked(level)) {
                                playing = level
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .fullScreenCover(item: $playing) { level in
            GameView(level: level,
                     onClose: { playing = nil },
                     onNext: nextAction(after: level))
                .id(level.id)
                .environmentObject(progress)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium])
        }
    }

    private func nextAction(after level: Level) -> (() -> Void)? {
        guard let next = progress.nextLevel(after: level) else { return nil }
        return { playing = next }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sött")
                    .font(Theme.title(44, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Ein ruhiges Bonbon-Puzzle")
                    .font(Theme.title(16, weight: .regular))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Label("\(progress.totalStars)", systemImage: "star.fill")
                .font(Theme.title(16))
                .foregroundStyle(Theme.star)
                .padding(.trailing, 8)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.surface))
            }
            .accessibilityLabel("Einstellungen")
        }
    }
}

private struct LevelTile: View {
    let level: Level
    let stars: Int
    let unlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text("\(level.id)")
                    .font(Theme.title(28, weight: .semibold))
                    .foregroundStyle(unlocked ? Theme.ink : Theme.muted.opacity(0.6))
                if unlocked {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < stars ? "star.fill" : "star")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(i < stars ? Theme.star : Theme.muted.opacity(0.4))
                        }
                    }
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted.opacity(0.6))
                }
                Text(level.name)
                    .font(Theme.title(11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: .black.opacity(unlocked ? 0.05 : 0), radius: 8, y: 3)
            )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel("Level \(level.id), \(level.name), \(stars) Sterne")
    }
}

struct SettingsView: View {
    @AppStorage(SettingsKey.sound) private var sound = true
    @AppStorage(SettingsKey.voice) private var voice = true
    @AppStorage(SettingsKey.haptics) private var haptics = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Soundeffekte", isOn: $sound)
                    Toggle("Stimme bei Kombos", isOn: $voice)
                    Toggle("Haptisches Feedback", isOn: $haptics)
                }
                Section {
                    Text("Tausche zwei benachbarte Bonbons, um drei oder mehr gleiche in eine Reihe zu bringen. Vier, fünf oder L-Formen ergeben Spezial-Bonbons.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.accent)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
