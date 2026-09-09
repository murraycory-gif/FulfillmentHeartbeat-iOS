import Foundation

struct PulseDashChrome: Codable {
    var summaries: [SectionSummary]
    var flags: [String: [HeartbeatMath.FiveStarFlag]]
    var packs: [String: [DashScopePack]]
    var pickerShoppers: Int

    static func from(_ caches: PulseCaches) -> PulseDashChrome {
        PulseDashChrome(
            summaries: caches.cachedSummaries,
            flags: Dictionary(uniqueKeysWithValues: caches.cachedCardFlags.map { ($0.key.rawValue, $0.value) }),
            packs: Dictionary(uniqueKeysWithValues: caches.cachedGrainPacks.map { ($0.key.rawValue, $0.value) }),
            pickerShoppers: caches.cachedPickerBoard.shopperCount
        )
    }
}

enum PulseLayoutCap {
    static var grainCap: Int {
        #if canImport(UIKit)
        return HubLayout.grainCap
        #else
        return 24
        #endif
    }
    static var storeGrainCap: Int {
        #if canImport(UIKit)
        return HubLayout.storeGrainCap
        #else
        return 50
        #endif
    }
}

struct PulseCaches {
    var latestBySection: [MetricSection: [MetricRow]]
    var roster: [String: HeartbeatMath.StoreIdentity]
    var filteredLatest: [MetricSection: [MetricRow]]
    var filteredMarket: [HeartbeatMath.MarketStore]
    var cachedDivisions: [String]
    var cachedDistricts: [String]
    var cachedOMs: [String]
    var cachedStores: [(number: String, name: String?)]
    var cachedSummaries: [SectionSummary]
    var cachedPickerBoard: HeartbeatMath.PickerBoard
    var cachedChecklistGroups: [MetricSection: [ChecklistDriverGroup]]
    var pickerIndex: [PickerFocus: [Int]]
    var pickerFocusHealth: [PickerFocus: Health]
    var pickPathPickersByStore: [String: [MetricRow]]
    var pickPathByShopper: [String: MetricRow]
    var pphPickersByStore: [String: [MetricRow]]
    var cachedCardFlags: [MetricSection: [HeartbeatMath.FiveStarFlag]]
    var cachedGrainPacks: [MetricSection: [DashScopePack]]

    struct HeavyBits {
        var pickerBoard: HeartbeatMath.PickerBoard
        var pickerIndex: [PickerFocus: [Int]]
        var pickerFocusHealth: [PickerFocus: Health]
        var pickPathPickersByStore: [String: [MetricRow]]
        var pickPathByShopper: [String: MetricRow]
        var pphPickersByStore: [String: [MetricRow]]
        var checklistGroups: [MetricSection: [ChecklistDriverGroup]]
    }

    static func build(rows: [MetricRow], filters: DashboardFilters, uploads: [UploadRecord], heavy: Bool = true, grain: DashScopeGrain? = .region) -> PulseCaches {
        var bySection: [MetricSection: [MetricRow]] = [:]
        bySection.reserveCapacity(16)
        for row in rows {
            bySection[row.section, default: []].append(row)
        }
        var roster = storeRoster(from: rows)
        var latest: [MetricSection: [MetricRow]] = [:]
        latest.reserveCapacity(MetricSection.allCases.count)
        for section in MetricSection.allCases {
            let sectionRows = bySection[section] ?? []
            if section == .dynacap {
                latest[section] = HeartbeatMath.materializeDynacap(sectionRows, roster: roster)
            } else if section == .pickPath {
                latest[section] = HeartbeatMath.materializePickPath(sectionRows, roster: roster)
            } else if section == .preSubOOSItem {
                latest[section] = HeartbeatMath.applyRoster(sectionRows, roster: roster)
            } else if section == .storeRoster {
                latest[section] = HeartbeatMath.latestPerStore(sectionRows)
            } else if section == .scheduleQuality || section == .fiveStar || section == .prepNotReady || section == .pph || section == .lostRevenue || section == .missingItems || section == .preSubOOS || section == .sales {
                let source = section == .lostRevenue
                    ? sectionRows.filter { $0.textPayload["lost_grain"] != "market" }
                    : sectionRows
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(source), roster: roster)
            } else if section == .labor {
                let stores = sectionRows.filter {
                    $0.textPayload["labor_grain"] == "store" && !$0.storeNumber.isEmpty
                }
                let fallback = sectionRows.filter {
                    $0.textPayload["labor_grain"] != "market" && !$0.storeNumber.isEmpty
                }
                latest[section] = HeartbeatMath.applyRoster(
                    HeartbeatMath.latestPerStore(stores.isEmpty ? fallback : stores),
                    roster: roster
                )
            } else if section == .pickerScorecard || section == .pickPathPicker {
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerShopper(sectionRows), roster: roster)
            } else {
                latest[section] = HeartbeatMath.latestPerStore(sectionRows)
            }
        }
        if let path = latest[.pickPath] {
            latest[.pickPath] = HeartbeatMath.applyAisleMapper(path, from: latest[.aisleMapper] ?? [])
        }
        return refilter(
            latest: latest,
            roster: roster,
            filters: filters,
            uploads: uploads,
            laborMarket: (bySection[.labor] ?? []).first { $0.textPayload["labor_grain"] == "market" },
            lostRevenueMarket: (bySection[.lostRevenue] ?? []).first { $0.textPayload["lost_grain"] == "market" },
            heavy: heavy,
            grain: grain
        )
    }

    static func refilter(
        latest: [MetricSection: [MetricRow]],
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters,
        uploads: [UploadRecord],
        laborMarket: MetricRow? = nil,
        lostRevenueMarket: MetricRow? = nil,
        heavy: Bool = true,
        grain: DashScopeGrain? = nil,
        hidePicker: Bool = false
    ) -> PulseCaches {
        let allowed = pickerStoreSet(roster: roster, filters: filters)
        var nextLatest: [MetricSection: [MetricRow]] = [:]
        nextLatest.reserveCapacity(latest.count)
        if let allowed {
            for (section, rows) in latest {
                nextLatest[section] = rowsMatchingStores(
                    rows,
                    stores: allowed,
                    skipMarket: section == .lostRevenue || section == .labor
                )
            }
        } else {
            nextLatest = latest
        }
        let pickers = nextLatest[.pickerScorecard] ?? []
        let pickerBoard = HeartbeatMath.pickerBoard(pickers)
        let picker = pickerIndexValues(pickers)
        let path = pickPathIndexValues(scorecard: pickers, pathRows: latest[.pickPathPicker] ?? nextLatest[.pickPathPicker] ?? [])
        let pph = heavy ? pphIndexValues(pickers) : [:]
        let districts = roster.values
            .filter { filters.includesDivision($0.division) }
            .map { HeartbeatMath.canonicalDistrict($0.district) }
            .filter { !$0.isEmpty }
            .uniquedIgnoringCase()
            .sorted()
        let oms = roster.values
            .filter { filters.includesDivision($0.division) }
            .filter { filters.includesDistrict($0.district) }
            .map { HeartbeatMath.canonicalOM($0.om) }
            .filter { value in !value.isEmpty && value.rangeOfCharacter(from: .letters) != nil }
            .uniquedIgnoringCase()
            .sorted()
        var seen: [String: String?] = [:]
        for (number, identity) in roster {
            if let allowed, !allowed.contains(number) { continue }
            if !filters.includesDivision(identity.division) { continue }
            if !filters.includesDistrict(identity.district) { continue }
            if !filters.includesOM(identity.om) { continue }
            if seen[number] == nil { seen[number] = identity.name }
        }
        let stores = seen.keys.sorted().map { ($0, seen[$0] ?? nil) }
        var pphByStore: [String: Double] = [:]
        for row in nextLatest[.pph] ?? [] {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if let value = row.number("pph") { pphByStore[store] = value }
        }
        var pathByStore: [String: Double] = [:]
        for row in nextLatest[.pickPath] ?? [] {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if let value = row.number("compliance_pct") { pathByStore[store] = value }
        }
        let market = stores.map { item in
            let identity = roster[item.0] ?? HeartbeatMath.StoreIdentity(division: "", district: "", om: "", name: nil)
            return HeartbeatMath.MarketStore(
                storeNumber: item.0,
                division: identity.division,
                district: identity.district,
                om: identity.om,
                pph: pphByStore[item.0],
                compliance: pathByStore[item.0]
            )
        }
        let summaries = MetricSection.dashboardCards.map { section -> SectionSummary in
            var input = nextLatest[section] ?? []
            if section == .labor, !filters.isActive, let laborMarket {
                input.append(laborMarket)
            }
            if section == .lostRevenue, !filters.isActive, let lostRevenueMarket {
                input.append(lostRevenueMarket)
            }
            var summary = HeartbeatMath.summarize(
                section,
                rows: input,
                upload: uploads.first { $0.section == section }
            )
            if summary.storeCount == 0, !market.isEmpty, summary.headline == nil {
                summary.secondary = "No \(section.short) data for \(market.count) stores in this filter"
                summary.health = .none
            }
            return summary
        }
        return PulseCaches(
            latestBySection: latest,
            roster: roster,
            filteredLatest: nextLatest,
            filteredMarket: market,
            cachedDivisions: MarketRegion.uniqueNames(roster.values.map(\.division)).sorted(),
            cachedDistricts: districts,
            cachedOMs: oms,
            cachedStores: stores,
            cachedSummaries: summaries,
            cachedPickerBoard: pickerBoard,
            cachedChecklistGroups: heavy ? checklistGroups(from: nextLatest, roster: roster) : [:],
            pickerIndex: picker.index,
            pickerFocusHealth: picker.health,
            pickPathPickersByStore: path.buckets,
            pickPathByShopper: path.byShopper,
            pphPickersByStore: pph,
            cachedCardFlags: cardFlags(latest: nextLatest, laborMarket: laborMarket),
            cachedGrainPacks: grainPacks(
                    latest: nextLatest,
                    grain: grain,
                    hidePicker: hidePicker,
                    stores: stores,
                    roster: roster
                )
        )
    }

    static func heavyExtras(
        latest: [MetricSection: [MetricRow]],
        roster: [String: HeartbeatMath.StoreIdentity]
    ) -> HeavyBits {
        let pickers = latest[.pickerScorecard] ?? []
        let picker = pickerIndexValues(pickers)
        let path = pickPathIndexValues(scorecard: pickers, pathRows: latest[.pickPathPicker] ?? [])
        return HeavyBits(
            pickerBoard: HeartbeatMath.pickerBoard(pickers),
            pickerIndex: picker.index,
            pickerFocusHealth: picker.health,
            pickPathPickersByStore: path.buckets,
            pickPathByShopper: path.byShopper,
            pphPickersByStore: pphIndexValues(pickers),
            checklistGroups: checklistGroups(from: latest, roster: roster)
        )
    }

    static func cardFlags(
        latest: [MetricSection: [MetricRow]],
        laborMarket: MetricRow? = nil
    ) -> [MetricSection: [HeartbeatMath.FiveStarFlag]] {
        let pickers = latest[.pickerScorecard] ?? []
        let pathPickers = latest[.pickPathPicker] ?? []
        let items = latest[.preSubOOSItem] ?? []
        var out: [MetricSection: [HeartbeatMath.FiveStarFlag]] = [:]
        out.reserveCapacity(MetricSection.dashboardCards.count)
        for section in MetricSection.dashboardCards {
            var rows = latest[section] ?? []
            if section == .labor, let laborMarket {
                rows.append(laborMarket)
            }
            out[section] = HeartbeatMath.dashboardActionFlags(
                section: section,
                rows: rows,
                pickers: pickers,
                pathPickers: pathPickers,
                items: items,
                includeAll: false
            )
        }
        return out
    }

    static func grainPacks(
        latest: [MetricSection: [MetricRow]],
        grain: DashScopeGrain?,
        hidePicker: Bool,
        stores: [(number: String, name: String?)] = [],
        roster: [String: HeartbeatMath.StoreIdentity] = [:]
    ) -> [MetricSection: [DashScopePack]] {
        guard let grain else { return [:] }
        let cap: Int
        switch grain {
        case .region: cap = 8
        case .store: cap = max(min(stores.count, PulseLayoutCap.storeGrainCap), 12)
        default: cap = PulseLayoutCap.grainCap
        }
        var out: [MetricSection: [DashScopePack]] = [:]
        for section in MetricSection.dashboardCards {
            if hidePicker, section == .pickerScorecard { continue }
            let rows = HeartbeatMath.rowsFillingRoster(latest[section] ?? [], roster: roster)
            let lines: [DashScopeLine]
            if grain == .store, !stores.isEmpty {
                lines = Array(HeartbeatMath.dashboardStoreLines(
                    section: section,
                    rows: rows,
                    stores: stores,
                    roster: roster
                ).prefix(cap))
            } else {
                lines = Array(HeartbeatMath.dashboardScopeLines(section: section, rows: rows, grain: grain).prefix(cap))
            }
            let shown: [DashScopeLine]
            if grain == .region {
                var byLabel: [String: DashScopeLine] = [:]
                byLabel.reserveCapacity(lines.count)
                for line in lines { byLabel[line.label] = line }
                shown = MarketRegion.allCases.map { region in
                    byLabel[region.rawValue] ?? DashScopeLine(
                        label: region.rawValue,
                        value: "—",
                        health: .none,
                        count: 0
                    )
                }
            } else {
                shown = lines.isEmpty ? placeholderLines(grain) : lines
            }
            var packs: [DashScopePack]
            if grain == .region {
                let markets = HeartbeatMath.dashboardScopeLines(section: section, rows: rows, grain: .division)
                packs = shown.map { line in
                    let kids = markets.filter { MarketRegion.containing($0.label)?.rawValue == line.label }
                    return DashScopePack(line: line, flags: [], children: kids)
                }
            } else {
                packs = shown.map { DashScopePack(line: $0, flags: [], children: []) }
            }
            if section != .sales, section != .pickerScorecard {
                let map = grainFlags(section: section, grain: grain, packs: packs, latest: latest, roster: roster)
                packs = packs.map { pack in
                    var next = pack
                    next.flags = map[pack.id] ?? map[pack.line.label] ?? []
                    return next
                }
            }
            out[section] = packs
        }
        return out
    }

    static func placeholderGrainPacks(grain: DashScopeGrain) -> [MetricSection: [DashScopePack]] {
        let lines = placeholderLines(grain)
        let packs = lines.map { DashScopePack(line: $0, flags: [], children: []) }
        var out: [MetricSection: [DashScopePack]] = [:]
        for section in MetricSection.dashboardCards {
            out[section] = packs
        }
        return out
    }

    private static func placeholderLines(_ grain: DashScopeGrain) -> [DashScopeLine] {
        switch grain {
        case .region:
            return MarketRegion.allCases.map { DashScopeLine(label: $0.rawValue, value: "—", health: .none, count: 0) }
        case .division:
            return MarketRegion.officialDivisions.map { DashScopeLine(label: $0, value: "—", health: .none, count: 0) }
        default:
            return []
        }
    }

    static func grainFlags(
        section: MetricSection,
        grain: DashScopeGrain,
        packs: [DashScopePack],
        latest: [MetricSection: [MetricRow]],
        roster: [String: HeartbeatMath.StoreIdentity] = [:]
    ) -> [String: [HeartbeatMath.FiveStarFlag]] {
        let rows = HeartbeatMath.rowsFillingRoster(latest[section] ?? [], roster: roster)
        var buckets: [String: [MetricRow]] = [:]
        func key(for row: MetricRow) -> String? {
            if grain == .store {
                let number = HeartbeatMath.canonicalStore(row.storeNumber)
                return number.isEmpty ? nil : number
            }
            return HeartbeatMath.dashboardScopeKey(row, grain: grain)
        }
        func packKey(_ pack: DashScopePack) -> String {
            if grain == .store {
                let raw = pack.line.label.split(separator: "|").first.map(String.init) ?? pack.line.label
                return HeartbeatMath.canonicalStore(raw.trimmingCharacters(in: .whitespaces))
            }
            return pack.line.label
        }
        for row in rows {
            if let key = key(for: row) { buckets[key, default: []].append(row) }
        }
        var out: [String: [HeartbeatMath.FiveStarFlag]] = [:]
        out.reserveCapacity(packs.count)
        for pack in packs {
            let match = packKey(pack)
            out[pack.id] = HeartbeatMath.dashboardActionFlags(
                section: section,
                rows: buckets[match] ?? [],
                includeAll: true
            )
        }
        return out
    }

    static func storeRoster(from rows: [MetricRow]) -> [String: HeartbeatMath.StoreIdentity] {
        let official = rows.filter { $0.section == .storeRoster || $0.textPayload["roster"] == "1" }
        let messy: Set<MetricSection> = [
            .scheduleQuality, .dynacap, .pickerScorecard, .pickPathPicker, .lostRevenue, .sales, .preSubOOS, .storeRoster
        ]
        let primary = official.isEmpty ? rows.filter { !messy.contains($0.section) } : official
        let fallback = official.isEmpty
            ? rows.filter { messy.contains($0.section) }
            : rows.filter { $0.section != .storeRoster && $0.textPayload["roster"] != "1" }
        var roster = HeartbeatMath.storeRoster(
            primary.isEmpty
                ? rows.filter { $0.section != .pickerScorecard && $0.section != .pickPathPicker }
                : primary
        )
        guard !fallback.isEmpty else { return roster }
        let extra = HeartbeatMath.storeRoster(fallback)
        for (number, identity) in extra {
            if var current = roster[number] {
                if current.division.isEmpty { current.division = identity.division }
                if current.district.isEmpty { current.district = identity.district }
                if current.om.isEmpty { current.om = identity.om }
                if current.name == nil { current.name = identity.name }
                roster[number] = current
            } else {
                roster[number] = identity
            }
        }
        HeartbeatMath.fillDivisionsFromDistrict(in: &roster)
        for row in rows {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty, !HeartbeatMath.isIgnoredStore(store) else { continue }
            var identity = roster[store] ?? HeartbeatMath.StoreIdentity(
                division: "",
                district: "",
                om: "",
                name: row.storeName
            )
            var changed = roster[store] == nil
            if identity.district.isEmpty {
                let district = HeartbeatMath.canonicalDistrict(row.district)
                if !district.isEmpty {
                    identity.district = district
                    changed = true
                }
            }
            if identity.division.isEmpty {
                let division = MarketRegion.canonicalName(row.division)
                if !division.isEmpty {
                    identity.division = division
                    changed = true
                } else {
                    let raw = row.division.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !raw.isEmpty {
                        identity.division = raw
                        changed = true
                    }
                }
            }
            if identity.om.isEmpty {
                let om = HeartbeatMath.canonicalOM(row.operationsOM)
                if !om.isEmpty {
                    identity.om = om
                    changed = true
                }
            }
            if identity.name == nil, let name = row.storeName, !name.isEmpty {
                identity.name = name
                changed = true
            }
            if changed { roster[store] = identity }
        }
        return roster
    }

    /// Pick section rows whose store number is in `stores`. No district/roster logic.
    static func rowsMatchingStores(
        _ rows: [MetricRow],
        stores: Set<String>,
        skipMarket: Bool
    ) -> [MetricRow] {
        var index: [String: MetricRow] = [:]
        index.reserveCapacity(rows.count)
        for row in rows {
            if skipMarket, row.textPayload["lost_grain"] == "market", HeartbeatMath.canonicalStore(row.storeNumber).isEmpty { continue }
            if row.textPayload["sales_grain"] == "company" { continue }
            if HeartbeatMath.isIgnoredStore(row.storeNumber), row.section != .sales { continue }
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            if index[store] == nil { index[store] = row }
            for alias in HeartbeatMath.storeAliases(store) where index[alias] == nil {
                index[alias] = row
            }
        }
        var seen: Set<String> = []
        var out: [MetricRow] = []
        out.reserveCapacity(min(stores.count, index.count))
        for raw in stores {
            let store = HeartbeatMath.canonicalStore(raw)
            guard let row = index[store] ?? index[raw] else { continue }
            let key = HeartbeatMath.canonicalStore(row.storeNumber)
            if seen.insert(key).inserted {
                out.append(row)
            }
        }
        return out
    }

    static func lostRevenueRows(
        pool: [MetricRow],
        scope: Set<String>,
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters
    ) -> [MetricRow] {
        let matched = rowsMatchingStores(pool, stores: scope, skipMarket: true)
        if !matched.isEmpty { return matched }
        return rowsMatchingStores(pool, stores: scope, skipMarket: false).filter {
            !HeartbeatMath.canonicalStore($0.storeNumber).isEmpty
        }
    }

    static func scopedRows(
        _ rows: [MetricRow],
        allowed: Set<String>,
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters,
        skipMarket: Bool = false
    ) -> [MetricRow] {
        var aliases: Set<String> = []
        aliases.reserveCapacity(allowed.count * 3)
        for store in allowed {
            aliases.formUnion(HeartbeatMath.storeAliases(store))
        }
        var seen: Set<String> = []
        var out: [MetricRow] = []
        out.reserveCapacity(min(rows.count, max(allowed.count, 8)))
        for row in rows {
            if skipMarket, row.textPayload["lost_grain"] == "market", HeartbeatMath.canonicalStore(row.storeNumber).isEmpty { continue }
            if HeartbeatMath.isIgnoredStore(row.storeNumber), row.section != .sales { continue }
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if store.isEmpty { continue }
            guard !aliases.isEmpty, !HeartbeatMath.storeAliases(store).isDisjoint(with: aliases) else { continue }
            if seen.insert(store).inserted { out.append(row) }
        }
        return out
    }

    static func rowMatchesFilter(
        _ row: MetricRow,
        allowed: Set<String>,
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters
    ) -> Bool {
        let store = HeartbeatMath.canonicalStore(row.storeNumber)
        let identity = store.isEmpty ? nil : roster[store]
        if !store.isEmpty, allowed.contains(store) { return true }
        if allowed.contains(where: { HeartbeatMath.sameStore($0, store) }) { return true }
        let district = {
            if let value = identity?.district, !value.isEmpty { return value }
            return row.district
        }()
        let division = {
            if let value = identity?.division, !value.isEmpty { return value }
            return row.division
        }()
        let om = {
            if let value = identity?.om, !value.isEmpty { return value }
            return row.operationsOM
        }()
        if !filters.includesDivision(division) { return false }
        if !filters.includesDistrict(district) { return false }
        if !filters.includesOM(om) { return false }
        if !filters.includesStore(store) { return false }
        if !store.isEmpty, identity != nil, !allowed.isEmpty { return false }
        return true
    }

    static func allowedStores(
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters
    ) -> Set<String>? {
        pickerStoreSet(roster: roster, filters: filters)
    }

    private static func pickerStoreSet(
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters
    ) -> Set<String>? {
        if !filters.isActive {
            return nil
        }
        var allowed: Set<String> = []
        for (number, identity) in roster {
            if !filters.includesDivision(identity.division) { continue }
            if !filters.includesDistrict(identity.district) { continue }
            if !filters.includesOM(identity.om) { continue }
            if !filters.includesStore(number) { continue }
            allowed.insert(HeartbeatMath.canonicalStore(number))
        }
        return allowed
    }

    static func pickerBuckets(_ pickers: [MetricRow]) -> (index: [PickerFocus: [Int]], health: [PickerFocus: Health]) {
        pickerIndexValues(pickers)
    }

    static func pickerIndexValues(_ pickers: [MetricRow]) -> (index: [PickerFocus: [Int]], health: [PickerFocus: Health]) {
        var buckets: [PickerFocus: [Int]] = [:]
        var worst: [PickerFocus: Health] = [:]
        for focus in PickerFocus.allCases {
            buckets[focus] = []
            worst[focus] = Health.none
        }
        func note(_ focus: PickerFocus, _ health: Health) {
            let ranks: [Health: Int] = [Health.none: 0, .good: 1, .watch: 2, .risk: 3]
            if (ranks[health] ?? 0) > (ranks[worst[focus] ?? Health.none] ?? 0) {
                worst[focus] = health
            }
        }
        for (index, row) in pickers.enumerated() {
            guard HeartbeatMath.isRealPicker(row) else { continue }
            buckets[.all]?.append(index)
            let volume = HeartbeatMath.pickerHasVolume(row)
            let overall = HeartbeatMath.pickerHealth(row)
            if volume && overall != .good {
                buckets[.opportunity]?.append(index)
                note(.opportunity, overall)
            }
            if volume && overall == .good {
                buckets[.strong]?.append(index)
                buckets[.healthy]?.append(index)
                note(.strong, .good)
                note(.healthy, .good)
            }
            if volume && overall == .watch {
                buckets[.watchList]?.append(index)
                note(.watchList, .watch)
            }
            if volume && overall == .risk {
                buckets[.riskList]?.append(index)
                note(.riskList, .risk)
            }
            let pph = HeartbeatMath.pphHealth(row)
            if row.number("pph") != nil, pph != .good {
                buckets[.pph]?.append(index)
                note(.pph, pph)
            }
            let presub = HeartbeatMath.presubStar(row).health
            if row.number("presub_pct") != nil, presub != .good {
                buckets[.presub]?.append(index)
                note(.presub, presub)
            }
            let oth = HeartbeatMath.othStar(row).health
            if row.number("oth5_pct") != nil, oth != .good {
                buckets[.oth]?.append(index)
                note(.oth, oth)
            }
            let coe = HeartbeatMath.coeStar(row).health
            if row.number("coe_pct") != nil, coe != .good {
                buckets[.coe]?.append(index)
                note(.coe, coe)
            }
            let ott = HeartbeatMath.ottStar(row).health
            if row.number("ott_pct") != nil, ott != .good {
                buckets[.ott]?.append(index)
                note(.ott, ott)
            }
            let oos = HeartbeatMath.oosStar(row).health
            if row.number("oos_pct") != nil, oos != .good {
                buckets[.oos]?.append(index)
                note(.oos, oos)
            }
            let refund = HeartbeatMath.refundHealth(row)
            if row.number("refund_amt") != nil, refund == .watch || refund == .risk {
                buckets[.refund]?.append(index)
                note(.refund, refund)
            }
        }
        return (buckets, worst)
    }

    private static func pickPathIndexValues(scorecard: [MetricRow], pathRows: [MetricRow]) -> (buckets: [String: [MetricRow]], byShopper: [String: MetricRow]) {
        var storesByShopper: [String: Set<String>] = [:]
        var buckets: [String: [MetricRow]] = [:]
        for row in scorecard {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            buckets[store, default: []].append(row)
            for alias in HeartbeatMath.shopperAliases(row) {
                storesByShopper[alias, default: []].insert(store)
            }
        }
        var byShopper: [String: MetricRow] = [:]
        for row in pathRows {
            for alias in HeartbeatMath.shopperAliases(row) {
                byShopper[alias] = row
            }
            var targets = Set<String>()
            let ownStore = HeartbeatMath.canonicalStore(row.storeNumber)
            if !ownStore.isEmpty { targets.insert(ownStore) }
            for alias in HeartbeatMath.shopperAliases(row) {
                targets.formUnion(storesByShopper[alias] ?? [])
            }
            for store in targets {
                buckets[store, default: []].append(row)
            }
        }
        return (buckets, byShopper)
    }

    private static func pphIndexValues(_ scorecard: [MetricRow]) -> [String: [MetricRow]] {
        var buckets: [String: [MetricRow]] = [:]
        for row in scorecard where row.number("pph") != nil {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            buckets[store, default: []].append(row)
        }
        return buckets
    }

    private static func identity(
        _ roster: [String: HeartbeatMath.StoreIdentity],
        store: String
    ) -> HeartbeatMath.StoreIdentity {
        roster[HeartbeatMath.canonicalStore(store)]
            ?? HeartbeatMath.StoreIdentity(division: "", district: "", om: "", name: nil)
    }

    private static func checklistGroups(
        from latest: [MetricSection: [MetricRow]],
        roster: [String: HeartbeatMath.StoreIdentity]
    ) -> [MetricSection: [ChecklistDriverGroup]] {
        #if HEARTBEAT_INGEST
        _ = latest
        _ = roster
        return [:]
        #else
        var groups: [MetricSection: [ChecklistDriverGroup]] = [:]
        for section in MetricSection.dashboardCards {
            let rows = HeartbeatMath.topOpportunityStores(section: section, rows: latest[section] ?? [], limit: 10)
            let items = rows.map { row -> ChecklistDriverItem in
                let division = row.division.isEmpty ? identity(roster, store: row.storeNumber).division : row.division
                return HeartbeatMath.makeChecklistItem(
                    section: section,
                    row: row,
                    division: division,
                    latest: latest
                )
            }
            .filter { $0.health.needsAction }
            if !items.isEmpty {
                groups[section] = [ChecklistDriverGroup(title: "Top \(items.count) opportunity stores", items: items)]
            }
        }
        let pickerGroups = HeartbeatMath.topPickersByMetric(latest[.pickerScorecard] ?? [], limit: 10).compactMap { board -> ChecklistDriverGroup? in
            let items = board.rows.compactMap { row -> ChecklistDriverItem? in
                    let health = HeartbeatMath.pickerHealth(row)
                    guard health.needsAction else { return nil }
                    let division = row.division.isEmpty ? identity(roster, store: row.storeNumber).division : row.division
                    let value: String
                    switch board.metric {
                    case "PPH": value = HeartbeatFormat.num(row.number("pph"), digits: 1)
                    case "Presub": value = HeartbeatFormat.pct(row.number("presub_pct"))
                    case "OTH": value = HeartbeatFormat.pct(row.number("oth5_pct"))
                    case "COE": value = HeartbeatFormat.pct(row.number("coe_pct"))
                    default: value = HeartbeatFormat.pct(row.number("ott_pct"))
                    }
                    return ChecklistDriverItem(
                        id: "picker-\(board.metric)-\(row.shopperName)-\(HeartbeatMath.canonicalStore(row.storeNumber))",
                        title: row.shopperName,
                        subtitle: "\(row.storeNumber)\(division.isEmpty ? "" : " · \(division)")",
                        value: value,
                        health: health,
                        broken: "\(board.metric) \(value)",
                        shoppers: row.shopperName,
                        action: "Coach \(row.shopperName) on \(board.metric) this week, side-by-side, then keep them off peak until it holds.",
                        findings: [
                            ChecklistFinding(
                                name: board.metric,
                                value: value,
                                need: "on goal",
                                health: health,
                                fact: HeartbeatMath.pickerOpportunityText(row),
                                shoppers: row.shopperName,
                                action: "Coach \(row.shopperName) on \(board.metric) this week, side-by-side, then keep them off peak until it holds."
                            )
                        ]
                    )
                }
            guard !items.isEmpty else { return nil }
            return ChecklistDriverGroup(title: "Top \(items.count) \(board.metric)", items: items)
        }
        if !pickerGroups.isEmpty {
            groups[.pickerScorecard] = pickerGroups
        }
        return groups
        #endif
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Array where Element == String {
    func uniquedIgnoringCase() -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for value in self {
            let key = HeartbeatMath.normalize(value)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            out.append(value)
        }
        return out
    }
}
