import Foundation
import UIKit

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
    @Published var importLabel: String?
    @Published var pendingExternalName: String?
    @Published var waitingForFileSection: MetricSection?
    @Published private(set) var isReady = false
    @Published private(set) var filterStamp = 0
    @Published private(set) var linkedMasterName: String?
    @Published private(set) var linkedMasterLoadedAt: Date?

    private let fileManager: FileManager
    private let snapshotURL: URL
    private let checklistURL: URL
    private let masterLinkURL: URL
    private let filtersURL: URL
    private var hydrating = false
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
        checklistURL = root.appendingPathComponent("checklist.json")
        masterLinkURL = root.appendingPathComponent("master-link.json")
        filtersURL = root.appendingPathComponent("filters.json")
        rows = []
        uploads = []
        seeded = false
        filters = DashboardFilters()
        loadChecklist()
        loadMasterLink()
        load()
        watchAppLifecycle()
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

    func displayRows(for section: MetricSection) -> [MetricRow] {
        filteredLatest[section] ?? []
    }

    func summary(for section: MetricSection) -> SectionSummary {
        cachedSummaries.first { $0.section == section }
            ?? HeartbeatMath.summarize(section, rows: [], upload: upload(for: section))
    }

    func upload(for section: MetricSection) -> UploadRecord? {
        uploads.first { $0.section == section }
    }

    var summaries: [SectionSummary] { cachedSummaries }

    var pickerBoard: HeartbeatMath.PickerBoard { cachedPickerBoard }

    func pphPickers(forStore store: String) -> [MetricRow] {
        pphPickersByStore[HeartbeatMath.canonicalStore(store)] ?? []
    }

    func pphPickerCount(forStore store: String) -> Int {
        pphPickersByStore[HeartbeatMath.canonicalStore(store)]?.count ?? 0
    }

    func pickPathPickers(forStore store: String) -> [MetricRow] {
        pickPathPickersByStore[HeartbeatMath.canonicalStore(store)] ?? []
    }

    func pickPathPicker(forShopper raw: String) -> MetricRow? {
        pickPathByShopper[HeartbeatMath.canonicalShopper(raw)]
    }

    func pickerCount(for focus: PickerFocus) -> Int {
        pickerIndex[focus]?.count ?? 0
    }

    func pickerFocusHealth(for focus: PickerFocus) -> Health {
        pickerFocusHealth[focus] ?? Health.none
    }

    func pickerPage(focus: PickerFocus, sort: PickerSort, ascending: Bool, limit: Int) -> [MetricRow] {
        let pickers = filteredLatest[.pickerScorecard] ?? []
        var idxs = pickerIndex[focus] ?? []
        idxs.sort { lhs, rhs in
            let result = comparePickers(pickers[lhs], pickers[rhs], sort: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
        if idxs.count > limit {
            idxs = Array(idxs.prefix(limit))
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
                note(.strong, .good)
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
        for row in scorecard {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            for alias in HeartbeatMath.shopperAliases(row) {
                storesByShopper[alias, default: []].insert(store)
            }
        }
        var byShopper: [String: MetricRow] = [:]
        var buckets: [String: [MetricRow]] = [:]
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
                ($0.number("compliance_pct") ?? 999) < ($1.number("compliance_pct") ?? 999)
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
                return value.isEmpty ? nil : value
            }
        }).sorted()
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

    func laborNeedsReload() -> Bool {
        let stores = rows.filter { $0.section == .labor && $0.textPayload["labor_grain"] == "store" }
        guard !stores.isEmpty else { return false }
        if laborMarketRow() == nil, laborWeekIds().isEmpty { return true }
        return stores.contains {
            let rev = $0.textPayload["parser_rev"] ?? ""
            return rev != "7" && rev != "8"
        }
    }

    static func importAudit(section: MetricSection, rows: [MetricRow]) -> String {
        if section == .labor {
            return laborAudit(rows)
        }
        let stores = Set(rows.map { HeartbeatMath.canonicalStore($0.storeNumber) }.filter { !$0.isEmpty })
        let shoppers = Set(rows.compactMap { $0.textPayload["shopper_id"] }.filter { !$0.isEmpty })
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
        for row in rows where row.section == .labor && row.textPayload["labor_grain"] == "week" {
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
        objectWillChange.send()
        commentSaveTask?.cancel()
        commentSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.persistChecklist()
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
        if filters == cleaned { return }
        filters = cleaned
        persistFilters()
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

    func clearFilters() {
        if isCompanyWide(unfilteredPulse) == false {
            unfilteredPulse = nil
        }
        commitFilters(DashboardFilters())
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
        rebuildIndex()
        replaceFilters(DashboardFilters())
        statusMessage = "Sample market loaded — 16 Chicago-area stores."
        persist()
    }

    func flush() {
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
        _ = saveToDocuments(data, filename: filename)
        Task {
            let ok = await runMasterImport(data: data, filename: filename, fallbackToPicker: false)
            if ok {
                rememberMasterFile(url: sourceURL, filename: filename)
            }
        }
    }

    func reloadLinkedMaster() {
        Task { await runLinkedMasterReload() }
    }

    func unlinkMasterFile() {
        masterBookmark = nil
        linkedMasterName = nil
        linkedMasterLoadedAt = nil
        try? fileManager.removeItem(at: masterLinkURL)
    }

    private func runLinkedMasterReload() async {
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
            isImporting = false
            importLabel = nil
            _ = saveToDocuments(file.data, filename: file.name)
            let ok = await runMasterImport(data: file.data, filename: file.name, fallbackToPicker: false)
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
                return parsed.map { $0.asRow(section: section) }
            }.value
            await applyImport(incoming, filename: filename, section: section)
        } catch {
            errorMessage = error.localizedDescription
        }
        isImporting = false
        importLabel = nil
    }

    private func applyImport(_ incoming: [MetricRow], filename: String, section: MetricSection) async {
        lastImportedSection = section
        seeded = true
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
            PulseCaches.build(rows: nextRows, filters: DashboardFilters(), uploads: nextUploads)
        }.value
        hydrating = true
        rows = nextRows
        uploads = nextUploads
        filters = DashboardFilters()
        install(caches)
        hydrating = false
        let stores = Set(incoming.map(\.storeNumber).filter { !$0.isEmpty }).count
        if section == .pickPathPicker {
            statusMessage = "Imported \(incoming.count) pickers into Pick Path Compliance Picker. Open a store on Pick Path to see them."
        } else if let validation = nextUploads.first?.validation {
            statusMessage = "Imported \(section.title): \(validation)"
        } else {
            statusMessage = "Imported \(incoming.count) rows · \(stores) stores into \(section.title). Filters cleared so the new file is in view."
        }
        await persistNow()
    }

    private func runMasterImport(data: Data, filename: String, fallbackToPicker: Bool) async -> Bool {
        guard !isImporting else { return false }
        isImporting = true
        importLabel = "Reading master workbook…"
        errorMessage = nil
        do {
            let sheets = try await Task.detached(priority: .userInitiated) {
                try WorkbookParser.parseMaster(data: data, filename: filename)
            }.value
            importLabel = "Updating \(sheets.count) scorecards…"
            var nextRows = rows
            var nextUploads = uploads
            var loaded: [String] = []
            for sheet in sheets {
                let incoming = sheet.rows.map { $0.asRow(section: sheet.section) }
                nextRows.removeAll { $0.section == sheet.section }
                nextRows.append(contentsOf: incoming)
                nextUploads.removeAll { $0.section == sheet.section }
                nextUploads.insert(
                    UploadRecord(
                        section: sheet.section,
                        filename: "\(filename) · \(sheet.sheetName)",
                        rowCount: incoming.count,
                        validation: Self.importAudit(section: sheet.section, rows: incoming)
                    ),
                    at: 0
                )
                loaded.append(sheet.section.short)
            }
            let caches = await Task.detached(priority: .userInitiated) {
                PulseCaches.build(rows: nextRows, filters: DashboardFilters(), uploads: nextUploads)
            }.value
            hydrating = true
            rows = nextRows
            uploads = nextUploads
            filters = DashboardFilters()
            install(caches)
            hydrating = false
            seeded = true
            lastImportedSection = sheets.first?.section
            let names = loaded.joined(separator: ", ")
            statusMessage = "Master load: \(loaded.count) scorecard\(loaded.count == 1 ? "" : "s") from \(filename) — \(names). Filters cleared so the new files are in view."
            await persistNow()
            isImporting = false
            importLabel = nil
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
        let identitySource = rows.filter {
            $0.section != .scheduleQuality && $0.section != .dynacap && $0.section != .pickerScorecard && $0.section != .pickPathPicker && $0.section != .lostRevenue
        }
        roster = HeartbeatMath.storeRoster(identitySource.isEmpty ? rows.filter { $0.section != .pickerScorecard && $0.section != .pickPathPicker } : identitySource)
        var latest: [MetricSection: [MetricRow]] = [:]
        for section in MetricSection.allCases {
            let sectionRows = rows.filter { $0.section == section }
            if section == .dynacap {
                latest[section] = HeartbeatMath.materializeDynacap(sectionRows, roster: roster)
            } else if section == .pickPath {
                latest[section] = HeartbeatMath.materializePickPath(sectionRows, roster: roster)
            } else if section == .scheduleQuality || section == .fiveStar || section == .prepNotReady || section == .pph || section == .lostRevenue || section == .missingItems {
                let source = section == .lostRevenue
                    ? sectionRows.filter { $0.textPayload["lost_grain"] != "market" }
                    : sectionRows
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(source), roster: roster)
            } else if section == .labor {
                let stores = sectionRows.filter { $0.textPayload["labor_grain"] == "store" }
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(stores), roster: roster)
            } else if section == .pickerScorecard || section == .pickPathPicker {
                latest[section] = HeartbeatMath.latestPerShopper(sectionRows)
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
        if !filters.isActive {
            if let pulse = unfilteredPulse, isCompanyWide(pulse) {
                install(pulse)
                filterStamp += 1
                return
            }
            installCompanyWideFast()
            filterStamp += 1
            warmUnfilteredPulse()
            return
        }

        let latest = latestBySection
        let rosterCopy = roster
        let uploadsCopy = uploads
        let current = filters
        let laborMarket = laborMarketRow()
        let lostMarket = lostRevenueMarketRow()
        refilterTask = Task.detached(priority: .userInitiated) {
            let caches = PulseCaches.refilter(
                latest: latest,
                roster: rosterCopy,
                filters: current,
                uploads: uploadsCopy,
                laborMarket: laborMarket,
                lostRevenueMarket: lostMarket
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled, self.filters == current else { return }
                let pulse = self.pulse(from: caches)
                self.install(pulse)
                self.filterStamp += 1
                if !current.isActive {
                    if self.isCompanyWide(pulse) {
                        self.unfilteredPulse = pulse
                    }
                } else {
                    self.warmUnfilteredPulse()
                }
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
            summaries: cachedSummaries
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
            summaries: caches.cachedSummaries
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
        var pphByStore: [String: Double] = [:]
        for row in latestBySection[.pph] ?? [] {
            if let value = row.number("pph") {
                pphByStore[HeartbeatMath.canonicalStore(row.storeNumber)] = value
            }
        }
        var pathByStore: [String: Double] = [:]
        for row in latestBySection[.pickPath] ?? [] {
            if let value = row.number("compliance_pct") {
                pathByStore[HeartbeatMath.canonicalStore(row.storeNumber)] = value
            }
        }
        filteredMarket = cachedStores.map { item in
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
        let laborMarket = laborMarketRow()
        let lostMarket = lostRevenueMarketRow()
        cachedSummaries = MetricSection.dashboardCards.map { section in
            var input = latestBySection[section] ?? []
            if section == .labor, let laborMarket { input.append(laborMarket) }
            if section == .lostRevenue, let lostMarket { input.append(lostMarket) }
            return HeartbeatMath.summarize(
                section,
                rows: input,
                upload: uploads.first { $0.section == section }
            )
        }
        objectWillChange.send()
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
        filteredLatest = pulse.filteredLatest
        cachedPickerBoard = pulse.pickerBoard
        pickerIndex = pulse.pickerIndex
        pickerFocusHealth = pulse.pickerFocusHealth
        pickPathPickersByStore = pulse.pickPathPickersByStore
        pickPathByShopper = pulse.pickPathByShopper
        pphPickersByStore = pulse.pphPickersByStore
        cachedChecklistGroups = pulse.checklistGroups
        filteredMarket = pulse.market
        cachedDistricts = pulse.districts
        cachedOMs = pulse.oms
        cachedStores = pulse.stores
        cachedSummaries = pulse.summaries
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
            allowed.insert(number)
        }
        return allowed
    }

    private func load() {
        let candidates = [snapshotURL] + Self.legacySnapshotURLs()
        guard let url = candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            rebuildIndex()
            applyFilters()
            isReady = true
            return
        }
        let filterFile = filtersURL
        let dest = snapshotURL
        Task.detached(priority: .userInitiated) {
            do {
                let decoded = try PulseDisk.read(from: url)
                var loadedFilters = decoded.filters
                if let overlay = try? Data(contentsOf: filterFile),
                   let saved = try? JSONDecoder().decode(DashboardFilters.self, from: overlay) {
                    loadedFilters = saved
                }
                let caches = PulseCaches.build(
                    rows: decoded.rows,
                    filters: loadedFilters,
                    uploads: decoded.uploads,
                    heavy: false
                )
                await MainActor.run {
                    self.hydrating = true
                    self.rows = decoded.rows
                    self.uploads = decoded.uploads.sorted { $0.uploadedAt > $1.uploadedAt }
                    self.seeded = decoded.seeded || !decoded.rows.isEmpty
                    self.filters = loadedFilters
                    self.filters.sanitize()
                    self.install(caches)
                    self.hydrating = false
                    self.isReady = true
                    self.warmUnfilteredPulse()
                }
                if url != dest {
                    try? PulseDisk.write(decoded, to: dest)
                }
                let heavy = PulseCaches.refilter(
                    latest: caches.latestBySection,
                    roster: caches.roster,
                    filters: loadedFilters,
                    uploads: decoded.uploads,
                    laborMarket: decoded.rows.first {
                        $0.section == .labor && $0.textPayload["labor_grain"] == "market"
                    },
                    lostRevenueMarket: decoded.rows.first {
                        $0.section == .lostRevenue && $0.textPayload["lost_grain"] == "market"
                    },
                    heavy: true
                )
                await MainActor.run {
                    self.mergeHeavy(heavy)
                    self.rebuildLaborWeekIndex()
                    self.warmUnfilteredPulse()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not load saved pulse: \(error.localizedDescription)"
                    self.rebuildIndex()
                    self.applyFilters()
                    self.isReady = true
                }
            }
        }
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
        pickerFocusHealth = caches.pickerFocusHealth
        pickPathPickersByStore = caches.pickPathPickersByStore
        pickPathByShopper = caches.pickPathByShopper
        pphPickersByStore = caches.pphPickersByStore
        refreshChecklistOpenCount()
        objectWillChange.send()
    }

    private func mergeHeavy(_ caches: PulseCaches) {
        cachedPickerBoard = caches.cachedPickerBoard
        cachedChecklistGroups = caches.cachedChecklistGroups
        pickerIndex = caches.pickerIndex
        pickerFocusHealth = caches.pickerFocusHealth
        pickPathPickersByStore = caches.pickPathPickersByStore
        pickPathByShopper = caches.pickPathByShopper
        pphPickersByStore = caches.pphPickersByStore
        refreshChecklistOpenCount()
        objectWillChange.send()
    }

    private func persist() {
        Task { await persistNow() }
    }

    private func persistNow() async {
        persistFilters()
        let snapshot = HeartbeatSnapshot(
            rows: rows,
            uploads: uploads,
            seeded: seeded,
            filters: filters
        )
        let url = snapshotURL
        do {
            try await Task.detached(priority: .userInitiated) {
                try PulseDisk.write(snapshot, to: url)
            }.value
        } catch {
            errorMessage = "Pulse did not save: \(error.localizedDescription). Keep Heartbeat open until the import finishes."
        }
    }

    private func persistBlocking() {
        persistFilters()
        let snapshot = HeartbeatSnapshot(
            rows: rows,
            uploads: uploads,
            seeded: seeded,
            filters: filters
        )
        do {
            try PulseDisk.write(snapshot, to: snapshotURL)
        } catch {
            errorMessage = "Pulse did not save: \(error.localizedDescription)"
        }
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
        let grain: String?
        if !filters.division.isEmpty || !filters.district.isEmpty || !filters.om.isEmpty || !filters.store.isEmpty {
            grain = "district"
        } else {
            grain = "division"
        }
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

    static func build(rows: [MetricRow], filters: DashboardFilters, uploads: [UploadRecord], heavy: Bool = true) -> PulseCaches {
        var bySection: [MetricSection: [MetricRow]] = [:]
        bySection.reserveCapacity(16)
        for row in rows {
            bySection[row.section, default: []].append(row)
        }
        var identitySource: [MetricRow] = []
        for (section, list) in bySection {
            if section != .scheduleQuality && section != .dynacap && section != .pickerScorecard && section != .pickPathPicker && section != .lostRevenue {
                identitySource.append(contentsOf: list)
            }
        }
        let roster = HeartbeatMath.storeRoster(
            identitySource.isEmpty
                ? rows.filter { $0.section != .pickerScorecard && $0.section != .pickPathPicker }
                : identitySource
        )
        var latest: [MetricSection: [MetricRow]] = [:]
        latest.reserveCapacity(MetricSection.allCases.count)
        for section in MetricSection.allCases {
            let sectionRows = bySection[section] ?? []
            if section == .dynacap {
                latest[section] = HeartbeatMath.materializeDynacap(sectionRows, roster: roster)
            } else if section == .pickPath {
                latest[section] = HeartbeatMath.materializePickPath(sectionRows, roster: roster)
            } else if section == .scheduleQuality || section == .fiveStar || section == .prepNotReady || section == .pph || section == .lostRevenue || section == .missingItems {
                let source = section == .lostRevenue
                    ? sectionRows.filter { $0.textPayload["lost_grain"] != "market" }
                    : sectionRows
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(source), roster: roster)
            } else if section == .labor {
                let stores = sectionRows.filter { $0.textPayload["labor_grain"] == "store" }
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(stores), roster: roster)
            } else if section == .pickerScorecard || section == .pickPathPicker {
                latest[section] = HeartbeatMath.latestPerShopper(sectionRows)
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
            heavy: heavy
        )
    }

    static func refilter(
        latest: [MetricSection: [MetricRow]],
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters,
        uploads: [UploadRecord],
        laborMarket: MetricRow? = nil,
        lostRevenueMarket: MetricRow? = nil,
        heavy: Bool = true
    ) -> PulseCaches {
        let allowed = pickerStoreSet(roster: roster, filters: filters)
        var nextLatest: [MetricSection: [MetricRow]] = [:]
        nextLatest.reserveCapacity(latest.count)
        if let allowed {
            for (section, rows) in latest {
                nextLatest[section] = rows.filter { allowed.contains(HeartbeatMath.canonicalStore($0.storeNumber)) }
            }
        } else {
            nextLatest = latest
        }
        let pickers = nextLatest[.pickerScorecard] ?? []
        let pickerBoard = heavy
            ? HeartbeatMath.pickerBoard(pickers)
            : HeartbeatMath.PickerBoard(shopperCount: pickers.count, opportunityCount: 0, strongCount: 0, opportunity: [], strong: [])
        let picker = heavy
            ? pickerIndexValues(pickers)
            : (index: [PickerFocus: [Int]](), health: [PickerFocus: Health]())
        let path = heavy
            ? pickPathIndexValues(scorecard: pickers, pathRows: latest[.pickPathPicker] ?? [])
            : (buckets: [String: [MetricRow]](), byShopper: [String: MetricRow]())
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
        let stores = seen.keys.sorted(by: HeartbeatFormat.storeOrder).map { ($0, seen[$0] ?? nil) }
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
            pphPickersByStore: pph
        )
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
            allowed.insert(number)
        }
        return allowed
    }

    private static func pickerIndexValues(_ pickers: [MetricRow]) -> (index: [PickerFocus: [Int]], health: [PickerFocus: Health]) {
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
                note(.strong, .good)
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
        for row in scorecard {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            for alias in HeartbeatMath.shopperAliases(row) {
                storesByShopper[alias, default: []].insert(store)
            }
        }
        var byShopper: [String: MetricRow] = [:]
        var buckets: [String: [MetricRow]] = [:]
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
