import Match3Core
import SwiftUI

/// Wechselgeld: pick the right change for a small purchase.
struct ChangeGameView: View {
    let onFinish: (Double) -> Void

    @State private var round: ChangeRound
    @State private var index = 0
    @State private var picked: Int?

    init(level: Int, seed: UInt64, onFinish: @escaping (Double) -> Void) {
        self.onFinish = onFinish
        _round = State(initialValue: ChangeRound(level: level, seed: seed))
    }

    private var task: ChangeRound.Task { round.tasks[index] }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                KGameTitle(title: "Wechselgeld", subtitle: "Aufgabe \(index + 1) von \(round.tasks.count)")
                KCard {
                    Text("Sie kaufen:")
                        .font(KTheme.small)
                        .foregroundStyle(KTheme.secondary)
                    ForEach(task.items.indices, id: \.self) { i in
                        HStack(spacing: 14) {
                            Text(task.items[i].emoji).font(.system(size: 34))
                            Text(task.items[i].name).font(KTheme.body).foregroundStyle(KTheme.ink)
                            Spacer()
                            Text(Money.format(task.prices[i])).font(KTheme.bodyBold).foregroundStyle(KTheme.ink)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if task.showsTotal && task.items.count > 1 {
                        Divider()
                        HStack {
                            Text("Zusammen").font(KTheme.body).foregroundStyle(KTheme.secondary)
                            Spacer()
                            Text(Money.format(task.total)).font(KTheme.bodyBold).foregroundStyle(KTheme.ink)
                        }
                    }
                    Divider()
                    HStack(spacing: 12) {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(KTheme.good)
                        Text("Sie bezahlen mit \(Money.format(task.paid))")
                            .font(KTheme.bodyBold)
                            .foregroundStyle(KTheme.ink)
                    }
                }
                Text("Wie viel Geld bekommen Sie zurück?")
                    .font(KTheme.heading)
                    .foregroundStyle(KTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(task.options, id: \.self) { amount in
                        Button { answer(amount) } label: { option(amount) }
                            .buttonStyle(KPressStyle())
                            .disabled(picked != nil)
                    }
                }
                if let picked {
                    Text(feedback(for: picked))
                        .font(KTheme.heading)
                        .foregroundStyle(picked == task.change ? KTheme.good : KTheme.hint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            if picked != nil {
                KButton(title: index + 1 < round.tasks.count ? "Nächste Aufgabe" : "Weiter",
                        systemImage: "arrow.right") { next() }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(KTheme.background)
            }
        }
    }

    private func feedback(for amount: Int) -> String {
        amount == task.change ? "Richtig!" : "Das Rückgeld beträgt \(Money.format(task.change))."
    }

    private func option(_ amount: Int) -> some View {
        let isRight = amount == task.change
        let chosen = picked == amount
        let fill: Color = picked == nil ? KTheme.card : (isRight ? KTheme.goodSoft : (chosen ? KTheme.hintSoft : KTheme.card))
        let border: Color = picked == nil ? KTheme.line : (isRight ? KTheme.good : (chosen ? KTheme.hint : KTheme.line))
        return Text(Money.format(amount))
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .foregroundStyle(KTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(border, lineWidth: picked == nil ? 1 : 3))
    }

    private func answer(_ amount: Int) {
        guard picked == nil else { return }
        picked = amount
        round.answer(amount) ? Haptics.success() : Haptics.invalid()
    }

    private func next() {
        if index + 1 < round.tasks.count {
            index += 1
            picked = nil
        } else {
            onFinish(round.score)
        }
    }
}
