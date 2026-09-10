import Foundation

/// Store-keyed facts published after a workbook parse.
/// District lives on every row so filters do not guess across sheets.
struct PulseFactsFile: Codable {
    var generatedAt: String
    var stamp: String
    var roster: [PulseFactRow]
    var lostRevenue: [PulseFactRow]
    var sales: [PulseFactRow]
    var fiveStar: [PulseFactRow]
}

struct PulseFactRow: Codable {
    var store: String
    var division: String
    var district: String
    var om: String
    var name: String?
    var numbers: [String: Double]
    var text: [String: String]
}

enum PulseFacts {
    static let object = "facts.json"

    static func build(
        rows: [MetricRow],
        roster: [String: HeartbeatMath.StoreIdentity]
    ) -> PulseFactsFile {
        PulseFactsFile(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            stamp: BuildStamp.id,
            roster: pack(rows.filter { $0.section == .storeRoster || $0.textPayload["roster"] == "1" }, roster: roster, keepEmpty: true),
            lostRevenue: pack(rows.filter { $0.section == .lostRevenue }, roster: roster, keepEmpty: false),
            sales: pack(rows.filter { $0.section == .sales }, roster: roster, keepEmpty: false),
            fiveStar: pack(rows.filter { $0.section == .fiveStar }, roster: roster, keepEmpty: false)
        )
    }

    static func metricRows(from file: PulseFactsFile) -> [MetricRow] {
        var out: [MetricRow] = []
        out.reserveCapacity(file.roster.count + file.lostRevenue.count + file.sales.count + file.fiveStar.count)
        out.append(contentsOf: file.roster.map { metricRow($0, section: .storeRoster, extra: ["roster": "1"]) })
        out.append(contentsOf: file.lostRevenue.map { fact in
            let grain = fact.store.isEmpty || fact.text["lost_grain"] == "market" ? "market" : "store"
            return metricRow(fact, section: .lostRevenue, extra: ["lost_grain": grain])
        })
        out.append(contentsOf: file.sales.map { fact in
            let grain = fact.store.isEmpty || fact.text["sales_grain"] == "company" ? "company" : "store"
            return metricRow(fact, section: .sales, extra: ["sales_grain": grain])
        })
        out.append(contentsOf: file.fiveStar.map { metricRow($0, section: .fiveStar, extra: [:]) })
        return out
    }

    /// Roster only. Scorecard dollars always come from the live workbook.
    static func identityRows(from file: PulseFactsFile) -> [MetricRow] {
        file.roster.map { metricRow($0, section: .storeRoster, extra: ["roster": "1"]) }
    }

    static func isUsable(_ file: PulseFactsFile) -> Bool {
        file.roster.filter { !$0.store.isEmpty }.count >= 200
            || file.lostRevenue.filter { !$0.store.isEmpty }.count >= 200
    }

    static func lostStoreCount(_ file: PulseFactsFile?) -> Int {
        file?.lostRevenue.filter { !$0.store.isEmpty && (($0.numbers["lost_revenue"] ?? 0) != 0) }.count ?? 0
    }

    static func richer(_ a: PulseFactsFile?, _ b: PulseFactsFile?) -> PulseFactsFile? {
        if lostStoreCount(a) >= lostStoreCount(b), lostStoreCount(a) > 0 { return a }
        if lostStoreCount(b) > 0 { return b }
        return a ?? b
    }

    static func loadRows() async -> [MetricRow] {
        let bundledFile = decode(bundledData())
        let cloudFile = decode(try? await PulseCloud.downloadFacts())
        let file = richer(cloudFile, bundledFile)
        guard let file, isUsable(file) else { return [] }
        var rows = metricRows(from: file)
        if let bundledFile, lostStoreCount(bundledFile) > lostStoreCount(file) || file.stamp != bundledFile.stamp {
            rows = PulseDataPolicy.fillMissing(existing: rows, facts: metricRows(from: bundledFile))
        }
        return rows
    }

    static func bundledLostRevenue() -> [MetricRow] {
        guard let file = decode(bundledData()) else { return [] }
        return file.lostRevenue.map { fact in
            let grain = fact.store.isEmpty || fact.text["lost_grain"] == "market" ? "market" : "store"
            return metricRow(fact, section: .lostRevenue, extra: ["lost_grain": grain])
        }
    }

    private static func decode(_ data: Data?) -> PulseFactsFile? {
        guard let data, data.count > 1_000 else { return nil }
        return try? JSONDecoder().decode(PulseFactsFile.self, from: data)
    }

    static func bundledData() -> Data? {
        guard let url = Bundle.main.url(forResource: "facts", withExtension: "json") else { return nil }
        return try? Data(contentsOf: url)
    }

    private static var cachedBundledRows: [MetricRow]?

    static func bundledMetricRows() -> [MetricRow] {
        if let cachedBundledRows { return cachedBundledRows }
        guard let file = decode(bundledData()) else { return [] }
        let rows = metricRows(from: file)
        cachedBundledRows = rows
        return rows
    }

    private static func pack(
        _ rows: [MetricRow],
        roster: [String: HeartbeatMath.StoreIdentity],
        keepEmpty: Bool
    ) -> [PulseFactRow] {
        var seen: Set<String> = []
        var out: [PulseFactRow] = []
        out.reserveCapacity(rows.count)
        for row in rows {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if store.isEmpty { continue }
            if row.textPayload["lost_grain"] == "market" { continue }
            if row.textPayload["sales_grain"] == "company" || row.textPayload["sales_grain"] == "day" { continue }
            if !seen.insert(store).inserted { continue }
            let identity = roster[store]
            let division = {
                if let value = identity?.division, !value.isEmpty { return value }
                return row.division
            }()
            let district = {
                if let value = identity?.district, !value.isEmpty { return value }
                return row.district
            }()
            let om = {
                if let value = identity?.om, !value.isEmpty { return value }
                return row.operationsOM
            }()
            if !keepEmpty, row.payload.isEmpty { continue }
            out.append(
                PulseFactRow(
                    store: store,
                    division: division,
                    district: district,
                    om: om,
                    name: identity?.name ?? row.storeName,
                    numbers: row.payload,
                    text: row.textPayload
                )
            )
        }
        return out
    }

    private static func metricRow(_ fact: PulseFactRow, section: MetricSection, extra: [String: String]) -> MetricRow {
        var text = fact.text
        text["district"] = fact.district
        extra.forEach { text[$0.key] = $0.value }
        return MetricRow(
            section: section,
            division: fact.division,
            operationsOM: fact.om,
            storeNumber: fact.store,
            storeName: fact.name,
            payload: fact.numbers,
            textPayload: text
        )
    }
}

/// Pack dollars win. Facts.json fills stores the pack never wrote.
enum PulseDataPolicy {
    static func weekKey(from rows: [MetricRow]) -> String {
        for row in rows where row.section == .sales {
            if let week = row.textPayload["sales_week"], !week.isEmpty { return week }
            if let recorded = row.recordedOn, !recorded.isEmpty { return recorded }
        }
        return ""
    }

    static func identityOnly(_ rows: [MetricRow]) -> [MetricRow] {
        rows.filter { $0.section == .storeRoster || $0.textPayload["roster"] == "1" }
    }

    static func applyIdentity(existing: [MetricRow], identity: [MetricRow]) -> [MetricRow] {
        let roster = identityOnly(identity)
        guard !roster.isEmpty else { return existing }
        var next = existing.filter { $0.section != .storeRoster && $0.textPayload["roster"] != "1" }
        next.append(contentsOf: roster)
        return next
    }

    /// Add fact rows for stores the pack does not already score. Never overwrite pack dollars.
    static func fillMissing(existing: [MetricRow], facts: [MetricRow]) -> [MetricRow] {
        let sections: [MetricSection] = [.lostRevenue, .sales, .fiveStar]
        var extra: [MetricRow] = []
        extra.reserveCapacity(2_200)
        for section in sections {
            extra.append(contentsOf: fillMissingStores(existing: existing, facts: facts, section: section))
        }
        var next = extra.isEmpty ? existing : existing + extra
        for section in sections {
            next = PulseQuery.fillMissingRegions(existing: next, facts: facts, section: section)
        }
        return next
    }

    static func fillMissingStores(
        existing: [MetricRow],
        facts: [MetricRow],
        section: MetricSection
    ) -> [MetricRow] {
        var have: Set<String> = []
        have.reserveCapacity(2_200)
        for row in existing where row.section == section {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if store.isEmpty { continue }
            if section == .lostRevenue, row.number("lost_revenue") == nil, row.number("ecomm_sales") == nil {
                continue
            }
            have.formUnion(HeartbeatMath.storeAliases(store))
        }
        var out: [MetricRow] = []
        var seen: Set<String> = []
        for row in facts where row.section == section {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if store.isEmpty { continue }
            if have.contains(store) { continue }
            if !seen.insert(store).inserted { continue }
            if section == .lostRevenue, row.number("lost_revenue") == nil { continue }
            out.append(row)
            have.formUnion(HeartbeatMath.storeAliases(store))
        }
        return out
    }

    /// Incoming workbook sections replace the same sections. Never keep a larger stale total.
    static func replaceLiveSections(existing: [MetricRow], live: [MetricRow]) -> [MetricRow] {
        let liveSections = Set(live.map(\.section))
        let kept = existing.filter { !liveSections.contains($0.section) }
        return kept + live
    }
}
