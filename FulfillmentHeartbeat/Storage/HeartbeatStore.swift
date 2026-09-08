import Foundation
import UIKit

final class ImportProgress: ObservableObject {
    @Published var label: String?
    @Published var loaded = 0
    @Published var expected = 0
    @Published var ready: [String] = []
    @Published var missing: [String] = []
}

@MainActor
final class HeartbeatStore: ObservableObject {
    @Published private(set) var rows: [MetricRow]
    @Published private(set) var uploads: [UploadRecord]
    @Published private(set) var seeded: Bool
    @Published var filters: DashboardFilters {
        didSet {
            guard !hydrating, oldValue != filters else { return }
            applyFilters()
        }
    }
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var lastImportedSection: MetricSection? = nil
    @Published var isImporting = false
    let importProgress = ImportProgress()
    @Published var importLabel: String?
    @Published var importLoaded = 0
    @Published var importExpected = 0
    @Published var importMissing: [String] = []
    @Published var importReady: [String] = []
    @Published var pendingExternalName: String?
    @Published var waitingForFileSection: MetricSection?
    @Published private(set) var isReady = false
    @Published private(set) var filterStamp = 0
    @Published private(set) var linkedMasterName: String?
    @Published private(set) var linkedMasterLoadedAt: Date?
    @Published var needsRolePick = true
    @Published private(set) var usingDatabasePack = false
    @Published private(set) var sessionRole: HeartbeatRole?
    @Published var laborWeekFilter = ""

    private let fileManager: FileManager
    private let snapshotURL: URL
    private let heavyURL: URL
    private let sqliteURL: URL
    private let cardsURL: URL
    private let checklistURL: URL
    private let masterLinkURL: URL
    private let filtersURL: URL
    private var hydrating = false
    private var packDirty = false
    private var pendingExternalData: Data?
    @Published private(set) var checklistRecipients: [String] = []
    private var checklistByKey: [String: ChecklistItem] = [:]
    private var commentSaveTask: Task<Void, Never>?
    private var latestBySection: [MetricSection: [MetricRow]] = [:]
    private var roster: [String: HeartbeatMath.StoreIdentity] = [:]
    private var filteredLatest: [MetricSection: [MetricRow]] = [:]
    private var filteredMarket: [HeartbeatMath.MarketStore] = []
    private var cachedDivisions: [String] = []
    private var cachedDistricts: [String] = []
    private var cachedOMs: [String] = []
    private var cachedStores: [(number: String, name: String?)] = []
    private var cachedSummaries: [SectionSummary] = []
    private var cachedPickerBoard = HeartbeatMath.PickerBoard(
        shopperCount: 0,
        opportunityCount: 0,
        strongCount: 0,
        opportunity: [],
        strong: []
    )
    private var cachedChecklistGroups: [MetricSection: [ChecklistDriverGroup]] = [:]
    private var pickerIndex: [PickerFocus: [Int]] = [:]
    private var pickerFocusHealth: [PickerFocus: Health] = [:]
    private var pickPathPickersByStore: [String: [MetricRow]] = [:]
    private var pickPathByShopper: [String: MetricRow] = [:]
    private var pphPickersByStore: [String: [MetricRow]] = [:]
    private var cachedCardFlags: [MetricSection: [HeartbeatMath.FiveStarFlag]] = [:]
    private var cachedGrainPacks: [MetricSection: [DashScopePack]] = [:]
    private(set) var cachedSalesScopeRows: [SalesRollupRow] = []
    private(set) var cachedSalesDayRows: [SalesRollupRow] = []
    private var laborWeeksByStore: [String: [MetricRow]] = [:]
    private var unfilteredPulse: FilterPulse?
    private var refilterTask: Task<Void, Never>?
    private var unfilteredWarmTask: Task<Void, Never>?
    private var pulseGeneration = 0
    private var masterBookmark: Data?
    private var lifetimeObservers: [NSObjectProtocol] = []

    init(rootURL: URL? = nil) {
        fileManager = .default
        let root = rootURL ?? Self.defaultRoot()
        if !fileManager.fileExists(atPath: root.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        snapshotURL = root.appendingPathComponent("heartbeat.json")
        heavyURL = root.appendingPathComponent("heartbeat-heavy.json")
        sqliteURL = root.appendingPathComponent(PulseSQLite.fileName)
        cardsURL = root.appendingPathComponent(PulseCards.fileName)
        checklistURL = root.appendingPathComponent("checklist.json")
        masterLinkURL = root.appendingPathComponent("master-link.json")
        filtersURL = root.appendingPathComponent("filters.json")
        rows = []
        uploads = []
        seeded = false
        filters = DashboardFilters()
        isReady = false
        isImporting = true
        importProgress.label = "Loading the data"
        importProgress.expected = MetricSection.uploadOrder.count
        importProgress.loaded = 0
        Task { await self.boot() }
        watchAppLifecycle()
    }

    private func boot() async {
        loadChecklist()
        loadMasterLink()
        isImporting = true
        isReady = false
        importProgress.label = "Opening the floor"
        await loadPack()
        if cachedSummaries.isEmpty, !rows.isEmpty {
            rebuildIndex()
            installCompanyWideFast()
        }
        var remoteXlsx = 0
        for name in PulseCloud.workbookNames {
            let size = await PulseCloud.objectSize(name)
            if size > 1_000 {
                remoteXlsx = size
                break
            }
        }
        let knownXlsx = UserDefaults.standard.integer(forKey: "hb.cloudXlsxBytes")
        let packReady = Self.hasUsableLabor(rows) && Self.hasUsablePicker(rows)
        if remoteXlsx > 1_000, remoteXlsx != knownXlsx {
            await importCloudWorkbook(blocking: true)
        } else if packReady {
            isImporting = false
            importLabel = nil
            isReady = true
            needsRolePick = true
            return
        } else {
            isImporting = true
            importProgress.label = "Downloading workbook"
            importProgress.loaded = 0
            importProgress.expected = MetricSection.uploadOrder.count
            importLabel = "Downloading workbook"
            await pullWorkbookFromServer()
        }
        if cachedSummaries.isEmpty, !rows.isEmpty {
            rebuildIndex()
            installCompanyWideFast()
        }
        isImporting = false
        importLabel = nil
        if seeded, !rows.isEmpty {
            isReady = true
            needsRolePick = true
        }
    }

    private func applyLocalCards() {
        guard let cards = PulseCards.read(from: cardsURL) else { return }
        if cards.opportunity.isEmpty && cards.strong.isEmpty { return }
        if cachedPickerBoard.opportunity.isEmpty && cachedPickerBoard.strong.isEmpty {
            cachedPickerBoard = cards.board()
        }
    }

    private func watchAppLifecycle() {
        let flush: (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.persist()
            }
        }
        let blocking: (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.persistBlocking()
            }
        }
        lifetimeObservers = [
            NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main, using: flush),
            NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main, using: flush),
            NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main, using: blocking),
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.pullLatestWorkbookIfNeeded()
                }
            },
        ]
    }

    private static func defaultRoot() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pulse", isDirectory: true)
    }

    private static func legacySnapshotURLs() -> [URL] {
        let fm = FileManager.default
        var roots: [URL] = []
        if let app = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            roots.append(app.appendingPathComponent("FulfillmentHeartbeat", isDirectory: true))
        }
        roots.append(
            fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("FulfillmentHeartbeat", isDirectory: true)
        )
        return roots.map { $0.appendingPathComponent("heartbeat.json") }
    }

    func rows(for section: MetricSection, relaxUnknown: Bool = false) -> [MetricRow] {
        if relaxUnknown {
            return HeartbeatMath.filtered(
                latestBySection[section] ?? [],
                filters: filters,
                relaxUnknown: true,
                universe: latestUniverse
            )
        }
        return filteredLatest[section] ?? []
    }

    func marketStores() -> [HeartbeatMath.MarketStore] { filteredMarket }

    func latest(for section: MetricSection, relaxUnknown: Bool = false) -> [MetricRow] {
        rows(for: section, relaxUnknown: relaxUnknown)
    }

    func allLatest(for section: MetricSection) -> [MetricRow] {
        latestBySection[section] ?? []
    }

    func salesStores() -> [MetricRow] {
        SalesRollupBuilder.source(from: allLatest(for: .sales), filters: filters, roster: roster)
    }

    func refreshSalesExpandCache() {
        let source = salesStores()
        let grain = effectiveDashboardGrain ?? .region
        cachedSalesScopeRows = SalesRollupBuilder.dashboardRows(from: source, grain: grain)
        cachedSalesDayRows = SalesRollupBuilder.dayRows(from: source)
    }

    func rollupStores(for section: MetricSection) -> [MetricRow] {
        let raw: [MetricRow]
        switch section {
        case .sales:
            raw = allLatest(for: .sales).filter {
                $0.textPayload["sales_grain"] != "day"
                    && $0.textPayload["sales_grain"] != "company"
                    && !$0.storeNumber.isEmpty
            }
        case .labor:
            raw = laborTableRows().filter {
                $0.textPayload["labor_grain"] != "market" && !$0.storeNumber.isEmpty
            }
        case .lostRevenue:
            raw = allLatest(for: .lostRevenue).filter {
                $0.textPayload["lost_grain"] != "market" && !$0.storeNumber.isEmpty
            }
        default:
            raw = allLatest(for: section).filter { !$0.storeNumber.isEmpty }
        }
        return RollupMarketFill.scopedRollup(raw, filters: filters, roster: roster)
    }

    func displayRows(for section: MetricSection) -> [MetricRow] {
        filteredLatest[section] ?? []
    }

    func summary(for section: MetricSection) -> SectionSummary {
        cachedSummaries.first { $0.section == section }
            ?? HeartbeatMath.summarize(section, rows: displayRows(for: section), upload: upload(for: section))
    }

    func upload(for section: MetricSection) -> UploadRecord? {
        uploads.first { $0.section == section }
    }

    var summaries: [SectionSummary] { cachedSummaries }

    func dashboardFlags(for section: MetricSection) -> [HeartbeatMath.FiveStarFlag] {
        cachedCardFlags[section] ?? []
    }

    func dashboardGrains(for section: MetricSection) -> [DashScopePack] {
        cachedGrainPacks[section] ?? []
    }

    func dashboardGrainChildren(section: MetricSection, label: String) -> [DashScopeLine] {
        let grain = effectiveDashboardGrain
        let rows = HeartbeatMath.rowsFillingRoster(filteredLatest[section] ?? [], roster: roster)
        switch grain {
        case .region:
            let markets = HeartbeatMath.dashboardScopeLines(section: section, rows: rows, grain: .division)
            let matched = markets.filter { MarketRegion.containing($0.label)?.rawValue == label }
            if !matched.isEmpty { return matched }
            return MarketRegion.allCases.first(where: { $0.rawValue == label })?.gateDivisions.map {
                DashScopeLine(label: $0, value: "—", health: .none, count: 0)
            } ?? []
        case .district:
            let scoped = rows.filter { RollupMarketFill.districtKey($0.district) == label }
            return Array(HeartbeatMath.dashboardScopeLines(section: section, rows: scoped, grain: .store).prefix(40))
        default:
            return []
        }
    }

    func fiveStarFlags(label: String, grain: DashScopeGrain) -> [HeartbeatMath.FiveStarFlag] {
        let rows = filteredLatest[.fiveStar] ?? []
        let matched = rows.filter { HeartbeatMath.dashboardScopeKey($0, grain: grain) == label }
        return HeartbeatMath.fiveStarActionFlags(matched, includeAll: true)
    }

    func fiveStarFlagsForDivision(_ name: String) -> [HeartbeatMath.FiveStarFlag] {
        fiveStarFlags(label: name, grain: .division)
    }

    func metricFlags(for metric: MetricSection, label: String, grain: DashScopeGrain) -> [HeartbeatMath.FiveStarFlag] {
        let rows = (filteredLatest[metric] ?? []).filter { HeartbeatMath.dashboardScopeKey($0, grain: grain) == label }
        let items = (filteredLatest[.preSubOOSItem] ?? []).filter { HeartbeatMath.dashboardScopeKey($0, grain: grain) == label }
        let pickers = (filteredLatest[.pickerScorecard] ?? []).filter { HeartbeatMath.dashboardScopeKey($0, grain: grain) == label }
        return HeartbeatMath.dashboardActionFlags(
            section: metric,
            rows: rows,
            pickers: pickers,
            items: items,
            includeAll: true
        )
    }

    func metricFlags(for metric: MetricSection, grain: DashScopeGrain, labels: [String]) -> [String: [HeartbeatMath.FiveStarFlag]] {
        var out: [String: [HeartbeatMath.FiveStarFlag]] = [:]
        out.reserveCapacity(labels.count)
        for label in labels {
            out[label] = metricFlags(for: metric, label: label, grain: grain)
        }
        return out
    }

    func dashboardGrainFlags(
        section: MetricSection,
        grain: DashScopeGrain,
        packs: [DashScopePack]
    ) -> [String: [HeartbeatMath.FiveStarFlag]] {
        PulseCaches.grainFlags(section: section, grain: grain, packs: packs, latest: filteredLatest)
    }

    func dashboardScopeCount(_ grain: DashScopeGrain) -> Int {
        if !cachedSalesScopeRows.isEmpty {
            return cachedSalesScopeRows.count
        }
        switch grain {
        case .region:
            return Set(roster.values.compactMap { MarketRegion.containing($0.division)?.rawValue }).count
        case .division:
            return cachedDivisions.filter { filters.includesDivision($0) }.count
        case .district:
            return cachedDistricts.count
        case .store:
            return cachedStores.count
        }
    }

    var effectiveDashboardGrain: DashScopeGrain {
        if !filters.store.isEmpty || !filters.om.isEmpty || !filters.district.isEmpty {
            return .store
        }
        if !filters.division.isEmpty {
            return .district
        }
        if !filters.region.isEmpty {
            return .division
        }
        return sessionRole?.dashboardGrain ?? .region
    }

    var pickerBoard: HeartbeatMath.PickerBoard { cachedPickerBoard }

    func pphPickers(forStore store: String) -> [MetricRow] {
        pphPickersByStore[HeartbeatMath.canonicalStore(store)] ?? []
    }

    func pphPickerCount(forStore store: String) -> Int {
        pphPickersByStore[HeartbeatMath.canonicalStore(store)]?.count ?? 0
    }

    func pickPathPickers(forStore store: String) -> [MetricRow] {
        let want = HeartbeatMath.canonicalStore(store)
        guard !want.isEmpty else { return [] }
        if let exact = pickPathPickersByStore[want], !exact.isEmpty {
            return exact
        }
        var matched: [MetricRow] = []
        for (key, rows) in pickPathPickersByStore where HeartbeatMath.sameStore(key, want) {
            matched.append(contentsOf: rows)
        }
        if !matched.isEmpty { return matched }
        for section in [MetricSection.pickerScorecard, .pickPathPicker] {
            let source = latestBySection[section] ?? filteredLatest[section] ?? []
            for row in source where HeartbeatMath.sameStore(row.storeNumber, want) {
                matched.append(row)
            }
        }
        return matched
    }

    func pickPathPicker(forShopper raw: String) -> MetricRow? {
        pickPathByShopper[HeartbeatMath.canonicalShopper(raw)]
    }

    func pickerCount(for focus: PickerFocus) -> Int {
        let pickers = filters.isActive
            ? (filteredLatest[.pickerScorecard] ?? [])
            : (latestBySection[.pickerScorecard] ?? [])
        if focus == .all { return pickers.count }
        if let indexed = pickerIndex[focus]?.count, indexed > 0 {
            return indexed
        }
        return 0
    }

    func pickerFocusHealth(for focus: PickerFocus) -> Health {
        pickerFocusHealth[focus] ?? Health.none
    }

    func pickerPage(focus: PickerFocus, sort: PickerSort, ascending: Bool, limit: Int) -> [MetricRow] {
        let pickers = filteredLatest[.pickerScorecard] ?? []
        guard !pickers.isEmpty else { return [] }
        var idxs = (pickerIndex[focus] ?? []).filter { pickers.indices.contains($0) }
        if idxs.isEmpty {
            if focus == .all {
                idxs = Array(pickers.indices)
            } else {
                return []
            }
        }
        let cap = min(max(limit, 1), idxs.count)
        idxs.sort { lhs, rhs in
            let result = comparePickers(pickers[lhs], pickers[rhs], sort: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
        if idxs.count > cap {
            idxs = Array(idxs.prefix(cap))
        }
        return idxs.map { pickers[$0] }
    }

    private func comparePickers(_ lhs: MetricRow, _ rhs: MetricRow, sort: PickerSort) -> ComparisonResult {
        switch sort {
        case .pph:
            return pickerNumberOrder(lhs.number("pph"), rhs.number("pph"))
        case .presub:
            return pickerNumberOrder(lhs.number("presub_pct"), rhs.number("presub_pct"))
        case .oos:
            return pickerNumberOrder(lhs.number("oos_pct"), rhs.number("oos_pct"))
        case .ott:
            return pickerNumberOrder(lhs.number("ott_pct"), rhs.number("ott_pct"))
        case .oth5:
            return pickerNumberOrder(lhs.number("oth5_pct"), rhs.number("oth5_pct"))
        case .refund:
            return pickerNumberOrder(lhs.number("refund_amt") ?? 0, rhs.number("refund_amt") ?? 0)
        case .name:
            return lhs.shopperName.localizedStandardCompare(rhs.shopperName)
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .status:
            let a = pickerHealthRank(HeartbeatMath.pickerHealth(lhs))
            let b = pickerHealthRank(HeartbeatMath.pickerHealth(rhs))
            if a == b { return pickerNumberOrder(lhs.number("pph"), rhs.number("pph")) }
            return a < b ? .orderedAscending : .orderedDescending
        }
    }

    private func pickerNumberOrder(_ a: Double?, _ b: Double?) -> ComparisonResult {
        let lhs = a ?? 9_999
        let rhs = b ?? 9_999
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private func pickerHealthRank(_ health: Health) -> Int {
        switch health {
        case .risk: return 0
        case .watch: return 1
        case .good: return 2
        case .none: return 3
        }
    }

    private func rebuildPickerIndex(_ pickers: [MetricRow]) {
        let built = pickerIndexValues(pickers)
        pickerIndex = built.index
        pickerFocusHealth = built.health
    }

    private func pickerIndexValues(_ pickers: [MetricRow]) -> (index: [PickerFocus: [Int]], health: [PickerFocus: Health]) {
        var buckets: [PickerFocus: [Int]] = [:]
        var worst: [PickerFocus: Health] = [:]
        for focus in PickerFocus.allCases {
            buckets[focus] = []
            buckets[focus]?.reserveCapacity(focus == .strong ? 512 : pickers.count / 2)
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
            note(.all, Health.none)

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

        func byNumber(_ key: String, invert: Bool) -> (Int, Int) -> Bool {
            { lhs, rhs in
                let a = pickers[lhs].number(key)
                let b = pickers[rhs].number(key)
                if invert {
                    return (a ?? -9_999) > (b ?? -9_999)
                }
                return (a ?? 9_999) < (b ?? 9_999)
            }
        }

        buckets[.all]?.sort(by: byNumber("pph", invert: false))
        buckets[.opportunity]?.sort { lhs, rhs in
            let a = pickers[lhs].number("orders") ?? 0
            let b = pickers[rhs].number("orders") ?? 0
            if a != b { return a > b }
            return (pickers[lhs].number("pph") ?? 9_999) < (pickers[rhs].number("pph") ?? 9_999)
        }
        buckets[.strong]?.sort { lhs, rhs in
            let a = pickers[lhs].number("orders") ?? 0
            let b = pickers[rhs].number("orders") ?? 0
            if a != b { return a > b }
            return (pickers[lhs].number("pph") ?? 0) > (pickers[rhs].number("pph") ?? 0)
        }
        buckets[.pph]?.sort(by: byNumber("pph", invert: false))
        buckets[.presub]?.sort(by: byNumber("presub_pct", invert: true))
        buckets[.oth]?.sort(by: byNumber("oth5_pct", invert: false))
        buckets[.coe]?.sort(by: byNumber("coe_pct", invert: false))
        buckets[.ott]?.sort(by: byNumber("ott_pct", invert: false))
        buckets[.oos]?.sort(by: byNumber("oos_pct", invert: true))
        buckets[.refund]?.sort(by: byNumber("refund_amt", invert: true))

        return (buckets, worst)
    }

    private func rebuildPickPathPickerIndex(scorecard: [MetricRow]) {
        let built = pickPathIndexValues(scorecard: scorecard, pathRows: latestBySection[.pickPathPicker] ?? [])
        pickPathByShopper = built.byShopper
        pickPathPickersByStore = built.buckets
    }

    private func pickPathIndexValues(scorecard: [MetricRow], pathRows: [MetricRow]) -> (buckets: [String: [MetricRow]], byShopper: [String: MetricRow]) {
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
        for store in buckets.keys {
            buckets[store]?.sort {
                ($0.number("compliance_pct") ?? $0.number("pph") ?? 999) < ($1.number("compliance_pct") ?? $1.number("pph") ?? 999)
            }
        }
        return (buckets, byShopper)
    }

    private func rebuildPPHPickerIndex(scorecard: [MetricRow]) {
        pphPickersByStore = pphIndexValues(scorecard)
    }

    private func pphIndexValues(_ scorecard: [MetricRow]) -> [String: [MetricRow]] {
        var buckets: [String: [MetricRow]] = [:]
        buckets.reserveCapacity(512)
        for row in scorecard where row.number("pph") != nil {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            buckets[store, default: []].append(row)
        }
        for store in buckets.keys {
            buckets[store]?.sort { ($0.number("pph") ?? 999) < ($1.number("pph") ?? 999) }
        }
        return buckets
    }

    func laborWeekIds() -> [String] {
        Set(laborWeeksByStore.values.flatMap { weeks in
            weeks.compactMap { week -> String? in
                let value = week.textPayload["week"] ?? week.recordedOn ?? ""
                return value.isEmpty || !value.hasPrefix("20") ? nil : value
            }
        }).sorted(by: >)
    }

    func setLaborWeekFilter(_ week: String) {
        if week.isEmpty {
            laborWeekFilter = ""
        } else {
            laborWeekFilter = laborWeekFilter == week ? "" : week
        }
        filterStamp += 1
    }

    func laborTableRows() -> [MetricRow] {
        if laborWeekFilter.isEmpty {
            return displayRows(for: .labor)
        }
        var out: [MetricRow] = []
        out.reserveCapacity(laborWeeksByStore.count)
        for weeks in laborWeeksByStore.values {
            if let row = weeks.first(where: { ($0.textPayload["week"] ?? $0.recordedOn ?? "") == laborWeekFilter }) {
                out.append(row)
            }
        }
        return HeartbeatMath.filtered(out, filters: filters)
    }

    func laborWeekSpan() -> String {
        let ids = laborWeekIds()
        guard let first = ids.first, let last = ids.last else { return "—" }
        return first == last ? first : "\(first) thru \(last)"
    }

    func laborMarketRow() -> MetricRow? {
        rows.first {
            $0.section == .labor && (
                $0.textPayload["labor_grain"] == "market"
                    || HeartbeatMath.canonicalStore($0.storeNumber).caseInsensitiveCompare("TOTAL") == .orderedSame
            )
        }
    }

    func lostRevenueMarketRow() -> MetricRow? {
        rows.first { $0.section == .lostRevenue && $0.textPayload["lost_grain"] == "market" }
    }

    func dynacapCoverageNote() -> String? {
        let scored = allLatest(for: .dynacap).filter { $0.number("dynacap_rate", "pieces_per_hour") != nil }
        let rosterCount = marketStores().count
        guard !scored.isEmpty, rosterCount > 0 else { return nil }
        let covered = Set(scored.map { HeartbeatMath.canonicalStore($0.storeNumber) }.filter { !$0.isEmpty })
        guard covered.count < rosterCount / 2 else { return nil }
        let markets = MarketRegion.uniqueNames(scored.map(\.division)).sorted().joined(separator: ", ")
        return "Dynacap in this workbook is only \(covered.count) stores (\(markets.isEmpty ? "no market names" : markets)). Power BI exported with IS_OPP_STORE on. Clear that slicer, export all stores, replace the Dynacap tab, and reload."
    }

    func dataWindow(for section: MetricSection) -> String? {
        rows.first { $0.section == section && !($0.textPayload["data_window"] ?? "").isEmpty }?.textPayload["data_window"]
    }

    func sharedDataWindow() -> String? {
        let labels = MetricSection.uploadOrder.compactMap { dataWindow(for: $0) }
        let unique = Array(Set(labels))
        if unique.count == 1 { return unique[0] }
        return labels.first
    }

    func laborNeedsReload() -> Bool {
        let stores = rows.filter { $0.section == .labor && $0.textPayload["labor_grain"] == "store" }
        guard !stores.isEmpty else { return false }
        if laborMarketRow() == nil, laborWeekIds().isEmpty { return true }
        return stores.contains {
            let rev = $0.textPayload["parser_rev"] ?? ""
            return rev != "7" && rev != "8" && rev != "9"
        }
    }

    static func importAudit(section: MetricSection, rows: [MetricRow]) -> String {
        if section == .labor {
            return laborAudit(rows)
        }
        let stores = Set(rows.map { HeartbeatMath.canonicalStore($0.storeNumber) }.filter { !$0.isEmpty })
        let shoppers = Set(rows.compactMap { $0.textPayload["shopper_id"] }.filter { !$0.isEmpty })
        if section == .dynacap {
            let named = rows.map { MarketRegion.canonicalName($0.division) }.filter { !$0.isEmpty }
            let divisions = MarketRegion.uniqueNames(named).sorted()
            var parts = [
                "\(HeartbeatFormat.num(Double(rows.count))) rows",
                "\(HeartbeatFormat.num(Double(stores.count))) stores",
            ]
            if !divisions.isEmpty {
                parts.append(divisions.joined(separator: ", "))
            }
            if stores.count > 0, stores.count < 800 {
                parts.append("Power BI export is filtered — turn off IS_OPP_STORE and re-export all stores so every market fills in")
            }
            return parts.joined(separator: " · ")
        }
        if section == .lostRevenue {
            let hasTotal = rows.contains { $0.textPayload["lost_grain"] == "market" }
            return [
                "\(HeartbeatFormat.num(Double(rows.count))) rows",
                "\(HeartbeatFormat.num(Double(stores.count))) stores",
                hasTotal ? "Power BI Total row captured for company tiles" : "missing Total row — filter totals will sum the stores in view",
            ].joined(separator: " · ")
        }
        if !shoppers.isEmpty {
            return "\(HeartbeatFormat.num(Double(rows.count))) rows · \(HeartbeatFormat.num(Double(stores.count))) stores · \(HeartbeatFormat.num(Double(shoppers.count))) shoppers"
        }
        return "\(HeartbeatFormat.num(Double(rows.count))) rows · \(HeartbeatFormat.num(Double(stores.count))) stores"
    }

    private static func laborAudit(_ rows: [MetricRow]) -> String {
        let stores = rows.filter { $0.textPayload["labor_grain"] == "store" }
        let weeks = rows.filter { $0.textPayload["labor_grain"] == "week" }
        let weekIds = Set(weeks.compactMap { $0.textPayload["week"] }.filter { !$0.isEmpty }).sorted()
        let noCost = stores.filter { $0.number("cost_trgt_pct") == nil }.count
        let noTva = stores.filter { $0.number("target_vs_actual_pct") == nil }.count
        let span = weekIds.isEmpty ? "—" : (weekIds.first == weekIds.last ? weekIds[0] : "\(weekIds.first!) thru \(weekIds.last!)")
        if weekIds.isEmpty {
            let hasTotal = rows.contains { $0.textPayload["labor_grain"] == "market" }
            return [
                "replaced prior Labor",
                "\(HeartbeatFormat.num(Double(stores.count))) stores",
                hasTotal ? "Power BI Total row captured for company tiles" : "missing Total row — re-upload Store View so tiles match Power BI",
            ].joined(separator: " · ")
        }
        var parts = [
            "replaced prior Labor",
            "\(HeartbeatFormat.num(Double(stores.count))) stores",
            "\(weekIds.count) weeks in this file (\(span))",
            weekIds.joined(separator: ", "),
            "\(HeartbeatFormat.num(Double(weeks.count))) store-weeks",
        ]
        if noCost > 0 { parts.append("\(noCost) stores have no CostTrgt% in the file") }
        if noTva > 0 { parts.append("\(noTva) stores have no Target vs Actual in the file") }
        return parts.joined(separator: " · ")
    }

    func laborWeeks(forStore storeNumber: String) -> [MetricRow] {
        let store = HeartbeatMath.canonicalStore(storeNumber)
        if let weeks = laborWeeksByStore[store], !weeks.isEmpty {
            return weeks
        }
        return synthesizedLaborWeeks(for: store)
    }

    func laborDays(from week: MetricRow) -> [LaborDay] {
        if let raw = week.textPayload["days_json"],
           let data = raw.data(using: .utf8),
           let days = try? JSONDecoder().decode([LaborDay].self, from: data),
           !days.isEmpty {
            return days
        }
        let store = HeartbeatMath.canonicalStore(week.storeNumber)
        let weekId = week.textPayload["week"] ?? week.recordedOn ?? ""
        return rows.compactMap { row -> LaborDay? in
            guard row.section == .labor,
                  row.textPayload["labor_grain"] == "day",
                  HeartbeatMath.canonicalStore(row.storeNumber) == store,
                  (row.textPayload["week"] ?? "") == weekId
            else { return nil }
            return LaborDay(
                date: row.recordedOn ?? "",
                scheduleEfficiencyPct: row.number("schedule_efficiency_pct"),
                schHrs: row.number("sch_hrs"),
                empowerHrs: row.number("empower_hrs"),
                earnedHrs: row.number("earned_hrs"),
                earnedHrsUtil: row.number("earned_hrs_util"),
                actCostPct: row.number("act_cost_pct"),
                overSchedulePct: row.number("over_schedule_pct"),
                chargedHrs: row.number("charged_hrs")
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func rebuildLaborWeekIndex() {
        var buckets: [String: [MetricRow]] = [:]
        buckets.reserveCapacity(512)
        for row in rows where row.section == .labor {
            let grain = row.textPayload["labor_grain"] ?? ""
            let week = row.textPayload["week"] ?? ""
            guard grain == "week" || (grain == "store" && week.hasPrefix("20")) else { continue }
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty, !HeartbeatMath.isIgnoredStore(store) else { continue }
            buckets[store, default: []].append(row)
        }
        for store in buckets.keys {
            buckets[store]?.sort { ($0.textPayload["week"] ?? "") > ($1.textPayload["week"] ?? "") }
        }
        laborWeeksByStore = buckets
    }

    private func synthesizedLaborWeeks(for store: String) -> [MetricRow] {
        let days = rows.filter {
            $0.section == .labor
                && $0.textPayload["labor_grain"] == "day"
                && HeartbeatMath.canonicalStore($0.storeNumber) == store
        }
        guard !days.isEmpty else { return [] }
        var byWeek: [String: [MetricRow]] = [:]
        for day in days {
            let week = day.textPayload["week"] ?? day.recordedOn ?? ""
            guard !week.isEmpty else { continue }
            byWeek[week, default: []].append(day)
        }
        return byWeek.keys.sorted(by: >).compactMap { week in
            guard let sample = byWeek[week]?.sorted(by: { ($0.recordedOn ?? "") < ($1.recordedOn ?? "") }).first else { return nil }
            return MetricRow(
                section: .labor,
                division: sample.division,
                operationsOM: sample.operationsOM,
                storeNumber: store,
                storeName: sample.storeName,
                recordedOn: week,
                payload: sample.payload,
                textPayload: [
                    "labor_grain": "week",
                    "week": week,
                    "district": sample.textPayload["district"] ?? sample.district,
                ]
            )
        }
    }

    func checklistItem(for item: ChecklistDriverItem, section: MetricSection) -> ChecklistItem {
        let key = checklistKey(for: item, section: section)
        return checklistByKey[key] ?? ChecklistItem(id: key)
    }

    func setChecklistStatus(_ status: ChecklistStatus, for item: ChecklistDriverItem, section: MetricSection) {
        var entry = checklistItem(for: item, section: section)
        entry.status = entry.status == status ? .open : status
        entry.updatedAt = Date()
        checklistByKey[entry.id] = entry
        persistChecklist()
        refreshChecklistOpenCount()
        objectWillChange.send()
    }

    func setChecklistComment(_ comment: String, for item: ChecklistDriverItem, section: MetricSection) {
        var entry = checklistItem(for: item, section: section)
        entry.comment = comment
        entry.updatedAt = Date()
        checklistByKey[entry.id] = entry
        commentSaveTask?.cancel()
        commentSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.persistChecklist()
            }
        }
    }

    func addChecklistRecipient(_ raw: String) {
        let emails = raw
            .split(whereSeparator: { ",; ".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter(Self.isEmail)
        guard !emails.isEmpty else { return }
        for email in emails where !checklistRecipients.contains(email) {
            checklistRecipients.append(email)
        }
        persistChecklist()
        objectWillChange.send()
    }

    func removeChecklistRecipient(_ email: String) {
        checklistRecipients.removeAll { $0 == email }
        persistChecklist()
        objectWillChange.send()
    }

    private var cachedChecklistOpenCount = 0

    var checklistOpenCount: Int { cachedChecklistOpenCount }

    private func refreshChecklistOpenCount() {
        var count = 0
        for section in MetricSection.checklistSections {
            var seen = Set<String>()
            for group in cachedChecklistGroups[section] ?? [] {
                for item in group.items {
                    guard seen.insert(item.title + "|" + item.subtitle).inserted else { continue }
                    if !checklistItem(for: item, section: section).status.isClosed {
                        count += 1
                    }
                    for finding in item.findings {
                        if !checklistItem(for: item.findingItem(finding), section: section).status.isClosed {
                            count += 1
                        }
                    }
                    for person in item.people {
                        if !checklistItem(for: item.shopperItem(person), section: section).status.isClosed {
                            count += 1
                        }
                    }
                }
            }
        }
        cachedChecklistOpenCount = count
    }

    var canSendChecklist: Bool { !checklistRecipients.isEmpty }

    func checklistGroups(for section: MetricSection) -> [ChecklistDriverGroup] {
        cachedChecklistGroups[section] ?? []
    }

    func checklistEmailSubject() -> String {
        "Fulfillment Checklist — \(filters.summary)"
    }

    func checklistEmailText() -> String {
        var lines: [String] = [
            "eCommerce Fulfillment Checklist",
            filters.summary,
            HeartbeatFormat.stamp(Date()),
            "",
        ]
        for section in MetricSection.checklistSections {
            let summary = self.summary(for: section)
            lines.append(section.title.uppercased())
            lines.append("\(summary.health.label) · \(summary.headlineLabel) \(summary.headlineText)")
            lines.append(summary.secondary)
            for group in checklistGroups(for: section) {
                lines.append("")
                lines.append(group.title)
                for item in group.items {
                    let action = checklistItem(for: item, section: section)
                    lines.append("• \(item.title) · \(item.subtitle) · \(item.value) · \(item.health.label)")
                    if !item.broken.isEmpty { lines.append("  Broken: \(item.broken)") }
                    if !item.shoppers.isEmpty { lines.append("  Shoppers: \(item.shoppers)") }
                    if !item.action.isEmpty { lines.append("  Action: \(item.action)") }
                    lines.append("  Status: \(action.status.label) · \(HeartbeatFormat.stamp(action.updatedAt))")
                    if !action.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lines.append("  Comments: \(action.comment)")
                    }
                    for person in item.people {
                        let personAction = checklistItem(for: item.shopperItem(person), section: section)
                        lines.append("    LDAP \(person.name) · \(person.issues.joined(separator: " · ")) · \(personAction.status.label)")
                        lines.append("    Action: \(person.action)")
                        if !personAction.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            lines.append("    Comments: \(personAction.comment)")
                        }
                    }
                }
            }
            lines.append("")
        }
        lines.append("Sent from Fulfillment Heartbeat")
        return lines.joined(separator: "\n")
    }

    func checklistEmailHTML() -> String {
        var html = """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta charset="utf-8">
        <style>
        body{margin:0;padding:16px;background:#F5F7FC;color:#141A29;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;line-height:1.45}
        .wrap{max-width:680px;margin:0 auto}
        h1{font-size:22px;margin:0 0 4px}
        .sub{color:#5C677A;font-size:14px;margin:0 0 16px}
        .card{background:#fff;border-radius:16px;padding:14px 16px;margin:0 0 14px;border:1px solid rgba(0,0,0,.06)}
        .kicker{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:#8A93A3;font-weight:600}
        .kpi{font-size:28px;font-weight:700;margin:4px 0}
        .row{padding:10px 0;border-top:1px solid #EEF1F6}
        .row:first-child{border-top:none}
        .title{font-weight:700}
        .meta{color:#5C677A;font-size:13px}
        .pill{display:inline-block;padding:3px 8px;border-radius:999px;font-size:12px;font-weight:600}
        .risk{background:#FEE2E2;color:#DC2626}
        .watch{background:#FEF3C7;color:#D97706}
        .good{background:#D1FAE5;color:#059669}
        .none{background:#E8EEFF;color:#266BF2}
        .comment{margin-top:6px;background:#F5F7FC;border-radius:10px;padding:8px 10px;font-size:14px}
        </style></head><body><div class="wrap">
        <h1>eCommerce Fulfillment Checklist</h1>
        <p class="sub">\(escape(filters.summary))<br>\(escape(HeartbeatFormat.stamp(Date())))</p>
        """
        for section in MetricSection.checklistSections {
            let summary = self.summary(for: section)
            html += """
            <div class="card">
            <div class="kicker">\(escape(section.title))</div>
            <div class="kpi">\(escape(summary.headlineText))</div>
            <div class="meta">\(escape(summary.health.label)) · \(escape(summary.secondary))</div>
            """
            for group in checklistGroups(for: section) {
                html += "<p class=\"kicker\" style=\"margin-top:14px\">\(escape(group.title))</p>"
                for item in group.items {
                    let action = checklistItem(for: item, section: section)
                    html += """
                    <div class="row">
                    <div class="title">\(escape(item.title)) · \(escape(item.value))
                    <span class="pill \(item.health.rawValue)">\(escape(item.health.label))</span></div>
                    <div class="meta">\(escape(item.subtitle)) · \(escape(action.status.label)) · \(escape(HeartbeatFormat.stamp(action.updatedAt)))</div>
                    """
                    if !item.broken.isEmpty {
                        html += "<div class=\"meta\"><b>Broken:</b> \(escape(item.broken))</div>"
                    }
                    if !item.shoppers.isEmpty {
                        html += "<div class=\"meta\"><b>Shoppers:</b> \(escape(item.shoppers))</div>"
                    }
                    if !item.action.isEmpty {
                        html += "<div class=\"meta\"><b>Action:</b> \(escape(item.action))</div>"
                    }
                    if !action.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        html += "<div class=\"comment\">\(escape(action.comment))</div>"
                    }
                    for person in item.people {
                        let personAction = checklistItem(for: item.shopperItem(person), section: section)
                        html += """
                        <div class="row">
                        <div class="title">LDAP \(escape(person.name))
                        <span class="pill \(person.health.rawValue)">\(escape(person.health.label))</span></div>
                        <div class="meta">\(escape(person.issues.joined(separator: " · "))) · \(escape(personAction.status.label))</div>
                        <div class="meta"><b>Action:</b> \(escape(person.action))</div>
                        """
                        if !personAction.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            html += "<div class=\"comment\">\(escape(personAction.comment))</div>"
                        }
                        html += "</div>"
                    }
                    html += "</div>"
                }
            }
            html += "</div>"
        }
        html += "<p class=\"sub\">Sent from Fulfillment Heartbeat</p></div></body></html>"
        return html
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "\u{0026}amp;")
            .replacingOccurrences(of: "<", with: "\u{0026}lt;")
            .replacingOccurrences(of: ">", with: "\u{0026}gt;")
    }

    private static func isEmail(_ value: String) -> Bool {
        value.contains("@") && value.contains(".") && !value.contains(" ")
    }

    private func checklistKey(for item: ChecklistDriverItem, section: MetricSection) -> String {
        "\(filters.division)|\(filters.district)|\(filters.om)|\(filters.store)|\(section.rawValue)|\(item.id)"
    }

    private func buildChecklistGroups(_ latest: [MetricSection: [MetricRow]]) -> [MetricSection: [ChecklistDriverGroup]] {
        var groups: [MetricSection: [ChecklistDriverGroup]] = [:]
        for section in MetricSection.dashboardCards {
            let rows = HeartbeatMath.topOpportunityStores(section: section, rows: latest[section] ?? [], limit: 10)
            let items = rows.map { row -> ChecklistDriverItem in
                let division = row.division.isEmpty ? identity(forStore: row.storeNumber).division : row.division
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
                    let division = row.division.isEmpty ? identity(forStore: row.storeNumber).division : row.division
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
    }

    func identity(forStore number: String) -> HeartbeatMath.StoreIdentity {
        roster[HeartbeatMath.canonicalStore(number)]
            ?? HeartbeatMath.StoreIdentity(division: "", district: "", om: "", name: nil)
    }

    var lastUpload: UploadRecord? {
        uploads.max(by: { $0.uploadedAt < $1.uploadedAt })
    }

    var divisions: [String] { cachedDivisions }
    var districts: [String] { cachedDistricts }
    var operationsOMs: [String] { cachedOMs }
    var stores: [(number: String, name: String?)] { cachedStores }

    func history(for section: MetricSection) -> [HistoryPoint] {
        let sectionRows = rows.filter { $0.section == section }
        return HeartbeatMath.history(
            section,
            rows: HeartbeatMath.filtered(
                sectionRows,
                filters: filters,
                relaxUnknown: false,
                universe: sectionRows + latestUniverse
            )
        )
    }

    func setDivision(_ value: String) {
        var next = DashboardFilters(region: MarketRegion.containing(value)?.rawValue ?? filters.region, division: value, district: "", om: "", store: "")
        if value.isEmpty { next.region = filters.region }
        replaceFilters(next)
    }

    func setDistrict(_ value: String) {
        var next = filters
        next.district = value
        next.om = ""
        next.store = ""
        replaceFilters(next)
    }

    func setOM(_ value: String) {
        var next = filters
        next.om = value
        next.store = ""
        replaceFilters(next)
    }

    func setStore(_ value: String) {
        var next = filters
        next.store = value
        replaceFilters(next)
    }

    func commitFilters(_ next: DashboardFilters) {
        var cleaned = next
        cleaned.sanitize()
        if filters != cleaned {
            filters = cleaned
            persistFilters()
            return
        }
        applyFilters()
    }

    func filterChoices(focus: FilterFocus, draft: DashboardFilters) -> [(id: String, label: String)] {
        func pairs(_ values: [String]) -> [(id: String, label: String)] {
            values.map { (id: $0, label: $0) }
        }
        switch focus {
        case .region:
            return MarketRegion.allCases.map { (id: $0.rawValue, label: $0.rawValue) }
        case .division:
            return pairs(MarketRegion.divisionChoices(regions: draft.regions))
        case .district:
            return pairs(
                roster.values
                    .filter { draft.includesDivision($0.division) }
                    .map { HeartbeatMath.canonicalDistrict($0.district) }
                    .filter { !$0.isEmpty }
                    .uniquedIgnoringCase()
                    .sorted()
            )
        case .om:
            return pairs(
                roster.values
                    .filter { draft.includesDivision($0.division) }
                    .filter { draft.includesDistrict($0.district) }
                    .map { HeartbeatMath.canonicalOM($0.om) }
                    .filter { value in
                        !value.isEmpty && value.rangeOfCharacter(from: .letters) != nil
                    }
                    .uniquedIgnoringCase()
                    .sorted()
            )
        case .store:
            var seen: [String: String] = [:]
            for (number, identity) in roster {
                if !draft.includesDivision(identity.division) { continue }
                if !draft.includesDistrict(identity.district) { continue }
                if !draft.includesOM(identity.om) { continue }
                if seen[number] == nil { seen[number] = identity.name ?? "" }
            }
            return seen.keys.sorted(by: HeartbeatFormat.storeOrder).map { number in
                let name = seen[number] ?? ""
                let label = name.isEmpty ? number : "\(number) · \(name)"
                return (id: number, label: label)
            }
        }
    }

    func applyLaunchRole(_ role: HeartbeatRole, region: String = "", division: String = "", district: String = "", om: String = "") {
        sessionRole = role
        var next = DashboardFilters()
        switch role {
        case .backstage:
            break
        case .evp:
            next.region = region
        case .director:
            next.division = division
            next.region = MarketRegion.containing(division)?.rawValue ?? ""
        case .districtManager:
            next.district = district
        case .om:
            next.om = om
        }
        next.sanitize()
        needsRolePick = false
        if filters != next {
            filters = next
            persistFilters()
        }
    }

    func reopenRoleGate() {
        needsRolePick = true
    }

    private func restoreSessionRole() {
        if let raw = UserDefaults.standard.string(forKey: "hb.sessionRole"),
           let role = HeartbeatRole(rawValue: raw) {
            sessionRole = role
            needsRolePick = false
        } else {
            needsRolePick = true
        }
    }

    func clearFilters() {
        refilterTask?.cancel()
        unfilteredWarmTask?.cancel()
        sessionRole = .backstage
        hydrating = true
        filters = DashboardFilters()
        hydrating = false
        persistFilters()
        unfilteredPulse = nil
        if latestBySection.isEmpty, !rows.isEmpty {
            rebuildIndex()
        }
        installCompanyWideFast()
        refreshSalesExpandCache()
        filterStamp += 1
        warmUnfilteredPulse()
    }

    func loadSampleMarket() {
        let sample = SampleMarket.rows()
        rows = sample
        uploads = MetricSection.allCases.map { section in
            UploadRecord(
                section: section,
                filename: "sample-\(section.rawValue).csv",
                rowCount: sample.filter { $0.section == section }.count
            )
        }
        seeded = true
        lastImportedSection = nil
        packDirty = true
        rebuildIndex()
        replaceFilters(DashboardFilters())
        statusMessage = "Sample market loaded — 16 Chicago-area stores."
        persist()
    }

    func flush() {
        guard !isImporting else { return }
        persist()
    }

    func inboxWorkbooks() -> [URL] {
        harvestInbox()
        let docs = documentsURL
        try? fileManager.createDirectory(at: docs, withIntermediateDirectories: true)
        let urls = (try? fileManager.contentsOfDirectory(
            at: docs,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.filter { url in
            ["xlsx", "xls", "csv"].contains(url.pathExtension.lowercased())
        }.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    func receiveExternalFile(url: URL) {
        Task {
            do {
                let file = try HeartbeatFilePicker.readPickedFile(url)
                _ = saveToDocuments(file.data, filename: file.name)
                if let section = waitingForFileSection {
                    waitingForFileSection = nil
                    await runImport(data: file.data, filename: file.name, section: section)
                } else {
                    let ok = await runMasterImport(data: file.data, filename: file.name, fallbackToPicker: true)
                    if ok {
                        rememberMasterFile(url: url, filename: file.name)
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func importPending(into section: MetricSection) {
        guard let data = pendingExternalData, let name = pendingExternalName else { return }
        pendingExternalData = nil
        pendingExternalName = nil
        importWorkbook(data: data, filename: name, section: section)
    }

    func dismissPending() {
        pendingExternalData = nil
        pendingExternalName = nil
    }

    @discardableResult
    func saveToDocuments(_ data: Data, filename: String) -> URL {
        let docs = documentsURL
        try? fileManager.createDirectory(at: docs, withIntermediateDirectories: true)
        let dest = docs.appendingPathComponent(filename)
        try? data.write(to: dest, options: [.atomic])
        return dest
    }

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func harvestInbox() {
        let inbox = documentsURL.appendingPathComponent("Inbox")
        guard fileManager.fileExists(atPath: inbox.path),
              let files = try? fileManager.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)
        else { return }
        for file in files {
            let dest = documentsURL.appendingPathComponent(file.lastPathComponent)
            try? fileManager.removeItem(at: dest)
            try? fileManager.moveItem(at: file, to: dest)
        }
    }

    func importWorkbook(url: URL, section: MetricSection) {
        Task {
            do {
                let file = try HeartbeatFilePicker.readPickedFile(url)
                await runImport(data: file.data, filename: file.name, section: section)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func importWorkbook(data: Data, filename: String, section: MetricSection) {
        _ = saveToDocuments(data, filename: filename)
        Task { await runImport(data: data, filename: filename, section: section) }
    }

    func importMasterWorkbook(data: Data, filename: String, sourceURL: URL? = nil) {
        guard !isImporting else { return }
        isImporting = true
        importLabel = "Reading master workbook…"
        importLoaded = 0
        importExpected = MetricSection.uploadOrder.count
        importMissing = []
        _ = saveToDocuments(data, filename: filename)
        Task {
            let ok = await runMasterImport(data: data, filename: filename, fallbackToPicker: false, alreadyOpen: true)
            if ok {
                rememberMasterFile(url: sourceURL, filename: filename)
            }
        }
    }

    func reloadLinkedMaster() {
        Task { await runLinkedMasterReload() }
    }

    func pullLatestWorkbookIfNeeded() {
        Task { await pullWatchedWorkbook() }
        pullCloudPackIfNeeded()
    }

    func pullCloudPackIfNeeded() {
        Task { await refreshFromCloud() }
    }

    private func refreshFromCloud() async {
        guard !isImporting else { return }
        await syncCloudPackIfChanged()
    }

    private func syncCloudPackIfChanged() async {
        let remote = await PulseCloud.objectSize(PulseCloud.object)
        let known = UserDefaults.standard.integer(forKey: "hb.cloudPackBytes")
        if remote > 50_000, remote != known {
            await importCloudSQLiteIfPresent()
        }
        await importCloudCardsIfPresent()
    }

    private func importCloudCardsIfPresent() async {
        let remote = await PulseCloud.objectSize(PulseCloud.cardsObject)
        guard remote > 50 else { return }
        let known = UserDefaults.standard.integer(forKey: "hb.cloudCardBytes")
        if known == remote, cachedPickerBoard.shopperCount > 0 { return }
        do {
            let data = try await PulseCloud.downloadCards()
            try data.write(to: cardsURL, options: .atomic)
            UserDefaults.standard.set(data.count, forKey: "hb.cloudCardBytes")
            applyLocalCards()
        } catch {
            return
        }
    }

    private func pullWorkbookFromServer() async {
        isImporting = true
        importProgress.label = "Downloading workbook"
        importLabel = "Downloading workbook"
        var lastError: String?
        for name in PulseCloud.workbookNames {
            do {
                importProgress.label = "Downloading \(name)"
                let book = try await PulseCloud.downloadNamed(name)
                guard book.count > 1_000 else { continue }
                importProgress.label = "Reading workbook"
                let ok = await runMasterImport(
                    data: book,
                    filename: name,
                    fallbackToPicker: false,
                    alreadyOpen: true,
                    presentRoleGate: true
                )
                if ok {
                    UserDefaults.standard.set(book.count, forKey: "hb.cloudXlsxBytes")
                    UserDefaults.standard.set(169, forKey: "hb.parserStamp")
                    return
                }
                lastError = "Workbook did not parse."
            } catch {
                lastError = error.localizedDescription
            }
        }
        if !Self.hasUsableLabor(rows) || !Self.hasUsablePicker(rows) {
            errorMessage = lastError ?? "Could not load Heartbeat Daily Report from the cloud."
        }
    }

    private func syncServerWorkbookIfChanged() async {
        var remoteXlsx = 0
        for name in PulseCloud.workbookNames {
            let size = await PulseCloud.objectSize(name)
            if size > 1_000 {
                remoteXlsx = size
                break
            }
        }
        let knownXlsx = UserDefaults.standard.integer(forKey: "hb.cloudXlsxBytes")
        let parserStamp = UserDefaults.standard.integer(forKey: "hb.parserStamp")
        guard remoteXlsx > 1_000, remoteXlsx != knownXlsx || parserStamp < 169 else { return }
        await importCloudWorkbook(blocking: false)
    }

    private func importCloudSQLiteIfPresent() async {
        let remote = await PulseCloud.objectSize(PulseCloud.object)
        guard remote > 50_000 else { return }
        let known = UserDefaults.standard.integer(forKey: "hb.cloudPackBytes")
        let localComplete = Self.hasUsableLabor(rows) && Self.hasUsablePicker(rows)
        if known == remote, localComplete { return }
        do {
            let data = try await PulseCloud.downloadPack()
            guard data.count > 50_000 else { return }
            let dest = sqliteURL
            try await Task.detached(priority: .userInitiated) {
                try data.write(to: dest, options: .atomic)
            }.value
            UserDefaults.standard.set(data.count, forKey: "hb.cloudPackBytes")
            await loadPack()
        } catch {
            return
        }
    }

    private func importCloudWorkbook() async {
        await importCloudWorkbook(blocking: true)
    }

    private func importCloudWorkbook(blocking: Bool) async {
        var remoteXlsx = 0
        var remoteName = "Heartbeat Daily Report.xlsx"
        for name in PulseCloud.workbookNames {
            let size = await PulseCloud.objectSize(name)
            if size > 1_000 {
                remoteXlsx = size
                remoteName = name
                break
            }
        }
        let knownXlsx = UserDefaults.standard.integer(forKey: "hb.cloudXlsxBytes")
        let hasPack = seeded && !rows.isEmpty
        let packComplete = hasPack && Self.hasUsableLabor(rows) && Self.hasUsablePicker(rows)
        guard remoteXlsx > 1_000, remoteXlsx != knownXlsx || !packComplete || UserDefaults.standard.integer(forKey: "hb.parserStamp") < 169 else {
            if hasPack {
                isImporting = false
                isReady = true
            }
            return
        }
        if !hasPack {
            isImporting = true
            isReady = false
            importLabel = "Loading the data"
            importProgress.label = "Loading the data"
            importProgress.loaded = 0
            importProgress.expected = MetricSection.uploadOrder.count
        }
        do {
            let book = try await PulseCloud.downloadNamed(remoteName)
            if blocking || !hasPack {
                importProgress.label = "Reading workbook"
            }
            let ok = await runMasterImport(
                data: book,
                filename: remoteName,
                fallbackToPicker: false,
                alreadyOpen: hasPack,
                presentRoleGate: !hasPack
            )
            if ok {
                UserDefaults.standard.set(book.count, forKey: "hb.cloudXlsxBytes")
                UserDefaults.standard.set(169, forKey: "hb.parserStamp")
                publishCloudPack()
            } else if !hasPack {
                UserDefaults.standard.removeObject(forKey: "hb.cloudXlsxBytes")
                isImporting = false
                importLabel = nil
                errorMessage = "Cloud workbook did not load."
            }
            return
        } catch {
            if !hasPack {
                isImporting = false
                importLabel = nil
                errorMessage = "Could not load Heartbeat Daily Report from the cloud."
            }
        }
    }

    private func installCloudPack(_ pack: PulseSQLite.Pack) {
        let caches = PulseCaches.build(
            rows: pack.rows,
            filters: DashboardFilters(),
            uploads: pack.uploads,
            heavy: false,
            grain: .region
        )
        rows = pack.rows
        if !pack.uploads.isEmpty {
            uploads = pack.uploads.sorted { $0.uploadedAt > $1.uploadedAt }
        }
        seeded = true
        usingDatabasePack = true
        packDirty = false
        install(caches)
        rebuildLaborWeekIndex()
        scheduleHeavyExtras(latest: caches.filteredLatest, roster: caches.roster)
    }

    private func publishCloudPack() {
        guard Self.hasUsableLabor(rows), Self.hasUsablePicker(rows) else { return }
        let url = sqliteURL
        let cardsPath = cardsURL
        let cards = PulseCards.from(board: cachedPickerBoard)
        Task.detached(priority: .utility) {
            var data = try? Data(contentsOf: url)
            if data == nil || (data?.count ?? 0) < 1_000 {
                try? await Task.sleep(nanoseconds: 800_000_000)
                data = try? Data(contentsOf: url)
            }
            guard let data, data.count > 1_000 else { return }
            try? PulseCards.write(cards, to: cardsPath)
            try await PulseCloud.uploadPack(data)
            if let cardData = try? Data(contentsOf: cardsPath) {
                try? await PulseCloud.uploadCards(cardData)
                await MainActor.run {
                    UserDefaults.standard.set(cardData.count, forKey: "hb.cloudCardBytes")
                }
            }
            await MainActor.run {
                UserDefaults.standard.set(data.count, forKey: "hb.cloudPackBytes")
            }
        }
    }

    private func pullWatchedWorkbook() async {
        guard !isImporting else { return }
        if let bookmark = masterBookmark {
            if await fileLooksNewer(bookmark: bookmark) {
                await runLinkedMasterReload(silent: true)
                return
            }
        }
        guard let dropped = newestDroppedWorkbook() else { return }
        let stamp = UserDefaults.standard.double(forKey: "hb.autoImportModified")
        let modified = (try? dropped.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate?.timeIntervalSince1970) ?? 0
        guard modified > stamp + 1 else { return }
        isImporting = true
        importLabel = "Updating from \(dropped.lastPathComponent)…"
        do {
            let file = try HeartbeatFilePicker.readPickedFile(dropped)
            UserDefaults.standard.set(modified, forKey: "hb.autoImportModified")
            _ = await runMasterImport(data: file.data, filename: file.name, fallbackToPicker: false, alreadyOpen: true, presentRoleGate: false)
        } catch {
            isImporting = false
            importLabel = nil
        }
    }

    private func fileLooksNewer(bookmark: Data) async -> Bool {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return false
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let last = linkedMasterLoadedAt ?? .distantPast
        return modified > last.addingTimeInterval(2)
    }

    private func newestDroppedWorkbook() -> URL? {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folders = [
            docs,
            docs.appendingPathComponent("Inbox", isDirectory: true),
            docs.appendingPathComponent("Heartbeat", isDirectory: true),
        ]
        var found: [(URL, Date)] = []
        for folder in folders {
            guard let items = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { continue }
            for url in items where isHeartbeatWorkbook(url) {
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                found.append((url, date))
            }
        }
        return found.max(by: { $0.1 < $1.1 })?.0
    }

    private func isHeartbeatWorkbook(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        guard name.hasSuffix(".xlsx") || name.hasSuffix(".xlsm") else { return false }
        return name.contains("heartbeat") || name.contains("daily report") || name.contains("master")
    }

    func unlinkMasterFile() {
        masterBookmark = nil
        linkedMasterName = nil
        linkedMasterLoadedAt = nil
        try? fileManager.removeItem(at: masterLinkURL)
    }

    private func runLinkedMasterReload(silent: Bool = false) async {
        guard let bookmark = masterBookmark else {
            errorMessage = "Link a shared master file first with Choose file."
            return
        }
        guard !isImporting else { return }
        isImporting = true
        importLabel = "Opening linked master file…"
        errorMessage = nil
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            importLabel = "Downloading \(linkedMasterName ?? url.lastPathComponent)…"
            let file = try HeartbeatFilePicker.readPickedFile(url)
            _ = saveToDocuments(file.data, filename: file.name)
            let ok = await runMasterImport(
                data: file.data,
                filename: file.name,
                fallbackToPicker: false,
                alreadyOpen: true,
                presentRoleGate: !silent
            )
            if ok {
                rememberMasterFile(url: url, filename: file.name)
            }
        } catch {
            isImporting = false
            importLabel = nil
            errorMessage = "Could not reach the linked file. Open it in Files so iCloud or OneDrive finishes downloading, then tap Reload — or Choose file again."
        }
    }

    private func rememberMasterFile(url: URL?, filename: String) {
        linkedMasterName = filename
        linkedMasterLoadedAt = Date()
        if let url {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                masterBookmark = data
            }
        }
        persistMasterLink()
    }

    private func loadMasterLink() {
        guard let data = try? Data(contentsOf: masterLinkURL),
              let record = try? JSONDecoder().decode(MasterLinkRecord.self, from: data)
        else { return }
        masterBookmark = record.bookmark
        linkedMasterName = record.filename
        linkedMasterLoadedAt = record.lastLoadedAt
    }

    private func persistMasterLink() {
        guard let bookmark = masterBookmark, let name = linkedMasterName else {
            try? fileManager.removeItem(at: masterLinkURL)
            return
        }
        let record = MasterLinkRecord(filename: name, bookmark: bookmark, lastLoadedAt: linkedMasterLoadedAt)
        if let data = try? JSONEncoder().encode(record) {
            try? data.write(to: masterLinkURL, options: [.atomic])
        }
    }

    private struct MasterLinkRecord: Codable {
        var filename: String
        var bookmark: Data
        var lastLoadedAt: Date?
    }

    private func runImport(data: Data, filename: String, section: MetricSection) async {
        guard !isImporting else { return }
        isImporting = true
        importLabel = "Reading \(filename)…"
        errorMessage = nil
        do {
            let incoming = try await Task.detached(priority: .userInitiated) {
                let parsed = try WorkbookParser.parse(data: data, filename: filename)
                if parsed.isEmpty { throw WorkbookParser.ParseError.empty }
                let target = WorkbookParser.classifySheet(name: filename, rows: parsed) ?? section
                return (parsed.map { $0.asRow(section: target) }, target)
            }.value
            await applyImport(incoming.0, filename: filename, section: incoming.1)
        } catch {
            errorMessage = error.localizedDescription
        }
        isImporting = false
        importLabel = nil
    }

    private func applyImport(_ incoming: [MetricRow], filename: String, section: MetricSection) async {
        lastImportedSection = section
        seeded = true
        packDirty = true
        importLabel = "Updating dashboard…"
        let currentRows = rows
        let currentUploads = uploads
        let nextRows = currentRows.filter { $0.section != section } + incoming
        var nextUploads = currentUploads.filter { $0.section != section }
        nextUploads.insert(
            UploadRecord(
                section: section,
                filename: filename,
                rowCount: incoming.count,
                validation: Self.importAudit(section: section, rows: incoming)
            ),
            at: 0
        )
        let caches = await Task.detached(priority: .userInitiated) {
            PulseCaches.build(rows: nextRows, filters: DashboardFilters(), uploads: nextUploads, heavy: false, grain: .region)
        }.value
        hydrating = true
        rows = nextRows
        uploads = nextUploads
        filters = DashboardFilters()
        install(caches)
        hydrating = false
        Task.detached(priority: .utility) {
            let heavy = PulseCaches.heavyExtras(latest: caches.filteredLatest, roster: caches.roster)
            await MainActor.run { self.mergeHeavy(heavy) }
        }
        let stores = Set(incoming.map(\.storeNumber).filter { !$0.isEmpty }).count
        if section == .pickPathPicker {
            statusMessage = "Imported \(incoming.count) pickers into Pick Path Compliance Picker. Open a store on Pick Path to see them."
        } else if section == .preSubOOSItem {
            statusMessage = "Imported \(incoming.count) item rows into Pre-Sub OOS Item. Open Pre-Sub OOS and expand Pre-Sub OOS Items under the store table."
        } else if let validation = nextUploads.first?.validation {
            statusMessage = "Imported \(section.title): \(validation)"
        } else {
            statusMessage = "Imported \(incoming.count) rows · \(stores) stores into \(section.title). Filters cleared so the new file is in view."
        }
        await persistNow()
    }

    private var masterApplyToken = 0

    private func applyMasterSheets(
        _ sheets: [WorkbookParser.ParsedSheet],
        filename: String,
        dismissOverlay: Bool,
        note: String?,
        presentRoleGate: Bool = false
    ) async {
        guard !sheets.isEmpty else { return }
        for sheet in sheets {
            let incoming = sheet.rows.map { $0.asRow(section: sheet.section) }
            rows.removeAll { $0.section == sheet.section }
            rows.append(contentsOf: incoming)
            uploads.removeAll { $0.section == sheet.section }
            uploads.insert(
                UploadRecord(
                    section: sheet.section,
                    filename: "\(filename) · \(sheet.sheetName)",
                    rowCount: incoming.count,
                    validation: incoming.count > 8_000
                        ? "\(incoming.count) rows"
                        : Self.importAudit(section: sheet.section, rows: incoming)
                ),
                at: 0
            )
        }
        masterApplyToken += 1
        let token = masterApplyToken
        let nextRows = rows
        let nextUploads = uploads
        let caches = await Task.detached(priority: .userInitiated) {
            PulseCaches.build(rows: nextRows, filters: DashboardFilters(), uploads: nextUploads, heavy: false, grain: .region)
        }.value
        guard token == masterApplyToken else { return }
        hydrating = true
        if presentRoleGate {
            filters = DashboardFilters()
            sessionRole = nil
            needsRolePick = true
        }
        rebuildLaborWeekIndex()
        install(caches)
        hydrating = false
        seeded = true
        packDirty = true
        lastImportedSection = sheets.first { $0.section == .pickerScorecard }?.section ?? sheets.first?.section
        let loadedSections = Set(uploads.map(\.section))
        let missing = MetricSection.uploadOrder.filter { !loadedSections.contains($0) }
        importMissing = missing.map(\.title)
        importLoaded = MetricSection.uploadOrder.count - missing.count
        importExpected = MetricSection.uploadOrder.count
        importProgress.missing = importMissing
        importProgress.loaded = importLoaded
        importProgress.expected = importExpected
        if let note {
            statusMessage = note
        } else if missing.isEmpty {
            statusMessage = "Loaded \(importProgress.loaded) of \(MetricSection.uploadOrder.count) scorecards."
        } else {
            statusMessage = "Loaded \(importProgress.loaded) of \(MetricSection.uploadOrder.count) scorecards. Missing: \(missing.map(\.title).joined(separator: ", "))."
        }
        if dismissOverlay {
            isImporting = false
            importLabel = nil
            isReady = true
        }
        Task { await persistNow() }
    }

    private func parseMasterOffMain(data: Data, filename: String) async throws -> [WorkbookParser.ParsedSheet] {
        try await withCheckedThrowingContinuation { continuation in
            let tick: @Sendable (Int, Int, String) -> Void = { loaded, total, name in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.importProgress.loaded = loaded
                    self.importProgress.expected = total
                    self.importProgress.label = name
                    if loaded > 0, !self.importProgress.ready.contains(name) {
                        self.importProgress.ready.append(name)
                    }
                }
            }
            let lightReady: @Sendable ([WorkbookParser.ParsedSheet]) -> Void = { _ in }
            let sheetReady: @Sendable (WorkbookParser.ParsedSheet) -> Void = { _ in }
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let sheets = try WorkbookParser.parseMaster(
                        data: data,
                        filename: filename,
                        onProgress: tick,
                        onLightReady: lightReady,
                        onSheetReady: sheetReady
                    )
                    continuation.resume(returning: sheets)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runMasterImport(data: Data, filename: String, fallbackToPicker: Bool, alreadyOpen: Bool = false, presentRoleGate: Bool = true) async -> Bool {
        do {
            let sheets = try await parseMasterOffMain(data: data, filename: filename)
            masterApplyToken += 1
            await applyMasterSheets(sheets, filename: filename, dismissOverlay: true, note: nil, presentRoleGate: presentRoleGate)
            return true
        } catch {
            if fallbackToPicker {
                pendingExternalData = data
                pendingExternalName = filename
                isImporting = false
                importLabel = nil
                return false
            }
            errorMessage = error.localizedDescription
        }
        isImporting = false
        importLabel = nil
        return false
    }

    func clearSection(_ section: MetricSection) {
        rows.removeAll { $0.section == section }
        uploads.removeAll { $0.section == section }
        if rows.isEmpty { seeded = false }
        rebuildIndex()
        applyFilters()
        persist()
    }

    func clearAll() {
        rows = []
        uploads = []
        seeded = false
        rebuildIndex()
        applyFilters()
        persist()
    }

    private var latestUniverse: [MetricRow] {
        MetricSection.allCases
            .filter { $0 != .pickerScorecard && $0 != .pickPathPicker }
            .flatMap { latestBySection[$0] ?? [] }
    }

    private func replaceFilters(_ next: DashboardFilters) {
        if filters == next {
            applyFilters()
            return
        }
        filters = next
    }

    private func rebuildIndex() {
        unfilteredPulse = nil
        unfilteredWarmTask?.cancel()
        unfilteredWarmTask = nil
        pulseGeneration += 1
        roster = PulseCaches.storeRoster(from: rows)
        var latest: [MetricSection: [MetricRow]] = [:]
        for section in MetricSection.allCases {
            let sectionRows = rows.filter { $0.section == section }
            if section == .dynacap {
                latest[section] = HeartbeatMath.materializeDynacap(sectionRows, roster: roster)
            } else if section == .pickPath {
                latest[section] = HeartbeatMath.materializePickPath(sectionRows, roster: roster)
            } else if section == .preSubOOSItem {
                latest[section] = HeartbeatMath.applyRoster(sectionRows, roster: roster)
            } else if section == .scheduleQuality || section == .fiveStar || section == .prepNotReady || section == .pph || section == .lostRevenue || section == .missingItems || section == .preSubOOS || section == .sales {
                let source = section == .lostRevenue
                    ? sectionRows.filter { $0.textPayload["lost_grain"] != "market" }
                    : sectionRows
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(source), roster: roster)
            } else if section == .labor {
                let stores = sectionRows.filter {
                    $0.textPayload["labor_grain"] != "market" && !$0.storeNumber.isEmpty
                }
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(stores), roster: roster)
            } else if section == .pickerScorecard || section == .pickPathPicker {
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerShopper(sectionRows), roster: roster)
            } else {
                latest[section] = HeartbeatMath.latestPerStore(sectionRows)
            }
        }
        if let path = latest[.pickPath] {
            latest[.pickPath] = HeartbeatMath.applyAisleMapper(path, from: latest[.aisleMapper] ?? [])
        }
        latestBySection = latest
        cachedDivisions = MarketRegion.uniqueNames(roster.values.map(\.division)).sorted()
        rebuildLaborWeekIndex()
    }

    private func applyFilters() {
        refilterTask?.cancel()
        applyVisibleFilter()
    }

    private func restoreCompanyWide() {
        let pulseOK = unfilteredPulse.map { snap in
            snap.summaries.contains { $0.storeCount > 0 || $0.headline != nil || $0.lastUploadedAt != nil }
        } ?? false
        if pulseOK, let pulse = unfilteredPulse {
            filteredLatest = pulse.filteredLatest.isEmpty ? latestBySection : pulse.filteredLatest
            cachedSummaries = pulse.summaries
            cachedCardFlags = pulse.cardFlags
            cachedPickerBoard = pulse.pickerBoard
            pickerIndex = pulse.pickerIndex
            pickerFocusHealth = pulse.pickerFocusHealth
            pickPathPickersByStore = pulse.pickPathPickersByStore
            pickPathByShopper = pulse.pickPathByShopper
            pphPickersByStore = pulse.pphPickersByStore
            rebuildCompanyGrainPacks()
            refreshSalesExpandCache()
            filterStamp += 1
            return
        }
        if latestBySection.isEmpty, !rows.isEmpty {
            rebuildIndex()
        }
        installCompanyWideFast()
        refreshSalesExpandCache()
        filterStamp += 1
        warmUnfilteredPulse()
        let grain = effectiveDashboardGrain
        let latest = latestBySection
        let hidePicker = sessionRole == .evp
        let stores = cachedStores
        let rosterCopy = roster
        Task.detached(priority: .utility) {
            let packs = PulseCaches.grainPacks(
                latest: latest,
                grain: grain,
                hidePicker: hidePicker,
                stores: stores,
                roster: rosterCopy
            )
            await MainActor.run {
                guard !self.filters.isActive else { return }
                self.cachedGrainPacks = packs
                var snap = self.snapshotPulse()
                snap.grainPacks = packs
                self.unfilteredPulse = snap
            }
        }
    }

    private func applyVisibleFilter() {
        refreshFilterOptions()
        if !filters.isActive {
            restoreCompanyWide()
            return
        }
        let allowed = PulseCaches.allowedStores(roster: roster, filters: filters)
        let latest = latestBySection
        let current = filters
        let rosterCopy = roster
        let uploadsCopy = uploads
        let grain = effectiveDashboardGrain
        let hidePicker = sessionRole == .evp
        let stores = cachedStores
        cachedGrainPacks = PulseCaches.placeholderGrainPacks(grain: grain)
        filterStamp += 1
        refilterTask = Task.detached(priority: .userInitiated) {
            var next: [MetricSection: [MetricRow]] = [:]
            next.reserveCapacity(latest.count)
            if let allowed {
                for (section, rows) in latest {
                    next[section] = rows.filter {
                        PulseCaches.rowMatchesFilter($0, allowed: allowed, roster: rosterCopy, filters: current)
                    }
                }
            } else {
                next = latest
            }
            let summaries = MetricSection.dashboardCards.map { section in
                HeartbeatMath.summarize(
                    section,
                    rows: next[section] ?? [],
                    upload: uploadsCopy.first { $0.section == section }
                )
            }
            let flags = PulseCaches.cardFlags(latest: next)
            let pickers = next[.pickerScorecard] ?? []
            let pickerBits = PulseCaches.pickerIndexValues(pickers)
            let board = HeartbeatMath.pickerBoard(pickers)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled, self.filters == current else { return }
                self.filteredLatest = next
                self.cachedSummaries = summaries
                self.cachedCardFlags = flags
                self.cachedPickerBoard = board
                self.pickerIndex = pickerBits.index
                self.pickerFocusHealth = pickerBits.health
                self.filterStamp += 1
                self.refreshSalesExpandCache()
            }
            let packs = PulseCaches.grainPacks(
                latest: next,
                grain: grain,
                hidePicker: hidePicker,
                stores: stores,
                roster: rosterCopy
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled, self.filters == current else { return }
                self.cachedGrainPacks = packs
            }
        }
    }

    private struct FilterPulse {
        var filteredLatest: [MetricSection: [MetricRow]]
        var pickerBoard: HeartbeatMath.PickerBoard
        var pickerIndex: [PickerFocus: [Int]]
        var pickerFocusHealth: [PickerFocus: Health]
        var pickPathPickersByStore: [String: [MetricRow]]
        var pickPathByShopper: [String: MetricRow]
        var pphPickersByStore: [String: [MetricRow]]
        var checklistGroups: [MetricSection: [ChecklistDriverGroup]]
        var market: [HeartbeatMath.MarketStore]
        var districts: [String]
        var oms: [String]
        var stores: [(number: String, name: String?)]
        var summaries: [SectionSummary]
        var cardFlags: [MetricSection: [HeartbeatMath.FiveStarFlag]]
        var grainPacks: [MetricSection: [DashScopePack]]
    }

    private func snapshotPulse() -> FilterPulse {
        FilterPulse(
            filteredLatest: filteredLatest,
            pickerBoard: cachedPickerBoard,
            pickerIndex: pickerIndex,
            pickerFocusHealth: pickerFocusHealth,
            pickPathPickersByStore: pickPathPickersByStore,
            pickPathByShopper: pickPathByShopper,
            pphPickersByStore: pphPickersByStore,
            checklistGroups: cachedChecklistGroups,
            market: filteredMarket,
            districts: cachedDistricts,
            oms: cachedOMs,
            stores: cachedStores,
            summaries: cachedSummaries,
            cardFlags: cachedCardFlags,
            grainPacks: cachedGrainPacks
        )
    }

    private func pulse(from caches: PulseCaches) -> FilterPulse {
        FilterPulse(
            filteredLatest: caches.filteredLatest,
            pickerBoard: caches.cachedPickerBoard,
            pickerIndex: caches.pickerIndex,
            pickerFocusHealth: caches.pickerFocusHealth,
            pickPathPickersByStore: caches.pickPathPickersByStore,
            pickPathByShopper: caches.pickPathByShopper,
            pphPickersByStore: caches.pphPickersByStore,
            checklistGroups: caches.cachedChecklistGroups,
            market: caches.filteredMarket,
            districts: caches.cachedDistricts,
            oms: caches.cachedOMs,
            stores: caches.cachedStores,
            summaries: caches.cachedSummaries,
            cardFlags: caches.cachedCardFlags,
            grainPacks: caches.cachedGrainPacks
        )
    }

    private func isCompanyWide(_ pulse: FilterPulse?) -> Bool {
        guard let pulse else { return false }
        let total = max(roster.count, 1)
        return pulse.stores.count >= min(total, max(total / 2, 8))
    }

    private func installCompanyWideFast() {
        filteredLatest = latestBySection
        refreshFilterOptions()
        cachedSummaries = MetricSection.dashboardCards.map { section in
            HeartbeatMath.summarize(
                section,
                rows: latestBySection[section] ?? [],
                upload: uploads.first { $0.section == section }
            )
        }
        cachedCardFlags = PulseCaches.cardFlags(latest: latestBySection)
        refreshSalesExpandCache()
        let pickers = latestBySection[.pickerScorecard] ?? []
        if !pickers.isEmpty {
            cachedPickerBoard = HeartbeatMath.pickerBoard(pickers)
            if (pickerIndex[.all] ?? []).isEmpty {
                pickerIndex[.all] = Array(pickers.indices)
            }
        }
        rebuildCompanyGrainPacks()
        if unfilteredPulse == nil {
            unfilteredPulse = snapshotPulse()
        }
    }

    private func rebuildCompanyGrainPacks() {
        let grain = effectiveDashboardGrain
        cachedGrainPacks = PulseCaches.placeholderGrainPacks(grain: grain)
        let latest = latestBySection
        let hidePicker = sessionRole == .evp
        let stores = cachedStores
        let rosterCopy = roster
        let token = filterStamp
        Task.detached(priority: .userInitiated) {
            let packs = PulseCaches.grainPacks(
                latest: latest,
                grain: grain,
                hidePicker: hidePicker,
                stores: stores,
                roster: rosterCopy
            )
            await MainActor.run {
                guard !self.filters.isActive else { return }
                guard self.effectiveDashboardGrain == grain else { return }
                guard self.filterStamp >= token else { return }
                self.cachedGrainPacks = packs
                var snap = self.snapshotPulse()
                snap.grainPacks = packs
                self.unfilteredPulse = snap
                self.filterStamp += 1
            }
        }
    }

    private func warmUnfilteredPulse() {
        if let pulse = unfilteredPulse, isCompanyWide(pulse) { return }
        if !filters.isActive {
            let snap = snapshotPulse()
            if isCompanyWide(snap) {
                unfilteredPulse = snap
            }
            return
        }
        guard unfilteredWarmTask == nil else { return }
        let latest = latestBySection
        let rosterCopy = roster
        let uploadsCopy = uploads
        let laborMarket = laborMarketRow()
        let lostMarket = lostRevenueMarketRow()
        let generation = pulseGeneration
        unfilteredWarmTask = Task.detached(priority: .utility) {
            let caches = PulseCaches.refilter(
                latest: latest,
                roster: rosterCopy,
                filters: DashboardFilters(),
                uploads: uploadsCopy,
                laborMarket: laborMarket,
                lostRevenueMarket: lostMarket
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.unfilteredWarmTask = nil
                guard self.pulseGeneration == generation else { return }
                let pulse = self.pulse(from: caches)
                if self.isCompanyWide(pulse) {
                    self.unfilteredPulse = pulse
                }
                if !self.filters.isActive {
                    self.refilterTask?.cancel()
                    self.install(pulse)
                    self.filterStamp += 1
                }
            }
        }
    }

    private func install(_ pulse: FilterPulse) {
        if filters.isActive {
            cachedPickerBoard = pulse.pickerBoard
            pickerIndex = pulse.pickerIndex
            pickerFocusHealth = pulse.pickerFocusHealth
            pickPathPickersByStore = pulse.pickPathPickersByStore
            pickPathByShopper = pulse.pickPathByShopper
            pphPickersByStore = pulse.pphPickersByStore
            if !pulse.checklistGroups.isEmpty {
                cachedChecklistGroups = pulse.checklistGroups
            }
            refreshChecklistOpenCount()
            objectWillChange.send()
            return
        }
        filteredLatest = pulse.filteredLatest
        cachedPickerBoard = pulse.pickerBoard
        pickerIndex = pulse.pickerIndex
        pickerFocusHealth = pulse.pickerFocusHealth
        pickPathPickersByStore = pulse.pickPathPickersByStore
        pickPathByShopper = pulse.pickPathByShopper
        pphPickersByStore = pulse.pphPickersByStore
        if !pulse.checklistGroups.isEmpty || filters.isActive {
            cachedChecklistGroups = pulse.checklistGroups
        }
        filteredMarket = pulse.market
        cachedDistricts = pulse.districts
        cachedOMs = pulse.oms
        cachedStores = pulse.stores
        cachedSummaries = pulse.summaries
        cachedCardFlags = pulse.cardFlags
        cachedGrainPacks = pulse.grainPacks
        refreshChecklistOpenCount()
        objectWillChange.send()
    }

    private func refreshFilterOptions() {
        cachedDistricts = roster.values
            .filter { filters.includesDivision($0.division) }
            .map { HeartbeatMath.canonicalDistrict($0.district) }
            .filter { !$0.isEmpty }
            .uniquedIgnoringCase()
            .sorted()
        cachedOMs = roster.values
            .filter { filters.includesDivision($0.division) }
            .filter { filters.includesDistrict($0.district) }
            .map { HeartbeatMath.canonicalOM($0.om) }
            .filter { value in
                !value.isEmpty && value.rangeOfCharacter(from: .letters) != nil
            }
            .uniquedIgnoringCase()
            .sorted()
        var seen: [String: String?] = [:]
        for (number, identity) in roster {
            if !filters.includesDivision(identity.division) { continue }
            if !filters.includesDistrict(identity.district) { continue }
            if !filters.includesOM(identity.om) { continue }
            if seen[number] == nil { seen[number] = identity.name }
        }
        cachedStores = seen.keys.sorted(by: HeartbeatFormat.storeOrder).map { ($0, seen[$0] ?? nil) }
    }

    private func pickerStoreSet() -> Set<String>? {
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

    private static let deferredSections: Set<MetricSection> = [
        .labor, .pickerScorecard, .pickPathPicker
    ]

    private func lightRows(_ rows: [MetricRow]) -> [MetricRow] {
        rows.filter { !Self.deferredSections.contains($0.section) }
    }

    private func heavyRows(_ rows: [MetricRow]) -> [MetricRow] {
        rows.filter { Self.deferredSections.contains($0.section) }
    }

    private static func hasUsableLabor(_ rows: [MetricRow]) -> Bool {
        rows.contains {
            $0.section == .labor
                && !$0.storeNumber.isEmpty
                && $0.storeNumber.uppercased() != "TOTAL"
                && $0.textPayload["labor_grain"] != "market"
        }
    }

    private static func hasUsablePicker(_ rows: [MetricRow]) -> Bool {
        let pickers = rows.filter {
            $0.section == .pickerScorecard
                && !($0.textPayload["shopper_id"] ?? $0.textPayload["shopper_name"] ?? "").isEmpty
        }
        return pickers.count >= 2_000
    }

    private func loadPack() async {
        if PulseSQLite.exists(at: sqliteURL) {
            let url = sqliteURL
            let pack = await Task.detached(priority: .userInitiated) {
                try? PulseSQLite.read(from: url)
            }.value
            if let pack, !pack.rows.isEmpty {
                importProgress.label = "Setting the aisle"
                let packRows = pack.rows
                let packUploads = pack.uploads
                let caches = await Task.detached(priority: .userInitiated) {
                    PulseCaches.build(
                        rows: packRows,
                        filters: DashboardFilters(),
                        uploads: packUploads,
                        heavy: false,
                        grain: .region
                    )
                }.value
                rows = pack.rows
                uploads = pack.uploads.sorted { $0.uploadedAt > $1.uploadedAt }
                seeded = true
                usingDatabasePack = true
                filters = DashboardFilters()
                sessionRole = nil
                needsRolePick = true
                install(caches)
                applyLocalCards()
                importProgress.loaded = MetricSection.uploadOrder.count
                scheduleHeavyExtras(latest: caches.filteredLatest, roster: caches.roster)
                return
            }
        }
        isReady = false
        rebuildIndex()
        applyFilters()
    }

    private func hydrateDeferredPack(from url: URL, uploads: [UploadRecord]) async {
        let pack = await Task.detached(priority: .utility) {
            try? PulseSQLite.read(from: url)
        }.value
        guard let pack, !pack.rows.isEmpty else { return }
        let caches = await Task.detached(priority: .utility) {
            PulseCaches.build(
                rows: pack.rows,
                filters: DashboardFilters(),
                uploads: pack.uploads,
                heavy: false,
                grain: .region
            )
        }.value
        rows = pack.rows
        self.uploads = pack.uploads.sorted { $0.uploadedAt > $1.uploadedAt }
        hydrating = true
        install(caches)
        hydrating = false
        scheduleHeavyExtras(latest: caches.filteredLatest, roster: caches.roster)
    }

    private func load() {
        Task { await loadPack() }
    }

    private func hydrate(_ decoded: HeartbeatSnapshot) {
        hydrating = true
        rows = decoded.rows
        uploads = decoded.uploads.sorted { $0.uploadedAt > $1.uploadedAt }
        seeded = decoded.seeded
        filters = decoded.filters
        hydrating = false
        rebuildIndex()
        applyFilters()
        isReady = true
    }

    private func install(_ caches: PulseCaches) {
        latestBySection = caches.latestBySection
        roster = caches.roster
        filteredLatest = caches.filteredLatest
        filteredMarket = caches.filteredMarket
        cachedDivisions = caches.cachedDivisions
        cachedDistricts = caches.cachedDistricts
        cachedOMs = caches.cachedOMs
        cachedStores = caches.cachedStores
        cachedSummaries = caches.cachedSummaries
        cachedPickerBoard = caches.cachedPickerBoard
        cachedChecklistGroups = caches.cachedChecklistGroups
        pickerIndex = caches.pickerIndex
        if (pickerIndex[.all] ?? []).isEmpty {
            let pickers = caches.filteredLatest[.pickerScorecard] ?? []
            if !pickers.isEmpty {
                pickerIndex[.all] = Array(pickers.indices)
            }
        }
        pickerFocusHealth = caches.pickerFocusHealth
        pickPathPickersByStore = caches.pickPathPickersByStore
        pickPathByShopper = caches.pickPathByShopper
        pphPickersByStore = caches.pphPickersByStore
        cachedCardFlags = caches.cachedCardFlags
        cachedGrainPacks = caches.cachedGrainPacks
        rebuildLaborWeekIndex()
        refreshChecklistOpenCount()
        refreshSalesExpandCache()
        if !filters.isActive {
            unfilteredPulse = snapshotPulse()
        }
    }

    private func scheduleHeavyExtras(
        latest: [MetricSection: [MetricRow]],
        roster: [String: HeartbeatMath.StoreIdentity]
    ) {
        Task.detached(priority: .utility) {
            let heavy = PulseCaches.heavyExtras(latest: latest, roster: roster)
            await MainActor.run { self.mergeHeavy(heavy) }
        }
    }

    private func mergeHeavy(_ bits: PulseCaches.HeavyBits) {
        if bits.pickerBoard.shopperCount > 0 {
            cachedPickerBoard = bits.pickerBoard
        }
        cachedChecklistGroups = bits.checklistGroups
        pickPathPickersByStore = bits.pickPathPickersByStore
        pickPathByShopper = bits.pickPathByShopper
        pphPickersByStore = bits.pphPickersByStore
        refreshChecklistOpenCount()
        let pickers = filteredLatest[.pickerScorecard] ?? []
        if !bits.pickerIndex.isEmpty {
            pickerIndex = bits.pickerIndex
            pickerFocusHealth = bits.pickerFocusHealth
        } else if pickerIndex[.all] == nil || pickerIndex[.all]?.isEmpty == true, !pickers.isEmpty {
            pickerIndex[.all] = Array(pickers.indices)
        }
        let count = pickers.count
        guard count > 0 else { return }
        Task.detached(priority: .utility) {
            let built = PulseCaches.pickerBuckets(pickers)
            await MainActor.run {
                guard (self.filteredLatest[.pickerScorecard] ?? []).count == count else { return }
                self.pickerIndex = built.index
                self.pickerFocusHealth = built.health
            }
        }
    }

    private func mergeHeavy(_ caches: PulseCaches) {
        mergeHeavy(PulseCaches.HeavyBits(
            pickerBoard: caches.cachedPickerBoard,
            pickerIndex: caches.pickerIndex,
            pickerFocusHealth: caches.pickerFocusHealth,
            pickPathPickersByStore: caches.pickPathPickersByStore,
            pickPathByShopper: caches.pickPathByShopper,
            pphPickersByStore: caches.pphPickersByStore,
            checklistGroups: caches.cachedChecklistGroups
        ))
    }

    private func persist() {
        persistFilters()
        guard packDirty else { return }
        Task { await persistNow() }
    }

    private func persistNow() async {
        persistFilters()
        guard packDirty else { return }
        let packURL = sqliteURL
        let packRows = rows
        let packUploads = uploads
        let packSeeded = seeded
        let incomingPicker = packRows.filter { $0.section == .pickerScorecard }.count
        let incomingLabor = packRows.filter { $0.section == .labor }.count
        let diskPicker = PulseSQLite.sectionCount(from: packURL, section: .pickerScorecard)
        let diskLabor = PulseSQLite.sectionCount(from: packURL, section: .labor)
        if incomingPicker + incomingLabor < diskPicker + diskLabor {
            packDirty = false
            return
        }
        do {
            try await Task.detached(priority: .utility) {
                try PulseSQLite.write(rows: packRows, uploads: packUploads, seeded: packSeeded, to: packURL)
            }.value
            try? PulseCards.write(PulseCards.from(board: cachedPickerBoard), to: cardsURL)
            packDirty = false
            publishCloudPack()
        } catch {
            errorMessage = "Pulse did not save: \(error.localizedDescription). Keep Heartbeat open until the import finishes."
        }
    }

    private func persistBlocking() {
        persistFilters()
    }

    private func persistFilters() {
        let current = filters
        let url = filtersURL
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(current)
                try data.write(to: url, options: [.atomic])
            } catch {}
        }
    }

    private func loadChecklist() {
        guard fileManager.fileExists(atPath: checklistURL.path),
              let data = try? Data(contentsOf: checklistURL)
        else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let file = try? decoder.decode(ChecklistFile.self, from: data) {
            checklistByKey = file.items
            checklistRecipients = file.recipients
        }
    }

    func pulseMailSnapshot() -> PulseMail.Snapshot {
        var pickerCounts: [String: Int] = [:]
        for row in displayRows(for: .pph) {
            let key = HeartbeatMath.canonicalStore(row.storeNumber)
            pickerCounts[key] = pphPickerCount(forStore: key)
        }
        var rows: [MetricSection: [MetricRow]] = [:]
        for section in PulseMail.pageOrder {
            rows[section] = displayRows(for: section)
        }
        rows[.pickPathPicker] = displayRows(for: .pickPathPicker)
        let grain = effectiveDashboardGrain.rawValue
        return PulseMail.Snapshot(
            filterSummary: filters.summary,
            grain: grain,
            summaries: summaries,
            rows: rows,
            pickerCounts: pickerCounts,
            generatedAt: Date()
        )
    }

    private func persistChecklist() {
        let file = ChecklistFile(items: checklistByKey, recipients: checklistRecipients)
        let url = checklistURL
        Task.detached(priority: .utility) {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(file)
                try data.write(to: url, options: [.atomic])
            } catch {}
        }
    }
}

private enum PulseDisk {
    static func write(_ snapshot: HeartbeatSnapshot, to url: URL) throws {
        let root = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var clean = snapshot
        clean.rows = snapshot.rows.map { row in
            var next = row
            next.payload = row.payload.filter { $0.value.isFinite }
            return next
        }
        clean.seeded = snapshot.seeded || !clean.rows.isEmpty
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        let data = try encoder.encode(clean)
        guard data.count > 20 else {
            throw NSError(domain: "Heartbeat", code: 1, userInfo: [NSLocalizedDescriptionKey: "Save produced an empty pulse file."])
        }
        try data.write(to: url, options: [.atomic, .noFileProtection])
        let verify = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard verify.count == data.count else {
            throw NSError(domain: "Heartbeat", code: 2, userInfo: [NSLocalizedDescriptionKey: "Saved pulse file did not verify."])
        }
    }

    static func read(from url: URL) throws -> HeartbeatSnapshot {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        return try decoder.decode(HeartbeatSnapshot.self, from: data)
    }
}

private struct PulseCaches {
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
            } else if section == .scheduleQuality || section == .fiveStar || section == .prepNotReady || section == .pph || section == .lostRevenue || section == .missingItems || section == .preSubOOS || section == .sales {
                let source = section == .lostRevenue
                    ? sectionRows.filter { $0.textPayload["lost_grain"] != "market" }
                    : sectionRows
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(source), roster: roster)
            } else if section == .labor {
                let stores = sectionRows.filter {
                    $0.textPayload["labor_grain"] != "market" && !$0.storeNumber.isEmpty
                }
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(stores), roster: roster)
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
                if section == .pickPathPicker {
                    nextLatest[section] = rows
                    continue
                }
                nextLatest[section] = rows.filter { row in
                    let store = HeartbeatMath.canonicalStore(row.storeNumber)
                    if !store.isEmpty, allowed.contains(store) { return true }
                    if !store.isEmpty, let identity = roster[store], !identity.division.isEmpty {
                        return false
                    }
                    if !filters.includesDivision(row.division) { return false }
                    if !filters.includesDistrict(row.district) { return false }
                    if !filters.includesOM(row.operationsOM) { return false }
                    if !filters.includesStore(store) { return false }
                    return true
                }
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
            cachedCardFlags: cardFlags(latest: nextLatest),
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

    static func cardFlags(latest: [MetricSection: [MetricRow]]) -> [MetricSection: [HeartbeatMath.FiveStarFlag]] {
        let pickers = latest[.pickerScorecard] ?? []
        let pathPickers = latest[.pickPathPicker] ?? []
        let items = latest[.preSubOOSItem] ?? []
        var out: [MetricSection: [HeartbeatMath.FiveStarFlag]] = [:]
        out.reserveCapacity(MetricSection.dashboardCards.count)
        for section in MetricSection.dashboardCards {
            out[section] = HeartbeatMath.dashboardActionFlags(
                section: section,
                rows: latest[section] ?? [],
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
        case .store: cap = max(min(stores.count, HubLayout.storeGrainCap), 12)
        default: cap = HubLayout.grainCap
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
            let shown = lines.isEmpty ? placeholderLines(grain) : lines
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
                let map = grainFlags(section: section, grain: grain, packs: packs, latest: latest)
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
        latest: [MetricSection: [MetricRow]]
    ) -> [String: [HeartbeatMath.FiveStarFlag]] {
        let rows = latest[section] ?? []
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
        let messy: Set<MetricSection> = [
            .scheduleQuality, .dynacap, .pickerScorecard, .pickPathPicker, .lostRevenue, .sales, .preSubOOS
        ]
        let primary = rows.filter { !messy.contains($0.section) }
        let fallback = rows.filter { messy.contains($0.section) }
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
        return roster
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
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == String {
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
