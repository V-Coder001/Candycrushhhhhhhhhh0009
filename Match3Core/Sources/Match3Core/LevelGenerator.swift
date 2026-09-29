import Foundation

/// Builds the long tail of the campaign. Every level comes from its own seed, so a level looks the same
/// on every device and after every update without shipping a level file.
///
/// Difficulty rises slowly over the whole campaign and in small waves inside each episode of six levels:
/// the first level of an episode is a breather, the last one is the hardest. Move counts and star scores
/// were tuned with a greedy bot that plays every level on many seeds.
enum LevelGenerator {
    static let firstID = 13
    static let count = 1_000

    static var levels: [Level] {
        (firstID..<(firstID + count)).map(level(id:))
    }

    static func level(id: Int) -> Level {
        var rng = LevelRandom(seed: UInt64(id) &* 0x2545_F491_4F6C_DD1D ^ 0x5077)
        let d = difficulty(id: id, rng: &rng)
        let kind = kind(id: id, difficulty: d, rng: &rng)
        // A sixth colour makes matches rare. It only goes with goals that do not need a specific spot.
        let colors = (kind == .jelly || kind == .score) && rng.chance(0.08 + 0.35 * d) ? 6 : 5
        let needsWay = [.ingredients, .jellyAndIngredients].contains(kind)
        let pool = shapes.filter { $0.ingredients || !needsWay }
        let shape = pool[rng.int(pool.count)]
        var grid = Grid(shape: shape.rows)

        var goals: [Goal] = []
        var ingredients = 0
        switch kind {
        case .score:
            break
        case .jelly:
            grid.addJelly(amount: d, rng: &rng)
            goals = [.clearJelly]
        case .ingredients:
            ingredients = 1 + rng.int(d < 0.3 ? 2 : (d < 0.6 ? 3 : 4))
            grid.addIngredients(ingredients, rng: &rng)
            goals = [.collectIngredients(ingredients)]
        case .chocolate:
            grid.addChocolate(amount: d, rng: &rng)
            goals = [.clearChocolate]
        case .jellyAndIngredients:
            ingredients = 1 + rng.int(2)
            grid.addIngredients(ingredients, rng: &rng)
            grid.addJelly(amount: d * 0.6, rng: &rng)
            goals = [.clearJelly, .collectIngredients(ingredients)]
        case .jellyAndChocolate:
            grid.addChocolate(amount: d * 0.5, rng: &rng)
            grid.addJelly(amount: d * 0.5, rng: &rng)
            goals = [.clearChocolate, .clearJelly]
        }

        let obstacleShare: Double
        switch kind {
        case .score, .jelly, .ingredients: obstacleShare = 1
        case .chocolate: obstacleShare = 0.6
        case .jellyAndIngredients, .jellyAndChocolate: obstacleShare = 0.5
        }
        grid.addObstacles(amount: d * obstacleShare, keepBottomFree: ingredients > 0, rng: &rng)

        let moves = moves(for: grid, kind: kind, ingredients: ingredients, colors: colors, difficulty: d,
                          shape: shape.moves)
        let expected = expectedScore(for: grid, kind: kind, moves: moves, colors: colors)
        let stars: [Int]
        if kind == .score {
            let target = roundScore(expected * (0.25 + 0.2 * d) * (colors == 6 ? 1.25 : 1))
            goals = [.score(target)]
            let two = max(target + 1_000, roundScore(expected * 0.65))
            stars = [target, two, max(two + 1_000, roundScore(expected * 0.95))]
        } else {
            stars = [roundScore(expected * 0.15), roundScore(expected * 0.65), roundScore(expected * 0.95)]
        }

        return Level(id: id, name: name(id: id), moves: moves, colors: colors, goals: goals, starScores: stars,
                     layout: grid.layout, maxIngredientsOnBoard: ingredients >= 3 ? 2 : 1)
    }

    // MARK: Difficulty

    /// 0 is a gentle level, 1 the hardest the campaign gets.
    static func difficulty(id: Int, rng: inout LevelRandom) -> Double {
        let progress = Double(id - firstID) / Double(count - 1)
        let wave = [-0.16, -0.06, 0.0, 0.04, 0.1, 0.2][(id - 1) % 6]
        let jitter = rng.double() * 0.1 - 0.05
        return min(1, max(0, 0.15 + 0.6 * progress + wave + jitter))
    }

    enum Kind {
        case score, jelly, ingredients, chocolate, jellyAndIngredients, jellyAndChocolate
    }

    /// Each episode shuffles its own mix of goals so the same kind never runs for long.
    static func kind(id: Int, difficulty d: Double, rng: inout LevelRandom) -> Kind {
        let episode = (id - 1) / 6
        var episodeRNG = LevelRandom(seed: UInt64(episode) &* 0x9E37_79B9_7F4A_7C15 ^ 0xE915)
        var mix: [Kind] = [.jelly, .jelly, .ingredients, .score, .chocolate,
                           episodeRNG.chance(0.5) ? .jelly : .ingredients]
        episodeRNG.shuffle(&mix)
        let base = mix[(id - 1) % 6]
        guard rng.chance(0.08 + 0.3 * d) else { return base }
        switch base {
        case .jelly: return rng.chance(0.5) ? .jellyAndIngredients : .jellyAndChocolate
        case .ingredients: return .jellyAndIngredients
        case .chocolate: return .jellyAndChocolate
        default: return base
        }
    }

    // MARK: Balance

    static func moves(for grid: Grid, kind: Kind, ingredients: Int, colors: Int, difficulty d: Double,
                      shape: Double) -> Int {
        let jelly = Double(grid.count { "jk".contains($0) } + 2 * grid.count { $0 == "J" })
        let chocolate = Double(grid.count { $0 == "c" })
        let obstacles = Double(grid.count { "lkbB".contains($0) })
        var moves: Double
        switch kind {
        case .score: moves = 18
        case .jelly: moves = 13 + 0.32 * jelly
        case .ingredients: moves = 12 + 7 * Double(ingredients)
        case .chocolate: moves = 14 + 0.75 * chocolate
        case .jellyAndIngredients: moves = 10 + 0.32 * jelly + 6 * Double(ingredients)
        case .jellyAndChocolate: moves = 12 + 0.32 * jelly + 0.75 * chocolate
        }
        if kind != .score { moves += 0.25 * obstacles }
        if colors == 6 { moves *= 1.4 }
        moves *= shape
        moves *= 1.22 - 0.42 * d
        return max(12, min(50, Int(moves.rounded())))
    }

    /// Median final score of the balance bot, fitted over all generated levels. Three stars sit just below
    /// it, two stars at about two thirds.
    static func expectedScore(for grid: Grid, kind: Kind, moves: Int, colors: Int) -> Double {
        let open = Double(grid.count { $0 != "#" }) / 81
        var score: Double
        if kind == .score {
            score = Double(moves) * exp(5.28 + 1.93 * open)
            if colors == 6 { score *= 0.5 }
        } else {
            score = exp(6.43 + 1.38 * open) * pow(Double(moves), 0.78)
            if colors == 6 { score *= 0.62 }
            if kind == .chocolate { score *= 0.83 }
        }
        return score
    }

    static func roundScore(_ value: Double) -> Int {
        max(500, Int((value / 500).rounded()) * 500)
    }

    // MARK: Names

    private static let flavours = [
        "Karamell", "Zucker", "Schoko", "Lakritz", "Marzipan", "Nougat", "Honig", "Brause", "Kirsch", "Minz",
        "Vanille", "Zimt", "Waffel", "Toffee", "Sahne", "Himbeer", "Erdbeer", "Mandel", "Kokos", "Bonbon",
        "Kaugummi", "Keks", "Krokant", "Pralinen", "Lolli", "Gummibären", "Brombeer", "Blaubeer", "Zitronen",
        "Orangen", "Apfel", "Pfirsich", "Kakao", "Trüffel", "Fondant", "Sirup", "Baiser", "Mokka", "Streusel",
        "Pudding",
    ]
    private static let places = [
        "brücke", "wald", "garten", "turm", "tal", "see", "insel", "bucht", "pfad", "hügel", "mühle", "markt",
        "schloss", "wiese", "quelle", "höhle", "gipfel", "hafen", "dorf", "allee", "strand", "grotte", "fluss",
        "feld", "berg", "bach",
    ]

    /// Every generated level gets its own name: flavour and place combined, spread out so neighbours differ.
    static func name(id: Int) -> String {
        let total = flavours.count * places.count
        let index = ((id - firstID) * 677 + 13) % total
        return flavours[index / places.count] + places[index % places.count]
    }

    // MARK: Shapes

    struct Shape {
        /// Extra moves for outlines with narrow three-wide parts, where fewer matches fit.
        var moves: Double
        /// Whether ingredients can find their way down without getting stuck in a narrow tower.
        var ingredients: Bool
        var rows: [String]

        init(moves: Double = 1, ingredients: Bool = true, _ rows: [String]) {
            self.moves = moves
            self.ingredients = ingredients
            self.rows = rows
        }
    }

    /// Board outlines, all mirror-symmetric. Every playable cell sits in a row of at least three playable
    /// cells, so there are no narrow corridors where only vertical matches fit.
    static let shapes: [Shape] = [
        Shape([
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
        ]),
        Shape([
            "##.....##",
            "#.......#",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            "#.......#",
            "##.....##",
        ]),
        Shape(moves: 1.15, [
            ".........",
            "#.......#",
            "##.....##",
            "###...###",
            "###...###",
            "###...###",
            "##.....##",
            "#.......#",
            ".........",
        ]),
        Shape([
            "###...###",
            "##.....##",
            "#.......#",
            ".........",
            ".........",
            ".........",
            "#.......#",
            "##.....##",
            "###...###",
        ]),
        Shape(moves: 1.12, [
            "###...###",
            "###...###",
            "###...###",
            ".........",
            ".........",
            ".........",
            "###...###",
            "###...###",
            "###...###",
        ]),
        Shape(moves: 1.25, ingredients: false, [
            "...###...",
            "...###...",
            "...###...",
            ".........",
            ".........",
            ".........",
            "...###...",
            "...###...",
            "...###...",
        ]),
        Shape(moves: 1.08, [
            ".........",
            ".........",
            ".........",
            "...###...",
            "...###...",
            "...###...",
            ".........",
            ".........",
            ".........",
        ]),
        Shape(moves: 1.12, [
            ".........",
            ".........",
            "...###...",
            "...###...",
            "...###...",
            "...###...",
            ".........",
            ".........",
            ".........",
        ]),
        Shape([
            "#...#...#",
            ".........",
            ".........",
            ".........",
            ".........",
            "#.......#",
            "##.....##",
            "###...###",
            "###...###",
        ]),
        Shape([
            ".........",
            ".........",
            ".........",
            ".........",
            "#.......#",
            "##.....##",
            "###...###",
            "###...###",
            "###...###",
        ]),
        Shape([
            "##.....##",
            "##.....##",
            "##.....##",
            ".........",
            ".........",
            ".........",
            "##.....##",
            "##.....##",
            "##.....##",
        ]),
        Shape([
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            "#.......#",
            "#.......#",
            "##.....##",
            "###...###",
        ]),
        Shape([
            "###...###",
            "###...###",
            "##.....##",
            "##.....##",
            "#.......#",
            "#.......#",
            ".........",
            ".........",
            ".........",
        ]),
        Shape(moves: 1.3, ingredients: false, [
            ".........",
            ".........",
            ".........",
            "###...###",
            "###...###",
            "###...###",
            "###...###",
            "###...###",
            "###...###",
        ]),
        Shape([
            "##.....##",
            "##.....##",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            "##.....##",
            "##.....##",
        ]),
        Shape([
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
        ]),
        Shape([
            "###...###",
            "##.....##",
            "#.......#",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
        ]),
        Shape([
            ".........",
            ".........",
            ".........",
            "....#....",
            "...###...",
            "....#....",
            ".........",
            ".........",
            ".........",
        ]),
    ]

    // MARK: Layout

    /// A 9x9 layout that is edited in mirrored pairs, so every generated board is symmetric.
    struct Grid {
        var cells: [[Character]]

        init(shape: [String]) {
            cells = shape.map(Array.init)
        }

        var layout: [String] { cells.map { String($0) } }
        var rows: Int { cells.count }
        var columns: Int { cells[0].count }

        func count(where predicate: (Character) -> Bool) -> Int {
            cells.reduce(0) { $0 + $1.filter(predicate).count }
        }

        subscript(_ r: Int, _ c: Int) -> Character {
            get { r >= 0 && r < rows && c >= 0 && c < columns ? cells[r][c] : "#" }
            set { cells[r][c] = newValue }
        }

        mutating func setMirrored(_ r: Int, _ c: Int, _ value: Character) {
            cells[r][c] = value
            cells[r][columns - 1 - c] = value
        }

        /// Cells in the left half and the middle column, the ones that get mirrored.
        func halfCells(where predicate: (Int, Int) -> Bool) -> [(Int, Int)] {
            var result: [(Int, Int)] = []
            for r in 0..<rows {
                for c in 0...(columns / 2) where predicate(r, c) {
                    result.append((r, c))
                }
            }
            return result
        }

        func isEdge(_ r: Int, _ c: Int) -> Bool {
            [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)].contains { self[$0.0, $0.1] == "#" }
        }

        // MARK: Goals

        static let jellyPatterns: [(Int, Int, Grid) -> Bool] = [
            { _, _, _ in true },
            { r, c, _ in (2...6).contains(r) && (2...6).contains(c) },
            { r, _, _ in (3...5).contains(r) },
            { r, _, _ in r >= 5 },
            { r, _, _ in r <= 3 },
            { r, c, g in g.isEdge(r, c) },
            { r, c, _ in (r + c) % 2 == 0 },
            { r, c, _ in r == c || r + c == 8 },
            { _, c, _ in [0, 1, 4, 7, 8].contains(c) },
            { r, _, _ in r % 2 == 0 },
            { r, c, _ in abs(r - 4) + abs(c - 4) <= 3 },
            { r, c, _ in min(r, 8 - r) + min(c, 8 - c) <= 2 },
            { r, c, _ in r >= 4 && abs(c - 4) <= r - 4 },
        ]

        mutating func addJelly(amount d: Double, rng: inout LevelRandom) {
            let pattern = Self.jellyPatterns[rng.int(Self.jellyPatterns.count)]
            var cells = halfCells { r, c in self[r, c] == "." && pattern(r, c, self) }
            if cells.count < 6 {
                cells = halfCells { r, c in self[r, c] == "." && (2...6).contains(r) }
            }
            let double = rng.chance(max(0, d - 0.35) * 1.3)
            let inner = Self.jellyPatterns[rng.int(3) + 1]
            for (r, c) in cells {
                setMirrored(r, c, double && inner(r, c, self) ? "J" : "j")
            }
        }

        mutating func addChocolate(amount d: Double, rng: inout LevelRandom) {
            let patterns: [(Int, Int) -> Bool] = [
                { r, _ in r >= 7 },
                { r, c in r >= 6 && c <= 2 },
                { r, c in r >= 5 && abs(c - 4) + abs(r - 7) <= 2 },
                { r, c in r >= 4 && c <= 1 },
                { r, c in r >= 6 && (c <= 1 || c == 4) },
            ]
            let pattern = patterns[rng.int(patterns.count)]
            var cells = halfCells { r, c in self[r, c] == "." && pattern(r, c) }
            if cells.count < 3 {
                cells = halfCells { r, c in r >= 5 && self[r, c] == "." }
            }
            // Keep the chocolate at the bottom and in one piece: lowest rows first, from the middle outwards.
            cells.sort { ($0.0, -abs($0.1 - 4)) > ($1.0, -abs($1.1 - 4)) }
            let wanted = 3 + Int(d * 6) + rng.int(3)
            var placed = 0
            for (r, c) in cells where placed < wanted {
                setMirrored(r, c, "c")
                placed += c == columns / 2 ? 1 : 2
            }
        }

        mutating func addIngredients(_ count: Int, rng: inout LevelRandom) {
            let top = (0..<columns).filter { self[0, $0] == "." }.sorted { abs($0 - 4) < abs($1 - 4) }
            guard let first = top.first else { return }
            if count >= 3, let pair = top.first(where: { $0 < 4 && $0 >= 1 }) {
                self[0, pair] = "i"
                self[0, columns - 1 - pair] = "h"
            } else {
                self[0, first] = rng.chance(0.5) ? "i" : "h"
            }
        }

        // MARK: Obstacles

        mutating func addObstacles(amount d: Double, keepBottomFree: Bool, rng: inout LevelRandom) {
            let open = count { $0 != "#" }
            var budget = Int(Double(open) * (0.04 + 0.16 * d)) + rng.int(3)
            guard budget > 1 else { return }

            // Blockers: never side by side or on top of each other, so candies can always slide around them.
            if rng.chance(0.35 + 0.5 * d) {
                let strong = rng.chance(max(0, d - 0.45))
                let rowsAllowed = keepBottomFree ? 2...5 : 2...7
                var candidates = halfCells { r, c in
                    rowsAllowed.contains(r) && self[r, c] == "."
                }
                rng.shuffle(&candidates)
                var blockers = min(budget / 2, 2 + Int(d * 8))
                for (r, c) in candidates where blockers > 0 {
                    let near = [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1), (r - 1, c - 1), (r - 1, c + 1)]
                    guard !near.contains(where: { "bBc".contains(self[$0.0, $0.1]) }) else { continue }
                    setMirrored(r, c, strong && rng.chance(0.5) ? "B" : "b")
                    let used = c == columns / 2 ? 1 : 2
                    blockers -= used
                    budget -= used
                }
            }

            // Locks: on candy or jelly, never stacked, so the cells below still get refilled.
            if budget > 1, rng.chance(0.3 + 0.5 * d) {
                var candidates = halfCells { r, c in
                    (1...7).contains(r) && (self[r, c] == "." || self[r, c] == "j")
                }
                rng.shuffle(&candidates)
                for (r, c) in candidates where budget > 1 {
                    guard !"lk".contains(self[r - 1, c]) else { continue }
                    setMirrored(r, c, self[r, c] == "j" ? "k" : "l")
                    budget -= c == columns / 2 ? 1 : 2
                }
            }
        }
    }
}

/// SplitMix64 with its own helpers, so the generated levels do not depend on how the standard library
/// maps random numbers into ranges (that could change with a new Swift version).
struct LevelRandom {
    private var generator: SeededGenerator

    init(seed: UInt64) {
        generator = SeededGenerator(seed: seed)
    }

    mutating func int(_ upperBound: Int) -> Int {
        Int(generator.next() % UInt64(upperBound))
    }

    mutating func double() -> Double {
        Double(generator.next() >> 11) / Double(UInt64(1) << 53)
    }

    mutating func chance(_ probability: Double) -> Bool {
        double() < probability
    }

    mutating func shuffle<T>(_ array: inout [T]) {
        guard array.count > 1 else { return }
        for i in stride(from: array.count - 1, to: 0, by: -1) {
            array.swapAt(i, int(i + 1))
        }
    }
}
