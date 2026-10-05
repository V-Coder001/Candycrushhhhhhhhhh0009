import Match3Core
import SwiftUI

/// Reihenfolge nachtippen: watch the fields light up, then tap them in the same order.
struct SequenceGameView: View {
    let onFinish: (Double) -> Void

    private enum Phase: Equatable {
        case watching
        case input
        case result(success: Bool)
    }

    @State private var round: SequenceRound
    @State private var phase: Phase = .watching
    @State private var lit: Int?
    @State private var showToken = 0

    private static let colors: [UInt32] = [0x2E7D9A, 0xC0662B, 0x5B8C3A, 0x8A4FA3, 0xB8475A, 0x3F5FB0,
                                           0x9A7A1E, 0x2F8A7A, 0x6E6A60]

    init(level: Int, seed: UInt64, onFinish: @escaping (Double) -> Void) {
        self.onFinish = onFinish
        _round = State(initialValue: SequenceRound(level: level, seed: seed))
    }

    private var columns: Int { round.pads == 9 ? 3 : 2 }

    var body: some View {
        VStack(spacing: 20) {
            KGameTitle(title: "Reihenfolge nachtippen", subtitle: instruction)
            Text("Reihe \(min(round.trialIndex + 1, SequenceRound.trialsPerRound)) von \(SequenceRound.trialsPerRound) · \(round.current.count) Felder")
                .font(KTheme.small)
                .foregroundStyle(KTheme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: columns), spacing: 14) {
                ForEach(0..<round.pads, id: \.self) { pad in
                    Button { tap(pad) } label: { padView(pad) }
                        .buttonStyle(KPressStyle())
                        .disabled(phase != .input)
                        .accessibilityLabel("Feld \(pad + 1)")
                }
            }
            Spacer(minLength: 0)
            if case let .result(success) = phase {
                Text(success ? "Richtig!" : "Nicht ganz – das macht nichts." as String)
                    .font(KTheme.heading)
                    .foregroundStyle(success ? KTheme.good : KTheme.hint)
                KButton(title: round.trialIndex + 1 < SequenceRound.trialsPerRound ? "Nächste Reihe" : "Weiter",
                        systemImage: "arrow.right") { next() }
            }
        }
        .padding(20)
        .task(id: showToken) { await show() }
    }

    private var instruction: String {
        switch phase {
        case .watching: return "Schauen Sie genau hin, welche Felder nacheinander aufleuchten."
        case .input: return "Jetzt Sie: Tippen Sie die Felder in derselben Reihenfolge an."
        case .result: return "Diese Reihe ist geschafft."
        }
    }

    private func padView(_ pad: Int) -> some View {
        let color = Color(uiColor: UIColor(hex: Self.colors[pad % Self.colors.count]))
        let on = lit == pad
        return ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(on ? color : color.opacity(0.28))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(on ? Color.white : color.opacity(0.6), lineWidth: on ? 5 : 2)
            Text("\(pad + 1)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(on ? Color.white : color)
        }
        .aspectRatio(round.pads == 9 ? 1 : 1.25, contentMode: .fit)
        .scaleEffect(on ? 1.04 : 1)
        .animation(.easeOut(duration: 0.15), value: on)
    }

    /// Lights the current sequence one field at a time.
    private func show() async {
        phase = .watching
        lit = nil
        try? await Task.sleep(nanoseconds: 900_000_000)
        for pad in round.current {
            lit = pad
            Haptics.tap()
            try? await Task.sleep(nanoseconds: 750_000_000)
            lit = nil
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        guard !Task.isCancelled else { return }
        phase = .input
    }

    private func tap(_ pad: Int) {
        switch round.tap(pad) {
        case .ignored:
            return
        case .correct:
            flash(pad)
        case let .finished(success):
            flash(pad)
            success ? Haptics.success() : Haptics.invalid()
            phase = .result(success: success)
        }
    }

    private func flash(_ pad: Int) {
        lit = pad
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            if lit == pad { lit = nil }
        }
    }

    private func next() {
        round.next()
        if round.isComplete {
            onFinish(round.score)
        } else {
            showToken += 1
        }
    }
}
