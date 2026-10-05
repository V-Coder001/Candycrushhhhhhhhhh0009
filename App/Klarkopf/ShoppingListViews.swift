import Match3Core
import SwiftUI

/// Shows the list to remember. No timer: the player says when they are ready.
struct ShoppingLearnView: View {
    let round: ShoppingListRound
    var laterNote = "Sie werden später danach gefragt."
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                KGameTitle(title: "Ihre Einkaufsliste",
                           subtitle: "Merken Sie sich diese \(round.list.count) Dinge. \(laterNote)")
                KCard {
                    ForEach(round.list) { item in
                        HStack(spacing: 16) {
                            Text(item.emoji).font(.system(size: 40))
                            Text(item.name).font(KTheme.body).foregroundStyle(KTheme.ink)
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            KButton(title: "Ich habe sie mir gemerkt", systemImage: "checkmark", action: onDone)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(KTheme.background)
        }
    }
}

/// Pick the remembered items from twice as many, then see what was right.
struct ShoppingRecallView: View {
    @Binding var round: ShoppingListRound
    let onFinish: (Double) -> Void

    @State private var checked = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                KGameTitle(title: "Was stand auf Ihrer Einkaufsliste?",
                           subtitle: checked
                               ? "Sie haben \(round.hits.count) von \(round.list.count) Dingen gefunden."
                               : "Tippen Sie alle Dinge an, die Sie sich gemerkt haben.")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(round.choices) { item in
                        Button { if !checked { round.toggle(item) } } label: { tile(item) }
                            .buttonStyle(KPressStyle())
                            .accessibilityLabel(item.name)
                            .accessibilityAddTraits(round.selected.contains(item) ? .isSelected : [])
                    }
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if checked {
                    KButton(title: "Weiter", systemImage: "arrow.right") { onFinish(round.score) }
                } else {
                    KButton(title: "Fertig", systemImage: "checkmark") {
                        withAnimation(.easeInOut(duration: 0.2)) { checked = true }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(KTheme.background)
        }
    }

    private func tile(_ item: ShoppingItem) -> some View {
        let picked = round.selected.contains(item)
        let onList = round.list.contains(item)
        var border = picked ? KTheme.accent : KTheme.line
        var fill = picked ? KTheme.accentSoft : KTheme.card
        var note: String?
        if checked {
            if picked && onList {
                border = KTheme.good; fill = KTheme.goodSoft; note = "Richtig"
            } else if onList {
                border = KTheme.hint; fill = KTheme.hintSoft; note = "Stand drauf"
            } else if picked {
                border = KTheme.hint; fill = KTheme.card; note = "Nicht auf der Liste"
            }
        }
        return VStack(spacing: 6) {
            Text(item.emoji).font(.system(size: 40))
            Text(item.name)
                .font(KTheme.small)
                .foregroundStyle(KTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let note {
                Text(note)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(border)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 116)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(border, lineWidth: picked || note != nil ? 3 : 1))
        .overlay(alignment: .topTrailing) {
            if picked && !checked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(KTheme.accent)
                    .padding(8)
            }
        }
    }
}
