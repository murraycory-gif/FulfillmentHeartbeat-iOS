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
            // District / region totals still have a rate. Keep them so California
            // Schedule Quality (and Dynacap) are not blank when Excel omits store numbers.
            if row.section == .dynacap, row.number("dynacap_rate", "pieces_per_hour") != nil {
                return !row.payload.isEmpty
            }
            if row.section == .scheduleQuality, row.number("schedule_efficiency_pct") != nil {
                return !row.payload.isEmpty
            }
            return false
        }
        return !row.payload.isEmpty
    }

    static func slice(
        _ rows: [MetricRow],
        allowed: Set<String>?,
        filters: DashboardFilters = DashboardFilters(),
        roster: [String: HeartbeatMath.StoreIdentity] = [:]
    ) -> [MetricRow] {
        let facts = rows.filter(isStoreFact)
        guard let allowed else { return facts }
        let matched = PulseCaches.rowsMatchingStores(facts, stores: allowed, skipMarket: true)
        return PulseCaches.unionRegionBook(matched, from: facts, filters: filters, roster: roster, allowed: allowed)
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
        return shoppers.filter { PulseLaunch.storeInScope($0.storeNumber, allowed: allowed) }
    }

    static func sliceSection(
        _ section: MetricSection,
        rows: [MetricRow],
        allowed: Set<String>?,
        filters: DashboardFilters = DashboardFilters(),
        roster: [String: HeartbeatMath.StoreIdentity] = [:]
    ) -> [MetricRow] {
        if section == .pickerScorecard || section == .pickPathPicker {
            return sliceShoppers(rows, allowed: allowed)
        }
        return slice(rows, allowed: allowed, filters: filters, roster: roster)
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
            if !store.isEmpty { seen.insert(store) }
        }
        var extra: [MetricRow] = []
        extra.reserveCapacity(1_200)
        for row in facts where row.section == section {
            guard isStoreFact(row) else { continue }
            guard let region = region(of: row), missing.contains(region) else { continue }
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if store.isEmpty {
                if section == .scheduleQuality {
                    extra.append(row)
                }
                continue
            }
            if seen.contains(store) { continue }
            extra.append(row)
            seen.insert(store)
            if let value = Int(store) {
                seen.insert(String(format: "%04d", value))
                seen.insert(String(format: "%05d", value))
            }
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
        includePageOnly: Bool = false,
        includeFlags: Bool = false
    ) -> View {
        let allowed = PulseCaches.allowedStores(roster: roster, filters: filters)
        var filtered: [MetricSection: [MetricRow]] = [:]
        filtered.reserveCapacity(warehouse.count)
        for (section, rows) in warehouse {
            if skipOnLight.contains(section), !includePageOnly { continue }
            filtered[section] = sliceSection(section, rows: rows, allowed: allowed, filters: filters, roster: roster)
        }
        if !filters.isActive {
            restoreCompanyTotals(filtered: &filtered, warehouse: warehouse)
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
                flags: includeFlags ? PulseCaches.cardFlags(latest: filtered) : [:],
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
        let goalFallback = HeartbeatMath.lostRevenueGoalFallback(
            (warehouse[.lostRevenue] ?? []) + (filtered[.lostRevenue] ?? [])
        )
        return View(
            filtered: filtered,
            summaries: summaries,
            flags: flags,
            grains: grains,
            tables: PulseCaches.grainTables(
                latest: filtered,
                grain: grain,
                roster: roster,
                packs: grains,
                goalFallback: goalFallback
            ),
            pickers: hidePicker ? [] : (filtered[.pickerScorecard] ?? [])
        )
    }

    /// Materialize / overlay / region-fill off the main thread. Callers pass CoW snapshots.
    static func prepareWarehouse(
        warehouse: [MetricSection: [MetricRow]],
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters,
        rawRows: [MetricRow],
        pickers: [MetricRow],
        bundledFacts: [MetricRow],
        scopedLost: [MetricRow]?
    ) -> [MetricSection: [MetricRow]] {
        var next = warehouse
        if scoredStoreFacts(next[.lostRevenue] ?? []).count < 8 {
            let filled = snapshotOrRaw(section: .lostRevenue, snapshot: next[.lostRevenue] ?? [], rawRows: rawRows, roster: roster)
            if scoredStoreFacts(filled).count > scoredStoreFacts(next[.lostRevenue] ?? []).count {
                next[.lostRevenue] = filled
            }
        }
        if (next[.dynacap] ?? []).filter({ $0.number("dynacap_rate", "pieces_per_hour") != nil }).isEmpty {
            let raw = (next[.dynacap] ?? []) + rawRows.filter { $0.section == .dynacap }
            let expanded = HeartbeatMath.materializeDynacap(raw, roster: roster)
            if !expanded.isEmpty { next[.dynacap] = expanded }
        }
        if (next[.pph] ?? []).filter({ HeartbeatMath.pphNumber($0) != nil }).isEmpty {
            let raw = (next[.pph] ?? []) + rawRows.filter { $0.section == .pph }
            let filled = HeartbeatMath.materializePPH(raw, roster: roster, pickers: pickers)
            if !filled.isEmpty { next[.pph] = filled }
        }
        if (next[.scheduleQuality] ?? []).filter({ $0.number("schedule_efficiency_pct") != nil }).count < 8 {
            let filled = snapshotOrRaw(section: .scheduleQuality, snapshot: next[.scheduleQuality] ?? [], rawRows: rawRows, roster: roster)
            if filled.filter({ $0.number("schedule_efficiency_pct") != nil }).count
                > (next[.scheduleQuality] ?? []).filter({ $0.number("schedule_efficiency_pct") != nil }).count {
                next[.scheduleQuality] = filled
            }
        }
        next = HeartbeatMath.overlayDynacapPPH(next)
        if filters.isActive, let scopedLost, !scopedLost.isEmpty {
            next[.lostRevenue] = scopedLost
        } else if !filters.isActive, !bundledFacts.isEmpty {
            for section in [MetricSection.lostRevenue, .sales, .fiveStar, .scheduleQuality] {
                let existing = next[section] ?? []
                let merged = fillMissingRegions(
                    existing: existing,
                    facts: bundledFacts,
                    section: section
                )
                if merged.count > existing.count {
                    next[section] = HeartbeatMath.applyRoster(merged, roster: roster)
                }
            }
        }
        return next
    }

    static func snapshotOrRaw(
        section: MetricSection,
        snapshot: [MetricRow],
        rawRows: [MetricRow],
        roster: [String: HeartbeatMath.StoreIdentity]
    ) -> [MetricRow] {
        let snapshotStores = snapshot.filter {
            !HeartbeatMath.canonicalStore($0.storeNumber).isEmpty
                && $0.textPayload["lost_grain"] != "market"
                && $0.textPayload["sales_grain"] != "company"
        }
        if snapshotStores.count >= 8 { return snapshot }
        let raw = rawRows.filter { $0.section == section }
        if raw.isEmpty { return snapshot }
        if section == .lostRevenue {
            let stores = raw.filter { $0.textPayload["lost_grain"] != "market" }
            return HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(stores), roster: roster)
        }
        return HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(raw), roster: roster)
    }

    /// Light / grain paints skip shopper tables. Keep the live slice so the dashboard card and PPH counts stay filled.
    /// Under a seat filter the painted slice wins — never restore the company shopper book.
    static func keepPageOnlyRows(
        painted: [MetricSection: [MetricRow]],
        live: [MetricSection: [MetricRow]],
        filtersActive: Bool = false
    ) -> [MetricSection: [MetricRow]] {
        if filtersActive { return painted }
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
        live: [SectionSummary],
        filtersActive: Bool = false
    ) -> [SectionSummary] {
        if filtersActive { return painted }
        return painted.map { card in
            guard pageOnlySections.contains(card.section) else { return card }
            guard let kept = live.first(where: { $0.section == card.section }) else { return card }
            if kept.storeCount > card.storeCount { return kept }
            if card.storeCount == 0, kept.storeCount > 0 { return kept }
            return card
        }
    }

    /// `slice` keeps store facts only. Unfiltered company tiles need the Power BI
    /// Total Opportunity row so Loss Revenue does not fall through to SUM(stores).
    /// Filtered seats must not get this row.
    static func restoreCompanyTotals(
        filtered: inout [MetricSection: [MetricRow]],
        warehouse: [MetricSection: [MetricRow]]
    ) {
        guard let market = warehouse[.lostRevenue]?.first(where: {
            $0.textPayload["lost_grain"] == "market"
                && HeartbeatMath.canonicalStore($0.storeNumber).isEmpty
        }) else { return }
        var rows = filtered[.lostRevenue] ?? []
        if rows.contains(where: { $0.textPayload["lost_grain"] == "market" }) { return }
        rows.append(market)
        filtered[.lostRevenue] = rows
    }

    /// Progressive section fill: keep live rows when this paint has not loaded that section.
    static func mergeFilteredRows(
        painted: [MetricSection: [MetricRow]],
        live: [MetricSection: [MetricRow]]
    ) -> [MetricSection: [MetricRow]] {
        var next = live
        for (section, rows) in painted where !rows.isEmpty {
            next[section] = rows
        }
        return next
    }
}
