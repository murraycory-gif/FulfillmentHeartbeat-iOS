import XCTest
@testable import FulfillmentHeartbeat

final class LoadingQuipsTests: XCTestCase {
    func testQuipListIsUniqueAndShuffleDoesNotRepeatUntilUsedUp() {
        let lines = LoadingQuips.lines
        XCTAssertFalse(lines.isEmpty)
        XCTAssertEqual(Set(lines).count, lines.count, "quip list has duplicate lines")

        var differedFromSource = false
        for seed in UInt64(1)...UInt64(30) {
            var generator = SeededGenerator(state: seed)
            let shuffled = LoadingQuips.shuffled(lines, using: &generator)
            XCTAssertEqual(shuffled.count, lines.count)
            XCTAssertEqual(Set(shuffled), Set(lines))
            XCTAssertEqual(Set(shuffled).count, shuffled.count, "shuffle repeated a line before the list was used up")
            if shuffled != lines { differedFromSource = true }
        }
        XCTAssertTrue(differedFromSource)

        var deckGenerator = SeededGenerator(state: 0x0828_0479)
        var deck = LoadingQuipDeck(lines: lines, using: &deckGenerator)
        let firstCycle = (0..<lines.count).map { _ in deck.next(using: &deckGenerator) }
        XCTAssertEqual(firstCycle.count, lines.count)
        XCTAssertEqual(Set(firstCycle).count, lines.count, "deck repeated a line before the list was used up")
        XCTAssertEqual(Set(firstCycle), Set(lines))

        let secondCycle = (0..<lines.count).map { _ in deck.next(using: &deckGenerator) }
        XCTAssertEqual(secondCycle.count, lines.count)
        XCTAssertEqual(Set(secondCycle).count, lines.count, "reshuffled deck repeated a line before that pass was used up")
        XCTAssertEqual(Set(secondCycle), Set(lines))
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
