import Foundation

/// Power BI model: one warehouse of store rows, one filter, one paint.
/// Dashboard cards, expand rows, and scorecard pages all read the same slice.
enum PulseQuery {
    struct View {
        var filtered: [MetricSection: [MetricRow]]
        var summaries: [SectionSummary]
        var flags: [MetricSection: [HeartbeatMath.FiveStarFlag]]
        var grains: [MetricSection: [DashScopePack]]
        var pickers: [MetricRow]
        var stores: [(number: String, name: String?)]
        var districts: [String]
        var oms: [String]
    }

    static func isStoreFact(_ row: MetricRow) -> Bool {
        if HeartbeatMath.canonicalStore(row.storeNumber).isEmpty { return false }
        if row.textPayload["lost_grain"] == "market" { return false }
        if row.textPayload["sales_grain"] == "company" { return false }
        if row.textPayload["sales_grain"] == "day" { return false }
        if row.textPayload["labor_grain"] == "market" { return false }
        return !row.payload.isEmpty
    }

    static func slice(_ rows: [MetricRow], allowed: Set<String>?) -> [MetricRow] {
        let facts = rows.filter(isStoreFact)
        guard let allowed else { return facts }
        return PulseCaches.rowsMatchingStores(facts, stores: allowed, skipMarket: true)
    }

    static func paint(
        warehouse: [MetricSection: [MetricRow]],
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters,
        grain: DashScopeGrain,
        uploads: [UploadRecord],
        hidePicker: Bool
    ) -> View {
        let allowed = PulseCaches.allowedStores(roster: roster, filters: filters)
        var filtered: [MetricSection: [MetricRow]] = [:]
        filtered.reserveCapacity(warehouse.count)
        for (section, rows) in warehouse {
            filtered[section] = slice(rows, allowed: allowed)
        }
        let summaries = MetricSection.dashboardCards.map { section in
            HeartbeatMath.summarize(
                section,
                rows: filtered[section] ?? [],
                upload: uploads.first { $0.section == section }
            )
        }
        let flags = PulseCaches.cardFlags(latest: filtered)
        let grains = PulseCaches.grainPacks(
            latest: filtered,
            grain: grain,
            hidePicker: hidePicker,
            stores: [],
            roster: [:]
        )
        let pickers = filtered[.pickerScorecard] ?? []
        let storeNumbers = (allowed ?? Set(roster.keys)).sorted(by: HeartbeatFormat.storeOrder)
        let stores = storeNumbers.map { number -> (number: String, name: String?) in
            (number, roster[HeartbeatMath.canonicalStore(number)]?.name)
        }
        let districts = Set(roster.values.map(\.district).filter { !$0.isEmpty }).sorted()
        let oms = Set(roster.values.map(\.om).filter { !$0.isEmpty }).sorted()
        return View(
            filtered: filtered,
            summaries: summaries,
            flags: flags,
            grains: grains,
            pickers: pickers,
            stores: stores,
            districts: Array(districts),
            oms: Array(oms)
        )
    }
}
