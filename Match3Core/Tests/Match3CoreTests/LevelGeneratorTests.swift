import XCTest
@testable import Match3Core

final class LevelGeneratorTests: XCTestCase {
    private var generated: ArraySlice<Level> { Level.campaign[(LevelGenerator.firstID - 1)...] }

    func testCampaignHasThousandNewLevels() {
        XCTAssertEqual(Level.campaign.count, Level.handmade.count + 1_000)
        XCTAssertEqual(generated.first?.id, Level.handmade.count + 1)
    }

    func testGenerationIsReproducible() {
        for id in [13, 14, 250, 777, 1_012] {
            XCTAssertEqual(LevelGenerator.level(id: id), Level.campaign[id - 1])
        }
    }

    /// Stars are stored per level id, so a generated level must not change by accident.
    /// If the generator is changed on purpose, update the checksum.
    func testGeneratedLevelsStayTheSame() {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for level in generated {
            let text = "\(level.id)|\(level.name)|\(level.moves)|\(level.colors)|\(level.goals)|\(level.starScores)|"
                + level.layout.joined(separator: "/") + "|\(level.maxIngredientsOnBoard)"
            for byte in text.utf8 {
                hash = (hash ^ UInt64(byte)) &* 0x100_0000_01B3
            }
        }
        XCTAssertEqual(hash, 13_202_938_759_730_414_724, "generated levels changed")
    }

    func testNamesAreUnique() {
        let names = Level.campaign.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testShapesHaveNoNarrowCorridors() {
        for (index, shape) in LevelGenerator.shapes.enumerated() {
            let cells = shape.rows.map(Array.init)
            XCTAssertEqual(cells.count, 9)
            XCTAssertTrue(cells.allSatisfy { $0.count == 9 })
            for (r, row) in cells.enumerated() {
                XCTAssertEqual(String(row), String(row.reversed()), "shape \(index) is symmetric")
                // Length of the stretch of playable cells around each cell in its row.
                for c in 0..<9 where row[c] != "#" {
                    var from = c, to = c
                    while from > 0 && row[from - 1] != "#" { from -= 1 }
                    while to < 8 && row[to + 1] != "#" { to += 1 }
                    XCTAssertGreaterThanOrEqual(to - from + 1, 3, "shape \(index) row \(r) col \(c)")
                }
            }
        }
    }

    func testGeneratedLevelsAreSound() {
        for level in generated {
            let text = level.layout.joined()
            // Symmetric apart from which ingredient sits where.
            let rows = level.layout.map { String($0.map { "ih".contains($0) ? "." : $0 }) }
            XCTAssertTrue(rows.allSatisfy { $0 == String($0.reversed()) }, "\(level.id) is symmetric")
            XCTAssertTrue((12...50).contains(level.moves), "\(level.id) moves")
            XCTAssertTrue((5...6).contains(level.colors), "\(level.id) colours")
            XCTAssertEqual(level.starScores, level.starScores.sorted(), "\(level.id) stars")
            XCTAssertEqual(Set(level.starScores).count, 3, "\(level.id) stars differ")
            if level.ingredientsRequired > 0 {
                XCTAssertTrue(level.layout[0].contains { "ih".contains($0) }, "\(level.id) starts with an ingredient")
                XCTAssertTrue((1...4).contains(level.ingredientsRequired))
            }
            if level.goals.contains(.clearJelly) {
                XCTAssertGreaterThanOrEqual(text.filter { "jJk".contains($0) }.count, 6, "\(level.id) jelly")
            }
            if level.goals.contains(.clearChocolate) {
                XCTAssertGreaterThanOrEqual(text.filter { $0 == "c" }.count, 3, "\(level.id) chocolate")
            }
            if case let .score(target) = level.goals.first {
                XCTAssertEqual(level.starScores[0], target, "\(level.id) first star is the goal")
            }
            // Obstacles stay a minority of the board.
            let open = text.filter { $0 != "#" }.count
            XCTAssertLessThanOrEqual(text.filter { "lkbBc".contains($0) }.count * 3, open, "\(level.id) obstacles")
        }
    }

    func testEveryGoalAndBothColourCountsAppear() {
        var kinds: Set<String> = []
        for level in generated {
            for goal in level.goals {
                switch goal {
                case .score: kinds.insert("score")
                case .clearJelly: kinds.insert("jelly")
                case .collectIngredients: kinds.insert("ingredients")
                case .clearChocolate: kinds.insert("chocolate")
                case .serveMixes: kinds.insert("mixes")
                }
            }
        }
        XCTAssertEqual(kinds, ["score", "jelly", "ingredients", "chocolate"])
        XCTAssertTrue(generated.contains { $0.colors == 6 })
        XCTAssertTrue(generated.contains { $0.goals.count == 2 })
    }

    func testDifficultyRisesOverTheCampaign() {
        func averageDifficulty(_ ids: Range<Int>) -> Double {
            let values = ids.map { id -> Double in
                var rng = LevelRandom(seed: UInt64(id))
                return LevelGenerator.difficulty(id: id, rng: &rng)
            }
            return values.reduce(0, +) / Double(values.count)
        }
        XCTAssertLessThan(averageDifficulty(13..<113) + 0.4, averageDifficulty(913..<1_013))
    }
}
