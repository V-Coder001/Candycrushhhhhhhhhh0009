import XCTest
@testable import Match3Core

func testLevel(moves: Int = 10, goals: [Goal] = [.score(1_000_000)], colors: Int = 5) -> Level {
    Level(id: 0, name: "Test", moves: moves, colors: colors, goals: goals,
          starScores: [0, 1_000, 2_000], layout: [])
}

final class SwapTests: XCTestCase {
    func testInvalidSwapRevertsAndCostsNoMove() {
        let board = Board.parse([
            "R G B",
            "G B R",
            "B R G",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(0, 0), Position(0, 1))
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(game.board, board)
        XCTAssertEqual(game.movesLeft, 10)
    }

    func testMatchClearsAndGravityPullsDown() {
        let board = Board.parse([
            "P B P",
            "Y O Y",
            "R G R",
            "O R O",
        ])
        let yellowLeft = board[Position(1, 0)]!.id
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(3, 1), Position(2, 1))
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(game.movesLeft, 9)

        let first = result.steps[0]
        XCTAssertEqual(Set(first.cleared.map(\.position)), [Position(2, 0), Position(2, 1), Position(2, 2)])
        XCTAssertTrue(first.falls.contains(FallMove(pieceID: yellowLeft, from: Position(1, 0), to: Position(2, 0))))
        XCTAssertEqual(first.spawns.count, 3)
        XCTAssertTrue(first.spawns.allSatisfy { $0.position.row == 0 && $0.startRow == -1 })
        XCTAssertEqual(first.scoreGained, 3 * Game.candyPoints)
        XCTAssertGreaterThanOrEqual(game.score, 60)
    }

    func testCascadesRunUntilBoardIsStable() {
        for level in Level.campaign {
            // Every handmade level on many seeds, the generated ones on a couple each.
            let seeds: ClosedRange<UInt64> = level.id < LevelGenerator.firstID ? 1...25 : 1...2
            for seed in seeds {
                let game = Game(level: level, seed: seed)
                var score = 0
                for _ in 0..<12 {
                    guard game.status == .playing, let (a, b) = game.hint() else { break }
                    let moves = game.movesLeft
                    let result = game.swap(a, b)
                    XCTAssertTrue(result.isValid)
                    // A won level turns its leftover moves into the sugar rush.
                    XCTAssertEqual(game.movesLeft, game.status == .won ? 0 : moves - 1, "level \(level.id)")
                    XCTAssertFalse(MatchFinder.hasAnyMatch(in: game.board), "level \(level.id) seed \(seed)\n\(game.board)")
                    XCTAssertFalse(game.board.positions.contains { game.board[$0]?.kind.special == .wrappedArmed })
                    XCTAssertGreaterThanOrEqual(game.score, score)
                    score = game.score
                    let ids = game.board.allPieces.map(\.1.id)
                    XCTAssertEqual(ids.count, Set(ids).count, "piece ids must be unique")
                    if game.status == .playing {
                        XCTAssertNotNil(game.hint(), "a playable board always has a move")
                    }
                    for step in result.steps {
                        XCTAssertEqual(step.board.rows, level.rows)
                    }
                }
            }
        }
    }

    func testOpenBoardsAreAlwaysFull() {
        for seed in 1...20 as ClosedRange<UInt64> {
            let game = Game(level: Level.campaign[0], seed: seed)
            for _ in 0..<10 {
                guard let (a, b) = game.hint(), game.status == .playing else { break }
                game.swap(a, b)
                XCTAssertTrue(game.board.positions.allSatisfy { game.board[$0] != nil })
            }
        }
    }

    func testSameSeedSameGame() {
        let a = Game(level: Level.campaign[2], seed: 42)
        let b = Game(level: Level.campaign[2], seed: 42)
        XCTAssertEqual(a.board.textRows, b.board.textRows)
        let (p, q) = a.hint()!
        a.swap(p, q)
        b.swap(p, q)
        XCTAssertEqual(a.board.textRows, b.board.textRows)
        XCTAssertEqual(a.score, b.score)
    }

    func testDiagonalRefillAroundBlocker() {
        var board = Board.parse([
            "R G B",
            "_ X3 _",
            "_ _ _",
        ])
        let (falls, spawns) = board.collapse { board, _ in board.makePiece(.plain(.yellow)) }
        XCTAssertTrue(board.positions.allSatisfy { board[$0] != nil }, "\(board)")
        XCTAssertEqual(board[Position(1, 1)]?.kind, .blocker(hits: 3))
        XCTAssertFalse(falls.isEmpty)
        XCTAssertFalse(spawns.isEmpty)
        XCTAssertTrue(spawns.allSatisfy { $0.startRow < 0 })
    }

    func testPiecesFallThroughHoles() {
        var board = Board.parse([
            "R",
            "#",
            "_",
        ])
        let id = board[Position(0, 0)]!.id
        let (falls, _) = board.collapse { board, _ in board.makePiece(.plain(.blue)) }
        XCTAssertEqual(board[Position(2, 0)]?.id, id)
        XCTAssertEqual(falls, [FallMove(pieceID: id, from: Position(0, 0), to: Position(2, 0))])
        XCTAssertNotNil(board[Position(0, 0)])
    }
}

final class SpecialCandyTests: XCTestCase {
    func testFourInRowCreatesStripedWhereThePlayerSwapped() {
        let board = Board.parse([
            "R R G R Y",
            "G B R B G",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(1, 2), Position(0, 2))
        let created = result.steps[0].created
        XCTAssertEqual(created.count, 1)
        XCTAssertEqual(created[0].position, Position(0, 2))
        XCTAssertEqual(created[0].piece.kind, .candy(.red, .stripedVertical))
    }

    func testLShapeCreatesWrappedAtCorner() {
        let board2 = Board.parse([
            "Y G B G",
            "Y B G B",
            "G Y Y B",
            "Y G R G",
        ])
        let game2 = Game(level: testLevel(), board: board2)
        let result2 = game2.swap(Position(3, 0), Position(2, 0))
        XCTAssertTrue(result2.isValid)
        XCTAssertEqual(result2.steps[0].created.first?.piece.kind, .candy(.yellow, .wrapped))
        XCTAssertEqual(result2.steps[0].created.first?.position, Position(2, 0))
    }

    func testStripedClearsItsRow() {
        let board = Board.parse([
            "G B R Y G",
            "R R- G B Y",
            "Y G B G R",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(0, 2), Position(1, 2))
        let step = result.steps[0]
        XCTAssertTrue(step.activations.contains { $0.kind == .lineHorizontal && $0.origin == Position(1, 1) })
        let clearedRow = Set(step.cleared.map(\.position)).filter { $0.row == 1 }
        XCTAssertEqual(clearedRow.count, 5)
    }

    func testWrappedExplodesTwice() {
        let board = Board.parse([
            "B G Y B G",
            "G Y B G Y",
            "Y R@ G R Y",
            "G B R B G",
            "B G Y G B",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(3, 2), Position(2, 2))
        XCTAssertTrue(result.isValid)
        let first = result.steps[0]
        XCTAssertTrue(first.activations.contains { $0.kind == .area(radius: 1) && $0.origin == Position(2, 1) })
        XCTAssertEqual(first.rearmed.count, 1)
        let armedID = first.rearmed[0].piece.id
        let landed = first.board.allPieces.first { $0.1.id == armedID }!.0
        XCTAssertGreaterThanOrEqual(result.steps.count, 2)
        XCTAssertTrue(result.steps[1].activations.contains { $0.kind == .area(radius: 1) && $0.origin == landed })
        XCTAssertFalse(game.board.allPieces.contains { $0.1.kind.special == .wrappedArmed })
    }

    func testColorBombClearsChosenColor() {
        let board = Board.parse([
            "* G B Y",
            "G B Y G",
            "Y G G B",
        ])
        let greens = Set(board.positions { $0.color == .green })
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(0, 0), Position(0, 1))
        XCTAssertTrue(result.isValid)
        let step = result.steps[0]
        XCTAssertTrue(step.activations.contains { $0.kind == .colorBomb(.green) })
        let cleared = Set(step.cleared.map(\.piece.id))
        for p in greens { XCTAssertTrue(cleared.contains(board[p]!.id)) }
        XCTAssertTrue(cleared.contains(board[Position(0, 0)]!.id))
    }

    func testColorBombWithStripedTurnsColorIntoStripes() {
        let board = Board.parse([
            "* G- B Y",
            "Y B G B",
            "B Y B G",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(0, 1), Position(0, 0))
        let step = result.steps[0]
        XCTAssertEqual(step.transformed.count, 3)
        XCTAssertTrue(step.transformed.allSatisfy { $0.piece.kind.special.isStriped })
        XCTAssertGreaterThanOrEqual(step.activations.filter { $0.kind == .lineHorizontal || $0.kind == .lineVertical }.count, 2)
    }

    func testTwoColorBombsClearTheBoard() {
        let board = Board.parse([
            "* * G",
            "B Y R",
            "G R Y",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(0, 0), Position(0, 1))
        XCTAssertEqual(result.steps[0].cleared.count, 9)
        XCTAssertTrue(result.steps[0].activations.contains { $0.kind == .wholeBoard })
    }

    func testStripedPlusStripedClearsCross() {
        let board = Board.parse([
            "G B Y G B",
            "Y G B Y G",
            "B R- G| B Y",
            "G Y B G B",
            "Y B Y B G",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(2, 1), Position(2, 2))
        let step = result.steps[0]
        XCTAssertTrue(step.activations.contains { $0.kind == .cross(width: 1) && $0.origin == Position(2, 2) })
        let cleared = Set(step.cleared.map(\.position))
        for c in 0..<5 { XCTAssertTrue(cleared.contains(Position(2, c))) }
        for r in 0..<5 { XCTAssertTrue(cleared.contains(Position(r, 2))) }
    }

    func testStripedPlusWrappedClearsThreeLines() {
        let board = Board.parse([
            "G B Y G B",
            "Y G B Y G",
            "B R- G@ B Y",
            "G Y B G B",
            "Y B Y B G",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(2, 1), Position(2, 2))
        XCTAssertEqual(result.steps[0].cleared.count, 25 - 4)
    }

    func testFishFliesToJelly() {
        let board = Board.parse([
            "B Y G Y",
            "G> G R jB",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(0, 2), Position(1, 2))
        let step = result.steps[0]
        XCTAssertTrue(step.activations.contains { $0.kind == .fish(target: Position(1, 3)) })
        XCTAssertEqual(step.jellyHit, [Position(1, 3)])
    }

    func testSquareCreatesFish() {
        let board = Board.parse([
            "G G B Y",
            "Y G B Y",
            "G B Y B",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(2, 0), Position(1, 0))
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.steps[0].created.first?.piece.kind, .candy(.green, .fish))
    }
}

final class ObstacleAndGoalTests: XCTestCase {
    func testJellyIsClearedUnderMatch() {
        let board = Board.parse([
            "jR jR G",
            "B G R",
        ])
        let game = Game(level: testLevel(goals: [.clearJelly]), board: board)
        let result = game.swap(Position(1, 2), Position(0, 2))
        XCTAssertEqual(Set(result.steps[0].jellyHit), [Position(0, 0), Position(0, 1)])
        XCTAssertEqual(game.board.jellyRemaining, 0)
        XCTAssertEqual(game.status, .won)
        XCTAssertEqual(game.movesLeft, 0, "leftover moves go into the sugar rush")
        XCTAssertFalse(result.sugarRush.isEmpty)
        XCTAssertEqual(result.sugarRush.reduce(0) { $0 + $1.movesSpent }, 9)
        XCTAssertGreaterThanOrEqual(result.bonusScore, 9 * Game.bonusPerMove)
    }

    func testDoubleJellyNeedsTwoHits() {
        let board = Board.parse([
            "kR R G",
            "B G R",
        ])
        let game = Game(level: testLevel(goals: [.clearJelly]), board: board)
        game.swap(Position(1, 2), Position(0, 2))
        XCTAssertEqual(game.board.cell(Position(0, 0)).jelly, 1)
        XCTAssertEqual(game.status, .playing)
    }

    func testMatchBreaksLockButKeepsCandy() {
        let board = Board.parse([
            "R G lR",
            "B R Y",
        ])
        let lockedID = board[Position(0, 2)]!.id
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(1, 1), Position(0, 1))
        let step = result.steps[0]
        XCTAssertEqual(step.locksBroken, [Position(0, 2)])
        XCTAssertFalse(step.cleared.contains { $0.piece.id == lockedID })
        XCTAssertFalse(step.board.cell(Position(0, 2)).locked)
    }

    func testBlockerNeedsSeveralHits() {
        let board = Board.parse([
            "R G R X2",
            "B R Y G",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(1, 1), Position(0, 1))
        XCTAssertEqual(result.steps[0].damaged.map(\.piece.kind), [.blocker(hits: 1)])
        XCTAssertEqual(game.board[Position(0, 3)]?.kind, .blocker(hits: 1))
    }

    func testChocolateNextToMatchIsDestroyed() {
        let board = Board.parse([
            "R G R C",
            "B R Y G",
        ])
        let game = Game(level: testLevel(goals: [.clearChocolate]), board: board)
        let result = game.swap(Position(1, 1), Position(0, 1))
        XCTAssertTrue(result.steps[0].cleared.contains { $0.piece.kind == .chocolate })
        XCTAssertNil(result.chocolateSpread)
        XCTAssertEqual(game.status, .won)
    }

    func testChocolateSpreadsWhenLeftAlone() {
        let board = Board.parse([
            "R G R Y B",
            "B R Y G Y",
            "Y B G B G",
            "G Y B G C",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.swap(Position(1, 1), Position(0, 1))
        let destroyed = result.steps.contains { $0.cleared.contains { $0.piece.kind == .chocolate } }
        XCTAssertFalse(destroyed)
        let spread = try! XCTUnwrap(result.chocolateSpread)
        XCTAssertEqual(spread.from, Position(3, 4))
        XCTAssertEqual(game.board.count { $0.isChocolate }, 2)
    }

    func testIngredientIsCollectedAtTheBottom() {
        let board = Board.parse([
            "Y I G",
            "R G R",
            "G R G",
        ])
        let game = Game(level: testLevel(goals: [.collectIngredients(1)]), board: board)
        let result = game.swap(Position(1, 1), Position(2, 1))
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(game.ingredientsCollected, 1)
        XCTAssertEqual(result.steps[0].collected.count, 1)
        XCTAssertEqual(game.status, .won)
    }

    func testScoreGoalWins() {
        let board = Board.parse([
            "R G R",
            "B R Y",
        ])
        let game = Game(level: testLevel(moves: 1, goals: [.score(10)]), board: board)
        game.swap(Position(1, 1), Position(0, 1))
        XCTAssertEqual(game.status, .won)
        XCTAssertEqual(game.stars, 1, "60 points, below the second star")
        XCTAssertTrue(game.goalProgress[0].isMet)
    }

    func testScoreLevelKeepsGoingUntilTheLastMove() {
        let board = Board.parse([
            "R G R Y",
            "B R Y B",
            "Y B G R",
        ])
        let game = Game(level: testLevel(moves: 5, goals: [.score(10)]), board: board)
        let result = game.swap(Position(1, 1), Position(0, 1))
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(game.goalProgress[0].isMet)
        XCTAssertEqual(game.status, .playing, "score levels use every move, so more stars stay reachable")
        XCTAssertEqual(game.movesLeft, 4)
    }

    func testSugarRushFiresLeftoverSpecials() {
        let board = Board.parse([
            "jR jR G B",
            "B G R Y|",
            "Y B G R",
        ])
        let game = Game(level: testLevel(moves: 3, goals: [.clearJelly]), board: board)
        let result = game.swap(Position(1, 2), Position(0, 2))
        XCTAssertEqual(game.status, .won)
        let fired = result.sugarRush.flatMap(\.activations)
        XCTAssertTrue(fired.contains { $0.kind == .lineVertical }, "the striped candy left on the board goes off")
        XCTAssertEqual(game.movesLeft, 0)
        XCTAssertEqual(game.score, result.steps.reduce(0) { $0 + $1.scoreGained } + result.bonusScore)
    }

    func testRunningOutOfMovesLoses() {
        let board = Board.parse([
            "R G R",
            "B R Y",
        ])
        let game = Game(level: testLevel(moves: 1), board: board)
        let result = game.swap(Position(1, 1), Position(0, 1))
        XCTAssertEqual(result.status, .lost)
        XCTAssertFalse(game.swap(Position(0, 0), Position(0, 1)).isValid, "no moves after the game ended")
    }

    func testShuffleCreatesAMoveWithoutMatches() {
        let board = Board.parse([
            "R G B Y",
            "B Y R G",
            "R G B Y",
            "B Y R G",
        ])
        XCTAssertNil(MatchFinder.findPossibleMove(in: board), "\(board)")
        let game = Game(level: testLevel(), board: board)
        game.shuffle()
        XCTAssertFalse(MatchFinder.hasAnyMatch(in: game.board))
        XCTAssertNotNil(MatchFinder.findPossibleMove(in: game.board))
    }

    func testComboWords() {
        XCTAssertNil(ComboWord.forMove(cascades: 1, cleared: 3))
        XCTAssertEqual(ComboWord.forMove(cascades: 2, cleared: 6), .sweet)
        XCTAssertEqual(ComboWord.forMove(cascades: 4, cleared: 12), .delicious)
        XCTAssertEqual(ComboWord.forMove(cascades: 6, cleared: 12), .divine)
    }
}

final class LevelTests: XCTestCase {
    func testCampaignIsWellFormed() {
        let levels = Level.campaign
        XCTAssertEqual(levels.map(\.id), Array(1...levels.count))
        for level in levels {
            XCTAssertEqual(level.rows, 9, level.name)
            XCTAssertTrue(level.layout.allSatisfy { $0.count == 9 }, level.name)
            XCTAssertEqual(level.starScores.count, 3)
            XCTAssertEqual(level.starScores, level.starScores.sorted())
            XCTAssertFalse(level.goals.isEmpty)
            if level.goals.contains(.clearJelly) {
                XCTAssertTrue(level.layout.joined().contains { "jJk".contains($0) }, level.name)
            }
            if level.goals.contains(.clearChocolate) {
                XCTAssertTrue(level.layout.joined().contains("c"), level.name)
            }
        }
    }

    func testEveryLevelStartsPlayable() {
        for level in Level.campaign {
            let seeds: ClosedRange<UInt64> = level.id < LevelGenerator.firstID ? 1...15 : 1...4
            for seed in seeds {
                let game = Game(level: level, seed: seed)
                XCTAssertFalse(MatchFinder.hasAnyMatch(in: game.board), "\(level.name) seed \(seed)")
                XCTAssertNotNil(game.hint(), "\(level.name) seed \(seed)")
                XCTAssertEqual(game.movesLeft, level.moves)
                XCTAssertEqual(game.status, .playing)
            }
        }
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(Level.campaign)
        let decoded = try JSONDecoder().decode([Level].self, from: data)
        XCTAssertEqual(decoded, Level.campaign)
    }
}
