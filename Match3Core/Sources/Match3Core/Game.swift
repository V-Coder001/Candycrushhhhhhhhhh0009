/// One running level: board, moves, score and goals. All rules live here; the app only renders results.
public final class Game {
    public let level: Level
    public private(set) var board: Board
    public private(set) var score = 0
    public private(set) var movesLeft: Int
    public private(set) var status: GameStatus = .playing
    public private(set) var ingredientsCollected = 0
    public private(set) var ingredientsSpawned = 0
    /// Mixed candies popped so far.
    public private(set) var mixesServed = 0
    public let initialJelly: Int
    public let initialChocolate: Int

    var rng: SeededGenerator

    /// Points per popped candy, multiplied by the cascade index.
    public static let candyPoints = 20
    /// Sugar rush points for every move that was left over.
    public static let bonusPerMove = 300
    /// Extra points for popping a mixed candy.
    public static let mixPoints = 300
    /// Striped candies placed per sugar rush round.
    static let sugarRushBatch = 4

    public init(level: Level, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        self.level = level
        rng = SeededGenerator(seed: seed)
        movesLeft = level.moves
        let (skeleton, slots) = level.skeleton()
        var board = skeleton
        Game.fillWithoutMatches(&board, slots: slots, palette: level.palette, rng: &rng)
        self.board = board
        initialJelly = board.jellyRemaining
        initialChocolate = board.count { $0.isChocolate }
        ingredientsSpawned = board.count { $0.isIngredient }
    }

    /// Start from a hand-made board (tests, tutorials).
    public init(level: Level, board: Board, seed: UInt64 = 1) {
        self.level = level
        self.board = board
        rng = SeededGenerator(seed: seed)
        movesLeft = level.moves
        initialJelly = board.jellyRemaining
        initialChocolate = board.count { $0.isChocolate }
        ingredientsSpawned = board.count { $0.isIngredient }
    }

    // MARK: Queries

    public var goalProgress: [GoalProgress] {
        GoalProgress.evaluate(goals: level.goals, score: score, board: board, collected: ingredientsCollected,
                              served: mixesServed,
                              initialJelly: initialJelly, initialChocolate: initialChocolate)
    }

    public var goalsMet: Bool { goalProgress.allSatisfy(\.isMet) }

    /// 0 while playing or lost, 1–3 when won.
    public var stars: Int {
        guard status == .won else { return 0 }
        let thresholds = level.starScores
        var stars = 1
        if thresholds.count > 1, score >= thresholds[1] { stars += 1 }
        if thresholds.count > 2, score >= thresholds[2] { stars += 1 }
        return stars
    }

    public func canSwap(_ a: Position, _ b: Position) -> Bool {
        status == .playing && MatchFinder.isValidSwap(a, b, in: board)
    }

    public func hint() -> (Position, Position)? {
        MatchFinder.findPossibleMove(in: board)
    }

    /// In mixing levels: a swap that makes a mixed candy, if there is one. Used for hints and demos.
    public func mixHint() -> (Position, Position)? {
        guard level.mixing, status == .playing else { return nil }
        for p in board.positions {
            for q in [p.right, p.down] where canSwap(p, q) {
                let trial = Game(level: level, board: board)
                let result = trial.swap(p, q)
                if result.steps.first?.created.contains(where: { $0.piece.kind.isMix }) == true { return (p, q) }
            }
        }
        return nil
    }

    // MARK: Move

    /// Swaps two neighbouring pieces and resolves all cascades.
    /// An invalid swap leaves the board untouched and costs no move.
    @discardableResult
    public func swap(_ from: Position, _ to: Position) -> MoveResult {
        guard canSwap(from, to), let moving = board[from], let other = board[to] else {
            return MoveResult(isValid: false, from: from, to: to, status: status, board: board)
        }
        board[to] = moving
        board[from] = other
        movesLeft -= 1

        let combo = MatchFinder.isCombo(moving.kind, other.kind)
        var result = MoveResult(isValid: true, from: from, to: to, status: status, board: board)
        var recentlyMoved: Set<Position> = []
        var chocolateDestroyed = false
        var index = 1
        while index < 200, let step = resolveStep(
            index: index,
            combo: index == 1 && combo ? (center: to, other: from) : nil,
            preferred: index == 1 ? [to, from] : [],
            recentlyMoved: recentlyMoved,
            chocolateDestroyed: &chocolateDestroyed
        ) {
            result.steps.append(step)
            score += step.scoreGained
            ingredientsCollected += step.collected.count
            mixesServed += step.served.count
            recentlyMoved = Set(step.falls.map(\.to) + step.spawns.map(\.position))
            index += 1
        }

        if !chocolateDestroyed {
            result.chocolateSpread = spreadChocolate()
        }

        let clearedCount = result.steps.reduce(0) { $0 + $1.cleared.count }
        result.comboWord = ComboWord.forMove(cascades: result.steps.count, cleared: clearedCount)

        if goalsMet && (!level.playsAllMoves || movesLeft <= 0) {
            status = .won
            let before = score
            result.sugarRush = sugarRush()
            result.bonusScore = score - before
        } else if movesLeft <= 0 {
            status = .lost
        } else if MatchFinder.findPossibleMove(in: board) == nil {
            shuffle()
            result.shuffledBoard = board
        }
        result.status = status
        result.board = board
        return result
    }

    // MARK: Sugar rush

    /// Fires all specials still on the board, then turns the leftover moves into striped candies
    /// (a few per round) and fires those, until no moves and no specials are left.
    private func sugarRush() -> [CascadeStep] {
        var steps: [CascadeStep] = []
        var chocolateDestroyed = false

        func cascade(detonate: [Position], transformed: [PlacedPiece], moves: Int) {
            var index = 1
            var recentlyMoved: Set<Position> = []
            var pending = detonate
            while index < 60, var step = resolveStep(index: index, combo: nil, preferred: [],
                                                     recentlyMoved: recentlyMoved,
                                                     chocolateDestroyed: &chocolateDestroyed,
                                                     detonate: pending) {
                if index == 1 {
                    step.transformed = transformed
                    step.movesSpent = moves
                    step.scoreGained += moves * Game.bonusPerMove
                }
                score += step.scoreGained
                ingredientsCollected += step.collected.count
                mixesServed += step.served.count
                recentlyMoved = Set(step.falls.map(\.to) + step.spawns.map(\.position))
                steps.append(step)
                pending = []
                index += 1
            }
        }

        for _ in 0..<40 {
            let specials = board.positions { $0 == .colorBomb || $0.special != .none }
            if !specials.isEmpty {
                cascade(detonate: specials, transformed: [], moves: 0)
                continue
            }
            guard movesLeft > 0 else { break }
            let spots = board.positions { $0.isPlainCandy }.shuffled(using: &rng)
            guard !spots.isEmpty else { break }
            let count = min(movesLeft, Game.sugarRushBatch, spots.count)
            var transformed: [PlacedPiece] = []
            for p in spots.prefix(count) {
                guard var piece = board[p], let color = piece.kind.color else { continue }
                piece.kind = .candy(color, Bool.random(using: &rng) ? .stripedHorizontal : .stripedVertical)
                board[p] = piece
                transformed.append(PlacedPiece(piece, p))
            }
            movesLeft -= count
            cascade(detonate: transformed.map(\.position), transformed: transformed, moves: count)
        }
        return steps
    }

    // MARK: Cascade step

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func resolveStep(index: Int, combo: (center: Position, other: Position)?, preferred: [Position],
                             recentlyMoved: Set<Position>, chocolateDestroyed: inout Bool,
                             detonate: [Position] = []) -> CascadeStep? {
        let groups = combo == nil ? MatchFinder.findMatches(in: board) : []
        let armed = board.positions { $0.special == .wrappedArmed }
        if combo == nil && groups.isEmpty && armed.isEmpty && detonate.isEmpty { return nil }

        var step = CascadeStep(index: index, board: board)
        step.matches = groups
        var hitSet = Set<Position>()
        var queue: [Position] = []
        var rearm: [(Position, CandyColor)] = []
        var creations: [(Position, PieceKind)] = []

        func clearJelly(_ p: Position) {
            var cell = board.cell(p)
            guard cell.jelly > 0 else { return }
            cell.jelly -= 1
            board.setCell(p, cell)
            step.jellyHit.append(p)
            step.scoreGained += 100
        }

        /// Removes a piece without triggering it (used for the two pieces of a combo swap).
        func consume(_ p: Position) {
            guard let piece = board[p] else { return }
            board[p] = nil
            hitSet.insert(p)
            step.cleared.append(PlacedPiece(piece, p))
            step.scoreGained += Game.candyPoints * index
            clearJelly(p)
        }

        func area(_ center: Position, radius: Int) -> [Position] {
            var result: [Position] = []
            for r in (center.row - radius)...(center.row + radius) {
                for c in (center.col - radius)...(center.col + radius) where board.isPlayable(Position(r, c)) {
                    result.append(Position(r, c))
                }
            }
            return result
        }

        func row(_ r: Int) -> [Position] {
            (0..<board.columns).map { Position(r, $0) }.filter(board.isPlayable)
        }

        func column(_ c: Int) -> [Position] {
            (0..<board.rows).map { Position($0, c) }.filter(board.isPlayable)
        }

        func fishTarget(from origin: Position) -> Position? {
            let taken = hitSet.union(queue).union([origin])
            let open = board.positions.filter { !taken.contains($0) }
            let tiers: [[Position]] = [
                open.filter { board.cell($0).jelly > 0 && board[$0] != nil && !(board[$0]!.kind.isIngredient) },
                open.filter { board[$0]?.kind.isObstacle == true },
                open.filter { board.cell($0).locked },
                open.filter { board[$0]?.kind.color != nil },
            ]
            for tier in tiers where !tier.isEmpty {
                return tier.randomElement(using: &rng)
            }
            return nil
        }

        func mostCommonColor() -> CandyColor? {
            var counts: [CandyColor: Int] = [:]
            for p in board.positions where !hitSet.contains(p) {
                if let color = board.color(at: p) { counts[color, default: 0] += 1 }
            }
            return CandyColor.allCases.filter { counts[$0] != nil }.max { counts[$0]! < counts[$1]! }
        }

        func colorPositions(_ color: CandyColor) -> [Position] {
            board.positions.filter { board.has(color, at: $0) && !hitSet.contains($0) }
        }

        /// Fires a special at `p` and queues the cells it hits.
        func activate(_ special: Special, color: CandyColor, at p: Position) {
            switch special {
            case .none:
                return
            case .stripedHorizontal:
                let cells = row(p.row)
                step.activations.append(Activation(origin: p, kind: .lineHorizontal, affected: cells))
                queue += cells
            case .stripedVertical:
                let cells = column(p.col)
                step.activations.append(Activation(origin: p, kind: .lineVertical, affected: cells))
                queue += cells
            case .wrapped, .wrappedArmed:
                let cells = area(p, radius: 1)
                step.activations.append(Activation(origin: p, kind: .area(radius: 1), affected: cells))
                queue += cells
                if special == .wrapped { rearm.append((p, color)) }
            case .fish:
                guard let target = fishTarget(from: p) else { return }
                step.activations.append(Activation(origin: p, kind: .fish(target: target), affected: [target]))
                queue.append(target)
            }
        }

        func activateColorBomb(at p: Position) {
            let color = mostCommonColor()
            let cells = color.map(colorPositions) ?? []
            step.activations.append(Activation(origin: p, kind: .colorBomb(color), affected: cells))
            queue += cells
        }

        // 1. Special combination from the player's swap.
        if let combo {
            let center = combo.center
            let a = board[center]!.kind
            let b = board[combo.other]!.kind
            switch (a, b) {
            case (.colorBomb, .colorBomb):
                consume(center)
                consume(combo.other)
                let cells = board.positions
                step.activations.append(Activation(origin: center, kind: .wholeBoard, affected: cells))
                queue += cells

            case let (.colorBomb, .candy(color, special)), let (.candy(color, special), .colorBomb):
                let bombAt = a == .colorBomb ? center : combo.other
                consume(bombAt)
                let cells = colorPositions(color)
                if special != .none && special != .wrappedArmed {
                    for p in cells {
                        guard var piece = board[p], !piece.kind.isMix else { continue }
                        let newSpecial: Special = special.isStriped
                            ? (Bool.random(using: &rng) ? .stripedHorizontal : .stripedVertical)
                            : special
                        piece.kind = .candy(color, newSpecial)
                        board[p] = piece
                        step.transformed.append(PlacedPiece(piece, p))
                    }
                }
                step.activations.append(Activation(origin: bombAt, kind: .colorBomb(color), affected: cells))
                queue += cells

            case let (.candy(c1, s1), .candy(c2, s2)):
                consume(center)
                consume(combo.other)
                if s1 == .fish || s2 == .fish {
                    let (carried, carriedColor) = s1 == .fish ? (s2, c2) : (s1, c1)
                    if carried == .fish {
                        for _ in 0..<3 { activate(.fish, color: c1, at: center) }
                    } else if let target = fishTarget(from: center) {
                        step.activations.append(Activation(origin: center, kind: .fish(target: target),
                                                           affected: [target]))
                        queue.append(target)
                        activate(carried, color: carriedColor, at: target)
                    }
                } else if s1.isStriped && s2.isStriped {
                    let cells = Array(Set(row(center.row) + column(center.col))).sorted()
                    step.activations.append(Activation(origin: center, kind: .cross(width: 1), affected: cells))
                    queue += cells
                } else if s1.isStriped || s2.isStriped {
                    var cells = Set<Position>()
                    for d in -1...1 {
                        cells.formUnion(row(center.row + d))
                        cells.formUnion(column(center.col + d))
                    }
                    let sorted = cells.sorted()
                    step.activations.append(Activation(origin: center, kind: .cross(width: 3), affected: sorted))
                    queue += sorted
                } else {
                    let cells = area(center, radius: 2)
                    step.activations.append(Activation(origin: center, kind: .area(radius: 2), affected: cells))
                    queue += cells
                }

            default:
                break
            }
        }

        // 2. Regular matches and the specials they create.
        var matched = Set<Position>()
        for group in groups {
            matched.formUnion(group.positions)
            if let kind = group.rewardKind,
               let spot = placement(for: group, preferred: preferred, recentlyMoved: recentlyMoved) {
                creations.append((spot, kind))
            }
        }
        if level.mixing && index == 1 {
            creations += mixCreations(for: groups, taken: Set(creations.map(\.0)), preferred: preferred,
                                      recentlyMoved: recentlyMoved)
        }
        let matchedSorted = matched.sorted()
        queue += matchedSorted
        // Matches next to chocolate or blockers damage them.
        for p in matchedSorted {
            for n in p.neighbors where board.isPlayable(n) && board[n]?.kind.isObstacle == true {
                queue.append(n)
            }
        }
        // Wrapped candies from the last step explode a second time.
        queue += armed
        // Sugar rush: specials fired without a match.
        queue += detonate

        // 3. Apply all hits, following chain reactions.
        var head = 0
        while head < queue.count {
            let p = queue[head]
            head += 1
            guard board.isPlayable(p), !hitSet.contains(p) else { continue }
            hitSet.insert(p)

            var cell = board.cell(p)
            if cell.locked {
                cell.locked = false
                board.setCell(p, cell)
                step.locksBroken.append(p)
                step.scoreGained += 40
                continue
            }
            guard let piece = board[p] else { continue }
            switch piece.kind {
            case let .candy(color, special):
                board[p] = nil
                step.cleared.append(PlacedPiece(piece, p))
                step.scoreGained += Game.candyPoints * index
                clearJelly(p)
                activate(special, color: color, at: p)
            case .colorBomb:
                board[p] = nil
                step.cleared.append(PlacedPiece(piece, p))
                step.scoreGained += Game.candyPoints * index
                clearJelly(p)
                activateColorBomb(at: p)
            case .mix:
                board[p] = nil
                step.cleared.append(PlacedPiece(piece, p))
                step.served.append(PlacedPiece(piece, p))
                step.scoreGained += Game.candyPoints * index + Game.mixPoints
                clearJelly(p)
            case .ingredient:
                continue
            case .chocolate:
                board[p] = nil
                step.cleared.append(PlacedPiece(piece, p))
                step.scoreGained += 40
                chocolateDestroyed = true
                clearJelly(p)
            case let .blocker(hits):
                step.scoreGained += 40
                if hits <= 1 {
                    board[p] = nil
                    step.cleared.append(PlacedPiece(piece, p))
                    clearJelly(p)
                } else {
                    var damaged = piece
                    damaged.kind = .blocker(hits: hits - 1)
                    board[p] = damaged
                    step.damaged.append(PlacedPiece(damaged, p))
                }
            }
        }

        // 4. New specials, then wrapped candies waiting for their second blast.
        for (p, kind) in creations where board[p] == nil {
            let piece = board.makePiece(kind)
            board[p] = piece
            step.created.append(PlacedPiece(piece, p))
            step.scoreGained += kind == .colorBomb ? 200 : 100
        }
        for (p, color) in rearm where board[p] == nil {
            let piece = board.makePiece(.candy(color, .wrappedArmed))
            board[p] = piece
            step.rearmed.append(PlacedPiece(piece, p))
        }

        // 5. Gravity, refill and ingredients leaving the board.
        while true {
            let (falls, spawns) = board.collapse { board, _ in self.spawnPiece(on: &board) }
            step.falls += falls
            step.spawns += spawns
            var collectedAny = false
            for c in 0..<board.columns {
                guard let exit = board.exitRow(column: c) else { continue }
                let p = Position(exit, c)
                if let piece = board[p], piece.kind.isIngredient {
                    board[p] = nil
                    step.collected.append(PlacedPiece(piece, p))
                    step.scoreGained += 1000
                    collectedAny = true
                }
            }
            if !collectedAny { break }
        }
        step.falls = Game.mergeFalls(step.falls, spawns: &step.spawns)
        step.board = board
        return step
    }

    /// Several collapse rounds can move the same piece; keep one movement per piece.
    private static func mergeFalls(_ falls: [FallMove], spawns: inout [Spawn]) -> [FallMove] {
        var spawnIndex: [Int: Int] = [:]
        for (i, s) in spawns.enumerated() { spawnIndex[s.piece.id] = i }
        var order: [Int] = []
        var merged: [Int: FallMove] = [:]
        for fall in falls {
            if let i = spawnIndex[fall.pieceID] {
                spawns[i].position = fall.to
                continue
            }
            if merged[fall.pieceID] != nil {
                merged[fall.pieceID]!.to = fall.to
            } else {
                merged[fall.pieceID] = fall
                order.append(fall.pieceID)
            }
        }
        return order.compactMap { merged[$0] }
    }

    /// Mixing: where two matches of different colours touch, one mixed candy of both colours appears
    /// at the contact, preferably on the swapped cell.
    private func mixCreations(for groups: [MatchGroup], taken: Set<Position>, preferred: [Position],
                              recentlyMoved: Set<Position>) -> [(Position, PieceKind)] {
        var taken = taken
        var result: [(Position, PieceKind)] = []
        for (i, a) in groups.enumerated() {
            for b in groups[(i + 1)...] where a.color != b.color {
                let contacts = (a.sortedPositions.filter { $0.neighbors.contains(where: b.positions.contains) }
                    + b.sortedPositions.filter { $0.neighbors.contains(where: a.positions.contains) })
                    .filter { !taken.contains($0) && !board.cell($0).locked }
                guard let spot = preferred.first(where: contacts.contains)
                    ?? contacts.first(where: recentlyMoved.contains) ?? contacts.first else { continue }
                taken.insert(spot)
                result.append((spot, .mixed(a.color, b.color)))
            }
        }
        return result
    }

    /// Where a new special appears: at the swapped cell, else where something just landed,
    /// else at the centre of the shape (the corner of an L, the middle of a line).
    private func placement(for group: MatchGroup, preferred: [Position], recentlyMoved: Set<Position>) -> Position? {
        let candidates = group.sortedPositions.filter { !board.cell($0).locked }
        if let p = preferred.first(where: candidates.contains) { return p }
        if let p = candidates.first(where: recentlyMoved.contains) { return p }
        return candidates.max { a, b in
            let na = a.neighbors.filter(group.positions.contains).count
            let nb = b.neighbors.filter(group.positions.contains).count
            return na < nb || (na == nb && a > b)
        }
    }

    private func spawnPiece(on board: inout Board) -> Piece {
        let required = level.ingredientsRequired
        if required > 0, ingredientsSpawned < required {
            let onBoard = board.count { $0.isIngredient }
            if onBoard == 0 || (onBoard < level.maxIngredientsOnBoard && Int.random(in: 0..<10, using: &rng) == 0) {
                let kind = Ingredient.allCases[ingredientsSpawned % Ingredient.allCases.count]
                ingredientsSpawned += 1
                return board.makePiece(.ingredient(kind))
            }
        }
        return board.makePiece(.plain(level.palette.randomElement(using: &rng)!))
    }

    // MARK: After the move

    private func spreadChocolate() -> ChocolateSpread? {
        var options: [(Position, Position)] = []
        for p in board.positions(where: { $0.isChocolate }) {
            for n in p.neighbors where board.isPlayable(n) && !board.cell(n).locked {
                if let kind = board[n]?.kind, kind.color != nil { options.append((p, n)) }
            }
        }
        guard let (from, to) = options.randomElement(using: &rng), let replaced = board[to] else { return nil }
        let chocolate = board.makePiece(.chocolate)
        board[to] = chocolate
        return ChocolateSpread(from: from, to: to, replaced: replaced, chocolate: chocolate)
    }

    /// Mixes all movable candies until there is no match and at least one move.
    public func shuffle() {
        let spots = board.positions.filter { board.isSwappable($0) && board[$0]?.kind.isIngredient == false }
        var pieces = spots.compactMap { board[$0] }
        for _ in 0..<200 {
            pieces.shuffle(using: &rng)
            for (p, piece) in zip(spots, pieces) { board[p] = piece }
            if !MatchFinder.hasAnyMatch(in: board), MatchFinder.findPossibleMove(in: board) != nil { return }
        }
        // Very crowded boards: recolour plain candies instead.
        let plain = spots.filter { board[$0]?.kind.isPlainCandy == true }
        for p in plain { board[p] = nil }
        Game.fillWithoutMatches(&board, slots: plain, palette: level.palette, rng: &rng)
    }

    // MARK: Initial fill

    static func fillWithoutMatches(_ board: inout Board, slots: [Position], palette: [CandyColor],
                                   rng: inout SeededGenerator) {
        let template = board
        for _ in 0..<500 {
            board = template
            for p in slots {
                let options = palette.filter { color in
                    board[p] = board.makePiece(.plain(color))
                    return !MatchFinder.hasMatch(at: p, in: board)
                }
                let color = options.randomElement(using: &rng) ?? palette.randomElement(using: &rng)!
                board[p] = board.makePiece(.plain(color))
            }
            if MatchFinder.findPossibleMove(in: board) != nil && !MatchFinder.hasAnyMatch(in: board) { return }
        }
    }
}
