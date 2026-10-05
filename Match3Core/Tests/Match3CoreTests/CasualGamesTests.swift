import XCTest
@testable import Match3Core

final class Twenty48Tests: XCTestCase {
    func testStartsWithTwoTiles() {
        let game = Twenty48(seed: 4)
        XCTAssertEqual(game.tiles.count, 2)
        XCTAssertTrue(game.tiles.allSatisfy { $0.value == 2 || $0.value == 4 })
    }

    func testEachTileMergesOncePerMove() {
        var game = Twenty48(grid: [[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        XCTAssertTrue(game.move(.left))
        XCTAssertEqual(Array(game.grid[0].prefix(2)), [4, 4])
        XCTAssertEqual(game.score, 8)
        XCTAssertEqual(game.tiles.count, 3, "two merged tiles plus one new")
    }

    func testMergesTowardsTheMovingSide() {
        var game = Twenty48(grid: [[0, 0, 0, 0], [2, 0, 2, 4], [0, 0, 0, 0], [0, 0, 0, 0]])
        game.move(.right)
        XCTAssertEqual(game.grid[1][2], 4)
        XCTAssertEqual(game.grid[1][3], 4)
    }

    func testVerticalMoves() {
        var game = Twenty48(grid: [[2, 0, 0, 0], [2, 0, 0, 0], [4, 0, 0, 0], [0, 0, 0, 0]])
        game.move(.down)
        XCTAssertEqual(game.grid[3][0], 4)
        XCTAssertEqual(game.grid[2][0], 4)
    }

    func testBlockedMoveChangesNothing() {
        var game = Twenty48(grid: [[2, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        XCTAssertFalse(game.move(.left))
        XCTAssertEqual(game.tiles.count, 2)
    }

    func testGameOverAndGoal() {
        let full = Twenty48(grid: [[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]])
        XCTAssertTrue(full.isOver)
        let open = Twenty48(grid: [[2, 2, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]])
        XCTAssertFalse(open.isOver)
        var almost = Twenty48(grid: [[1024, 1024, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        almost.move(.left)
        XCTAssertTrue(almost.reachedGoal)
    }

    func testRandomPlayKeepsTilesConsistent() {
        var game = Twenty48(seed: 11)
        var moves = 0
        while !game.isOver && moves < 2_000 {
            if !game.move(Twenty48.Direction.allCases[moves % 4]) { _ = game.move(.down) }
            moves += 1
            let cells = game.tiles.map { [$0.row, $0.col] }
            XCTAssertEqual(Set(cells).count, cells.count, "one tile per cell")
            XCTAssertEqual(Set(game.tiles.map(\.id)).count, game.tiles.count)
        }
        XCTAssertGreaterThan(game.score, 0)
    }
}

final class BlockPuzzleTests: XCTestCase {
    private let empty = Array(repeating: "........", count: 8)

    func testFullRowAndColumnClear() {
        // Row 7 and column 7 are full except their shared corner: one block finishes both.
        var rows = Array(repeating: ".......#", count: 7)
        rows.append("#######.")
        var game = BlockPuzzle(rows: rows, hand: [[.init(0, 0)], [.init(0, 0)], [.init(0, 0)]])
        let result = game.place(handIndex: 0, row: 7, col: 7)
        XCTAssertEqual(result?.clearedRows, [7])
        XCTAssertEqual(result?.clearedCols, [7])
        XCTAssertTrue(game.board.allSatisfy { $0.allSatisfy { $0 == nil } })
        XCTAssertEqual(result?.points, 1 + 2 * 10 * 2)
    }

    func testCannotPlaceOverBlocksOrEdge() {
        var rows = empty
        rows[0] = "#......."
        let game = BlockPuzzle(rows: rows, hand: [[.init(0, 0), .init(0, 1)]])
        let shape = game.hand[0]!
        XCTAssertFalse(game.canPlace(shape, row: 0, col: 0))
        XCTAssertFalse(game.canPlace(shape, row: 3, col: 7))
        XCTAssertTrue(game.canPlace(shape, row: 0, col: 1))
    }

    func testNewHandAfterThreePlacements() {
        var game = BlockPuzzle(seed: 3)
        for i in 0..<3 {
            let shape = game.hand[i]!
            var placed = false
            for r in 0..<8 where !placed {
                for c in 0..<8 where !placed && game.canPlace(shape, row: r, col: c) {
                    placed = game.place(handIndex: i, row: r, col: c) != nil
                }
            }
            XCTAssertTrue(placed)
        }
        XCTAssertEqual(game.hand.compactMap { $0 }.count, 3)
    }

    func testGameEndsWhenNothingFits() {
        let rows = ["#.#.#.#.", ".#.#.#.#", "#.#.#.#.", ".#.#.#.#", "#.#.#.#.", ".#.#.#.#", "#.#.#.#.", ".#.#.#.#"]
        let blocked = BlockPuzzle(rows: rows, hand: [[.init(0, 0), .init(0, 1)]])
        XCTAssertTrue(blocked.isOver)
        let single = BlockPuzzle(rows: rows, hand: [[.init(0, 0)]])
        XCTAssertFalse(single.isOver)
    }

    func testCatalogShapesAreNormalised() {
        for cells in BlockPuzzle.catalog {
            XCTAssertEqual(cells.map(\.row).min(), 0)
            XCTAssertEqual(cells.map(\.col).min(), 0)
            XCTAssertEqual(Set(cells).count, cells.count)
        }
    }
}

final class KlondikeTests: XCTestCase {
    private func card(_ suit: PlayingCard.Suit, _ rank: Int, up: Bool = true) -> PlayingCard {
        PlayingCard(suit: suit, rank: rank, faceUp: up)
    }

    func testDealHas52CardsAndTopsFaceUp() {
        let game = Klondike(seed: 9)
        XCTAssertEqual(game.tableau.map(\.count), [1, 2, 3, 4, 5, 6, 7])
        XCTAssertTrue(game.tableau.allSatisfy { $0.last!.faceUp && $0.dropLast().allSatisfy { !$0.faceUp } })
        XCTAssertEqual(game.stock.count, 24)
        let all = game.tableau.flatMap { $0 } + game.stock
        XCTAssertEqual(Set(all.map(\.id)).count, 52)
    }

    func testAceGoesToFoundationAndRevealsCardBelow() {
        var game = Klondike(tableau: [[card(.clubs, 9, up: false), card(.hearts, 1)], [], [], [], [], [], []])
        XCTAssertEqual(game.autoMove(from: .tableau(0)), .foundation(0))
        XCTAssertEqual(game.foundations[0].map(\.rank), [1])
        XCTAssertTrue(game.tableau[0][0].faceUp)
    }

    func testStackMovesOntoOppositeColourOneHigher() {
        var game = Klondike(tableau: [
            [card(.spades, 8), card(.hearts, 7), card(.clubs, 6)],
            [card(.diamonds, 9)],
            [], [], [], [], [],
        ])
        // The 8 with everything on it goes onto the red 9.
        XCTAssertEqual(game.autoMove(from: .tableau(0), index: 0), .tableau(1))
        XCTAssertEqual(game.tableau[1].map(\.rank), [9, 8, 7, 6])
        XCTAssertTrue(game.tableau[0].isEmpty)
    }

    func testOnlyKingsOnEmptyColumns() {
        var game = Klondike(tableau: [[card(.hearts, 5)], [], [card(.spades, 13)], [], [], [], []])
        XCTAssertNil(game.autoMove(from: .tableau(0)))
        var withKing = Klondike(tableau: [[card(.hearts, 2, up: false), card(.spades, 13)], [], [], [], [], [], []])
        XCTAssertEqual(withKing.autoMove(from: .tableau(0)), .tableau(1))
        XCTAssertNil(game.autoMove(from: .tableau(2)), "a king that is already alone stays")
    }

    func testDrawAndRecycleAndUndo() {
        var game = Klondike(tableau: Array(repeating: [], count: 7),
                            stock: [card(.clubs, 3, up: false), card(.hearts, 4, up: false)])
        game.draw()
        XCTAssertEqual(game.waste.map(\.rank), [4])
        game.draw()
        XCTAssertEqual(game.stock.count, 0)
        game.draw()
        XCTAssertEqual(game.stock.map(\.rank), [3, 4], "the waste turns back over in its original order")
        XCTAssertTrue(game.stock.allSatisfy { !$0.faceUp })
        game.undo()
        XCTAssertEqual(game.waste.count, 2)
    }

    func testAutoFinishWinsAnOpenGame() {
        var tableau: [[PlayingCard]] = Array(repeating: [], count: 7)
        for (i, suit) in PlayingCard.Suit.allCases.enumerated() {
            tableau[i] = (1...13).reversed().map { card(suit, $0) }
        }
        var game = Klondike(tableau: tableau)
        XCTAssertTrue(game.canAutoFinish)
        game.autoFinish()
        XCTAssertTrue(game.isWon)
    }
}

final class ChessTests: XCTestCase {
    /// Counts leaf positions; the standard numbers catch almost every rule mistake.
    private func perft(_ game: Chess, _ depth: Int) -> Int {
        guard depth > 0 else { return 1 }
        return game.legalMoves().reduce(0) { total, move in
            var next = game
            next.play(move)
            return total + perft(next, depth - 1)
        }
    }

    func testPerftFromStart() {
        XCTAssertEqual(perft(Chess(), 1), 20)
        XCTAssertEqual(perft(Chess(), 2), 400)
        XCTAssertEqual(perft(Chess(), 3), 8_902)
    }

    func testPerftKiwipete() {
        // A position full of castling, en passant and promotion tricks.
        let game = Chess(diagram: [
            "r...k..r",
            "p.ppqpb.",
            "bn..pnp.",
            "...PN...",
            ".p..P...",
            "..N..Q.p",
            "PPPBBPPP",
            "R...K..R",
        ])
        XCTAssertEqual(perft(game, 1), 48)
        XCTAssertEqual(perft(game, 2), 2_039)
    }

    func testCastlingNotThroughCheck() {
        var game = Chess(diagram: [
            "....k...",
            "........",
            "........",
            "........",
            "........",
            "........",
            "........",
            "R...K..R",
        ])
        XCTAssertTrue(game.legalMoves(from: 4).contains(Chess.Move(from: 4, to: 6)))
        XCTAssertTrue(game.play(Chess.Move(from: 4, to: 6)))
        XCTAssertEqual(game.board[5], Chess.Piece(.white, .rook))
        let attacked = Chess(diagram: [
            "....k...",
            ".....r..",
            "........",
            "........",
            "........",
            "........",
            "........",
            "R...K..R",
        ])
        XCTAssertFalse(attacked.legalMoves(from: 4).contains(Chess.Move(from: 4, to: 6)), "f1 is attacked")
        XCTAssertTrue(attacked.legalMoves(from: 4).contains(Chess.Move(from: 4, to: 2)))
    }

    func testEnPassantAndPromotion() {
        var game = Chess(diagram: [
            "....k...",
            "...p....",
            "........",
            "....P...",
            "........",
            "........",
            "......p.",
            "....K...",
        ], turn: .black)
        XCTAssertTrue(game.play(Chess.Move(from: 51, to: 35)))  // d7-d5
        XCTAssertTrue(game.play(Chess.Move(from: 36, to: 43)))  // e5xd6 en passant
        XCTAssertNil(game.board[35], "the passed pawn is taken")
        XCTAssertTrue(game.play(Chess.Move(from: 14, to: 6)))   // g2-g1 becomes a queen
        XCTAssertEqual(game.board[6], Chess.Piece(.black, .queen))
    }

    func testMateAndStalemate() {
        let mated = Chess(diagram: [
            "R.....k.",
            ".....ppp",
            "........",
            "........",
            "........",
            "........",
            "........",
            "......K.",
        ], turn: .black)
        XCTAssertEqual(mated.status, .checkmate(winner: .white))
        let stalemate = Chess(diagram: [
            "k.......",
            "..Q.....",
            ".K......",
            "........",
            "........",
            "........",
            "........",
            "........",
        ], turn: .black)
        XCTAssertEqual(stalemate.status, .stalemate)
    }

    func testComputerFindsMateInOne() {
        let game = Chess(diagram: [
            "......k.",
            ".....ppp",
            "........",
            "........",
            "........",
            "........",
            "........",
            "R.....K.",
        ])
        XCTAssertEqual(game.computerMove(level: 2, seed: 1), Chess.Move(from: 0, to: 56))
    }

    func testComputerTakesAHangingQueen() {
        let game = Chess(diagram: [
            "....k...",
            "........",
            "........",
            "...q....",
            "........",
            "..N.....",
            "........",
            "....K...",
        ])
        XCTAssertEqual(game.computerMove(level: 2, seed: 3), Chess.Move(from: 18, to: 35))
    }

    func testUndoRestoresPosition() {
        var game = Chess()
        game.play(Chess.Move(from: 12, to: 28))
        game.play(Chess.Move(from: 52, to: 36))
        game.undo()
        game.undo()
        XCTAssertEqual(game.board, Chess().board)
        XCTAssertEqual(game.turn, .white)
        XCTAssertFalse(game.canUndo)
    }
}
