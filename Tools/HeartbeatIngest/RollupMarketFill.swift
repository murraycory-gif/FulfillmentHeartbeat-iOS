import Foundation

/// Ingest-only copy of the app helper so the kitchen does not compile SwiftUI.
enum RollupMarketFill {
    static func divisionKey(_ raw: String) -> String {
        let canonical = MarketRegion.canonicalName(raw)
        if !canonical.isEmpty { return canonical }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }

    static func districtKey(_ raw: String) -> String {
        let value = HeartbeatMath.canonicalDistrict(raw)
        if !value.isEmpty { return value }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }
}
