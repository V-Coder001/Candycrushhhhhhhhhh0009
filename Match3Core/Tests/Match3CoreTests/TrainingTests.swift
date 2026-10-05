import XCTest
@testable import Match3Core

final class SkillLevelTests: XCTestCase {
    func testTwoGoodRoundsMakeItHarder() {
        var level = SkillLevel()
        XCTAssertEqual(level.record(score: 0.9), 0)
        XCTAssertEqual(level.record(score: 0.85), 1)
        XCTAssertEqual(level.value, 2)
        XCTAssertEqual(level.record(score: 0.9), 0, "the streak starts again after a step up")
    }

    func testWeakRoundMakesItEasierButNotBelowOne() {
        var level = SkillLevel(value: 3)
        XCTAssertEqual(level.record(score: 0.3), -1)
        XCTAssertEqual(level.value, 2)
        level.record(score: 0.1)
        XCTAssertEqual(level.record(score: 0), 0)
        XCTAssertEqual(level.value, 1)
    }

    func testMiddlingRoundKeepsLevelAndBreaksStreak() {
        var level = SkillLevel(value: 5)
        level.record(score: 0.9)
        XCTAssertEqual(level.record(score: 0.6), 0)
        XCTAssertEqual(level.record(score: 0.9), 0)
        XCTAssertEqual(level.value, 5)
    }

    func testTopLevelStays() {
        var level = SkillLevel(value: 20)
        level.record(score: 1)
        XCTAssertEqual(level.record(score: 1), 0)
        XCTAssertEqual(level.value, 20)
        XCTAssertEqual(SkillLevel(value: 99).value, 20)
    }

    func testScaledRunsFromLowToHigh() {
        XCTAssertEqual(SkillLevel.scaled(1, from: 3, to: 12), 3)
        XCTAssertEqual(SkillLevel.scaled(20, from: 3, to: 12), 12)
        let values = (1...20).map { SkillLevel.scaled($0, from: 4, to: 12) }
        XCTAssertEqual(values, values.sorted())
    }
}

final class PairsRoundTests: XCTestCase {
    func testDeckHasMatchingPairs() {
        for level in SkillLevel.range {
            let round = PairsRound(level: level, motifCount: 24, seed: UInt64(level))
            XCTAssertEqual(round.pairs, PairsRound.pairCount(level: level))
            let counts = Dictionary(grouping: round.cards, by: \.motif).mapValues(\.count)
            XCTAssertTrue(counts.values.allSatisfy { $0 == 2 })
        }
    }

    func testPerfectGameScoresOne() {
        var round = PairsRound(level: 5, motifCount: 24, seed: 7)
        for motif in Set(round.cards.map(\.motif)) {
            let both = round.cards.indices.filter { round.cards[$0].motif == motif }
            XCTAssertEqual(round.flip(both[0]), .first)
            XCTAssertEqual(round.flip(both[1]), .match)
        }
        XCTAssertTrue(round.isComplete)
        XCTAssertEqual(round.score, 1)
        XCTAssertEqual(round.flip(0), .ignored)
    }

    func testMismatchTurnsBackOnNextFlip() {
        var round = PairsRound(level: 1, motifCount: 24, seed: 3)
        let a = 0
        let b = round.cards.indices.first { round.cards[$0].motif != round.cards[a].motif }!
        round.flip(a)
        XCTAssertEqual(round.flip(b), .mismatch)
        XCTAssertTrue(round.cards[a].isFaceUp)
        let c = round.cards.indices.first { $0 != a && $0 != b }!
        XCTAssertEqual(round.flip(c), .first)
        XCTAssertFalse(round.cards[a].isFaceUp)
        XCTAssertFalse(round.cards[b].isFaceUp)
        XCTAssertEqual(round.flip(c), .ignored, "an open card cannot be picked again")
        XCTAssertEqual(round.attempts, 1)
    }

    func testScoreDropsWithExtraAttempts() {
        var round = PairsRound(level: 1, motifCount: 24, seed: 1)
        // Three wrong attempts before solving: 6 attempts for 3 pairs.
        let byMotif = Dictionary(grouping: round.cards.indices, by: { round.cards[$0].motif })
        let motifs = Array(byMotif.keys)
        for i in 0..<3 {
            round.flip(byMotif[motifs[i]]![0])
            round.flip(byMotif[motifs[(i + 1) % 3]]![0])
        }
        round.hideMismatch()
        for motif in motifs {
            round.flip(byMotif[motif]![0])
            round.flip(byMotif[motif]![1])
        }
        XCTAssertTrue(round.isComplete)
        XCTAssertEqual(round.attempts, 6)
        XCTAssertEqual(round.score, 0.5, accuracy: 0.001)
    }
}

final class ShoppingListTests: XCTestCase {
    func testCatalogNamesAreUnique() {
        let names = ShoppingItem.catalog.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertGreaterThanOrEqual(names.count, 24, "enough items for 12 targets and 12 decoys")
    }

    func testChoicesHoldListAndDecoys() {
        for level in SkillLevel.range {
            let round = ShoppingListRound(level: level, seed: UInt64(level) * 31)
            XCTAssertEqual(round.list.count, ShoppingListRound.length(level: level))
            XCTAssertEqual(round.choices.count, 2 * round.list.count)
            XCTAssertEqual(Set(round.choices).count, round.choices.count)
            XCTAssertTrue(Set(round.list).isSubset(of: Set(round.choices)))
        }
    }

    func testScoreCountsHitsMinusWrongPicks() {
        var round = ShoppingListRound(level: 1, seed: 5)
        for item in round.list { round.toggle(item) }
        XCTAssertEqual(round.score, 1)
        let decoy = round.choices.first { !round.list.contains($0) }!
        round.toggle(decoy)
        XCTAssertEqual(round.score, 0.75)
        XCTAssertEqual(round.wrong, [decoy])
        round.toggle(round.list[0])
        XCTAssertEqual(round.missed, [round.list[0]])
        XCTAssertEqual(round.score, 0.5)
    }
}

final class SequenceRoundTests: XCTestCase {
    func testSequencesFitTheLevel() {
        for level in SkillLevel.range {
            let round = SequenceRound(level: level, seed: UInt64(level))
            XCTAssertEqual(round.trials.count, SequenceRound.trialsPerRound)
            for trial in round.trials {
                XCTAssertEqual(trial.count, SequenceRound.length(level: level))
                XCTAssertTrue(trial.allSatisfy { (0..<round.pads).contains($0) })
                XCTAssertFalse(zip(trial, trial.dropFirst()).contains { $0 == $1 }, "no pad twice in a row")
            }
        }
    }

    func testTappingBackTheSequence() {
        var round = SequenceRound(level: 1, seed: 9)
        let first = round.current
        for pad in first.dropLast() { XCTAssertEqual(round.tap(pad), .correct) }
        XCTAssertEqual(round.tap(first.last!), .finished(success: true))
        XCTAssertEqual(round.tap(0), .ignored, "waits until the player moves on")
        round.next()
        let wrong = (round.current[0] + 1) % round.pads
        XCTAssertEqual(round.tap(wrong), .finished(success: false))
        round.next()
        for pad in round.current { round.tap(pad) }
        round.next()
        XCTAssertTrue(round.isComplete)
        XCTAssertEqual(round.score, 2.0 / 3.0, accuracy: 0.001)
    }
}

final class ChangeRoundTests: XCTestCase {
    func testTasksHaveOneRightAnswerAmongFour() {
        for level in SkillLevel.range {
            for seed in 1...20 as ClosedRange<UInt64> {
                let round = ChangeRound(level: level, seed: seed)
                for task in round.tasks {
                    XCTAssertEqual(task.items.count, ChangeRound.itemCount(level: level))
                    XCTAssertGreaterThan(task.change, 0)
                    XCTAssertEqual(task.options.count, 4)
                    XCTAssertEqual(Set(task.options).count, 4)
                    XCTAssertEqual(task.options.filter { $0 == task.change }.count, 1)
                    XCTAssertTrue(task.options.allSatisfy { $0 > 0 })
                    XCTAssertTrue(task.prices.allSatisfy { $0 % ChangeRound.priceStep(level: level) == 0 })
                }
            }
        }
    }

    func testScoreCountsRightAnswers() {
        var round = ChangeRound(level: 3, seed: 2)
        for (i, task) in round.tasks.enumerated() {
            let wrong = task.options.first { $0 != task.change }!
            XCTAssertEqual(round.answer(i < 4 ? task.change : wrong), i < 4)
        }
        XCTAssertTrue(round.isComplete)
        XCTAssertEqual(round.score, 0.8, accuracy: 0.001)
    }

    func testMoneyFormat() {
        XCTAssertEqual(Money.format(730), "7,30 €")
        XCTAssertEqual(Money.format(5), "0,05 €")
        XCTAssertEqual(Money.format(1_000), "10,00 €")
    }
}

final class DailyPlanTests: XCTestCase {
    func testListFramesTwoDifferentGames() {
        let plan = DailyPlan(lastPlayed: [:], day: 100)
        XCTAssertEqual(plan.steps.first, .learnList)
        XCTAssertEqual(plan.steps.last, .recallList)
        XCTAssertEqual(plan.steps.count, 4)
        XCTAssertNotEqual(plan.steps[1], plan.steps[2])
        XCTAssertEqual(plan.gameCount, 3)
    }

    func testPicksGamesPlayedLongestAgo() {
        let plan = DailyPlan(lastPlayed: [.pairs: 10, .sequence: 12, .change: 11], day: 13)
        XCTAssertEqual(plan.steps[1], .play(.pairs))
        XCTAssertEqual(plan.steps[2], .play(.change))
        let fresh = DailyPlan(lastPlayed: [.pairs: 12], day: 13)
        XCTAssertFalse(fresh.steps.contains(.play(.pairs)), "never played games come first")
    }

    func testRotatesWhenNothingWasPlayed() {
        let firsts = Set((0..<3).map { DailyPlan(lastPlayed: [:], day: $0).steps[1] })
        XCTAssertEqual(firsts.count, 3)
    }
}
