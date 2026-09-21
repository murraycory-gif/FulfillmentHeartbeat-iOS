import Foundation

/// Ingest-only copy of the app helper so the kitchen does not compile SwiftUI.
enum RollupMarketFill {
    static func divisionKey(_ raw: String) -> String {
        let canonical = MarketRegion.canonicalName(raw)
        if !canonical.isEmpty { return canonical }
        if MarketRegion.isIgnoredDivisionToken(raw) { return "" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }

    static func districtKey(_ raw: String) -> String {
        let value = HeartbeatMath.canonicalDistrict(raw)
        if !value.isEmpty { return value }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }

    /// Same rule as the app helper. Domain.swift hides ignored / Unassigned at cook.
    static func hidesUnassignedMarket(_ key: String) -> Bool {
        MarketRegion.isIgnoredDivisionToken(key)
    }
}
