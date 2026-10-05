import Match3Core
import SwiftUI

/// Klarkopf start screen: greeting, today's training, the single games and the Bonbon-Puzzle.
struct HomeView: View {
    @EnvironmentObject private var training: TrainingStore
    @EnvironmentObject private var progress: ProgressStore
    @State private var showTraining = false
    @State private var single: BrainGame?
    @State private var showPuzzle = false
    @State private var showSettings = false

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                dailyCard
                Text("Einzelne Spiele")
                    .font(KTheme.heading)
                    .foregroundStyle(KTheme.ink)
                    .padding(.top, 6)
                ForEach(BrainGame.allCases) { game in
                    gameRow(game)
                }
                puzzleRow
                Text("Klarkopf ist ein Gedächtnistraining zum Spaß und ersetzt keine ärztliche Beratung.")
                    .font(KTheme.small)
                    .foregroundStyle(KTheme.secondary)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .background(KTheme.background.ignoresSafeArea())
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: $showTraining) {
            DailyTrainingView(plan: training.plan(), listLevel: training.level(.shoppingList),
                              seed: training.seed()) { showTraining = false }
                .environmentObject(training)
        }
        .fullScreenCover(item: $single) { game in
            SingleGameView(game: game) { single = nil }
                .environmentObject(training)
        }
        .fullScreenCover(isPresented: $showPuzzle) {
            RootView(onClose: {
                showPuzzle = false
                SoundManager.shared.stopMusic()
            })
            .environmentObject(progress)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
        .onAppear(perform: openDemo)
    }

    // MARK: Parts

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(KTheme.title)
                    .foregroundStyle(KTheme.ink)
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_DE"))))
                    .font(KTheme.body)
                    .foregroundStyle(KTheme.secondary)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(KTheme.accent)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(KTheme.card))
                    .overlay(Circle().stroke(KTheme.line, lineWidth: 1))
            }
            .buttonStyle(KPressStyle())
            .accessibilityLabel("Einstellungen")
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 { return "Guten Morgen" }
        if hour < 18 { return "Guten Tag" }
        return "Guten Abend"
    }

    private var dailyCard: some View {
        KCard {
            if training.trainedToday {
                Label("Heute geschafft", systemImage: "checkmark.circle.fill")
                    .font(KTheme.heading)
                    .foregroundStyle(KTheme.good)
                Text("Schön, dass Sie dabei waren. Morgen wartet ein neues Training auf Sie.")
                    .font(KTheme.body)
                    .foregroundStyle(KTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                KButton(title: "Noch einmal trainieren", systemImage: "arrow.clockwise", kind: .secondary) {
                    showTraining = true
                }
            } else {
                Text("Ihr Tagestraining")
                    .font(KTheme.heading)
                    .foregroundStyle(KTheme.ink)
                Text("\(training.plan().gameCount) Spiele · etwa 10 Minuten")
                    .font(KTheme.body)
                    .foregroundStyle(KTheme.secondary)
                Text(planNames)
                    .font(KTheme.small)
                    .foregroundStyle(KTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                KButton(title: "Training starten", systemImage: "play.fill") { showTraining = true }
            }
            Text(monthText)
                .font(KTheme.small)
                .foregroundStyle(KTheme.secondary)
        }
    }

    private var monthText: String {
        let days = training.daysThisMonth
        return days == 1 ? "In diesem Monat: 1 Trainingstag" : "In diesem Monat: \(days) Trainingstage"
    }

    private var planNames: String {
        var names: [String] = [BrainGame.shoppingList.title]
        for step in training.plan().steps {
            if case let .play(game) = step { names.append(game.title) }
        }
        return names.joined(separator: " · ")
    }

    private func gameRow(_ game: BrainGame) -> some View {
        Button { single = game } label: {
            HStack(spacing: 16) {
                KGameIcon(game: game)
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.title)
                        .font(KTheme.bodyBold)
                        .foregroundStyle(KTheme.ink)
                    Text("\(game.area) · Stufe \(training.level(game))")
                        .font(KTheme.small)
                        .foregroundStyle(KTheme.secondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(KTheme.secondary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(KTheme.card))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(KTheme.line, lineWidth: 1))
        }
        .buttonStyle(KPressStyle())
    }

    private var puzzleRow: some View {
        Button { showPuzzle = true } label: {
            HStack(spacing: 16) {
                Image(uiImage: CandyArt.shared.image(for: .plain(.red), size: 56))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bonbon-Puzzle")
                        .font(KTheme.bodyBold)
                        .foregroundStyle(KTheme.ink)
                    Text("Entspannung · über 1000 Level")
                        .font(KTheme.small)
                        .foregroundStyle(KTheme.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(KTheme.secondary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(KTheme.card))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(KTheme.line, lineWidth: 1))
        }
        .buttonStyle(KPressStyle())
    }

    /// Launch arguments for screenshots: `-demoScreen training|pairs|sequence|change|list|puzzle`, and the
    /// Bonbon-Puzzle demos (`-demoLevel`, `-demoIntro`, `-demoLab`) open the puzzle first.
    private func openDemo() {
        switch Demo.screen {
        case "training": showTraining = true
        case "pairs": single = .pairs
        case "sequence": single = .sequence
        case "change": single = .change
        case "list": single = .shoppingList
        case "puzzle": showPuzzle = true
        default:
            if Demo.level != nil || Demo.intro != nil || Demo.lab { showPuzzle = true }
        }
    }
}
