import Foundation

/// Power BI model: one warehouse of store rows, one filter, one paint.
/// Dashboard cards, expand rows, and scorecard pages all read the same slice.
enum PulseQuery {
    struct View {
        var filtered: [MetricSection: [MetricRow]]
        var summaries: [SectionSummary]
        var flags: [MetricSection: [HeartbeatMath.FiveStarFlag]]
        var grains: [MetricSection: [DashScopePack]]
        var tables: [MetricSection: [HeartbeatMath.DashboardGrainTableRow]]
        var pickers: [MetricRow]
    }

    static let skipOnLight: Set<MetricSection> = [
        .pickerScorecard, .pickPathPicker, .preSubOOSItem
    ]

    /// Shopper / item grains stay out of filter and grain paints until that page opens.
    static var pageOnlySections: Set<MetricSection> { skipOnLight }

    static func isStoreFact(_ row: MetricRow) -> Bool {
        if row.textPayload["lost_grain"] == "market" { return false }
        if row.textPayload["sales_grain"] == "company" { return false }
        if row.textPayload["sales_grain"] == "day" { return false }
        if row.textPayload["labor_grain"] == "market" { return false }
        if HeartbeatMath.canonicalStore(row.storeNumber).isEmpty {
            // District-level Dynacap still has a rate. Keep it so the section is not blank.
            if row.section == .dynacap, row.number("dynacap_rate", "pieces_per_hour") != nil {
                return !row.payload.isEmpty
            }
            return false
        }
        return !row.payload.isEmpty
    }

    static func slice(_ rows: [MetricRow], allowed: Set<String>?) -> [MetricRow] {
        let facts = rows.filter(isStoreFact)
        guard let allowed else { return facts }
        return PulseCaches.rowsMatchingStores(facts, stores: allowed, skipMarket: true)
    }

    static func isShopperRow(_ row: MetricRow) -> Bool {
        HeartbeatMath.isRealPicker(row) || !(row.textPayload["shopper_id"] ?? "").isEmpty
    }

    /// Keep every shopper in the filter. Store-fact slice keeps one row per store.
    static func sliceShoppers(_ rows: [MetricRow], allowed: Set<String>?) -> [MetricRow] {
        var shoppers = rows.filter(isShopperRow)
        if shoppers.isEmpty {
            shoppers = rows.filter {
                $0.section == .pickerScorecard || $0.section == .pickPathPicker
            }
        }
        guard let allowed else { return shoppers }
        return shoppers.filter { row in
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if store.isEmpty { return false }
            if allowed.contains(store) { return true }
            return HeartbeatMath.storeAliases(store).contains(where: { allowed.contains($0) })
        }
    }

    static func sliceSection(_ section: MetricSection, rows: [MetricRow], allowed: Set<String>?) -> [MetricRow] {
        if section == .pickerScorecard || section == .pickPathPicker {
            return sliceShoppers(rows, allowed: allowed)
        }
        return slice(rows, allowed: allowed)
    }

    static func scoredStoreFacts(_ rows: [MetricRow]) -> [MetricRow] {
        rows.filter(isStoreFact)
    }

    static func storeFactDollars(_ rows: [MetricRow]) -> Double {
        rows.reduce(0) { sum, row in
            sum
                + (row.number("lost_revenue") ?? 0)
                + HeartbeatMath.salesHeadlineDollars(row)
        }
    }

    /// Company-wide East-only packs can already pass `fillIfThin`'s store-count gate.
    /// Append fact stores for official regions the pack never scored.
    static func fillMissingRegions(
        existing: [MetricRow],
        facts: [MetricRow],
        section: MetricSection
    ) -> [MetricRow] {
        func region(of row: MetricRow) -> String? {
            HeartbeatMath.dashboardScopeKey(row, grain: .region)
        }
        let have = Set(existing.compactMap(region))
        let missing = Set(MarketRegion.allCases.map(\.rawValue).filter { !have.contains($0) })
        guard !missing.isEmpty else { return existing }
        var seen: Set<String> = []
        seen.reserveCapacity(existing.count + 2_200)
        for row in existing {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if !store.isEmpty { seen.formUnion(HeartbeatMath.storeAliases(store)) }
        }
        var extra: [MetricRow] = []
        extra.reserveCapacity(1_200)
        for row in facts where row.section == section {
            guard isStoreFact(row) else { continue }
            guard let region = region(of: row), missing.contains(region) else { continue }
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if store.isEmpty { continue }
            if seen.contains(store) { continue }
            extra.append(row)
            seen.formUnion(HeartbeatMath.storeAliases(store))
        }
        guard !extra.isEmpty else { return existing }
        return existing + extra
    }

    /// Fill a thin warehouse from Excel store facts. Never replace a full table.
    static func fillIfThin(existing: [MetricRow], incoming: [MetricRow], minimum: Int = 200) -> [MetricRow]? {
        let have = scoredStoreFacts(existing)
        if have.count >= minimum { return nil }
        let next = scoredStoreFacts(incoming)
        guard next.count >= minimum else { return nil }
        return next
    }

    /// Live Excel / cloud facts replace a thin pack, or the same stores when dollars moved.
    static func takeIfRicher(existing: [MetricRow], incoming: [MetricRow], minimum: Int = 200) -> [MetricRow]? {
        let next = scoredStoreFacts(incoming)
        guard next.count >= minimum else { return nil }
        let have = scoredStoreFacts(existing)
        if have.count < minimum { return next }
        if next.count > have.count { return next }
        if abs(storeFactDollars(next) - storeFactDollars(have)) > 1 { return next }
        return nil
    }

    static func paint(
        warehouse: [MetricSection: [MetricRow]],
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters,
        grain: DashScopeGrain,
        uploads: [UploadRecord],
        hidePicker: Bool,
        light: Bool,
        includePageOnly: Bool = false
    ) -> View {
        let allowed = PulseCaches.allowedStores(roster: roster, filters: filters)
        var filtered: [MetricSection: [MetricRow]] = [:]
        filtered.reserveCapacity(warehouse.count)
        for (section, rows) in warehouse {
            if skipOnLight.contains(section), !includePageOnly { continue }
            filtered[section] = sliceSection(section, rows: rows, allowed: allowed)
        }
        let summaries = MetricSection.dashboardCards.map { section in
            HeartbeatMath.summarize(
                section,
                rows: filtered[section] ?? [],
                upload: uploads.first { $0.section == section }
            )
        }
        if light {
            return View(
                filtered: filtered,
                summaries: summaries,
                flags: [:],
                grains: PulseCaches.placeholderGrainPacks(grain: grain),
                tables: [:],
                pickers: []
            )
        }
        let flags = PulseCaches.cardFlags(latest: filtered)
        let storeNumbers = (allowed ?? Set(roster.keys)).sorted(by: HeartbeatFormat.storeOrder)
        let stores = storeNumbers.map { number -> (number: String, name: String?) in
            (number, roster[HeartbeatMath.canonicalStore(number)]?.name)
        }
        let grains = PulseCaches.grainPacks(
            latest: filtered,
            grain: grain,
            hidePicker: true,
            stores: stores,
            roster: roster
        )
        return View(
            filtered: filtered,
            summaries: summaries,
            flags: flags,
            grains: grains,
            tables: PulseCaches.grainTables(latest: filtered, grain: grain, roster: roster, packs: grains),
            pickers: hidePicker ? [] : (filtered[.pickerScorecard] ?? [])
        )
    }

    /// Light / grain paints skip shopper tables. Keep the live slice so the dashboard card and PPH counts stay filled.
    static func keepPageOnlyRows(
        painted: [MetricSection: [MetricRow]],
        live: [MetricSection: [MetricRow]]
    ) -> [MetricSection: [MetricRow]] {
        var next = painted
        for section in pageOnlySections {
            if let keep = live[section], !keep.isEmpty {
                next[section] = keep
            }
        }
        return next
    }

    static func overlayPageOnlySummaries(
        painted: [SectionSummary],
        live: [SectionSummary]
    ) -> [SectionSummary] {
        painted.map { card in
            guard pageOnlySections.contains(card.section) else { return card }
            guard let kept = live.first(where: { $0.section == card.section }) else { return card }
            if kept.storeCount > card.storeCount { return kept }
            if card.storeCount == 0, kept.storeCount > 0 { return kept }
            return card
        }
    }
}
