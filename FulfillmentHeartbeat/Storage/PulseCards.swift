import Foundation

struct PulseCards: Codable {
    var generatedAt: Date
    var shopperCount: Int
    var opportunityCount: Int
    var strongCount: Int
    var opportunity: [MetricRow]
    var strong: [MetricRow]

    static let fileName = "pulse-cards.json"

    static func write(_ cards: PulseCards, to url: URL) throws {
        let data = try JSONEncoder().encode(cards)
        try data.write(to: url, options: .atomic)
    }

    static func read(from url: URL) -> PulseCards? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PulseCards.self, from: data)
    }

    func board() -> HeartbeatMath.PickerBoard {
        HeartbeatMath.PickerBoard(
            shopperCount: shopperCount,
            opportunityCount: opportunityCount,
            strongCount: strongCount,
            opportunity: opportunity,
            strong: strong
        )
    }

    static func from(board: HeartbeatMath.PickerBoard) -> PulseCards {
        PulseCards(
            generatedAt: Date(),
            shopperCount: board.shopperCount,
            opportunityCount: board.opportunityCount,
            strongCount: board.strongCount,
            opportunity: Array(board.opportunity.prefix(6)),
            strong: Array(board.strong.prefix(6))
        )
    }
}
