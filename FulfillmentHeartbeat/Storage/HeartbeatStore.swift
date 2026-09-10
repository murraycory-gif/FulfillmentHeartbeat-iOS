import Foundation
import UIKit

final class ImportProgress: ObservableObject {
    @Published var label: String?
    @Published var loaded = 0
    @Published var expected = 0
    @Published var fraction = 0.0
    @Published var ready: [String] = []
    @Published var missing: [String] = []
}

@MainActor
final class HeartbeatStore: ObservableObject {
    /// Not @Published — wave merges must not invalidate the hub while the user scrolls.
    private(set) var rows: [MetricRow]
    private(set) var uploads: [UploadRecord]
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
    @Published private(set) var warehouseHydrating = false
    @Published private(set) var sessionRole: HeartbeatRole?
    @Published var laborWeekFilter = ""
    @Published private(set) var pickerLoading = false

    private let fileManager: FileManager
    private let rootURL: URL
    private let companySQLiteURL: URL
    private var activePackURL: URL
    private var activeSeatKey: PulseSeatPack.Key?
    private var sqliteURL: URL { activePackURL }
    private let snapshotURL: URL
    private let heavyURL: URL
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
    private var lostByStore: [String: MetricRow] = [:]
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
    private var pphPickerCountByStore: [String: Int] = [:]
    private var cachedCardFlags: [MetricSection: [HeartbeatMath.FiveStarFlag]] = [:]
    private var cachedGrainPacks: [MetricSection: [DashScopePack]] = [:]
    private var cachedGrainTables: [MetricSection: [HeartbeatMath.DashboardGrainTableRow]] = [:]
    private(set) var cachedSalesScopeRows: [SalesRollupRow] = []
    private(set) var cachedSalesDayRows: [SalesRollupRow] = []
    private var laborWeeksByStore: [String: [MetricRow]] = [:]
    private var unfilteredPulse: FilterPulse?
    private var refilterTask: Task<Void, Never>?
    private var grainPaintTask: Task<Void, Never>?
    private var expandFillTask: Task<Void, Never>?
    private var pageOnlyTask: Task<Void, Never>?
    private var pickerLoadTask: Task<Void, Never>?
    private var unfilteredWarmTask: Task<Void, Never>?
    private var visibleDestination: HubDestination = .dashboard
    private var pickerStreamDone = false
    private var grainPaintSettled = false
    private var hubBecameInteractiveAt: Date?
    private var lastPickerStampCount = 0
    private var paintGeneration = 0
    private var pageOnlyGeneration = -1
    private var becameReadyAt: Date?
    private var pulseGeneration = 0
    private var masterBookmark: Data?
    private var lastCloudPullAt: Date?
    private var lifetimeObservers: [NSObjectProtocol] = []
    private var cloudHydrateStarted = false
    private var packFetchInFlight = false
    private var pendingHeavyExtras = false
    private var heavyLoadStarted = false
    private var usingPackChrome = false
    private var packChrome: PulseDashChrome?
    private var packPickerFactCount = 0
    private var factsOwned: Set<MetricSection> = []
    private var didAdoptExcelFacts = false
    private var pendingLaunchFilters: DashboardFilters?
    private var seatLoadHalloweenStartedAt: Date?

    init(rootURL: URL? = nil) {
        fileManager = .default
        let root = rootURL ?? Self.defaultRoot()
        if !fileManager.fileExists(atPath: root.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        self.rootURL = root
        companySQLiteURL = root.appendingPathComponent(PulseSQLite.fileName)
        activePackURL = companySQLiteURL
        snapshotURL = root.appendingPathComponent("heartbeat.json")
        heavyURL = root.appendingPathComponent("heartbeat-heavy.json")
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
        importProgress.label = PulseLaunch.BootPhase.openingFloor.label
        importProgress.expected = PulseLaunch.BootPhase.ready.rawValue
        importProgress.loaded = PulseLaunch.BootPhase.openingFloor.rawValue
        importProgress.fraction = PulseLaunch.BootPhase.openingFloor.fraction
        Task { await self.boot() }
        watchAppLifecycle()
    }

    private func boot() async {
        loadChecklist()
        loadMasterLink()
        loadPersistedFilters()
        restoreSessionRoleName()
        isImporting = true
        isReady = false
        errorMessage = nil
        setBootPhase(.openingFloor)
        let chrome = await loadChromeIfPresent()
        if PulseLaunch.shouldPresentSeatBeforeWarehouse(),
           PulseLaunch.shouldLeaveSplashForSeatLoad()
            || PulseLaunch.leaveSplashAfterChrome(paintedStoreCards: PulseLaunch.usablePaintedCards(cachedSummaries)) {
            presentSeatUI()
            warehouseHydrating = true
            Task { await self.finishWarehouseAfterSeat(chrome: chrome) }
            return
        }
        setBootPhase(.readingPack)
        await loadWarehousePack(chromeFirst: chrome)
        await paintFromWarehouse(light: true, adoptFacts: true)
        if canLeaveSplash() {
            finishLocalLaunch()
            Task { await self.fillAfterReady() }
            if HubLayout.ingestsWorkbook {
                Task { await self.ingestWorkbookOnMacIfNeeded() }
            }
            return
        }
        if HubLayout.ingestsWorkbook {
            importProgress.label = PulseLaunch.comedyLoadStatus(at: 4)
            await ingestWorkbookOnMacIfNeeded()
            await paintFromWarehouse(light: true, adoptFacts: true)
        } else if !PulseSQLite.isUsableFile(at: sqliteURL) {
            importProgress.label = PulseLaunch.comedyLoadStatus(at: 3)
            await importCloudSQLiteIfPresent(reason: .boot)
            await paintFromWarehouse(light: true, adoptFacts: true)
        }
        if canLeaveSplash() {
            finishLocalLaunch()
            Task { await self.fillAfterReady() }
            return
        }
        isImporting = false
        importLabel = nil
        errorMessage = PulseLaunch.missingPackMessage()
    }

    private func setBootPhase(_ phase: PulseLaunch.BootPhase) {
        importProgress.label = phase.label
        importProgress.loaded = phase.rawValue
        importProgress.expected = PulseLaunch.BootPhase.ready.rawValue
        importProgress.fraction = phase.fraction
    }

    var aisleFillCaption: String {
        if needsRolePick, warehouseHydrating {
            return PulseLaunch.seatLoadQuip(at: importProgress.loaded)
        }
        if needsRolePick {
            return PulseLaunch.displayLoadStatus(importProgress.label, tick: importProgress.loaded)
        }
        if let pending = pendingLaunchFilters, pending.isActive, warehouseHydrating {
            return "Opening \(pending.summary)"
        }
        return PulseLaunch.displayLoadStatus(importProgress.label, tick: importProgress.loaded)
    }

    var shareReady: Bool {
        PulseLaunch.shouldAllowShare(warehouseHydrating: warehouseHydrating)
    }

    private func presentSeatUI() {
        if !cachedSummaries.isEmpty {
            seeded = true
        }
        isImporting = false
        importLabel = nil
        isReady = true
        becameReadyAt = Date()
        lastCloudPullAt = Date()
        if PulseLaunch.shouldSkipRoleGateOnRelaunch(
            role: sessionRole,
            filtersActive: pendingLaunchFilters?.isActive == true
        ) {
            needsRolePick = false
            noteHubInteractive()
            startCloudHydrateIfNeeded()
        } else {
            needsRolePick = true
        }
        setBootPhase(.presentingSeat)
        if PulseLaunch.shouldPlaySeatLoadHalloween() {
            seatLoadHalloweenStartedAt = Date()
        }
    }

    /// Who's looking stays locked only while warehouse work runs. Timeout / fail must unlock.
    func unlockWarehouseAfterSeat(
        outcome: PulseLaunch.SeatWarehouseOutcome = .completed,
        error: Error? = nil
    ) {
        if PulseLaunch.seatWarehouseUnlocksHydrating(outcome) {
            warehouseHydrating = false
        }
        if PulseLaunch.seatWarehouseShowsError(outcome) {
            errorMessage = error?.localizedDescription ?? PulseLaunch.seatWarehouseTimeoutMessage()
            setBootPhase(.ready)
        }
    }

    func beginSeatWarehouseHydrating() {
        warehouseHydrating = true
        if PulseLaunch.shouldPlaySeatLoadHalloween(), seatLoadHalloweenStartedAt == nil {
            seatLoadHalloweenStartedAt = Date()
        }
    }

    private func holdSeatLoadHalloweenIfNeeded() async {
        guard PulseLaunch.shouldHoldSeatLoadHalloweenMinDwell() else { return }
        guard PulseLaunch.shouldMountSeatLoadHalloween(warehouseHydrating: warehouseHydrating) else { return }
        let elapsed = UInt64(max(0, Date().timeIntervalSince(seatLoadHalloweenStartedAt ?? Date())) * 1_000_000_000)
        let remain = PulseLaunch.halloweenDwellRemainingNanoseconds(elapsedNanoseconds: elapsed)
        if remain > 0 {
            try? await Task.sleep(nanoseconds: remain)
        }
    }

    private func finishWarehouseAfterSeat(chrome: PulseDashChrome?) async {
        let work = Task { @MainActor in
            await self.runWarehouseAfterSeat(chrome: chrome)
        }
        let timedOut = await PulseLaunch.awaitSeatWarehouseTask(
            timeoutNanoseconds: PulseLaunch.warehouseAfterSeatTimeoutNanoseconds(),
            work: work
        )
        if timedOut {
            work.cancel()
            unlockWarehouseAfterSeat(outcome: .timedOut)
            return
        }
        await holdSeatLoadHalloweenIfNeeded()
        unlockWarehouseAfterSeat(outcome: .completed)
    }

    private func runWarehouseAfterSeat(chrome: PulseDashChrome?) async {
        if PulseLaunch.shouldCheckCloudPackDuringSeatWait() {
            setBootPhase(.readingPack)
            PulseCloud.invalidateObjectList()
            if await importCloudSQLiteIfPresent(reason: .boot), warehouseRowCount > 0 {
                setBootPhase(.ready)
                Task { await self.adoptFactsThenFill() }
                if HubLayout.ingestsWorkbook {
                    Task { await self.ingestWorkbookOnMacIfNeeded() }
                }
                return
            }
        }
        if PulseLaunch.shouldPaintDashboardSectionsProgressively() {
            setBootPhase(.readingPack)
            await loadWarehouseWave(PulseLaunch.dashboardFirstWave)
            applyRestoredLaunchFiltersIfNeeded()
            setBootPhase(.buildingTables)
            await paintFromWarehouse(light: true, adoptFacts: false, urgent: true)
            setBootPhase(.paintingAisle)
            await loadWarehouseWave(PulseLaunch.dashboardSecondWave)
            await paintFromWarehouse(light: true, adoptFacts: false)
            syncWarehouseTape()
            setBootPhase(.ready)
            Task { await self.adoptFactsThenFill() }
            if HubLayout.ingestsWorkbook {
                Task { await self.ingestWorkbookOnMacIfNeeded() }
            }
            return
        }
        setBootPhase(.readingPack)
        await loadWarehousePack(chromeFirst: chrome)
        applyRestoredLaunchFiltersIfNeeded()
        setBootPhase(.paintingAisle)
        await paintFromWarehouse(light: true, adoptFacts: false)
        syncWarehouseTape()
        setBootPhase(.ready)
        Task { await self.adoptFactsThenFill() }
        if HubLayout.ingestsWorkbook {
            Task { await self.ingestWorkbookOnMacIfNeeded() }
        }
    }

    private func applyRestoredLaunchFiltersIfNeeded() {
        let decision = PulseLaunch.consumePendingLaunchFilters(
            pending: pendingLaunchFilters,
            filtersActive: filters.isActive,
            needsRolePick: needsRolePick
        )
        pendingLaunchFilters = decision.remaining
        guard let pending = decision.apply else { return }
        hydrating = true
        filters = pending
        hydrating = false
        if PulseLaunch.shouldKeepLiveCalloutsUntilFilterPaint() {
            invalidateShareGrainTables()
            cachedGrainPacks = PulseCaches.placeholderGrainPacks(grain: effectiveDashboardGrain)
        } else {
            invalidateFilteredGrainChrome()
        }
    }

    private func restoreSessionRoleName() {
        if let raw = UserDefaults.standard.string(forKey: "hb.sessionRole"),
           let role = HeartbeatRole(rawValue: raw) {
            sessionRole = role
        }
    }

    private func loadPersistedFilters() {
        guard fileManager.fileExists(atPath: filtersURL.path),
              let data = try? Data(contentsOf: filtersURL),
              let saved = try? JSONDecoder().decode(DashboardFilters.self, from: data)
        else { return }
        pendingLaunchFilters = saved
    }

    private func canLeaveSplash() -> Bool {
        PulseLaunch.leaveSplash(
            localPackBytes: PulseSQLite.fileBytes(at: sqliteURL),
            loadedRows: rows.count,
            paintedStoreCards: PulseLaunch.usablePaintedCards(cachedSummaries)
        )
    }

    private func finishLocalLaunch() {
        presentSeatUI()
        if PulseLaunch.shouldKeepHydratingThroughFinishLocalLaunch() {
            warehouseHydrating = true
        } else {
            warehouseHydrating = false
        }
        setBootPhase(.ready)
    }

    /// Facts + picker stream after the hub can scroll. Never on the wave-2 paint.
    private func adoptFactsThenFill() async {
        if !PulseLaunch.shouldAdoptFactsDuringInteractivePaint() {
            let changed = await adoptExcelFactsIntoWarehouse()
            if changed {
                await paintFromWarehouse(light: true)
            }
        }
        await fillAfterReady()
    }

    /// Splash stays local-first. Shopper warehouse stream stays join-page only.
    /// Dashboard still locks card + expand from chrome / a first pack chunk.
    private func fillAfterReady() async {
        lockPickerDashboard()
        await prefetchPickerDashboardIfNeeded()
        guard PulseLaunch.streamPickerAfterReady else { return }
        guard PulseLaunch.shouldStreamPickerOnDashboard() else { return }
        if PulseLaunch.shouldDeferPickerStreamUntilHubQuiet() {
            while needsRolePick {
                try? await Task.sleep(nanoseconds: 80_000_000)
                if Task.isCancelled { return }
            }
            noteHubInteractive()
            try? await Task.sleep(nanoseconds: PulseLaunch.hubFirstInteractionNanoseconds)
            if Task.isCancelled { return }
        }
        await streamPicker(preferSnappy: PulseLaunch.streamPickerSnappyAfterReady)
    }

    func setVisibleDestination(_ dest: HubDestination) {
        visibleDestination = dest
        if PulseLaunch.shouldDeferDestinationWorkOnNav() {
            Task { @MainActor in
                await Task.yield()
                guard self.visibleDestination == dest else { return }
                self.applyDestinationSideEffects(dest)
            }
            return
        }
        applyDestinationSideEffects(dest)
    }

    private func applyDestinationSideEffects(_ dest: HubDestination) {
        if dest != .dashboard {
            grainPaintTask?.cancel()
        } else if isReady, !needsRolePick, PulseLaunch.shouldRestartGrainPaint(alreadySettled: grainPaintSettled, dest: dest) {
            scheduleGrainPaint(generation: paintGeneration)
        }
        if PulseLaunch.needsShopperJoin(dest),
           !pickerStreamDone,
           PulseLaunch.shouldStartPickerStreamOnDestinationSwitch() {
            Task { await self.streamPicker(preferSnappy: dest == .pickerScorecard) }
        }
    }

    func retryLaunch() {
        guard !isImporting else { return }
        errorMessage = nil
        isReady = false
        isImporting = true
        warehouseHydrating = false
        importProgress.label = PulseLaunch.comedyLoadStatus(at: 1)
        Task { await boot() }
    }

    private func hydrateFromCloudInBackground() async {
        let snap = await PulseCloud.snapshot()
        await syncCloudPackIfChanged(snap)
        applyLocalCards()
        let lost = PulseQuery.scoredStoreFacts(latestBySection[.lostRevenue] ?? []).count
        let sales = PulseQuery.scoredStoreFacts(latestBySection[.sales] ?? []).count
        guard PulseLaunch.shouldLoadPublishedFacts(lostStores: lost, salesStores: sales) else { return }
        await loadPublishedFacts()
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
        HeartbeatMath.rowsFillingRoster(displayRows(for: section), roster: roster)
    }

    func marketStores() -> [HeartbeatMath.MarketStore] { filteredMarket }

    func latest(for section: MetricSection, relaxUnknown: Bool = false) -> [MetricRow] {
        rows(for: section, relaxUnknown: relaxUnknown)
    }

    func allLatest(for section: MetricSection) -> [MetricRow] {
        latestBySection[section] ?? []
    }

    func salesCompanyFact() -> MetricRow? {
        let pool = (latestBySection[.sales] ?? []) + rows.filter { $0.section == .sales }
        if let hit = pool.first(where: { $0.textPayload["sales_grain"] == "company" }) {
            return hit
        }
        return pool.first {
            HeartbeatMath.canonicalStore($0.storeNumber).isEmpty
                && HeartbeatMath.salesHeadlineDollars($0) >= 5_000_000
        }
    }

    func salesStores() -> [MetricRow] {
        SalesRollupBuilder.source(from: seatRows(for: .sales), filters: DashboardFilters(), roster: roster)
    }

    func refreshSalesExpandCache() {
        let source = salesStores()
        let grain = effectiveDashboardGrain
        cachedSalesScopeRows = SalesRollupBuilder.dashboardRows(from: source, grain: grain)
        cachedSalesDayRows = SalesRollupBuilder.dayRows(
            from: source,
            company: filters.isActive ? nil : salesCompanyFact()
        )
    }

    func rollupStores(for section: MetricSection) -> [MetricRow] {
        switch section {
        case .pickerScorecard, .pickPathPicker, .preSubOOSItem, .aisleMapper:
            let allowed = PulseCaches.allowedStores(roster: roster, filters: filters)
                ?? Set(roster.keys.map { HeartbeatMath.canonicalStore($0) })
            return (allLatest(for: section)).compactMap { row in
                let store = HeartbeatMath.canonicalStore(row.storeNumber)
                guard !store.isEmpty, HeartbeatMath.storeInAllowed(store, allowed: allowed) else { return nil }
                return HeartbeatMath.stampRoster(row, roster: roster)
            }
        default:
            return rosterJoined(for: section)
        }
    }

    func rosterJoined(for section: MetricSection) -> [MetricRow] {
        let allowed = PulseCaches.allowedStores(roster: roster, filters: filters)
            ?? Set(roster.keys.map { HeartbeatMath.canonicalStore($0) })
        var byStore: [String: MetricRow] = [:]
        let pool: [MetricRow]
        switch section {
        case .labor:
            pool = allLatest(for: .labor)
        default:
            pool = allLatest(for: section)
        }
        for row in pool {
            if section == .sales {
                let grain = row.textPayload["sales_grain"]
                if grain == "day" || grain == "company" { continue }
            }
            if section == .lostRevenue, row.textPayload["lost_grain"] == "market" { continue }
            if section == .labor, row.textPayload["labor_grain"] == "market" { continue }
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            guard HeartbeatMath.storeInAllowed(store, allowed: allowed) else { continue }
            let key = store
            if byStore[key] == nil { byStore[key] = row }
        }
        var out: [MetricRow] = []
        out.reserveCapacity(allowed.count)
        for store in allowed.sorted(by: { ($0 as NSString).localizedStandardCompare($1) == .orderedAscending }) {
            let identity = roster[store]
            if var row = byStore[store] {
                row = HeartbeatMath.stampRoster(row, roster: roster)
                out.append(row)
            } else if let identity {
                out.append(
                    MetricRow(
                        section: section,
                        division: identity.division,
                        operationsOM: identity.om,
                        storeNumber: store,
                        storeName: identity.name,
                        textPayload: identity.district.isEmpty ? [:] : ["district": identity.district]
                    )
                )
            }
        }
        return out
    }

    /// Seat pages list Heartbeat Stores N. Fact-only `displayRows` is banned under a filter.
    func seatRows(for section: MetricSection) -> [MetricRow] {
        if filters.isActive {
            return rollupStores(for: section)
        }
        return displayRows(for: section)
    }

    func displayRows(for section: MetricSection) -> [MetricRow] {
        if filters.isActive {
            return rollupStores(for: section)
        }
        if let cached = filteredLatest[section], !cached.isEmpty {
            return cached
        }
        return PulseQuery.sliceSection(
            section,
            rows: latestBySection[section] ?? [],
            allowed: PulseCaches.allowedStores(roster: roster, filters: filters),
            filters: filters,
            roster: roster
        )
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

    func dashboardGrainRows(for section: MetricSection) -> [HeartbeatMath.DashboardGrainTableRow] {
        let grain = effectiveDashboardGrain
        if section == .pickerScorecard, filters.isActive {
            if let cached = cachedGrainTables[.pickerScorecard],
               PulseLaunch.pickerExpandHasStatusBuckets(cached),
               PulseLaunch.grainMatchesSeat(cached, filters: filters, grain: grain) {
                return cached
            }
            let seat = PulseLaunch.pickerSeatRows(
                filtered: filteredLatest[.pickerScorecard] ?? [],
                warehouse: latestBySection[.pickerScorecard] ?? [],
                allowed: pickerStoreSet(),
                filters: filters,
                roster: roster
            )
            let table = PulseLaunch.pickerExpandTable(
                seatRows: seat,
                chrome: nil,
                filters: filters,
                grain: grain
            )
            if PulseLaunch.pickerExpandHasStatusBuckets(table) {
                return table
            }
        }
        if let cached = cachedGrainTables[section], HeartbeatMath.grainRowsAreLive(cached) {
            if !filters.isActive || PulseLaunch.grainTableMatchesCurrent(labels: cached.map(\.label), grain: grain) {
                if section != .pickerScorecard || PulseLaunch.pickerExpandHasStatusBuckets(cached)
                    || PulseSeatPack.shouldPaintHubFromActiveSeatSQLite() {
                    return cached
                }
            }
        }
        if filters.isActive, section != .pickerScorecard {
            return PulseLaunch.grainRowsFromSeatPacks(
                cachedGrainPacks[section] ?? [],
                section: section,
                grain: grain
            )
        }
        return []
    }

    func salesExpandRows() -> [SalesRollupRow] {
        cachedSalesScopeRows
    }

    func salesExpandIsLive() -> Bool {
        PulseLaunch.salesExpandIsLive(cachedSalesScopeRows)
    }

    /// Chevron / table gate: never open a header shell over an empty body.
    func dashboardExpandIsLive(_ section: MetricSection) -> Bool {
        PulseLaunch.dashboardExpandIsLive(
            section: section,
            salesRows: cachedSalesScopeRows,
            grainRows: dashboardGrainRows(for: section),
            pickerFacts: pickerFactCount()
        )
    }

    private func pickerFactCount() -> Int {
        let filtered = (filteredLatest[.pickerScorecard] ?? []).count
        let sliced = PulseQuery.sliceSection(
            .pickerScorecard,
            rows: latestBySection[.pickerScorecard] ?? [],
            allowed: pickerStoreSet(),
            filters: filters,
            roster: roster
        ).count
        let chrome = packChrome
        let head = Int(chrome?.card(.pickerScorecard)?.headline ?? 0)
        return PulseLaunch.pickerExpandFactCount(
            filteredCount: filtered,
            warehouseSlicedCount: sliced,
            chromeCount: max(chrome?.pickerShoppers ?? 0, head, packPickerFactCount),
            filtersActive: filters.isActive
        )
    }

    /// Fill expand caches off the tap turn. Writes cache only — no filterStamp.
    func prefetchExpand(section: MetricSection) async {
        if section == .sales {
            if PulseLaunch.salesExpandIsLive(cachedSalesScopeRows) { return }
            let source = salesStores()
            let grain = effectiveDashboardGrain
            let company = filters.isActive ? nil : salesCompanyFact()
            let built = await Task.detached(priority: .userInitiated) {
                (
                    SalesRollupBuilder.dashboardRows(from: source, grain: grain),
                    SalesRollupBuilder.dayRows(from: source, company: company)
                )
            }.value
            adoptLiveSalesExpand(built.0, days: built.1)
            return
        }
        if section == .pickerScorecard {
            if filters.isActive {
                await loadFilteredPickerExpandIfNeeded()
            } else if let chrome = packChrome {
                seedPickerGrainFromChrome(chrome)
            }
        }
        if let cached = cachedGrainTables[section],
           HeartbeatMath.grainRowsAreLive(cached),
           PulseLaunch.grainMatchesSeat(cached, filters: filters, grain: effectiveDashboardGrain) {
            return
        }
        let grain = effectiveDashboardGrain
        var source = HeartbeatMath.rowsFillingRoster(displayRows(for: section), roster: roster)
        if source.isEmpty, !filters.isActive {
            source = HeartbeatMath.rowsFillingRoster(latestBySection[section] ?? [], roster: roster)
        }
        if section == .lostRevenue {
            source = attachingCompanyLostTotal(source)
        }
        let packs = cachedGrainPacks[section] ?? []
        let order = packs.map(\.line.label)
        let goal = section == .lostRevenue ? lostRevenueGoalFallbackValue() : nil
        let table = await Task.detached(priority: .userInitiated) {
            HeartbeatMath.dashboardGrainTableFilled(
                section: section,
                rows: source,
                grain: grain,
                order: order,
                goalFallback: goal
            )
        }.value
        // Live grain only. Placeholder packs must not land in cachedGrainTables.
        if HeartbeatMath.grainRowsAreLive(table) {
            let wasLive = HeartbeatMath.grainRowsAreLive(cachedGrainTables[section] ?? [])
            cachedGrainTables[section] = table
            if !wasLive {
                acknowledgeBackgroundFill(stampIfAllowed: PulseLaunch.shouldStampHubWhenExpandCacheFills())
            }
        }
    }

    /// Cache/packs only. Expand must not walk the warehouse on the tap turn.
    func ensureDashboardExpandReady(_ section: MetricSection) {
        if PulseLaunch.shouldBuildExpandTableOffMain() { return }
        if section == .sales {
            if cachedSalesScopeRows.isEmpty { refreshSalesExpandCache() }
            return
        }
        let cached = cachedGrainTables[section] ?? []
        if section == .lostRevenue, HeartbeatMath.grainTableNeedsGoalFill(cached),
           let goal = lostRevenueGoalFallbackValue() {
            cachedGrainTables[section] = HeartbeatMath.fillingLostRevenueGoal(cached, goal: goal)
        }
        let next = cachedGrainTables[section] ?? cached
        if !HeartbeatMath.grainRowsAreLive(next) || regionExpandNeedsFill(next)
            || (section == .lostRevenue && HeartbeatMath.grainTableNeedsGoalFill(next))
            || !PulseLaunch.grainTableMatchesCurrent(labels: next.map(\.label), grain: effectiveDashboardGrain) {
            cachedGrainTables[section] = buildGrainTableNow(for: section)
        }
    }

    private func regionExpandNeedsFill(_ table: [HeartbeatMath.DashboardGrainTableRow]) -> Bool {
        guard effectiveDashboardGrain == .region, !filters.isActive else { return false }
        let live = Set(table.filter { $0.storeCount > 0 }.map(\.label))
        return MarketRegion.allCases.contains { !live.contains($0.rawValue) }
    }

    private func buildGrainTableNow(for section: MetricSection) -> [HeartbeatMath.DashboardGrainTableRow] {
        let grain = effectiveDashboardGrain
        var source = HeartbeatMath.rowsFillingRoster(displayRows(for: section), roster: roster)
        if source.isEmpty, !filters.isActive {
            source = HeartbeatMath.rowsFillingRoster(latestBySection[section] ?? [], roster: roster)
        }
        if section == .lostRevenue, source.filter({ $0.number("lost_revenue") != nil }).isEmpty {
            let facts = HeartbeatMath.rowsFillingRoster(latestOrFacts(for: .lostRevenue), roster: roster)
            source = filters.isActive
                ? PulseQuery.sliceSection(
                    .lostRevenue,
                    rows: facts,
                    allowed: pickerStoreSet(),
                    filters: filters,
                    roster: roster
                )
                : facts
        }
        if section == .dynacap, source.filter({ $0.number("dynacap_rate", "pieces_per_hour") != nil }).isEmpty {
            let raw = (latestBySection[.dynacap] ?? []) + rows.filter { $0.section == .dynacap }
            let filled = HeartbeatMath.materializeDynacap(raw, roster: roster)
            source = filters.isActive
                ? PulseQuery.sliceSection(
                    .dynacap,
                    rows: filled,
                    allowed: pickerStoreSet(),
                    filters: filters,
                    roster: roster
                )
                : filled
        }
        if section == .dynacap {
            source = HeartbeatMath.overlayStorePPH(
                source,
                from: latestBySection[.pph] ?? filteredLatest[.pph] ?? [],
                pickers: latestBySection[.pickerScorecard] ?? filteredLatest[.pickerScorecard] ?? []
            )
        }
        if grain == .region, !filters.isActive {
            source = PulseQuery.fillMissingRegions(
                existing: source,
                facts: PulseFacts.bundledMetricRows(),
                section: section
            )
            source = HeartbeatMath.rowsFillingRoster(source, roster: roster)
        }
        if section == .lostRevenue {
            source = attachingCompanyLostTotal(source)
        }
        let packs = cachedGrainPacks[section] ?? []
        let order = packs.map(\.line.label)
        let goalFallback = section == .lostRevenue ? lostRevenueGoalFallbackValue() : nil
        let table = HeartbeatMath.dashboardGrainTableFilled(
            section: section,
            rows: source,
            grain: grain,
            order: order,
            goalFallback: goalFallback
        )
        if section == .lostRevenue, let goalFallback, HeartbeatMath.grainTableNeedsGoalFill(table) {
            return HeartbeatMath.fillingLostRevenueGoal(table, goal: goalFallback)
        }
        if HeartbeatMath.grainRowsAreLive(table) { return table }
        return HeartbeatMath.dashboardGrainRowsFromPacks(packs, section: section, goalFallback: goalFallback)
    }

    private func fillExpandTablesSoon() {
        guard PulseLaunch.shouldPrefillExpandTables(filtersActive: filters.isActive) else { return }
        let grain = effectiveDashboardGrain
        var latest = filteredLatest.isEmpty ? latestBySection : filteredLatest
        if let lost = latest[.lostRevenue] {
            latest[.lostRevenue] = attachingCompanyLostTotal(lost)
        }
        let packs = cachedGrainPacks
        let rosterCopy = roster
        let goalFallback = lostRevenueGoalFallbackValue()
        let delay = grainTablePrefetchDelayNanoseconds()
        let salesRaw = latest[.sales] ?? []
        let company = filters.isActive ? nil : salesCompanyFact()
        expandFillTask?.cancel()
        expandFillTask = Task.detached(priority: .background) {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            let tables = PulseCaches.grainTables(
                latest: latest,
                grain: grain,
                roster: rosterCopy,
                packs: packs,
                goalFallback: goalFallback
            )
            let salesSource = SalesRollupBuilder.source(
                from: salesRaw,
                filters: DashboardFilters(),
                roster: rosterCopy
            )
            let salesScope = SalesRollupBuilder.dashboardRows(from: salesSource, grain: grain)
            let salesDays = SalesRollupBuilder.dayRows(from: salesSource, company: company)
            await MainActor.run {
                guard !Task.isCancelled else { return }
                guard self.effectiveDashboardGrain == grain else { return }
                self.mergeGrainTables(tables)
                if PulseLaunch.shouldPrefetchSalesExpandWithGrainTables(),
                   salesScope.count >= self.cachedSalesScopeRows.count {
                    self.adoptLiveSalesExpand(salesScope, days: salesDays)
                }
            }
        }
    }

    private func lostRevenueGoalFallbackValue() -> Double? {
        lostRevenueMarketRow().flatMap { HeartbeatMath.lostRevenueGoalPct($0) }
            ?? HeartbeatMath.lostRevenueGoalFallback(
                (latestBySection[.lostRevenue] ?? []) + (filteredLatest[.lostRevenue] ?? [])
            )
    }

    private func grainTablePrefetchDelayNanoseconds() -> UInt64 {
        guard PulseLaunch.shouldDeferGrainTablesUntilHubQuiet() else { return 0 }
        // Prefill while Who's looking is up so expand is live on the first hub frame.
        if needsRolePick { return 0 }
        let quiet = PulseLaunch.hubFirstInteractionNanoseconds
        guard let start = hubBecameInteractiveAt else { return quiet }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed >= Double(quiet) / 1_000_000_000 { return 0 }
        let remaining = Double(quiet) / 1_000_000_000 - elapsed
        return UInt64(max(0, remaining) * 1_000_000_000)
    }

    private func mergeGrainTables(_ tables: [MetricSection: [HeartbeatMath.DashboardGrainTableRow]]) {
        var changed = false
        let merged = PulseLaunch.mergeLiveGrainTables(
            incoming: tables,
            live: cachedGrainTables,
            grain: effectiveDashboardGrain,
            filtersActive: filters.isActive
        )
        for (section, rows) in merged where !rows.isEmpty {
            if !HeartbeatMath.grainRowsAreLive(rows),
               let keep = cachedGrainTables[section],
               HeartbeatMath.grainRowsAreLive(keep) {
                continue
            }
            if cachedGrainTables[section] != rows {
                cachedGrainTables[section] = rows
                changed = true
            }
        }
        if let goal = lostRevenueGoalFallbackValue(),
           HeartbeatMath.grainTableNeedsGoalFill(cachedGrainTables[.lostRevenue] ?? []) {
            cachedGrainTables[.lostRevenue] = HeartbeatMath.fillingLostRevenueGoal(
                cachedGrainTables[.lostRevenue] ?? [],
                goal: goal
            )
            changed = true
        }
        if changed, !needsRolePick {
            acknowledgeBackgroundFill(stampIfAllowed: PulseLaunch.shouldStampHubWhenExpandCacheFills())
        }
    }

    /// Write sales expand cache. `objectWillChange` only — never `filterStamp`.
    private func adoptLiveSalesExpand(_ rows: [SalesRollupRow], days: [SalesRollupRow]) {
        let wasLive = PulseLaunch.salesExpandIsLive(cachedSalesScopeRows)
        if rows.isEmpty, wasLive { return }
        if PulseLaunch.salesExpandIsLive(rows) || cachedSalesScopeRows.isEmpty {
            cachedSalesScopeRows = rows
            cachedSalesDayRows = days
        }
        if PulseLaunch.salesExpandIsLive(cachedSalesScopeRows), !wasLive {
            acknowledgeBackgroundFill(stampIfAllowed: PulseLaunch.shouldStampHubWhenExpandCacheFills())
        }
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
        let pphRows = (filteredLatest[.pph] ?? []).filter { HeartbeatMath.dashboardScopeKey($0, grain: grain) == label }
        return HeartbeatMath.dashboardActionFlags(
            section: metric,
            rows: rows,
            pickers: pickers,
            items: items,
            pphRows: pphRows,
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
        PulseCaches.grainFlags(section: section, grain: grain, packs: packs, latest: filteredLatest, roster: roster)
    }

    func dashboardScopeCount(_ grain: DashScopeGrain) -> Int {
        // Roster / placeholder packs are not an expand count. "Regions 4" with
        // an empty table was `containing(division)` while sales cache was empty.
        _ = grain
        if PulseLaunch.salesExpandIsLive(cachedSalesScopeRows) {
            return cachedSalesScopeRows.count
        }
        return 0
    }

    var effectiveDashboardGrain: DashScopeGrain {
        PulseLaunch.dashboardGrain(filters: filters, sessionRole: sessionRole)
    }

    var pickerBoard: HeartbeatMath.PickerBoard { cachedPickerBoard }

    func pphPickers(forStore store: String) -> [MetricRow] {
        let want = HeartbeatMath.canonicalStore(store)
        if want.isEmpty { return [] }
        return pphPickersByStore[want] ?? pphPickersByStore[store] ?? []
    }

    func pphPickerCount(forStore store: String) -> Int {
        PulseLaunch.pphPickerCount(store: store, counts: pphPickerCountByStore)
    }

    func pphPickerCounts() -> [String: Int] { pphPickerCountByStore }

    func pickPathPickers(forStore store: String) -> [MetricRow] {
        let want = HeartbeatMath.canonicalStore(store)
        guard !want.isEmpty else { return [] }
        if let exact = pickPathPickersByStore[want], !exact.isEmpty {
            return exact
        }
        return []
    }

    func pickPathPicker(forShopper raw: String) -> MetricRow? {
        pickPathByShopper[HeartbeatMath.canonicalShopper(raw)]
    }

    func pickerCount(for focus: PickerFocus) -> Int {
        let pickers = visiblePickers()
        if focus == .all { return pickers.count }
        if pickerIndexMatches(pickers), let indexed = pickerIndex[focus]?.count {
            return indexed
        }
        return pickers.filter { HeartbeatMath.pickerMatches($0, focus: focus) }.count
    }

    func pickerFocusHealth(for focus: PickerFocus) -> Health {
        let pickers = visiblePickers()
        guard pickerIndexMatches(pickers) else { return Health.none }
        return pickerFocusHealth[focus] ?? Health.none
    }

    func pickerPage(focus: PickerFocus, sort: PickerSort, ascending: Bool, limit: Int) -> [MetricRow] {
        let pickers = visiblePickers()
        guard !pickers.isEmpty else { return [] }
        var idxs = pickerIndexMatches(pickers)
            ? (pickerIndex[focus] ?? []).filter { pickers.indices.contains($0) }
            : []
        if idxs.isEmpty {
            if focus == .all {
                idxs = Array(pickers.indices)
            } else {
                idxs = pickers.indices.filter { HeartbeatMath.pickerMatches(pickers[$0], focus: focus) }
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

    private func visiblePickers() -> [MetricRow] {
        if let painted = filteredLatest[.pickerScorecard], !painted.isEmpty {
            return painted
        }
        return displayRows(for: .pickerScorecard)
    }

    private func pickerIndexMatches(_ pickers: [MetricRow]) -> Bool {
        PulseLaunch.pickerIndexMatchesSeat(
            visibleCount: pickers.count,
            indexedAll: (pickerIndex[.all] ?? []).count
        )
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
        installPPHPickerIndex(PulseLaunch.pphPickerIndex(scorecard))
    }

    private func installPPHPickerIndex(_ index: PulseLaunch.PPHPickerIndex) {
        pphPickersByStore = index.rows
        pphPickerCountByStore = index.counts
    }

    private func installPPHPickerIndex(fromRows rows: [String: [MetricRow]]) {
        pphPickersByStore = rows
        var counts: [String: Int] = [:]
        counts.reserveCapacity(rows.count)
        for (key, group) in rows {
            counts[key] = group.count
        }
        pphPickerCountByStore = counts
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
            return rosterJoined(for: .labor)
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
        let pool = (latestBySection[.lostRevenue] ?? []) + (filteredLatest[.lostRevenue] ?? []) + rows
        return pool.first { $0.textPayload["lost_grain"] == "market" }
    }

    /// Unfiltered company only. Seat filters must not inherit the global Total.
    private func attachingCompanyLostTotal(_ rows: [MetricRow]) -> [MetricRow] {
        guard !filters.isActive else { return rows }
        if rows.contains(where: { $0.textPayload["lost_grain"] == "market" }) { return rows }
        guard let market = lostRevenueMarketRow() else { return rows }
        return rows + [market]
    }

    private func pinUnfilteredLostRevenueHeadline() {
        guard !filters.isActive,
              let market = lostRevenueMarketRow(),
              let target = market.number("lost_revenue"),
              target > 0
        else { return }
        guard let index = cachedSummaries.firstIndex(where: { $0.section == .lostRevenue }) else { return }
        if abs((cachedSummaries[index].headline ?? 0) - target) <= 1 { return }
        cachedSummaries[index] = HeartbeatMath.summarize(
            .lostRevenue,
            rows: attachingCompanyLostTotal(filteredLatest[.lostRevenue] ?? []),
            upload: upload(for: .lostRevenue)
        )
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
            values.map { (id: $0, label: HeartbeatMath.displayGrainLabel($0)) }
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
                let name = HeartbeatMath.usableStoreName(seen[number]) ?? ""
                let label = name.isEmpty ? number : "\(number) · \(name)"
                return (id: number, label: label)
            }
        }
    }

    func suggestedSeatValues(for role: HeartbeatRole) -> [String] {
        PulseLaunch.suggestedSeatValues(role: role, pending: pendingLaunchFilters)
    }

    func applyLaunchRole(
        _ role: HeartbeatRole,
        region: String = "",
        division: String = "",
        district: String = "",
        om: String = "",
        store: String = ""
    ) {
        sessionRole = role
        UserDefaults.standard.set(role.rawValue, forKey: "hb.sessionRole")
        var next = DashboardFilters()
        switch role {
        case .backstage:
            break
        case .evp:
            next.region = region
        case .director:
            next.division = division
            let regions = DashboardFilters.parts(division).compactMap { MarketRegion.containing($0)?.rawValue }
            next.region = Set(regions).sorted().joined(separator: "\n")
        case .districtManager:
            next.district = district
        case .om:
            next.om = om
        case .store:
            next.store = store
        }
        next.sanitize()
        if PulseLaunch.shouldDiscardPendingLaunchFiltersOnRolePick() {
            pendingLaunchFilters = nil
        }
        let key = PulseSeatPack.Key.forSeat(filters: next, role: role)
        Task { @MainActor in
            await self.activateSeatPack(key, filters: next)
            self.revealHubAfterSeat()
        }
    }

    private func revealHubAfterSeat() {
        guard needsRolePick else { return }
        needsRolePick = false
        noteHubInteractive()
        if let chrome = packChrome {
            seedPickerGrainFromChrome(chrome)
            pinUnfilteredLostRevenueHeadline()
        }
        lockPickerDashboard()
        // Seat paint skipped grains while Who's looking was up. Start them now.
        scheduleGrainPaint(generation: paintGeneration)
        startCloudHydrateIfNeeded()
    }

    func finishRoleGate() {
        needsRolePick = false
        noteHubInteractive()
        let decision = PulseLaunch.consumePendingLaunchFilters(
            pending: pendingLaunchFilters,
            filtersActive: filters.isActive,
            needsRolePick: false
        )
        pendingLaunchFilters = decision.remaining
        if let pending = decision.apply {
            filters = pending
        }
        startCloudHydrateIfNeeded()
    }

    private func noteHubInteractive() {
        if hubBecameInteractiveAt == nil { hubBecameInteractiveAt = Date() }
    }

    private func startCloudHydrateIfNeeded() {
        guard !cloudHydrateStarted else { return }
        cloudHydrateStarted = true
        Task(priority: .background) {
            try? await Task.sleep(nanoseconds: PulseLaunch.cloudHydrateDelayNanoseconds)
            guard !Task.isCancelled else { return }
            await self.hydrateFromCloudInBackground()
        }
    }

    func reopenRoleGate() {
        needsRolePick = true
    }

    private func restoreSessionRole() {
        restoreSessionRoleName()
    }

    func clearFilters() {
        if PulseLaunch.shouldDiscardPendingLaunchFiltersOnClear() {
            pendingLaunchFilters = nil
        }
        Task { @MainActor in
            self.hydrating = true
            self.wipeSeatDashboardState()
            self.filters = DashboardFilters()
            self.hydrating = false
            self.persistFilters()
            await self.restoreCompanyPack()
            self.refreshFilterOptions()
        }
    }

    /// Seat grain/packs must not ride into company restore (merge kept District rows).
    private func wipeSeatDashboardState() {
        filteredLatest = [:]
        cachedGrainTables = [:]
        cachedGrainPacks = [:]
        cachedSalesScopeRows = []
        cachedSalesDayRows = []
        cachedCardFlags = [:]
        lastPickerStampCount = 0
        if PulseLaunch.shouldWipePickerIndexOnSeatClear() {
            wipePickerIndex()
        }
    }

    private func wipePickerIndex() {
        pickerIndex = [:]
        pickerFocusHealth = [:]
    }

    private func activateSeatPack(_ key: PulseSeatPack.Key, filters next: DashboardFilters) async {
        beginSeatWarehouseHydrating()
        hydrating = true
        filters = next
        persistFilters()
        hydrating = false
        await swapToSeatPack(key)
        if PulseLaunch.shouldUnlockWarehouseHydratingAfterSeat(completed: true) {
            unlockWarehouseAfterSeat(outcome: .completed)
        }
    }

    private func swapToSeatPack(_ key: PulseSeatPack.Key) async {
        if key == .company {
            await restoreCompanyPack()
            return
        }
        if !PulseSeatPack.shouldPaintHubFromActiveSeatSQLite() {
            return
        }
        if activeSeatKey == key,
           PulseSeatPack.isUsable(at: activePackURL),
           !latestBySection.isEmpty {
            if let chrome = packChrome {
                applyPreRolledSeatChrome(chrome)
            }
            filterStamp += 1
            return
        }
        let dest = PulseSeatPack.localURL(root: rootURL, key: key)
        try? fileManager.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !PulseSeatPack.isUsable(at: dest) {
            _ = await downloadSeatPack(key, to: dest)
        }
        if !PulseSeatPack.isUsable(at: dest), PulseSeatPack.shouldMaterializeMissingSeat() {
            _ = materializeSeatFromCompany(key, to: dest)
        }
        guard PulseSeatPack.isUsable(at: dest) else {
            errorMessage = PulseSeatPack.missingSeatMessage(key)
            return
        }
        if !PulseSeatPack.shouldMergeSeatWithCompanyOnSwap() {
            wipeWarehouseForPackSwap()
        }
        activeSeatKey = key
        activePackURL = dest
        guard let pack = try? PulseSQLite.read(from: dest) else { return }
        let grain = key.dashboardGrain
        let caches = PulseCaches.build(
            rows: pack.rows,
            filters: key.filters,
            uploads: pack.uploads,
            heavy: true,
            grain: grain
        )
        hydrating = true
        install(caches)
        if let chrome = pack.chrome {
            applyPreRolledSeatChrome(chrome)
        }
        hydrating = false
        usingPackChrome = pack.chrome != nil
        seeded = true
        lockPickerDashboard()
        installSeatExpandTables()
        PulseSeatPack.evictSeatCache(root: rootURL, keeping: key)
        filterStamp += 1
        objectWillChange.send()
    }

    private func restoreCompanyPack() async {
        if !PulseSeatPack.shouldMergeSeatWithCompanyOnSwap() {
            wipeWarehouseForPackSwap()
        }
        activeSeatKey = nil
        activePackURL = companySQLiteURL
        let chrome = await loadChromeIfPresent()
        if PulseSQLite.exists(at: companySQLiteURL) {
            await loadWarehouseWave(PulseLaunch.dashboardFirstWave)
            await loadWarehouseWave(PulseLaunch.dashboardSecondWave)
        }
        if let chrome {
            applyDashChrome(chrome)
        }
        await paintFromWarehouse(light: true)
        filterStamp += 1
    }

    private func wipeWarehouseForPackSwap() {
        rows = []
        latestBySection = [:]
        filteredLatest = [:]
        wipeSeatDashboardState()
        packChrome = nil
        usingPackChrome = false
        packPickerFactCount = 0
    }

    private func applyPreRolledSeatChrome(_ chrome: PulseDashChrome) {
        packChrome = chrome
        usingPackChrome = true
        if !chrome.summaries.isEmpty {
            cachedSummaries = chrome.summaries
        }
        if !chrome.flags.isEmpty {
            var next: [MetricSection: [HeartbeatMath.FiveStarFlag]] = [:]
            for (key, value) in chrome.flags {
                if let section = MetricSection(rawValue: key) {
                    next[section] = value
                }
            }
            cachedCardFlags = next
        }
        if !chrome.packs.isEmpty {
            var next: [MetricSection: [DashScopePack]] = [:]
            for (key, value) in chrome.packs {
                if let section = MetricSection(rawValue: key) {
                    next[section] = value
                }
            }
            cachedGrainPacks = next
        }
        for (key, rows) in chrome.tables {
            guard let section = MetricSection(rawValue: key) else { continue }
            if HeartbeatMath.grainRowsAreLive(rows) {
                cachedGrainTables[section] = rows
            }
        }
        if chrome.pickerShoppers > 0 {
            cachedPickerBoard = HeartbeatMath.PickerBoard(
                shopperCount: chrome.pickerShoppers,
                opportunityCount: max(chrome.pickerOpportunity, cachedPickerBoard.opportunityCount),
                strongCount: max(chrome.pickerStrong, cachedPickerBoard.strongCount),
                opportunity: cachedPickerBoard.opportunity,
                strong: cachedPickerBoard.strong
            )
        }
        lockPickerDashboard()
    }

    /// Seat pack plane: every dashboard card gets a live Stores footer + table.
    /// Sales used a one-off prefetch in .380 — that left Loss / 5 Star / Labor grey.
    private func installSeatExpandTables() {
        let grain = effectiveDashboardGrain
        let latest = filteredLatest.isEmpty ? latestBySection : filteredLatest
        let tables = PulseSeatPack.expandTables(
            latest: latest,
            roster: roster,
            grain: grain,
            packs: cachedGrainPacks
        )
        for section in MetricSection.dashboardCards {
            if let rows = tables[section], HeartbeatMath.grainRowsAreLive(rows) {
                cachedGrainTables[section] = rows
            }
        }
        refreshSalesExpandCache()
        if let picker = cachedGrainTables[.pickerScorecard],
           !PulseLaunch.pickerExpandHasStatusBuckets(picker) {
            lockPickerDashboard()
        }
    }

    @discardableResult
    private func downloadSeatPack(_ key: PulseSeatPack.Key, to dest: URL) async -> Bool {
        do {
            let staging = dest.deletingLastPathComponent()
                .appendingPathComponent("incoming-\(UUID().uuidString).sqlite")
            let size = try await PulseCloud.downloadObject(key.objectPath, to: staging)
            guard size > 1_000 else {
                try? fileManager.removeItem(at: staging)
                return false
            }
            try PulseSeatPack.atomicReplace(from: staging, to: dest)
            return PulseSeatPack.isUsable(at: dest)
        } catch {
            return false
        }
    }

    /// Kitchen only. Field iPad Release must fail instead of calling this.
    @discardableResult
    private func materializeSeatFromCompany(_ key: PulseSeatPack.Key, to dest: URL) -> Bool {
        guard PulseSeatPack.shouldMaterializeMissingSeat() else { return false }
        guard PulseSQLite.exists(at: companySQLiteURL) else { return false }
        do {
            _ = try PulseSeatPack.materialize(
                from: companySQLiteURL,
                key: key,
                roster: roster,
                uploads: uploads,
                to: dest
            )
            return PulseSeatPack.isUsable(at: dest)
        } catch {
            return false
        }
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
        guard isReady, !needsRolePick, !isImporting else { return }
        if let ready = becameReadyAt, !PulseLaunch.shouldPullCloudOnForeground(secondsSinceReady: Date().timeIntervalSince(ready)) {
            return
        }
        if let last = lastCloudPullAt, Date().timeIntervalSince(last) < 300 { return }
        lastCloudPullAt = Date()
        pullCloudPackIfNeeded()
        guard HubLayout.ingestsWorkbook else { return }
        Task { await pullWatchedWorkbook() }
        Task { await ingestWorkbookOnMacIfNeeded() }
    }

    func pullCloudPackIfNeeded() {
        Task { await refreshFromCloud() }
    }

    private func refreshFromCloud() async {
        guard !isImporting else { return }
        let snap = await PulseCloud.snapshot()
        await syncCloudPackIfChanged(snap)
    }

    private func syncCloudPackIfChanged(_ snap: [String: PulseCloud.ObjectStat]? = nil) async {
        let info: PulseCloud.ObjectStat
        if let hit = snap?[PulseCloud.object] {
            info = hit
        } else {
            let remote = await PulseCloud.objectInfo(PulseCloud.object)
            info = PulseCloud.ObjectStat(size: remote.size, updated: remote.updated)
        }
        let localBytes = PulseSQLite.fileBytes(at: companySQLiteURL)
        let knownUpdated = UserDefaults.standard.string(forKey: "hb.cloudPackUpdated") ?? ""
        if PulseLaunch.shouldFetchRemotePack(
            remoteBytes: info.size,
            localBytes: localBytes,
            localRowsLoaded: warehouseRowCount,
            remoteUpdated: info.updated,
            knownUpdated: knownUpdated
        ) {
            await importCloudSQLiteIfPresent(reason: .refresh)
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
        guard HubLayout.ingestsWorkbook else { return }
        isImporting = true
        importProgress.label = PulseLaunch.comedyLoadStatus(at: 2)
        importLabel = PulseLaunch.comedyLoadStatus(at: 2)
        var lastError: String?
        for name in PulseCloud.workbookNames {
            do {
                importProgress.label = PulseLaunch.comedyLoadStatus(at: 2)
                let book = try await PulseCloud.downloadNamed(name)
                guard book.count > 1_000 else { continue }
                importProgress.label = PulseLaunch.comedyLoadStatus(at: 5)
                let ok = await runMasterImport(
                    data: book,
                    filename: name,
                    fallbackToPicker: false,
                    alreadyOpen: true,
                    presentRoleGate: true
                )
                if ok {
                    UserDefaults.standard.set(book.count, forKey: "hb.cloudXlsxBytes")
                    UserDefaults.standard.set(180, forKey: "hb.parserStamp")
                    return
                }
                lastError = "Workbook did not parse."
            } catch {
                lastError = error.localizedDescription
            }
        }
        if !Self.hasFullScorecards(rows) {
            errorMessage = lastError ?? "Could not load Heartbeat Daily Report from the cloud."
        }
    }

    private func syncServerWorkbookIfChanged(_ snap: [String: PulseCloud.ObjectStat]? = nil) async {
    }

    private func ingestWorkbookOnMacIfNeeded() async {
        guard HubLayout.ingestsWorkbook else { return }
        await importCloudWorkbook(blocking: true)
    }

    private enum PackFetchReason {
        case boot, refresh
    }

    @discardableResult
    private func importCloudSQLiteIfPresent(reason: PackFetchReason) async -> Bool {
        guard !packFetchInFlight else { return false }
        let remote = await PulseCloud.objectInfo(PulseCloud.object)
        let localBytes = PulseSQLite.fileBytes(at: companySQLiteURL)
        let alreadyLoaded = warehouseRowCount
        let knownUpdated = UserDefaults.standard.string(forKey: "hb.cloudPackUpdated") ?? ""
        guard PulseLaunch.shouldFetchRemotePack(
            remoteBytes: remote.size,
            localBytes: localBytes,
            localRowsLoaded: alreadyLoaded,
            remoteUpdated: remote.updated,
            knownUpdated: knownUpdated
        ) else { return false }
        packFetchInFlight = true
        defer { packFetchInFlight = false }
        let staging = companySQLiteURL.deletingLastPathComponent().appendingPathComponent(PulseLaunch.stagingFileName)
        let timeout = reason == .boot ? PulseLaunch.bootDownloadTimeout : 180
        do {
            let size = try await PulseCloud.downloadPack(to: staging, timeout: timeout)
            guard PulseSQLite.isUsableFile(at: staging) else {
                try? fileManager.removeItem(at: staging)
                return false
            }
            try promoteCompanyStagingPack(staging)
            UserDefaults.standard.set(size, forKey: "hb.cloudPackBytes")
            if !remote.updated.isEmpty {
                UserDefaults.standard.set(remote.updated, forKey: "hb.cloudPackUpdated")
            } else {
                let stamp = await PulseCloud.objectInfo(PulseCloud.object)
                if !stamp.updated.isEmpty {
                    UserDefaults.standard.set(stamp.updated, forKey: "hb.cloudPackUpdated")
                }
            }
            guard PulseLaunch.reloadInSessionAfterFetch(
                constrained: HubLayout.constrained,
                localRowsLoaded: alreadyLoaded
            ) else {
                applyLocalCards()
                return true
            }
            if alreadyLoaded > 0 {
                rows = []
                latestBySection = [:]
            }
            await loadPack()
            guard seeded, warehouseRowCount > 0 else { return true }
            await paintFromWarehouse(light: true)
            if reason != .boot {
                scheduleGrainPaint(generation: paintGeneration)
            }
            return true
        } catch {
            try? fileManager.removeItem(at: staging)
            return false
        }
    }

    private func promoteCompanyStagingPack(_ staging: URL) throws {
        if fileManager.fileExists(atPath: companySQLiteURL.path) {
            _ = try fileManager.replaceItemAt(companySQLiteURL, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: companySQLiteURL)
        }
        if activeSeatKey == nil {
            activePackURL = companySQLiteURL
        }
    }

    private func importCloudWorkbook() async {
        await importCloudWorkbook(blocking: true)
    }

    private func importCloudWorkbook(blocking: Bool) async {
        guard HubLayout.ingestsWorkbook else { return }
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
        let hasPack = seeded && warehouseRowCount > 0
        guard remoteXlsx > 1_000 else { return }
        isImporting = true
        isReady = false
        importLabel = PulseLaunch.comedyLoadStatus(at: 4)
        importProgress.label = PulseLaunch.comedyLoadStatus(at: 4)
        importProgress.loaded = 0
        importProgress.expected = MetricSection.uploadOrder.count
        do {
            let book = try await PulseCloud.downloadNamed(remoteName)
            importProgress.label = PulseLaunch.comedyLoadStatus(at: 5)
            let ok = await runMasterImport(
                data: book,
                filename: remoteName,
                fallbackToPicker: false,
                alreadyOpen: hasPack,
                presentRoleGate: !hasPack
            )
            if ok {
                UserDefaults.standard.set(book.count, forKey: "hb.cloudXlsxBytes")
                UserDefaults.standard.set(180, forKey: "hb.parserStamp")
                let info = await PulseCloud.objectInfo(remoteName)
                if !info.updated.isEmpty {
                    UserDefaults.standard.set(info.updated, forKey: "hb.cloudXlsxUpdated")
                }
                publishFacts()
                publishCloudPack()
            } else if !hasPack {
                UserDefaults.standard.removeObject(forKey: "hb.cloudXlsxBytes")
                isImporting = false
                importLabel = nil
                errorMessage = "Cloud workbook did not load."
            }
        } catch {
            if !hasPack {
                isImporting = false
                importLabel = nil
                errorMessage = "Could not build Heartbeat pack from the workbook."
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
        publishFacts()
        guard Self.hasFullScorecards(rows) else { return }
        let companyURL = companySQLiteURL
        let cardsPath = cardsURL
        let cards = PulseCards.from(board: cachedPickerBoard)
        let packRows = rows
        let packUploads = uploads
        let packRoot = rootURL.appendingPathComponent("packs", isDirectory: true)
        let appRoot = rootURL
        Task.detached(priority: .utility) {
            var data = try? Data(contentsOf: companyURL)
            if data == nil || (data?.count ?? 0) < 1_000 {
                try? await Task.sleep(nanoseconds: 800_000_000)
                data = try? Data(contentsOf: companyURL)
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
            guard PulseSeatPack.shouldPublishSeatPlaneFromCook() else { return }
            do {
                let manifest = try PulseSeatPack.cookPublished(
                    rows: packRows,
                    uploads: packUploads,
                    packRoot: packRoot,
                    includeStores: PulseSeatPack.shouldCookEveryStoreSeat()
                )
                try await PulseCloud.publishSeatPacks(root: appRoot, manifest: manifest)
                await MainActor.run {
                    UserDefaults.standard.set(manifest.allEntries.count, forKey: "hb.cloudSeatPackCount")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Seat packs did not publish. \(error.localizedDescription)"
                }
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
        let week = PulseDataPolicy.weekKey(from: nextRows)
        if !week.isEmpty {
            UserDefaults.standard.set(week, forKey: "hb.dataWeek")
        }
        let caches = await Task.detached(priority: .userInitiated) {
            PulseCaches.build(rows: nextRows, filters: DashboardFilters(), uploads: nextUploads, heavy: false, grain: .region)
        }.value
        guard token == masterApplyToken else { return }
        hydrating = true
        if presentRoleGate, sessionRole == nil {
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
            publishFacts()
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
            } else if section == .storeRoster {
                latest[section] = HeartbeatMath.latestPerStore(sectionRows)
            } else if section == .pph {
                latest[section] = HeartbeatMath.materializePPH(
                    sectionRows,
                    roster: roster,
                    pickers: latest[.pickerScorecard] ?? rows.filter { $0.section == .pickerScorecard }
                )
            } else if section == .scheduleQuality || section == .fiveStar || section == .prepNotReady || section == .lostRevenue || section == .missingItems || section == .preSubOOS || section == .sales {
                let source = section == .lostRevenue
                    ? sectionRows.filter { $0.textPayload["lost_grain"] != "market" }
                    : sectionRows
                var collapsed = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(source), roster: roster)
                if section == .lostRevenue, let market = sectionRows.first(where: { $0.textPayload["lost_grain"] == "market" }) {
                    collapsed.append(market)
                }
                latest[section] = collapsed
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
        latest = HeartbeatMath.overlayDynacapPPH(latest)
        latestBySection = latest
        rebuildLostIndex()
        cachedDivisions = MarketRegion.uniqueNames(roster.values.map(\.division)).sorted()
        rebuildLaborWeekIndex()
    }

    /// Prefer the collapsed snapshot. If it has no real store rows, rebuild from raw facts.
    private func latestOrFacts(for section: MetricSection) -> [MetricRow] {
        let snapshot = latestBySection[section] ?? []
        let snapshotStores = snapshot.filter {
            !HeartbeatMath.canonicalStore($0.storeNumber).isEmpty
                && $0.textPayload["lost_grain"] != "market"
                && $0.textPayload["sales_grain"] != "company"
        }
        if snapshotStores.count >= 8 { return snapshot }
        let raw = rows.filter { $0.section == section }
        if raw.isEmpty { return snapshot }
        if section == .lostRevenue {
            let stores = raw.filter { $0.textPayload["lost_grain"] != "market" }
            return HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(stores), roster: roster)
        }
        return HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(raw), roster: roster)
    }

    private func rebuildLostIndex() {
        var map: [String: MetricRow] = [:]
        map.reserveCapacity(2200)
        func consider(_ row: MetricRow) {
            if row.textPayload["lost_grain"] == "market", HeartbeatMath.canonicalStore(row.storeNumber).isEmpty {
                return
            }
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if store.isEmpty { return }
            func keep(_ existing: MetricRow?) -> Bool {
                guard let existing else { return true }
                let old = existing.number("lost_revenue")
                let next = row.number("lost_revenue")
                if old == nil, next != nil { return true }
                if old != nil, next == nil { return false }
                return false
            }
            if keep(map[store]) { map[store] = row }
            for alias in HeartbeatMath.storeAliases(store) {
                if keep(map[alias]) { map[alias] = row }
            }
        }
        for row in rows where row.section == .lostRevenue {
            consider(row)
        }
        for row in (latestBySection[.lostRevenue] ?? []) {
            consider(row)
        }
        lostByStore = map
    }

    private func lostRevenueForStores(_ stores: Set<String>) -> [MetricRow] {
        if lostByStore.isEmpty { rebuildLostIndex() }
        var seen: Set<String> = []
        var out: [MetricRow] = []
        out.reserveCapacity(stores.count)
        for raw in stores {
            let store = HeartbeatMath.canonicalStore(raw)
            var row = lostByStore[store] ?? lostByStore[raw]
            if row == nil {
                for alias in HeartbeatMath.storeAliases(store) {
                    if let hit = lostByStore[alias] {
                        row = hit
                        break
                    }
                }
            }
            guard let row else { continue }
            let key = HeartbeatMath.canonicalStore(row.storeNumber)
            if seen.insert(key).inserted {
                out.append(HeartbeatMath.stampRoster(row, roster: roster))
            }
        }
        return out
    }

    private func scopedLostRevenue(_ allowed: Set<String>) -> [MetricRow] {
        rebuildLostIndex()
        var hits = lostRevenueForStores(allowed)
        if hits.isEmpty {
            let pool = (latestBySection[.lostRevenue] ?? []) + rows.filter { $0.section == .lostRevenue }
            hits = PulseCaches.rowsMatchingStores(pool, stores: allowed, skipMarket: true)
                .map { HeartbeatMath.stampRoster($0, roster: roster) }
        }
        if hits.isEmpty {
            hits = PulseCaches.rowsMatchingStores(
                PulseFacts.bundledLostRevenue(),
                stores: allowed,
                skipMarket: true
            ).map { HeartbeatMath.stampRoster($0, roster: roster) }
        }
        return hits
    }

    private func applyFilters() {
        refilterTask?.cancel()
        grainPaintTask?.cancel()
        pageOnlyTask?.cancel()
        expandFillTask?.cancel()
        let clearing = !filters.isActive
        if clearing {
            wipeSeatDashboardState()
            grainPaintSettled = restoreUnfilteredChrome()
            paintGeneration += 1
            pageOnlyGeneration = -1
            if PulseLaunch.shouldAcknowledgeFilterClearImmediately(previousActive: true, nextActive: false) {
                filterStamp += 1
            }
            if PulseLaunch.shouldSkipWarehousePaintOnClear(restoredCompanyWide: grainPaintSettled)
                || !PulseLaunch.shouldPaintWarehouseOnClear() {
                return
            }
            return
        }
        if PulseLaunch.shouldWipePickerIndexOnSeatApply() {
            wipePickerIndex()
        }
        if PulseLaunch.shouldKeepLiveCalloutsUntilFilterPaint() {
            invalidateShareGrainTables()
            cachedGrainPacks = PulseCaches.placeholderGrainPacks(grain: effectiveDashboardGrain)
        } else {
            invalidateFilteredGrainChrome()
        }
        if !PulseSeatPack.shouldApplySeatSliceOfMarketWarehouse() {
            let key = PulseSeatPack.Key.forSeat(filters: filters, role: sessionRole)
            grainPaintSettled = false
            paintGeneration += 1
            pageOnlyGeneration = -1
            refilterTask = Task { @MainActor in
                await self.swapToSeatPack(key)
            }
            return
        }
        applySeatSliceNow()
        grainPaintSettled = false
        paintGeneration += 1
        pageOnlyGeneration = -1
        filterStamp += 1
        let generation = paintGeneration
        let delay = PulseLaunch.filterPaintDelayNanoseconds(clearingAll: false)
        refilterTask = Task(priority: .userInitiated) {
            await Task.yield()
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
                guard self.acceptPaint(generation) else { return }
            }
            await self.paintFromWarehouse(light: true, generation: generation, filterPaint: true)
            guard self.acceptPaint(generation) else { return }
            if self.filters.isActive {
                await self.loadFilteredPickerExpandIfNeeded()
            }
            self.refreshFilterOptions()
            if PulseLaunch.shouldRefreshPickersAfterFilter(dest: self.visibleDestination) {
                if PulseLaunch.shouldRefreshPageOnly(pageVisible: self.visibleDestination == .pickerScorecard) {
                    self.schedulePageOnlyRefresh(generation: generation)
                } else if let pickers = self.latestBySection[.pickerScorecard], pickers.count >= 2 {
                    self.refreshPickerDashboard(
                        PulseQuery.sliceSection(
                            .pickerScorecard,
                            rows: pickers,
                            allowed: PulseCaches.allowedStores(roster: self.roster, filters: self.filters)
                        ),
                        stamp: true
                    )
                }
            }
            if PulseLaunch.shouldPaintGrains(
                dashboardVisible: self.visibleDestination == .dashboard,
                ready: self.isReady,
                rolePicked: !self.needsRolePick
            ) {
                self.scheduleGrainPaint(generation: generation)
            }
            self.warmUnfilteredPulse()
        }
    }

    /// Rebuild every section card + expand from the seat slice. Never chrome labels.
    private func applySeatSliceNow() {
        guard filters.isActive else { return }
        if PulseLaunch.shouldRefreshFilterOptionsOnSeatSlice() {
            refreshFilterOptions()
        }
        let allowed = PulseCaches.allowedStores(roster: roster, filters: filters)
        let grain = effectiveDashboardGrain
        var latest: [MetricSection: [MetricRow]] = [:]
        latest.reserveCapacity(MetricSection.dashboardCards.count)
        for section in MetricSection.dashboardCards {
            latest[section] = PulseQuery.sliceSection(
                section,
                rows: latestBySection[section] ?? [],
                allowed: allowed,
                filters: filters,
                roster: roster
            )
        }
        filteredLatest = latest
        cachedSummaries = MetricSection.dashboardCards.map { section in
            let card = HeartbeatMath.summarize(
                section,
                rows: latest[section] ?? [],
                upload: upload(for: section)
            )
            if let allowed, !allowed.isEmpty {
                return PulseLaunch.pinSeatStoreCount(card, seatStores: allowed.count)
            }
            return card
        }
        if PulseLaunch.shouldBuildCardFlagsOnSeatSlice() {
            cachedCardFlags = PulseCaches.cardFlags(latest: latest)
        }
        if PulseLaunch.shouldBuildGrainTablesOnSeatSlice() {
            let seatStores: [(number: String, name: String?)] = {
                if let allowed {
                    return allowed.sorted(by: HeartbeatFormat.storeOrder).map {
                        ($0, roster[HeartbeatMath.canonicalStore($0)]?.name)
                    }
                }
                return cachedStores
            }()
            let packs = PulseCaches.grainPacks(
                latest: latest,
                grain: grain,
                hidePicker: false,
                stores: seatStores,
                roster: roster
            )
            cachedGrainPacks = packs
            cachedGrainTables = PulseLaunch.mergeLiveGrainTables(
                incoming: PulseCaches.grainTables(
                    latest: latest,
                    grain: grain,
                    roster: roster,
                    packs: packs,
                    goalFallback: lostRevenueGoalFallbackValue()
                ),
                live: cachedGrainTables,
                grain: grain,
                filtersActive: true
            )
            refreshSalesExpandCache()
        }
        if PulseLaunch.shouldLockPickerDashboardOnSeatSlice() {
            lockPickerDashboard()
        }
    }

    /// Drop company-wide region tables so Share / expand cannot emit East/South/CA/West under a district filter.
    private func invalidateFilteredGrainChrome() {
        invalidateShareGrainTables()
        cachedGrainPacks = [:]
        cachedCardFlags = [:]
    }

    /// Share-unsafe tables only. Live store tables stay so a light filter paint
    /// cannot leave the chevron inert. Chrome region labels are dropped.
    private func invalidateShareGrainTables() {
        if filters.isActive {
            cachedGrainTables = PulseLaunch.mergeLiveGrainTables(
                incoming: [:],
                live: cachedGrainTables,
                grain: effectiveDashboardGrain,
                filtersActive: true
            )
        } else {
            cachedGrainTables = [:]
        }
        cachedSalesScopeRows = []
        cachedSalesDayRows = []
    }

    @discardableResult
    private func restoreUnfilteredChrome() -> Bool {
        if PulseLaunch.shouldRestoreUnfilteredPulseOnClear(hasCompanyWideCache: unfilteredPulseIsReady(unfilteredPulse)),
           let pulse = unfilteredPulse {
            install(pulse)
            let grainLabels = pulse.grainTables[.sales]?.map(\.label)
                ?? pulse.grainTables[.scheduleQuality]?.map(\.label)
                ?? pulse.grainTables.values.first(where: { !$0.isEmpty })?.map(\.label)
                ?? []
            if pulse.grainTables.values.allSatisfy(\.isEmpty)
                || !PulseLaunch.grainTableMatchesCurrent(
                    labels: grainLabels,
                    grain: PulseLaunch.unfilteredDashboardGrain()
                ) {
                applyUnfilteredGrainFromWarehouse()
            }
            return true
        }
        applyUnfilteredFromWarehouse()
        return true
    }

    private func unfilteredPulseIsReady(_ pulse: FilterPulse?) -> Bool {
        guard isCompanyWide(pulse) else { return false }
        guard let pulse else { return false }
        return pulse.grainTables.values.contains { HeartbeatMath.grainRowsAreLive($0) }
            || pulse.summaries.contains { $0.storeCount >= 8 }
    }

    private func applyUnfilteredFromWarehouse() {
        guard !latestBySection.isEmpty else { return }
        filteredLatest = latestBySection
        refreshFilterOptions()
        cachedSummaries = MetricSection.dashboardCards.map { section in
            HeartbeatMath.summarize(
                section,
                rows: latestBySection[section] ?? [],
                upload: uploads.first { $0.section == section }
            )
        }
        if let pulse = unfilteredPulse, !pulse.cardFlags.isEmpty {
            cachedCardFlags = pulse.cardFlags
        }
        applyUnfilteredGrainFromWarehouse()
    }

    private func applyUnfilteredGrainFromWarehouse() {
        if !PulseLaunch.shouldPaintWarehouseOnClear() {
            if let pulse = unfilteredPulse {
                cachedGrainPacks = PulseLaunch.mergeDashboardPacks(
                    incoming: pulse.grainPacks,
                    live: [:],
                    filtersActive: false
                )
                cachedGrainTables = PulseLaunch.mergeLiveGrainTables(
                    incoming: pulse.grainTables,
                    live: [:],
                    grain: PulseLaunch.unfilteredDashboardGrain(),
                    filtersActive: false
                )
            }
            if !filters.isActive, let chrome = packChrome {
                seedExpandTablesFromChrome(chrome)
                seedPickerGrainFromChrome(chrome)
            }
            lockPickerDashboard()
            refreshSalesExpandCache()
            return
        }
        let grain = PulseLaunch.unfilteredDashboardGrain()
        let latest = filteredLatest.isEmpty ? latestBySection : filteredLatest
        let packs = PulseCaches.grainPacks(
            latest: latest,
            grain: grain,
            hidePicker: true,
            stores: cachedStores,
            roster: roster
        )
        let tables = PulseCaches.grainTables(
            latest: latest,
            grain: grain,
            roster: roster,
            packs: packs,
            goalFallback: lostRevenueGoalFallbackValue()
        )
        cachedGrainPacks = PulseLaunch.mergeDashboardPacks(
            incoming: packs,
            live: cachedGrainPacks,
            filtersActive: false
        )
        cachedGrainTables = PulseLaunch.mergeLiveGrainTables(
            incoming: tables,
            live: cachedGrainTables,
            grain: grain,
            filtersActive: false
        )
        lockPickerDashboard()
        refreshSalesExpandCache()
    }

    private func acceptPaint(_ generation: Int) -> Bool {
        PulseLaunch.acceptPaint(
            generation: generation,
            current: paintGeneration,
            cancelled: Task.isCancelled
        )
    }

    /// Cache writes during grain / pageOnly / picker fill. Never remount the hub
    /// while the user is scrolling or switching pages.
    private func acknowledgeBackgroundFill(stampIfAllowed: Bool) {
        if stampIfAllowed {
            filterStamp += 1
            return
        }
        if PulseLaunch.shouldInvalidateHubOnBackgroundFill() {
            objectWillChange.send()
        }
    }

    /// Slice picker / item grains only after cards, and only if already in memory.
    private func schedulePageOnlyRefresh(generation: Int) {
        pageOnlyTask?.cancel()
        let warehouse = latestBySection
        let hasPageOnly = PulseQuery.pageOnlySections.contains { section in
            (warehouse[section] ?? []).count >= 2
        }
        guard hasPageOnly else { return }
        let rosterCopy = roster
        let current = filters
        pageOnlyTask = Task(priority: .utility) {
            guard self.acceptPaint(generation) else { return }
            let allowed = PulseCaches.allowedStores(roster: rosterCopy, filters: current)
            let slices = await Task.detached(priority: .utility) { () -> [MetricSection: [MetricRow]] in
                var out: [MetricSection: [MetricRow]] = [:]
                for section in PulseQuery.pageOnlySections {
                    guard let rows = warehouse[section], rows.count >= 2 else { continue }
                    out[section] = PulseQuery.sliceSection(section, rows: rows, allowed: allowed)
                }
                return out
            }.value
            guard self.acceptPaint(generation) else { return }
            guard self.filters == current else { return }
            self.mergePageOnlySlices(slices, generation: generation)
        }
    }

    private func mergePageOnlySlices(_ slices: [MetricSection: [MetricRow]], generation: Int) {
        guard !slices.isEmpty else { return }
        for (section, rows) in slices {
            filteredLatest[section] = rows
            refreshSummary(for: section, rows: rows)
            if section == .pickerScorecard, !rows.isEmpty {
                cachedPickerBoard = HeartbeatMath.pickerBoard(rows)
                schedulePickerIndex(rows)
            }
        }
        pageOnlyGeneration = generation
        acknowledgeBackgroundFill(stampIfAllowed: PulseLaunch.shouldStampGrainOrPageOnlyFill())
    }

    /// Full grain expand after cards, at utility, and only once the hub is in use.
    private func scheduleGrainPaint(generation: Int? = nil) {
        guard PulseLaunch.shouldScheduleLiveGrainPaint(filtersActive: filters.isActive) else { return }
        grainPaintTask?.cancel()
        let token = generation ?? paintGeneration
        grainPaintTask = Task(priority: .background) {
            try? await Task.sleep(nanoseconds: PulseLaunch.grainPaintDelayNanoseconds)
            guard self.acceptPaint(token) else { return }
            guard PulseLaunch.shouldPaintGrains(
                dashboardVisible: self.visibleDestination == .dashboard,
                ready: self.isReady,
                rolePicked: !self.needsRolePick
            ) else { return }
            await self.paintFromWarehouse(light: false, generation: token)
        }
    }

    private func restoreCompanyWide() {
        applyFilters()
    }

    private func applyVisibleFilter() {
        applyFilters()
    }

    @MainActor
    private func paintFromWarehouse(
        light: Bool,
        generation: Int? = nil,
        adoptFacts: Bool = false,
        urgent: Bool = false,
        filterPaint: Bool = false
    ) async {
        if adoptFacts, PulseLaunch.shouldAdoptFactsDuringInteractivePaint() || !isReady {
            await adoptExcelFactsIntoWarehouse()
        }
        let warehouse = latestBySection
        let rosterCopy = roster
        let current = filters
        let grain = effectiveDashboardGrain
        let uploadsCopy = uploads
        let scoredStores = PulseQuery.scoredStoreFacts(warehouse[.lostRevenue] ?? []).count
            + PulseQuery.scoredStoreFacts(warehouse[.sales] ?? []).count
        let needFacts = !current.isActive && !filterPaint
        let passRaw = PulseLaunch.shouldPassRawRowsToPaint(
            needFacts: needFacts,
            warehouseHasScoredStores: scoredStores >= 8
        )
        let rawRows = passRaw ? rows : []
        let pickers = warehouse[.pickerScorecard] ?? []
        let skipPrepare = filterPaint && !PulseLaunch.shouldPrepareWarehouseOnFilterPaint()
        let scopedLost: [MetricRow]? = {
            guard !skipPrepare, current.isActive,
                  let allowed = PulseCaches.allowedStores(roster: rosterCopy, filters: current) else {
                return nil
            }
            let lost = scopedLostRevenue(allowed)
            return lost.isEmpty ? nil : lost
        }()
        let dest = visibleDestination
        let includeFlags = filterPaint && PulseLaunch.shouldIncludeFlagsOnFilterPaint()
        let paintPriority = PulseLaunch.warehousePaintPriority(
            light: light,
            hubReady: isReady && !needsRolePick,
            firstSectionWave: urgent,
            filterPaint: filterPaint
        )
        let view = await Task.detached(priority: paintPriority) {
            let prepared: [MetricSection: [MetricRow]]
            if skipPrepare {
                prepared = warehouse
            } else {
                let facts = needFacts ? PulseFacts.bundledMetricRows() : []
                prepared = PulseQuery.prepareWarehouse(
                    warehouse: warehouse,
                    roster: rosterCopy,
                    filters: current,
                    rawRows: rawRows,
                    pickers: pickers,
                    bundledFacts: facts,
                    scopedLost: scopedLost
                )
            }
            return PulseQuery.paint(
                warehouse: prepared,
                roster: rosterCopy,
                filters: current,
                grain: grain,
                uploads: uploadsCopy,
                hidePicker: true,
                light: light,
                includePageOnly: current.isActive,
                includeFlags: includeFlags
            )
        }.value
        if let generation {
            guard acceptPaint(generation) else { return }
        }
        guard filters == current else { return }
        let liveSummaries = cachedSummaries
        let liveFiltered = filteredLatest
        var next = view.filtered
        next = PulseQuery.keepPageOnlyRows(painted: next, live: liveFiltered, filtersActive: current.isActive)
        next = current.isActive
            ? next
            : PulseQuery.mergeFilteredRows(painted: next, live: liveFiltered)
        filteredLatest = next
        cachedSummaries = PulseLaunch.mergeDashboardSummaries(
            painted: PulseQuery.overlayPageOnlySummaries(
                painted: view.summaries,
                live: liveSummaries,
                filtersActive: current.isActive
            ),
            live: liveSummaries,
            filtersActive: current.isActive
        )
        pinUnfilteredLostRevenueHeadline()
        if !view.flags.isEmpty {
            var flags = view.flags
            for (section, nextFlags) in flags {
                let live = nextFlags.contains {
                    $0.stores > 0 || (!$0.value.isEmpty && $0.value != "—" && $0.value != "$0" && $0.value != "$0.00")
                }
                if !live, let keep = cachedCardFlags[section], !keep.isEmpty {
                    flags[section] = keep
                }
            }
            cachedCardFlags = flags
        }
        if PulseLaunch.shouldRebuildPPHIndexDuringPaint(dest: dest),
           let livePickers = filteredLatest[.pickerScorecard], !livePickers.isEmpty {
            refreshSummary(for: .pickerScorecard, rows: livePickers)
            cachedCardFlags[.pickerScorecard] = HeartbeatMath.dashboardActionFlags(
                section: .pickerScorecard,
                rows: livePickers,
                includeAll: true
            )
            rebuildPPHPickerIndex(scorecard: livePickers)
        }
        if !light {
            var tables = view.tables
            for (section, rows) in tables {
                if !HeartbeatMath.grainRowsAreLive(rows),
                   let keep = cachedGrainTables[section],
                   HeartbeatMath.grainRowsAreLive(keep) {
                    tables[section] = keep
                }
            }
            cachedGrainPacks = PulseLaunch.mergeDashboardPacks(
                incoming: view.grains,
                live: cachedGrainPacks,
                filtersActive: current.isActive
            )
            cachedGrainTables = PulseLaunch.mergeLiveGrainTables(
                incoming: tables,
                live: cachedGrainTables,
                grain: grain,
                filtersActive: current.isActive
            )
            if let goal = lostRevenueGoalFallbackValue(),
               HeartbeatMath.grainTableNeedsGoalFill(cachedGrainTables[.lostRevenue] ?? []) {
                cachedGrainTables[.lostRevenue] = HeartbeatMath.fillingLostRevenueGoal(
                    cachedGrainTables[.lostRevenue] ?? [],
                    goal: goal
                )
            }
            grainPaintSettled = true
        } else {
            if current.isActive {
                cachedGrainTables = PulseLaunch.mergeLiveGrainTables(
                    incoming: [:],
                    live: cachedGrainTables,
                    grain: grain,
                    filtersActive: true
                )
            }
            if cachedGrainPacks.isEmpty || filterPaint {
                cachedGrainPacks = PulseLaunch.mergeDashboardPacks(
                    incoming: view.grains,
                    live: cachedGrainPacks,
                    filtersActive: current.isActive
                )
            }
        }
        lockPickerDashboard()
        usingPackChrome = false
        if lostByStore.isEmpty {
            rebuildLostIndex()
        }
        if PulseLaunch.shouldRefreshFilterOptionsOnEveryPaint() {
            refreshFilterOptions()
        }
        if !light {
            refreshSalesExpandCache()
        } else if !PulseLaunch.salesExpandIsLive(cachedSalesScopeRows) {
            // Light paint must not wait on the 1.2s grain defer. Prefill sales
            // off-main so the chevron is live before it is tappable.
            Task { await prefetchExpand(section: .sales) }
        }
        if cachedGrainTables.values.allSatisfy(\.isEmpty) || cachedSalesScopeRows.isEmpty {
            fillExpandTablesSoon()
        }
        let hasFilteredPPH = (filteredLatest[.pph] ?? []).contains { HeartbeatMath.pphNumber($0) != nil }
        if PulseLaunch.shouldPatchPPHOnPaint(hasFilteredPPH: hasFilteredPPH) {
            patchPPHCallouts()
        }
        hydrating = false
        if !filters.isActive {
            unfilteredPulse = snapshotPulse()
        }
        if needsRolePick, !PulseLaunch.shouldStampUIDuringRolePick() {
            return
        }
        acknowledgeBackgroundFill(stampIfAllowed: PulseLaunch.shouldStampGrainOrPageOnlyFill())
    }

    /// Light paint skips flag grids (pack chrome stays). .343 built a PPH chip that
    /// never replaced that chrome, so the total callout stayed blank. Always write
    /// the filtered week's Pure PPH onto the PPH card — header and equal tiles.
    private func patchPPHCallouts() {
        var rows = filteredLatest[.pph] ?? []
        let pickers = filteredLatest[.pickerScorecard] ?? latestBySection[.pickerScorecard] ?? []
        if rows.filter({ HeartbeatMath.pphNumber($0) != nil }).isEmpty {
            let filled = HeartbeatMath.materializePPH(
                latestBySection[.pph] ?? [],
                roster: roster,
                pickers: pickers
            )
            if !filled.isEmpty {
                if filters.isActive, let allowed = PulseCaches.allowedStores(roster: roster, filters: filters) {
                    rows = PulseQuery.sliceSection(
                        .pph,
                        rows: filled,
                        allowed: allowed,
                        filters: filters,
                        roster: roster
                    )
                } else {
                    rows = filled
                }
                filteredLatest[.pph] = rows
            }
        }
        cachedCardFlags[.pph] = HeartbeatMath.pphDashboardFlags(rows, pickers: pickers)
        if !rows.isEmpty {
            refreshSummary(for: .pph, rows: rows)
        }
        if !rows.isEmpty, var dyn = filteredLatest[.dynacap], !dyn.isEmpty {
            dyn = HeartbeatMath.overlayStorePPH(dyn, from: rows, pickers: pickers)
            filteredLatest[.dynacap] = dyn
            cachedCardFlags[.dynacap] = HeartbeatMath.dashboardActionFlags(
                section: .dynacap,
                rows: dyn,
                pickers: pickers,
                pphRows: rows
            )
        } else if let dyn = filteredLatest[.dynacap], !dyn.isEmpty {
            cachedCardFlags[.dynacap] = HeartbeatMath.dashboardActionFlags(
                section: .dynacap,
                rows: dyn,
                pickers: pickers,
                pphRows: rows
            )
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
        var grainTables: [MetricSection: [HeartbeatMath.DashboardGrainTableRow]]
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
            grainPacks: cachedGrainPacks,
            grainTables: cachedGrainTables
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
            grainPacks: caches.cachedGrainPacks,
            grainTables: [:]
        )
    }

    private func isCompanyWide(_ pulse: FilterPulse?) -> Bool {
        guard let pulse else { return false }
        let total = max(roster.count, 1)
        return pulse.stores.count >= min(total, max(total / 2, 8))
    }

    private func installCompanyWideFast() {
        if restorePackChrome() { return }
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
        if !usingPackChrome {
            cachedGrainPacks = PulseCaches.placeholderGrainPacks(grain: effectiveDashboardGrain)
        }
        if unfilteredPulse == nil {
            unfilteredPulse = snapshotPulse()
        }
        Task { await paintFromWarehouse(light: true) }
    }

    private func rebuildCompanyGrainPacks() {
        let grain = effectiveDashboardGrain
        let latest = latestBySection
        let hidePicker = true
        let stores = cachedStores
        let rosterCopy = roster
        let token = filterStamp
        Task.detached(priority: .utility) {
            let packs = PulseCaches.grainPacks(
                latest: latest,
                grain: grain,
                hidePicker: hidePicker,
                stores: stores,
                roster: rosterCopy
            )
            let tables = PulseCaches.grainTables(
                latest: latest,
                grain: grain,
                roster: rosterCopy,
                packs: packs,
                goalFallback: HeartbeatMath.lostRevenueGoalFallback(latest[.lostRevenue] ?? [])
            )
            await MainActor.run {
                guard !self.filters.isActive else { return }
                guard self.effectiveDashboardGrain == grain else { return }
                guard self.filterStamp >= token else { return }
                self.cachedGrainPacks = PulseLaunch.mergeDashboardPacks(
                    incoming: packs,
                    live: self.cachedGrainPacks,
                    filtersActive: false
                )
                self.cachedGrainTables = PulseLaunch.mergeLiveGrainTables(
                    incoming: tables,
                    live: self.cachedGrainTables,
                    grain: PulseLaunch.unfilteredDashboardGrain(),
                    filtersActive: false
                )
                self.lockPickerDashboard()
                var snap = self.snapshotPulse()
                snap.grainPacks = packs
                self.unfilteredPulse = snap
                if !self.needsRolePick {
                    self.acknowledgeBackgroundFill(stampIfAllowed: PulseLaunch.shouldStampGrainOrPageOnlyFill())
                }
            }
        }
    }

    private func warmUnfilteredPulse() {
        if unfilteredPulseIsReady(unfilteredPulse) { return }
        if !filters.isActive {
            let snap = snapshotPulse()
            if unfilteredPulseIsReady(snap) {
                unfilteredPulse = snap
                return
            }
        }
        guard unfilteredWarmTask == nil else { return }
        let latest = latestBySection
        let rosterCopy = roster
        let uploadsCopy = uploads
        let laborMarket = laborMarketRow()
        let lostMarket = lostRevenueMarketRow()
        let grain = PulseLaunch.unfilteredDashboardGrain()
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
            let packs = PulseCaches.grainPacks(
                latest: caches.filteredLatest,
                grain: grain,
                hidePicker: true,
                stores: caches.cachedStores,
                roster: rosterCopy
            )
            let tables = PulseCaches.grainTables(
                latest: caches.filteredLatest,
                grain: grain,
                roster: rosterCopy,
                packs: packs,
                goalFallback: HeartbeatMath.lostRevenueGoalFallback(caches.filteredLatest[.lostRevenue] ?? [])
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.unfilteredWarmTask = nil
                guard self.pulseGeneration == generation else { return }
                if self.unfilteredPulseIsReady(self.unfilteredPulse) { return }
                var pulse = self.pulse(from: caches)
                pulse.grainPacks = packs
                pulse.grainTables = tables
                if self.isCompanyWide(pulse) {
                    self.unfilteredPulse = pulse
                }
            }
        }
    }

    private func install(_ pulse: FilterPulse) {
        if filters.isActive {
            if !PulseLaunch.shouldRejectCompanyPickerIndexUnderSeat() {
                cachedPickerBoard = pulse.pickerBoard
                pickerIndex = pulse.pickerIndex
                pickerFocusHealth = pulse.pickerFocusHealth
            }
            pickPathPickersByStore = pulse.pickPathPickersByStore
            pickPathByShopper = pulse.pickPathByShopper
            installPPHPickerIndex(fromRows: pulse.pphPickersByStore)
            if !pulse.checklistGroups.isEmpty {
                cachedChecklistGroups = pulse.checklistGroups
            }
            refreshChecklistOpenCount()
            return
        }
        filteredLatest = pulse.filteredLatest
        cachedPickerBoard = pulse.pickerBoard
        pickerIndex = pulse.pickerIndex
        pickerFocusHealth = pulse.pickerFocusHealth
        pickPathPickersByStore = pulse.pickPathPickersByStore
        pickPathByShopper = pulse.pickPathByShopper
        installPPHPickerIndex(fromRows: pulse.pphPickersByStore)
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
        if pulse.grainTables.isEmpty {
            applyUnfilteredGrainFromWarehouse()
        } else {
            cachedGrainTables = pulse.grainTables
        }
        if let chrome = packChrome {
            seedPickerGrainFromChrome(chrome)
        }
        refreshChecklistOpenCount()
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
            if !filters.includesStore(number) { continue }
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
        .pickerScorecard, .pickPathPicker
    ]

    private static var launchSkip: Set<MetricSection> {
        deferredSections
    }

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

    private static func hasUsableLostRevenue(_ rows: [MetricRow]) -> Bool {
        var dollars = 0.0
        var stores = Set<String>()
        for row in rows where row.section == .lostRevenue {
            if row.textPayload["lost_grain"] == "market" {
                dollars = max(dollars, row.number("lost_revenue") ?? 0)
                continue
            }
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            stores.insert(store)
            dollars += row.number("lost_revenue") ?? 0
        }
        return stores.count >= 200 && dollars >= 1_000_000
    }

    private static func hasUsableSales(_ rows: [MetricRow]) -> Bool {
        var dollars = 0.0
        var stores = Set<String>()
        for row in rows where row.section == .sales {
            if row.textPayload["sales_grain"] == "company" {
                dollars = max(dollars, HeartbeatMath.salesHeadlineDollars(row))
                continue
            }
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            if row.textPayload["sales_grain"] == "day" { continue }
            stores.insert(store)
            dollars += HeartbeatMath.salesHeadlineDollars(row)
        }
        return stores.count >= 200 && dollars >= 5_000_000
    }

    private static func salesDayCount(_ rows: [MetricRow]) -> Int {
        var seen: Set<Int> = []
        for row in rows where row.section == .sales {
            for index in 0..<7 {
                if (row.number("sales_d\(index)_dollars") ?? 0) > 0 {
                    seen.insert(index)
                }
            }
            if seen.count == 7 { break }
        }
        return seen.count
    }

    private static func hasWeekSalesDays(_ rows: [MetricRow]) -> Bool {
        salesDayCount(rows) >= 2
    }

    private static func hasUsableFiveStar(_ rows: [MetricRow]) -> Bool {
        var stores = Set<String>()
        for row in rows where row.section == .fiveStar {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if store.isEmpty { continue }
            stores.insert(store)
            if stores.count >= 200 { return true }
        }
        return false
    }

    private static func hasFullScorecards(_ rows: [MetricRow]) -> Bool {
        hasUsableLabor(rows)
            && hasUsablePicker(rows)
            && hasUsableLostRevenue(rows)
            && hasUsableSales(rows)
            && hasUsableFiveStar(rows)
    }

    private func loadPublishedFacts() async {
        importProgress.label = PulseLaunch.comedyLoadStatus(at: 2)
        let incoming: [MetricRow] = await Task.detached(priority: .background) {
            await PulseFacts.loadRows()
        }.value
        guard !incoming.isEmpty else { return }
        rows = PulseDataPolicy.applyIdentity(existing: rows, identity: incoming)
        rows = PulseDataPolicy.fillMissing(existing: rows, facts: incoming)
        seeded = true
        let changed = adoptFactRows(incoming, mode: .takeIfRicher)
        guard changed else { return }
        lostByStore = [:]
        rebuildLostIndex()
        applyFilters()
    }

    private func publishFacts() {
        let file = PulseFacts.build(rows: rows, roster: roster)
        let scored = file.lostRevenue.filter { !$0.store.isEmpty && ($0.numbers["lost_revenue"] ?? 0) > 0 }.count
        guard scored >= 1500, PulseFacts.isUsable(file) else { return }
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(file), data.count > 1_000 else { return }
            try? await PulseCloud.uploadFacts(data)
        }
    }

    private func loadPack() async {
        let chrome = await loadChromeIfPresent()
        if isReady, PulseLaunch.shouldPaintDashboardSectionsProgressively() {
            await loadWarehouseWave(PulseLaunch.dashboardFirstWave)
            await loadWarehouseWave(PulseLaunch.dashboardSecondWave)
            syncWarehouseTape()
            return
        }
        await loadWarehousePack(chromeFirst: chrome)
    }

    private func loadChromeIfPresent() async -> PulseDashChrome? {
        guard PulseSQLite.exists(at: sqliteURL) else { return nil }
        setBootPhase(.readingChrome)
        let url = sqliteURL
        let priority = PulseLaunch.warehouseReadPriority(hubInteractive: isReady && !needsRolePick)
        let chrome = await Task.detached(priority: priority) {
            PulseSQLite.readChrome(from: url)
        }.value
        if let chrome {
            applyDashChrome(chrome)
        }
        packPickerFactCount = max(
            packPickerFactCount,
            PulseSQLite.sectionCount(from: url, section: .pickerScorecard)
        )
        lockPickerDashboard()
        return chrome
    }

    private func loadWarehouseWave(_ sections: [MetricSection]) async {
        let url = sqliteURL
        guard PulseSQLite.exists(at: url), !sections.isEmpty else { return }
        let only = Set(sections)
        let priority = PulseLaunch.warehouseReadPriority(hubInteractive: isReady && !needsRolePick)
        let pack = await Task.detached(priority: priority) {
            try? PulseSQLite.read(from: url, only: only)
        }.value
        guard let pack, !pack.rows.isEmpty else { return }
        let packRows = pack.rows
        let packUploads = pack.uploads
        let caches = await Task.detached(priority: priority) {
            PulseCaches.build(
                rows: packRows,
                filters: DashboardFilters(),
                uploads: packUploads,
                heavy: false,
                grain: nil
            )
        }.value
        mergeWarehouse(caches, pack: pack)
    }

    private func mergeWarehouse(_ caches: PulseCaches, pack: PulseSQLite.Pack) {
        let incoming = Set(pack.rows.map(\.section))
        if PulseLaunch.shouldPublishWarehouseRowsDuringHydrate() || !warehouseHydrating {
            rows.removeAll { incoming.contains($0.section) }
            rows.append(contentsOf: pack.rows)
        }
        if !pack.uploads.isEmpty {
            uploads = pack.uploads.sorted { $0.uploadedAt > $1.uploadedAt }
        }
        for (section, sectionRows) in caches.latestBySection where !sectionRows.isEmpty {
            latestBySection[section] = sectionRows
        }
        for (store, identity) in caches.roster {
            if let have = roster[store], !have.district.isEmpty, identity.district.isEmpty {
                continue
            }
            roster[store] = identity
        }
        if !seeded { seeded = true }
        if !usingDatabasePack { usingDatabasePack = true }
        if incoming.contains(.lostRevenue), latestBySection[.lostRevenue] != nil {
            rebuildLostIndex()
        }
    }

    /// One publish of the row tape after both waves. During hydrate the hub reads latestBySection.
    private func syncWarehouseTape() {
        var tape: [MetricRow] = []
        tape.reserveCapacity(latestBySection.values.reduce(0) { $0 + $1.count })
        for section in MetricSection.allCases {
            tape.append(contentsOf: latestBySection[section] ?? [])
        }
        if !tape.isEmpty {
            rows = tape
        }
    }

    private var warehouseRowCount: Int {
        if !rows.isEmpty { return rows.count }
        return latestBySection.values.reduce(0) { $0 + $1.count }
    }

    private func loadWarehousePack(chromeFirst: PulseDashChrome?) async {
        let url = sqliteURL
        guard PulseSQLite.exists(at: url) else {
            if seeded, !cachedSummaries.isEmpty { return }
            rebuildIndex()
            return
        }
        setBootPhase(.readingPack)
        let skipHeavy: Set<MetricSection> = HubLayout.lightLaunch || chromeFirst != nil ? Self.launchSkip : []
        let priority = PulseLaunch.warehouseReadPriority(hubInteractive: isReady && !needsRolePick)
        let pack = await Task.detached(priority: priority) {
            try? PulseSQLite.read(from: url, skipping: skipHeavy)
        }.value
        if let pack, !pack.rows.isEmpty {
            setBootPhase(.buildingTables)
            let packRows = pack.rows
            let packUploads = pack.uploads
            let chrome = pack.chrome ?? chromeFirst
            let caches = await Task.detached(priority: priority) {
                PulseCaches.build(
                    rows: packRows,
                    filters: DashboardFilters(),
                    uploads: packUploads,
                    heavy: false,
                    grain: chrome == nil ? .region : nil
                )
            }.value
            hydrating = true
            rows = pack.rows
            uploads = pack.uploads.sorted { $0.uploadedAt > $1.uploadedAt }
            seeded = true
            usingDatabasePack = true
            if !isReady {
                filters = DashboardFilters()
                sessionRole = nil
                needsRolePick = true
            }
            packPickerFactCount = max(
                packPickerFactCount,
                pack.counts[MetricSection.pickerScorecard.rawValue] ?? 0
            )
            install(caches)
            if let chrome {
                applyDashChrome(chrome)
            }
            lockPickerDashboard()
            hydrating = false
            applyLocalCards()
            importProgress.loaded = MetricSection.uploadOrder.count
            pendingHeavyExtras = chrome == nil || !(chrome?.isComplete ?? false)
            return
        }
        if seeded, !cachedSummaries.isEmpty { return }
        rebuildIndex()
    }

    private func applyDashChrome(_ chrome: PulseDashChrome) {
        packChrome = chrome
        usingPackChrome = true
        if !chrome.summaries.isEmpty {
            cachedSummaries = chrome.summaries
        }
        pinUnfilteredLostRevenueHeadline()
        if !chrome.flags.isEmpty {
            var next: [MetricSection: [HeartbeatMath.FiveStarFlag]] = [:]
            for (key, value) in chrome.flags {
                if let section = MetricSection(rawValue: key) {
                    next[section] = value
                }
            }
            cachedCardFlags = next
        }
        if !chrome.packs.isEmpty {
            var next: [MetricSection: [DashScopePack]] = [:]
            for (key, value) in chrome.packs {
                if let section = MetricSection(rawValue: key) {
                    next[section] = value
                }
            }
            cachedGrainPacks = next
        }
        if filters.isActive, PulseSeatPack.shouldApplySeatSliceOfMarketWarehouse() {
            applySeatSliceNow()
        } else if filters.isActive {
            applyPreRolledSeatChrome(chrome)
        } else {
            seedExpandTablesFromChrome(chrome)
            seedPickerGrainFromChrome(chrome)
        }
        if chrome.pickerShoppers > 0 {
            cachedPickerBoard = HeartbeatMath.PickerBoard(
                shopperCount: chrome.pickerShoppers,
                opportunityCount: max(chrome.pickerOpportunity, cachedPickerBoard.opportunityCount),
                strongCount: max(chrome.pickerStrong, cachedPickerBoard.strongCount),
                opportunity: cachedPickerBoard.opportunity,
                strong: cachedPickerBoard.strong
            )
        }
        if !filters.isActive {
            unfilteredPulse = snapshotPulse()
        }
        fillExpandTablesSoon()
        lockPickerDashboard()
    }

    /// Pack chrome already has live expand numbers. Seed them on the first
    /// frame so gold / chevron do not wait for a second tap.
    private func seedExpandTablesFromChrome(_ chrome: PulseDashChrome) {
        guard !filters.isActive else { return }
        guard !chrome.tables.isEmpty else { return }
        var incoming: [MetricSection: [HeartbeatMath.DashboardGrainTableRow]] = [:]
        for (key, rows) in chrome.tables {
            guard let section = MetricSection(rawValue: key) else { continue }
            if HeartbeatMath.grainRowsAreLive(rows) {
                incoming[section] = rows
            }
        }
        cachedGrainTables = PulseLaunch.mergeLiveGrainTables(
            incoming: incoming,
            live: cachedGrainTables,
            grain: PulseLaunch.unfilteredDashboardGrain(),
            filtersActive: false
        )
    }

    /// Picker rows stay out of dashboard `displayRows` (Jetsam). Prefill expand
    /// from chrome so the chevron is never permanently light-blue inert.
    private func seedPickerGrainFromChrome(_ chrome: PulseDashChrome) {
        guard !filters.isActive else { return }
        if let cached = cachedGrainTables[.pickerScorecard],
           HeartbeatMath.grainRowsAreLive(cached),
           PulseLaunch.grainTableMatchesCurrent(labels: cached.map(\.label), grain: .region) {
            return
        }
        let table = PulseLaunch.pickerExpandRows(
            from: chrome,
            filters: filters,
            grain: effectiveDashboardGrain
        )
        guard HeartbeatMath.grainRowsAreLive(table) else { return }
        cachedGrainTables[.pickerScorecard] = table
    }

    /// Card + expand stay filled whenever the pack has picker facts.
    /// Chrome numbers win unfiltered so a first-chunk warehouse cannot show 80
    /// shoppers over a 26,349 pack total. Never stamps the hub.
    private func lockPickerDashboard() {
        let allowed = pickerStoreSet()
        let latest = PulseLaunch.pickerSeatRows(
            filtered: filteredLatest[.pickerScorecard] ?? [],
            warehouse: latestBySection[.pickerScorecard] ?? [],
            allowed: allowed,
            filters: filters,
            roster: roster
        )
        let grain = effectiveDashboardGrain
        if filters.isActive {
            if !latest.isEmpty {
                filteredLatest[.pickerScorecard] = latest
                var painted = HeartbeatMath.summarize(
                    .pickerScorecard,
                    rows: latest,
                    upload: upload(for: .pickerScorecard)
                )
                if let seat = allowed?.count, seat > 0 {
                    painted = PulseLaunch.pinSeatStoreCount(painted, seatStores: seat)
                }
                upsertPickerSummary(painted)
                cachedCardFlags[.pickerScorecard] = HeartbeatMath.dashboardActionFlags(
                    section: .pickerScorecard,
                    rows: latest,
                    includeAll: true
                )
                cachedPickerBoard = HeartbeatMath.pickerBoard(latest)
                rebuildSeatPickerIndex()
            } else if PulseLaunch.shouldWipePickerIndexOnSeatClear() {
                wipePickerIndex()
            }
            let table = PulseLaunch.pickerExpandTable(
                seatRows: latest,
                chrome: nil,
                filters: filters,
                grain: grain
            )
            if HeartbeatMath.grainRowsAreLive(table) {
                cachedGrainTables[.pickerScorecard] = table
                let packs = PulseCaches.grainPacks(
                    latest: [.pickerScorecard: latest],
                    grain: grain,
                    hidePicker: false,
                    stores: cachedStores,
                    roster: roster
                )[.pickerScorecard] ?? []
                if PulseLaunch.pickerPacksAreLive(packs) {
                    cachedGrainPacks[.pickerScorecard] = packs
                }
            } else if !PulseLaunch.grainMatchesSeat(
                cachedGrainTables[.pickerScorecard] ?? [],
                filters: filters,
                grain: grain
            ) {
                cachedGrainTables[.pickerScorecard] = []
            }
            return
        }
        if !latest.isEmpty {
            let painted = HeartbeatMath.summarize(
                .pickerScorecard,
                rows: latest,
                upload: upload(for: .pickerScorecard)
            )
            let chromeHead = Double(max(packChrome?.pickerShoppers ?? 0, Int(packChrome?.card(.pickerScorecard)?.headline ?? 0), packPickerFactCount))
            if (painted.headline ?? 0) >= chromeHead {
                upsertPickerSummary(painted)
                cachedCardFlags[.pickerScorecard] = HeartbeatMath.dashboardActionFlags(
                    section: .pickerScorecard,
                    rows: latest,
                    includeAll: true
                )
                cachedPickerBoard = HeartbeatMath.pickerBoard(latest)
            } else if let chrome = packChrome, let card = PulseLaunch.pickerSummaryFromChrome(chrome) {
                upsertPickerSummary(card)
            }
            let table = PulseLaunch.pickerExpandTable(
                seatRows: latest,
                chrome: packChrome,
                filters: filters,
                grain: grain,
                packOrder: cachedGrainPacks[.pickerScorecard]?.map(\.line.label) ?? []
            )
            if HeartbeatMath.grainRowsAreLive(table) {
                cachedGrainTables[.pickerScorecard] = table
            }
            let packs = PulseCaches.grainPacks(
                latest: [.pickerScorecard: latest],
                grain: grain,
                hidePicker: false,
                roster: roster
            )[.pickerScorecard] ?? []
            if PulseLaunch.pickerPacksAreLive(packs), Double(latest.count) >= chromeHead * 0.5 {
                cachedGrainPacks[.pickerScorecard] = packs
            }
        } else if let chrome = packChrome {
            if let card = PulseLaunch.pickerSummaryFromChrome(chrome) {
                upsertPickerSummary(card)
            }
            seedPickerGrainFromChrome(chrome)
            if let packs = chrome.packs[MetricSection.pickerScorecard.rawValue],
               PulseLaunch.pickerPacksAreLive(packs) {
                cachedGrainPacks[.pickerScorecard] = packs
            }
        }
        if !HeartbeatMath.grainRowsAreLive(cachedGrainTables[.pickerScorecard] ?? []),
           let chrome = packChrome {
            seedPickerGrainFromChrome(chrome)
        }
    }

    private func upsertPickerSummary(_ summary: SectionSummary) {
        if let index = cachedSummaries.firstIndex(where: { $0.section == .pickerScorecard }) {
            let have = cachedSummaries[index].headline ?? 0
            if !filters.isActive, have > (summary.headline ?? 0) { return }
            cachedSummaries[index] = summary
        } else {
            cachedSummaries.append(summary)
        }
    }

    private func prefetchPickerDashboardIfNeeded() async {
        if filters.isActive {
            await loadFilteredPickerExpandIfNeeded()
            return
        }
        lockPickerDashboard()
        if HeartbeatMath.grainRowsAreLive(cachedGrainTables[.pickerScorecard] ?? []),
           (cachedSummaries.first(where: { $0.section == .pickerScorecard })?.headline ?? 0) > 0 {
            return
        }
        guard PulseSQLite.exists(at: sqliteURL) else { return }
        let url = sqliteURL
        let count = PulseSQLite.sectionCount(from: url, section: .pickerScorecard)
        if count > packPickerFactCount { packPickerFactCount = count }
        if count == 0 { return }
        let rosterCopy = roster
        let first = PulseLaunch.pickerFirstPaintCount
        let rows = await Task.detached(priority: .userInitiated) { () -> [MetricRow] in
            let raw = PulseSQLite.readSection(from: url, section: .pickerScorecard, limit: first, offset: 0)
            return HeartbeatMath.applyRoster(HeartbeatMath.latestPerShopper(raw), roster: rosterCopy)
        }.value
        if !rows.isEmpty, (latestBySection[.pickerScorecard] ?? []).isEmpty {
            latestBySection[.pickerScorecard] = rows
        }
        lockPickerDashboard()
    }

    private func loadFilteredPickerExpandIfNeeded() async {
        lockPickerDashboard()
        let grain = effectiveDashboardGrain
        if PulseLaunch.grainMatchesSeat(
            cachedGrainTables[.pickerScorecard] ?? [],
            filters: filters,
            grain: grain
        ), !(filteredLatest[.pickerScorecard] ?? []).isEmpty {
            return
        }
        let allowed = pickerStoreSet() ?? []
        guard filters.isActive, !allowed.isEmpty, PulseSQLite.exists(at: sqliteURL) else { return }
        let wasEmpty = (filteredLatest[.pickerScorecard] ?? []).isEmpty
        let showLoading = wasEmpty && PulseLaunch.shouldShowPickerLoadingOnSeatFill(dest: visibleDestination)
        if showLoading { pickerLoading = true }
        let url = sqliteURL
        let stores = allowed
        let rosterCopy = roster
        let rows = await Task.detached(priority: .userInitiated) { () -> [MetricRow] in
            let raw = PulseSQLite.readStores(from: url, sections: [.pickerScorecard], stores: stores)
            return HeartbeatMath.applyRoster(HeartbeatMath.latestPerShopper(raw), roster: rosterCopy)
        }.value
        if showLoading { pickerLoading = false }
        guard !rows.isEmpty else { return }
        filteredLatest[.pickerScorecard] = rows
        latestBySection[.pickerScorecard] = PulseLaunch.mergePickerRows(
            existing: latestBySection[.pickerScorecard] ?? [],
            incoming: rows
        )
        lockPickerDashboard()
        rebuildSeatPickerIndex()
        if PulseLaunch.shouldPublishSeatFill(
            dest: visibleDestination,
            interactiveAt: hubBecameInteractiveAt
        ) {
            objectWillChange.send()
        }
    }

    @discardableResult
    private func restorePackChrome() -> Bool {
        guard !latestBySection.isEmpty else { return false }
        paintFactsScorecards()
        return true
    }

    private enum FactAdoptMode {
        case fillIfThin
        case takeIfRicher
    }

    /// Put Excel store rows for Sales, 5 Star, and Loss Revenue into the warehouse.
    /// A full live pack / cloud table is kept. Bundled facts only fill a thin pack.
    @discardableResult
    private func adoptExcelFactsIntoWarehouse() async -> Bool {
        if didAdoptExcelFacts { return false }
        let priority = PulseLaunch.warehouseReadPriority(hubInteractive: isReady && !needsRolePick)
        let facts = await Task.detached(priority: priority) {
            PulseFacts.bundledMetricRows()
        }.value
        let changed = adoptFactRows(facts, mode: .fillIfThin)
        didAdoptExcelFacts = true
        return changed
    }

    @discardableResult
    private func adoptFactRows(_ facts: [MetricRow], mode: FactAdoptMode) -> Bool {
        guard !facts.isEmpty else { return false }
        var changed = false
        for row in facts where row.section == .storeRoster || row.textPayload["roster"] == "1" {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            let existing = roster[store]
            roster[store] = HeartbeatMath.StoreIdentity(
                division: row.division.isEmpty ? (existing?.division ?? "") : row.division,
                district: row.district.isEmpty ? (existing?.district ?? "") : row.district,
                om: row.operationsOM.isEmpty ? (existing?.om ?? "") : row.operationsOM,
                name: row.storeName ?? existing?.name
            )
        }
        let owned: [MetricSection] = [.lostRevenue, .sales, .fiveStar]
        for section in owned {
            let factRows = facts.filter { PulseQuery.isStoreFact($0) && $0.section == section }
            let stamped = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(factRows), roster: roster)
            let incoming: [MetricRow]?
            switch mode {
            case .fillIfThin:
                if let full = PulseQuery.fillIfThin(existing: latestBySection[section] ?? [], incoming: stamped) {
                    incoming = full
                } else {
                    let merged = PulseQuery.fillMissingRegions(
                        existing: latestBySection[section] ?? [],
                        facts: stamped,
                        section: section
                    )
                    incoming = merged.count > (latestBySection[section] ?? []).count ? merged : nil
                }
            case .takeIfRicher:
                incoming = PulseQuery.takeIfRicher(existing: latestBySection[section] ?? [], incoming: stamped)
            }
            guard let incoming else { continue }
            latestBySection[section] = incoming
            factsOwned.insert(section)
            changed = true
        }
        return changed
    }

    private func paintFactsScorecards() {
        Task { await paintFromWarehouse(light: true) }
    }

    private func loadDeferredPicker() async {
        await streamPicker(preferSnappy: false)
    }

    private func streamPicker(preferSnappy: Bool) async {
        if pickerStreamDone, (latestBySection[.pickerScorecard] ?? []).count >= 2 {
            let join = PulseLaunch.needsShopperJoin(visibleDestination)
            if join {
                refreshPickerDashboard(visiblePickers(), stamp: true, chrome: true)
            }
            return
        }
        if pickerLoadTask != nil {
            let join = PulseLaunch.needsShopperJoin(visibleDestination)
            if join, let first = latestBySection[.pickerScorecard], first.count >= 2 {
                refreshPickerDashboard(
                    PulseQuery.sliceSection(
                        .pickerScorecard,
                        rows: first,
                        allowed: PulseCaches.allowedStores(roster: roster, filters: filters)
                    ),
                    stamp: true,
                    chrome: true
                )
            }
            if preferSnappy { return }
            await pickerLoadTask?.value
            return
        }
        guard PulseSQLite.exists(at: sqliteURL) else { return }
        let url = sqliteURL
        let rosterCopy = roster
        let firstLimit = PulseLaunch.pickerFirstPaintCount
        let chunk = PulseLaunch.pickerChunkCount
        let firstPriority: TaskPriority = (preferSnappy && !isReady) ? .userInitiated : .utility
        if (latestBySection[.pickerScorecard] ?? []).isEmpty {
            pickerLoading = true
        }
        let firstRows = await Task.detached(priority: firstPriority) { () -> [MetricRow] in
            let raw = PulseSQLite.readSection(from: url, section: .pickerScorecard, limit: firstLimit, offset: 0)
            return HeartbeatMath.applyRoster(HeartbeatMath.latestPerShopper(raw), roster: rosterCopy)
        }.value
        applyPickerChunk(firstRows, replace: true)
        pickerLoadTask = Task.detached(priority: .background) {
            var offset = firstRows.count
            var warehouse = firstRows
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: PulseLaunch.pickerChunkPauseNanoseconds)
                guard !Task.isCancelled else { return }
                let raw = PulseSQLite.readSection(from: url, section: .pickerScorecard, limit: chunk, offset: offset)
                let more = HeartbeatMath.applyRoster(HeartbeatMath.latestPerShopper(raw), roster: rosterCopy)
                if more.isEmpty { break }
                offset += more.count
                guard !Task.isCancelled else { return }
                warehouse = PulseLaunch.mergePickerRows(existing: warehouse, incoming: more)
                if warehouse.count >= PulseLaunch.pickerWarehouseCap { break }
                let snapshot = warehouse
                let dest = await MainActor.run { self.visibleDestination }
                if PulseLaunch.needsShopperJoin(dest) {
                    await MainActor.run { self.parkPickerWarehouse(snapshot) }
                }
                if more.count < chunk { break }
            }
            let final = warehouse
            await MainActor.run {
                self.latestBySection[.pickerScorecard] = final
                self.pickerStreamDone = final.count >= 2
                self.pickerLoading = false
                let join = PulseLaunch.needsShopperJoin(self.visibleDestination)
                if join {
                    self.refreshPickerDashboard(self.visiblePickers(), stamp: true, chrome: true)
                    self.schedulePickerIndex(self.visiblePickers())
                }
                self.pickerLoadTask = nil
            }
        }
        if !preferSnappy {
            await pickerLoadTask?.value
        }
    }

    /// Grow the in-memory shopper pack without waking SwiftUI unless a join page needs it.
    private func parkPickerWarehouse(_ rows: [MetricRow]) {
        latestBySection[.pickerScorecard] = rows
        guard PulseLaunch.needsShopperJoin(visibleDestination) else { return }
        let sliced = PulseQuery.sliceSection(
            .pickerScorecard,
            rows: rows,
            allowed: PulseCaches.allowedStores(roster: roster, filters: filters)
        )
        let count = sliced.count
        let stamp = PulseLaunch.shouldStampPicker(
            replace: false,
            dest: visibleDestination,
            count: count,
            lastStampCount: lastPickerStampCount
        )
        if stamp { lastPickerStampCount = count }
        let chrome = PulseLaunch.shouldRefreshPickerChrome(
            replace: false,
            dest: visibleDestination,
            stamp: stamp
        )
        guard PulseLaunch.shouldTouchPickerUI(stamp: stamp, chrome: chrome) else { return }
        refreshPickerDashboard(sliced, stamp: stamp, chrome: chrome)
    }

    private func applyPickerChunk(_ rows: [MetricRow], replace: Bool) {
        guard !rows.isEmpty else { return }
        if replace {
            latestBySection[.pickerScorecard] = rows
        } else {
            latestBySection[.pickerScorecard] = PulseLaunch.mergePickerRows(
                existing: latestBySection[.pickerScorecard] ?? [],
                incoming: rows
            )
        }
        let sliced = PulseQuery.sliceSection(
            .pickerScorecard,
            rows: latestBySection[.pickerScorecard] ?? [],
            allowed: PulseCaches.allowedStores(roster: roster, filters: filters)
        )
        let count = sliced.count
        let stamp = PulseLaunch.shouldStampPicker(
            replace: replace,
            dest: visibleDestination,
            count: count,
            lastStampCount: lastPickerStampCount
        )
        if stamp { lastPickerStampCount = count }
        let chrome = PulseLaunch.shouldRefreshPickerChrome(
            replace: replace,
            dest: visibleDestination,
            stamp: stamp
        )
        guard PulseLaunch.shouldTouchPickerUI(stamp: stamp, chrome: chrome) else { return }
        refreshPickerDashboard(sliced, stamp: stamp, chrome: chrome)
    }

    private func refreshPickerDashboard(_ sliced: [MetricRow], stamp: Bool, chrome: Bool = true) {
        filteredLatest[.pickerScorecard] = sliced
        refreshSummary(for: .pickerScorecard, rows: sliced)
        if chrome, !sliced.isEmpty {
            cachedPickerBoard = HeartbeatMath.pickerBoard(sliced)
            cachedCardFlags[.pickerScorecard] = HeartbeatMath.dashboardActionFlags(
                section: .pickerScorecard,
                rows: sliced,
                includeAll: true
            )
            rebuildPPHPickerIndex(scorecard: sliced)
            patchPPHCallouts()
        }
        pageOnlyGeneration = paintGeneration
        if stamp {
            acknowledgeBackgroundFill(stampIfAllowed: PulseLaunch.shouldStampPickerOrPageOnlyInstall())
        }
    }

    private func refreshLoadedPickers() {
        installSectionSlice(.pickerScorecard)
    }

    private func installSectionSlice(_ section: MetricSection) {
        let allowed = PulseCaches.allowedStores(roster: roster, filters: filters)
        let sliced = PulseQuery.sliceSection(
            section,
            rows: latestBySection[section] ?? [],
            allowed: allowed,
            filters: filters,
            roster: roster
        )
        filteredLatest[section] = sliced
        refreshSummary(for: section, rows: sliced)
        if section == .pickerScorecard, !sliced.isEmpty {
            cachedPickerBoard = HeartbeatMath.pickerBoard(sliced)
            schedulePickerIndex(sliced)
        }
        if PulseQuery.pageOnlySections.contains(section) {
            pageOnlyGeneration = paintGeneration
        }
        acknowledgeBackgroundFill(stampIfAllowed: PulseLaunch.shouldStampPickerOrPageOnlyInstall())
    }

    private func rebuildSeatPickerIndex() {
        guard filters.isActive else { return }
        let seat = filteredLatest[.pickerScorecard] ?? []
        if PulseLaunch.shouldRebuildPickerIndexOnSeatPaint(filtersActive: true, seatRowCount: seat.count) {
            schedulePickerIndex(seat)
        } else {
            wipePickerIndex()
        }
    }

    private func schedulePickerIndex(_ pickers: [MetricRow]) {
        let seat = filters.isActive ? (filteredLatest[.pickerScorecard] ?? []) : pickers
        let source = filters.isActive ? seat : pickers
        let count = source.count
        guard count > 0 else { return }
        Task.detached(priority: .background) {
            let built = PulseCaches.pickerBuckets(source)
            await MainActor.run {
                guard (self.filteredLatest[.pickerScorecard] ?? []).count == count else { return }
                if self.filters.isActive, PulseLaunch.shouldRejectCompanyPickerIndexUnderSeat() {
                    guard (self.filteredLatest[.pickerScorecard] ?? []).count == count else { return }
                }
                self.pickerIndex = built.index
                self.pickerFocusHealth = built.health
            }
        }
    }

    func ensureSectionLoaded(_ section: MetricSection) async {
        let seatFirst = PulseLaunch.sectionPageFirstPaint(
            section: section,
            filtersActive: filters.isActive
        ) == .seatReadStores

        if section == .pickerScorecard {
            if seatFirst {
                await loadFilteredPickerExpandIfNeeded()
                return
            }
            await streamPicker(preferSnappy: isReady)
            return
        }

        if PulseLaunch.sectionNeedsShopperJoin(section) {
            if seatFirst {
                Task { await self.loadFilteredPickerExpandIfNeeded() }
            } else if !pickerStreamDone,
                      PulseLaunch.shouldStartCompanyPickerStreamOnJoinPage(filtersActive: false) {
                Task { await self.streamPicker(preferSnappy: false) }
            }
        }

        if seatFirst {
            await loadFilteredSectionIfNeeded(section)
            return
        }

        let deferred = PulseQuery.skipOnLight.contains(section)
        if deferred {
            if (latestBySection[section] ?? []).count >= 2 {
                if filteredLatest[section]?.isEmpty != false {
                    installSectionSlice(section)
                }
                return
            }
        } else {
            if factsOwned.contains(section) { return }
            if !(latestBySection[section] ?? []).isEmpty { return }
        }
        guard PulseSQLite.exists(at: sqliteURL) else { return }
        let url = sqliteURL
        let rosterCopy = roster
        let readPriority: TaskPriority = isReady ? .utility : .userInitiated
        let incoming = await Task.detached(priority: readPriority) { () -> [MetricRow] in
            guard let pack = try? PulseSQLite.read(from: url, only: [section]) else { return [] }
            return PulseLaunch.materializeSectionRows(pack.rows, section: section, roster: rosterCopy)
        }.value
        adoptSectionWarehouse(section, incoming)
    }

    /// Seat page-open: `readStores(allowed)` when the warehouse is empty. Never company LIMIT/OFFSET.
    private func loadFilteredSectionIfNeeded(_ section: MetricSection) async {
        if section == .pickerScorecard {
            await loadFilteredPickerExpandIfNeeded()
            return
        }
        if let have = latestBySection[section], !have.isEmpty {
            installSectionSlice(section)
            return
        }
        let allowed = pickerStoreSet() ?? []
        guard filters.isActive, !allowed.isEmpty, PulseSQLite.exists(at: sqliteURL) else {
            if !(latestBySection[section] ?? []).isEmpty {
                installSectionSlice(section)
            }
            return
        }
        let url = sqliteURL
        let stores = allowed
        let rosterCopy = roster
        let incoming = await Task.detached(priority: .userInitiated) { () -> [MetricRow] in
            let raw = PulseSQLite.readStores(from: url, sections: [section], stores: stores)
            return PulseLaunch.materializeSectionRows(raw, section: section, roster: rosterCopy)
        }.value
        guard !incoming.isEmpty else { return }
        adoptSectionWarehouse(section, incoming)
        if PulseLaunch.shouldPublishSeatFill(
            dest: visibleDestination,
            interactiveAt: hubBecameInteractiveAt
        ) {
            objectWillChange.send()
        }
    }

    private func adoptSectionWarehouse(_ section: MetricSection, _ incoming: [MetricRow]) {
        guard !incoming.isEmpty else { return }
        latestBySection[section] = incoming
        if section == .dynacap || section == .pph || section == .pickerScorecard {
            latestBySection = HeartbeatMath.overlayDynacapPPH(latestBySection)
        }
        if section == .labor {
            rebuildLaborWeekIndex()
        }
        installSectionSlice(section)
    }

    private func hydrateFilteredHeavy() async {
        guard filters.isActive else { return }
        applyVisibleFilter()
    }

    private func loadHeavySections() async {
        guard PulseSQLite.exists(at: sqliteURL) else { return }
        if (latestBySection[.labor] ?? []).isEmpty {
            await ensureSectionLoaded(.labor)
        }
        if (latestBySection[.pickerScorecard] ?? []).count < 50 {
            await ensureSectionLoaded(.pickerScorecard)
        }
        if usingPackChrome, !filters.isActive {
            restorePackChrome()
            return
        }
        refreshDashboardChrome()
    }

    private func refreshDashboardChrome() {
        if usingPackChrome, !filters.isActive {
            restorePackChrome()
            return
        }
        let grain = effectiveDashboardGrain
        let latest = filteredLatest
        let stores = cachedStores
        let rosterCopy = roster
        let laborMarket = laborMarketRow()
        Task.detached(priority: .utility) {
            let flags = PulseCaches.cardFlags(latest: latest, laborMarket: laborMarket)
            let packs = PulseCaches.grainPacks(
                latest: latest,
                grain: grain,
                hidePicker: true,
                stores: stores,
                roster: rosterCopy
            )
            let tables = PulseCaches.grainTables(
                latest: latest,
                grain: grain,
                roster: rosterCopy,
                packs: packs,
                goalFallback: HeartbeatMath.lostRevenueGoalFallback(latest[.lostRevenue] ?? [])
            )
            await MainActor.run {
                if self.usingPackChrome, !self.filters.isActive { return }
                self.cachedCardFlags = flags
                self.cachedGrainPacks = PulseLaunch.mergeDashboardPacks(
                    incoming: packs,
                    live: self.cachedGrainPacks,
                    filtersActive: self.filters.isActive
                )
                self.cachedGrainTables = PulseLaunch.mergeLiveGrainTables(
                    incoming: tables,
                    live: self.cachedGrainTables,
                    grain: grain,
                    filtersActive: self.filters.isActive
                )
                self.lockPickerDashboard()
                self.patchPPHCallouts()
            }
        }
        if let labor = filteredLatest[.labor] {
            refreshSummary(for: .labor, rows: labor + [laborMarketRow()].compactMap { $0 })
        }
        if let pickers = filteredLatest[.pickerScorecard] {
            refreshSummary(for: .pickerScorecard, rows: pickers)
            if cachedPickerBoard.shopperCount == 0 {
                cachedPickerBoard = HeartbeatMath.pickerBoard(pickers)
            }
        }
        refreshSalesExpandCache()
    }

    private func refreshSummary(for section: MetricSection, rows: [MetricRow]) {
        let summary = HeartbeatMath.summarize(
            section,
            rows: rows,
            upload: uploads.first { $0.section == section }
        )
        if let index = cachedSummaries.firstIndex(where: { $0.section == section }) {
            cachedSummaries[index] = summary
        } else {
            cachedSummaries.append(summary)
        }
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
        Task { await paintFromWarehouse(light: true) }
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
        let seatPickers = filters.isActive ? (filteredLatest[.pickerScorecard] ?? []) : []
        latestBySection = caches.latestBySection
        roster = caches.roster
        filteredLatest = caches.filteredLatest
        if filters.isActive, PulseLaunch.shouldRejectCompanyPickerIndexUnderSeat(), !seatPickers.isEmpty {
            filteredLatest[.pickerScorecard] = seatPickers
        }
        filteredMarket = caches.filteredMarket
        cachedDivisions = caches.cachedDivisions
        cachedDistricts = caches.cachedDistricts
        cachedOMs = caches.cachedOMs
        cachedStores = caches.cachedStores
        cachedChecklistGroups = caches.cachedChecklistGroups
        if filters.isActive, PulseLaunch.shouldRejectCompanyPickerIndexUnderSeat() {
            rebuildSeatPickerIndex()
        } else {
            pickerIndex = caches.pickerIndex
            if (pickerIndex[.all] ?? []).isEmpty {
                let pickers = caches.filteredLatest[.pickerScorecard] ?? []
                if !pickers.isEmpty {
                    pickerIndex[.all] = Array(pickers.indices)
                }
            }
            pickerFocusHealth = caches.pickerFocusHealth
        }
        pickPathPickersByStore = caches.pickPathPickersByStore
        pickPathByShopper = caches.pickPathByShopper
        installPPHPickerIndex(fromRows: caches.pphPickersByStore)
        if usingPackChrome, packChrome != nil {
            rebuildLostIndex()
            rebuildLaborWeekIndex()
            refreshChecklistOpenCount()
            refreshSalesExpandCache()
            fillExpandTablesSoon()
            return
        }
        cachedSummaries = caches.cachedSummaries
        cachedPickerBoard = caches.cachedPickerBoard
        cachedCardFlags = caches.cachedCardFlags
        cachedGrainPacks = caches.cachedGrainPacks
        rebuildLostIndex()
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
        if usingPackChrome, !filters.isActive { return }
        if bits.pickerBoard.shopperCount > 0 {
            cachedPickerBoard = bits.pickerBoard
        }
        cachedChecklistGroups = bits.checklistGroups
        pickPathPickersByStore = bits.pickPathPickersByStore
        pickPathByShopper = bits.pickPathByShopper
        installPPHPickerIndex(fromRows: bits.pphPickersByStore)
        refreshChecklistOpenCount()
        let pickers = filteredLatest[.pickerScorecard] ?? []
        if filters.isActive, PulseLaunch.shouldRejectCompanyPickerIndexUnderSeat() {
            rebuildSeatPickerIndex()
            return
        }
        if !bits.pickerIndex.isEmpty {
            pickerIndex = bits.pickerIndex
            pickerFocusHealth = bits.pickerFocusHealth
            return
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
        guard HubLayout.ingestsWorkbook else { return }
        guard packDirty else { return }
        Task { await persistNow() }
    }

    private func persistNow() async {
        persistFilters()
        guard HubLayout.ingestsWorkbook else { packDirty = false; return }
        guard packDirty else { return }
        let packURL = sqliteURL
        let packRows = rows
        let packUploads = uploads
        let packSeeded = seeded
        let incomingPicker = packRows.filter { $0.section == .pickerScorecard }.count
        let incomingLabor = packRows.filter { $0.section == .labor }.count
        let diskPicker = PulseSQLite.sectionCount(from: packURL, section: .pickerScorecard)
        let diskLabor = PulseSQLite.sectionCount(from: packURL, section: .labor)
        if diskPicker > 100, incomingPicker == 0 { packDirty = false; return }
        if diskLabor > 100, incomingLabor == 0 { packDirty = false; return }
        do {
            let chrome = PulseDashChrome(
                summaries: cachedSummaries,
                flags: Dictionary(uniqueKeysWithValues: cachedCardFlags.map { ($0.key.rawValue, $0.value) }),
                packs: Dictionary(uniqueKeysWithValues: cachedGrainPacks.map { ($0.key.rawValue, $0.value) }),
                tables: Dictionary(uniqueKeysWithValues: cachedGrainTables.map { ($0.key.rawValue, $0.value) }),
                pickerShoppers: cachedPickerBoard.shopperCount,
                pickerOpportunity: cachedPickerBoard.opportunityCount,
                pickerStrong: cachedPickerBoard.strongCount
            )
            try await Task.detached(priority: .utility) {
                try PulseSQLite.write(
                    rows: packRows,
                    uploads: packUploads,
                    seeded: packSeeded,
                    chrome: chrome,
                    to: packURL
                )
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

    func pulseMailSnapshot(_ pages: Set<PulseMail.SharePage> = Set(PulseMail.SharePage.allCases)) -> PulseMail.Snapshot {
        var needed: Set<MetricSection> = []
        for page in pages {
            if let section = page.section { needed.insert(section) }
        }
        if pages.contains(.preSubOOS) { needed.insert(.preSubOOSItem) }
        if pages.contains(.dashboard) {
            needed.formUnion(MetricSection.dashboardCards)
        }
        var pickerCounts: [String: Int] = [:]
        var rows: [MetricSection: [MetricRow]] = [:]
        var rowTotals: [MetricSection: Int] = [:]
        for section in needed {
            let all = displayRows(for: section)
            rowTotals[section] = all.count
            rows[section] = PulseMail.pageRows(all, section: section)
        }
        if needed.contains(.pph) || needed.contains(.pickPath) || needed.contains(.pickerScorecard) {
            pickerCounts = pphPickerCounts()
        }
        let grain = effectiveDashboardGrain
        var grainTables: [MetricSection: [HeartbeatMath.DashboardGrainTableRow]] = [:]
        var flags: [MetricSection: [HeartbeatMath.FiveStarFlag]] = [:]
        for section in needed {
            if let table = cachedGrainTables[section], !table.isEmpty,
               PulseLaunch.grainTableMatchesCurrent(labels: table.map(\.label), grain: grain) {
                grainTables[section] = table
            }
            if let card = cachedCardFlags[section], !card.isEmpty {
                let scoped = summaries.first { $0.section == section }?.storeCount ?? 0
                if PulseLaunch.flagsMatchFilter(flagStores: card.map(\.stores), scopedStores: scoped) {
                    flags[section] = card
                }
            }
        }
        return PulseMail.Snapshot(
            filterSummary: filters.summary,
            grain: effectiveDashboardGrain.rawValue,
            summaries: pages.contains(.dashboard) ? summaries : summaries.filter { needed.contains($0.section) },
            rows: rows,
            pickerCounts: pickerCounts,
            generatedAt: Date(),
            rowTotals: rowTotals,
            grainTables: grainTables,
            flags: flags
        )
    }

    /// Headlines only so the Share sheet can appear before HTML is streamed.
    func pulseMailBriefSnapshot(_ pages: Set<PulseMail.SharePage>) -> PulseMail.Snapshot {
        var needed: Set<MetricSection> = []
        for page in pages {
            if let section = page.section { needed.insert(section) }
        }
        return PulseMail.Snapshot(
            filterSummary: filters.summary,
            grain: effectiveDashboardGrain.rawValue,
            summaries: pages.contains(.dashboard) ? summaries : summaries.filter { needed.contains($0.section) },
            rows: [:],
            pickerCounts: [:],
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
