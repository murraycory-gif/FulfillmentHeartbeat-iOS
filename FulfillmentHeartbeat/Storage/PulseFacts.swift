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
        out.append(contentsOf: file.lostRevenue.map { metricRow($0, section: .lostRevenue, extra: ["lost_grain": "store"]) })
        out.append(contentsOf: file.sales.map { metricRow($0, section: .sales, extra: [:]) })
        out.append(contentsOf: file.fiveStar.map { metricRow($0, section: .fiveStar, extra: [:]) })
        return out
    }

    static func isUsable(_ file: PulseFactsFile) -> Bool {
        file.lostRevenue.filter { !$0.store.isEmpty }.count >= 200
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
