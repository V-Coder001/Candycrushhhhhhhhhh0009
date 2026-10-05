/// Something to buy, shown with an emoji so it needs no picture assets.
public struct ShoppingItem: Hashable, Identifiable {
    public enum Category: String, CaseIterable {
        case fruit, vegetables, dairy, bakery, drinks, sweets, pantry, household
    }

    public let emoji: String
    public let name: String
    public let category: Category
    /// Typical price in cents, used by the Wechselgeld game.
    public let price: Int

    public var id: String { name }

    public static let catalog: [ShoppingItem] = [
        ShoppingItem(emoji: "🍎", name: "Äpfel", category: .fruit, price: 249),
        ShoppingItem(emoji: "🍌", name: "Bananen", category: .fruit, price: 179),
        ShoppingItem(emoji: "🍐", name: "Birnen", category: .fruit, price: 229),
        ShoppingItem(emoji: "🍇", name: "Trauben", category: .fruit, price: 299),
        ShoppingItem(emoji: "🍓", name: "Erdbeeren", category: .fruit, price: 349),
        ShoppingItem(emoji: "🍋", name: "Zitronen", category: .fruit, price: 129),
        ShoppingItem(emoji: "🍒", name: "Kirschen", category: .fruit, price: 399),
        ShoppingItem(emoji: "🥕", name: "Möhren", category: .vegetables, price: 99),
        ShoppingItem(emoji: "🥔", name: "Kartoffeln", category: .vegetables, price: 249),
        ShoppingItem(emoji: "🍅", name: "Tomaten", category: .vegetables, price: 199),
        ShoppingItem(emoji: "🥒", name: "Gurke", category: .vegetables, price: 69),
        ShoppingItem(emoji: "🧅", name: "Zwiebeln", category: .vegetables, price: 119),
        ShoppingItem(emoji: "🥦", name: "Brokkoli", category: .vegetables, price: 149),
        ShoppingItem(emoji: "🌽", name: "Mais", category: .vegetables, price: 89),
        ShoppingItem(emoji: "🥛", name: "Milch", category: .dairy, price: 109),
        ShoppingItem(emoji: "🧀", name: "Käse", category: .dairy, price: 279),
        ShoppingItem(emoji: "🧈", name: "Butter", category: .dairy, price: 229),
        ShoppingItem(emoji: "🥚", name: "Eier", category: .dairy, price: 289),
        ShoppingItem(emoji: "🍦", name: "Eis", category: .dairy, price: 349),
        ShoppingItem(emoji: "🍞", name: "Brot", category: .bakery, price: 259),
        ShoppingItem(emoji: "🥐", name: "Croissants", category: .bakery, price: 199),
        ShoppingItem(emoji: "🥨", name: "Brezeln", category: .bakery, price: 149),
        ShoppingItem(emoji: "🍰", name: "Kuchen", category: .bakery, price: 449),
        ShoppingItem(emoji: "🥖", name: "Baguette", category: .bakery, price: 119),
        ShoppingItem(emoji: "☕", name: "Kaffee", category: .drinks, price: 699),
        ShoppingItem(emoji: "🍵", name: "Tee", category: .drinks, price: 249),
        ShoppingItem(emoji: "🧃", name: "Saft", category: .drinks, price: 189),
        ShoppingItem(emoji: "🍷", name: "Wein", category: .drinks, price: 599),
        ShoppingItem(emoji: "💧", name: "Wasser", category: .drinks, price: 49),
        ShoppingItem(emoji: "🍫", name: "Schokolade", category: .sweets, price: 129),
        ShoppingItem(emoji: "🍪", name: "Kekse", category: .sweets, price: 179),
        ShoppingItem(emoji: "🍯", name: "Honig", category: .sweets, price: 499),
        ShoppingItem(emoji: "🍬", name: "Bonbons", category: .sweets, price: 149),
        ShoppingItem(emoji: "🍝", name: "Nudeln", category: .pantry, price: 119),
        ShoppingItem(emoji: "🍚", name: "Reis", category: .pantry, price: 169),
        ShoppingItem(emoji: "🐟", name: "Fisch", category: .pantry, price: 549),
        ShoppingItem(emoji: "🍗", name: "Hähnchen", category: .pantry, price: 649),
        ShoppingItem(emoji: "🥫", name: "Dosensuppe", category: .pantry, price: 189),
        ShoppingItem(emoji: "🧂", name: "Salz", category: .pantry, price: 59),
        ShoppingItem(emoji: "🧻", name: "Toilettenpapier", category: .household, price: 399),
        ShoppingItem(emoji: "🧼", name: "Seife", category: .household, price: 149),
        ShoppingItem(emoji: "🪥", name: "Zahnbürste", category: .household, price: 249),
        ShoppingItem(emoji: "🧽", name: "Schwamm", category: .household, price: 99),
        ShoppingItem(emoji: "🕯️", name: "Kerzen", category: .household, price: 349),
        ShoppingItem(emoji: "💐", name: "Blumen", category: .household, price: 599),
    ]
}

/// Einkaufsliste: look at a list, play something else, then pick the items again from a larger choice.
public struct ShoppingListRound {
    public let level: Int
    /// The list to remember, in the order shown.
    public let list: [ShoppingItem]
    /// Everything offered when recalling: the list plus as many look-alikes, shuffled.
    public let choices: [ShoppingItem]
    public private(set) var selected: Set<ShoppingItem> = []

    public static func length(level: Int) -> Int {
        SkillLevel.scaled(level, from: 4, to: 12)
    }

    public init(level: Int, seed: UInt64) {
        self.level = level
        var rng = TrainingRandom(seed: seed)
        let count = Self.length(level: level)
        let list = Array(rng.shuffled(ShoppingItem.catalog).prefix(count))
        let rest = ShoppingItem.catalog.filter { !list.contains($0) }
        // From level 10 on the decoys come from the same shelves, which makes them easier to mix up.
        let categories = Set(list.map(\.category))
        let sameShelf = rng.shuffled(rest.filter { categories.contains($0.category) })
        let otherShelf = rng.shuffled(rest.filter { !categories.contains($0.category) })
        let pool = level >= 10 ? sameShelf + otherShelf : rng.shuffled(rest)
        let decoys = Array(pool.prefix(count))
        self.list = list
        choices = rng.shuffled(list + decoys)
    }

    public mutating func toggle(_ item: ShoppingItem) {
        if selected.contains(item) {
            selected.remove(item)
        } else {
            selected.insert(item)
        }
    }

    public var hits: [ShoppingItem] { list.filter(selected.contains) }
    public var missed: [ShoppingItem] { list.filter { !selected.contains($0) } }
    public var wrong: [ShoppingItem] { choices.filter { selected.contains($0) && !list.contains($0) } }

    /// Share of the list found, minus wrong picks.
    public var score: Double {
        Double(max(0, hits.count - wrong.count)) / Double(list.count)
    }
}
