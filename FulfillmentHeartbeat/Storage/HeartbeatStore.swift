import Foundation

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
    @Published private(set) var isReady = false

    private let fileManager: FileManager
    private let snapshotURL: URL
    private let checklistURL: URL
    private var hydrating = false
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

    init(rootURL: URL? = nil) {
        fileManager = .default
        let root = rootURL ?? Self.defaultRoot()
        if !fileManager.fileExists(atPath: root.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        snapshotURL = root.appendingPathComponent("heartbeat.json")
        checklistURL = root.appendingPathComponent("checklist.json")
        rows = []
        uploads = []
        seeded = false
        filters = DashboardFilters()
        loadChecklist()
        load()
    }

    private static func defaultRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("FulfillmentHeartbeat", isDirectory: true)
    }

    func rows(for section: MetricSection, relaxUnknown: Bool = false) -> [MetricRow] {
        if relaxUnknown {
            return HeartbeatMath.filtered(
                latestBySection[section] ?? [],
                division: filters.division,
                district: filters.district,
                om: filters.om,
                store: filters.store,
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

    func displayRows(for section: MetricSection) -> [MetricRow] {
        let latest = filteredLatest[section] ?? []
        if section == .pickerScorecard { return latest }
        if !latest.isEmpty { return latest }
        return filteredMarket.map { store in
            MetricRow(
                section: section,
                division: store.division,
                operationsOM: store.om,
                storeNumber: store.storeNumber,
                payload: [:],
                textPayload: ["district": store.district, "placeholder": "1"]
            )
        }
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

    func pickerCount(for focus: PickerFocus) -> Int {
        pickerIndex[focus]?.count ?? 0
    }

    func pickerFocusHealth(for focus: PickerFocus) -> Health {
        pickerFocusHealth[focus] ?? Health.none
    }

    func pickerPage(focus: PickerFocus, sort: PickerSort, ascending: Bool, limit: Int) -> [MetricRow] {
        let pickers = filteredLatest[.pickerScorecard] ?? []
        let source = pickerIndex[focus] ?? []
        let idxs: [Int]
        switch sort {
        case .pph:
            if ascending {
                idxs = Array(source.prefix(limit))
            } else {
                idxs = Array(source.suffix(limit).reversed())
            }
        case .name:
            var ordered = source
            ordered.sort {
                let order = pickers[$0].shopperName.localizedStandardCompare(pickers[$1].shopperName)
                return ascending ? order == .orderedAscending : order == .orderedDescending
            }
            idxs = Array(ordered.prefix(limit))
        case .store:
            var ordered = source
            ordered.sort {
                let order: ComparisonResult
                if let a = Int(pickers[$0].storeNumber), let b = Int(pickers[$1].storeNumber) {
                    order = a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
                } else {
                    order = pickers[$0].storeNumber.localizedStandardCompare(pickers[$1].storeNumber)
                }
                return ascending ? order == .orderedAscending : order == .orderedDescending
            }
            idxs = Array(ordered.prefix(limit))
        }
        return idxs.map { pickers[$0] }
    }

    private func rebuildPickerIndex(_ pickers: [MetricRow]) {
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

        pickerIndex = buckets
        pickerFocusHealth = worst
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

    var checklistOpenCount: Int {
        var count = 0
        for section in MetricSection.checklistSections {
            var seen = Set<String>()
            var shown = 0
            for group in cachedChecklistGroups[section] ?? [] {
                for item in group.items {
                    guard seen.insert(item.title + "|" + item.subtitle).inserted else { continue }
                    if !checklistItem(for: item, section: section).status.isClosed {
                        count += 1
                    }
                    shown += 1
                    if shown == 5 { break }
                }
                if shown == 5 { break }
            }
        }
        return count
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
                    lines.append("  Status: \(action.status.label) · \(HeartbeatFormat.stamp(action.updatedAt))")
                    if !action.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lines.append("  Comments: \(action.comment)")
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
                    if !action.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        html += "<div class=\"comment\">\(escape(action.comment))</div>"
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
            .replacingOccurrences(of: "&", with: "&")
            .replacingOccurrences(of: "<", with: "<")
            .replacingOccurrences(of: ">", with: ">")
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
                let cell = StoreCellViewModel.make(section: section, row: row)
                let health = HeartbeatMath.health(for: section, row: row)
                let division = row.division.isEmpty ? identity(forStore: row.storeNumber).division : row.division
                return ChecklistDriverItem(
                    id: "store-\(HeartbeatMath.canonicalStore(row.storeNumber))",
                    title: "Store \(row.storeNumber)",
                    subtitle: division.isEmpty ? "Store" : division,
                    value: cell.primary,
                    health: health
                )
            }
            if !items.isEmpty {
                groups[section] = [ChecklistDriverGroup(title: "Top \(items.count) opportunity stores", items: items)]
            }
        }
        let pickerGroups = HeartbeatMath.topPickersByMetric(latest[.pickerScorecard] ?? [], limit: 10).map { board -> ChecklistDriverGroup in
            ChecklistDriverGroup(
                title: "Top \(board.rows.count) \(board.metric)",
                items: board.rows.map { row in
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
                        health: HeartbeatMath.pickerHealth(row)
                    )
                }
            )
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
                division: filters.division,
                district: filters.district,
                om: filters.om,
                store: filters.store,
                relaxUnknown: false,
                universe: sectionRows + latestUniverse
            )
        )
    }

    func setDivision(_ value: String) {
        replaceFilters(DashboardFilters(division: value, district: "", om: "", store: ""))
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

    func clearFilters() {
        replaceFilters(DashboardFilters())
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

    func importWorkbook(url: URL, section: MetricSection) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            Task { await runImport(data: data, filename: url.lastPathComponent, section: section) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importWorkbook(data: Data, filename: String, section: MetricSection) {
        Task { await runImport(data: data, filename: filename, section: section) }
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
            applyImport(incoming, filename: filename, section: section)
        } catch {
            errorMessage = error.localizedDescription
        }
        isImporting = false
        importLabel = nil
    }

    private func applyImport(_ incoming: [MetricRow], filename: String, section: MetricSection) {
        rows.removeAll { $0.section == section }
        rows.append(contentsOf: incoming)
        uploads.removeAll { $0.section == section }
        uploads.insert(UploadRecord(section: section, filename: filename, rowCount: incoming.count), at: 0)
        seeded = true
        lastImportedSection = section
        rebuildIndex()
        replaceFilters(DashboardFilters())
        let stores = Set(incoming.map(\.storeNumber).filter { !$0.isEmpty }).count
        statusMessage = "Imported \(incoming.count) rows · \(stores) stores into \(section.title). Filters cleared so the new file is in view."
        persist()
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
            .filter { $0 != .pickerScorecard }
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
        let identitySource = rows.filter {
            $0.section != .scheduleQuality && $0.section != .dynacap && $0.section != .pickerScorecard
        }
        roster = HeartbeatMath.storeRoster(identitySource.isEmpty ? rows.filter { $0.section != .pickerScorecard } : identitySource)
        var latest: [MetricSection: [MetricRow]] = [:]
        for section in MetricSection.allCases {
            let sectionRows = rows.filter { $0.section == section }
            if section == .dynacap {
                latest[section] = HeartbeatMath.materializeDistrictMetric(sectionRows, roster: roster)
            } else if section == .pickPath {
                latest[section] = HeartbeatMath.materializePickPath(sectionRows, roster: roster)
            } else if section == .scheduleQuality || section == .fiveStar || section == .prepNotReady || section == .pph {
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(sectionRows), roster: roster)
            } else if section == .pickerScorecard {
                latest[section] = HeartbeatMath.latestPerShopper(sectionRows)
            } else {
                latest[section] = HeartbeatMath.latestPerStore(sectionRows)
            }
        }
        latestBySection = latest
        cachedDivisions = roster.values.map(\.division).filter { !$0.isEmpty }.uniqued().sorted()
    }

    private func applyFilters() {
        let universe = latestUniverse
        var nextLatest: [MetricSection: [MetricRow]] = [:]
        for section in MetricSection.allCases where section != .pickerScorecard {
            nextLatest[section] = HeartbeatMath.filtered(
                latestBySection[section] ?? [],
                division: filters.division,
                district: filters.district,
                om: filters.om,
                store: filters.store,
                relaxUnknown: false,
                universe: universe
            )
        }
        let pickers = latestBySection[.pickerScorecard] ?? []
        if let allowed = pickerStoreSet() {
            nextLatest[.pickerScorecard] = pickers.filter { allowed.contains(HeartbeatMath.canonicalStore($0.storeNumber)) }
        } else {
            nextLatest[.pickerScorecard] = pickers
        }
        filteredLatest = nextLatest
        cachedPickerBoard = HeartbeatMath.pickerBoard(nextLatest[.pickerScorecard] ?? [])
        rebuildPickerIndex(nextLatest[.pickerScorecard] ?? [])
        cachedChecklistGroups = buildChecklistGroups(nextLatest)
        filteredMarket = HeartbeatMath.marketBoard(
            universe,
            division: filters.division,
            district: filters.district,
            om: filters.om,
            store: filters.store
        )
        refreshFilterOptions()
        cachedSummaries = MetricSection.dashboardCards.map { section in
            var summary = HeartbeatMath.summarize(section, rows: nextLatest[section] ?? [], upload: upload(for: section))
            if summary.storeCount == 0, !filteredMarket.isEmpty {
                summary.secondary = "No \(section.short) data for \(filteredMarket.count) stores in this filter"
                summary.health = .none
            }
            return summary
        }
        objectWillChange.send()
    }

    private func refreshFilterOptions() {
        cachedDistricts = roster.values
            .filter { filters.division.isEmpty || HeartbeatMath.matches($0.division, filters.division) }
            .map(\.district)
            .filter { !$0.isEmpty }
            .uniqued()
            .sorted()
        cachedOMs = roster.values
            .filter { filters.division.isEmpty || HeartbeatMath.matches($0.division, filters.division) }
            .filter { filters.district.isEmpty || HeartbeatMath.matches($0.district, filters.district) }
            .map(\.om)
            .filter { value in
                !value.isEmpty && value.rangeOfCharacter(from: .letters) != nil
            }
            .uniqued()
            .sorted()
        var seen: [String: String?] = [:]
        for (number, identity) in roster {
            if !filters.division.isEmpty, !HeartbeatMath.matches(identity.division, filters.division) { continue }
            if !filters.district.isEmpty, !HeartbeatMath.matches(identity.district, filters.district) { continue }
            if !filters.om.isEmpty, !HeartbeatMath.matches(identity.om, filters.om) { continue }
            if seen[number] == nil { seen[number] = identity.name }
        }
        cachedStores = seen.keys.sorted(by: HeartbeatFormat.storeOrder).map { ($0, seen[$0] ?? nil) }
    }

    private func pickerStoreSet() -> Set<String>? {
        if filters.division.isEmpty, filters.district.isEmpty, filters.om.isEmpty, filters.store.isEmpty {
            return nil
        }
        var allowed: Set<String> = []
        for (number, identity) in roster {
            if !filters.division.isEmpty, !HeartbeatMath.matches(identity.division, filters.division) { continue }
            if !filters.district.isEmpty, !HeartbeatMath.matches(identity.district, filters.district) { continue }
            if !filters.om.isEmpty, !HeartbeatMath.matches(identity.om, filters.om) { continue }
            if !filters.store.isEmpty, !HeartbeatMath.matches(number, filters.store) { continue }
            allowed.insert(number)
        }
        return allowed
    }

    private func load() {
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            rebuildIndex()
            applyFilters()
            isReady = true
            return
        }
        let url = snapshotURL
        Task.detached(priority: .userInitiated) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decoded = try decoder.decode(HeartbeatSnapshot.self, from: data)
                let caches = PulseCaches.build(rows: decoded.rows, filters: decoded.filters, uploads: decoded.uploads)
                try? await Task.sleep(nanoseconds: 120_000_000)
                await MainActor.run {
                    self.hydrating = true
                    self.rows = decoded.rows
                    self.uploads = decoded.uploads.sorted { $0.uploadedAt > $1.uploadedAt }
                    self.seeded = decoded.seeded
                    self.filters = decoded.filters
                    self.install(caches)
                    self.hydrating = false
                    self.isReady = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not load saved pulse: \(error.localizedDescription)"
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
        rebuildPickerIndex(caches.filteredLatest[.pickerScorecard] ?? [])
        objectWillChange.send()
    }

    private func persist() {
        let snapshot = HeartbeatSnapshot(
            rows: rows,
            uploads: uploads,
            seeded: seeded,
            filters: filters
        )
        let url = snapshotURL
        Task.detached(priority: .utility) {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: [.atomic])
            } catch {
                // Keep the in-memory pulse; the next successful save will replace this file.
            }
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

    static func build(rows: [MetricRow], filters: DashboardFilters, uploads: [UploadRecord]) -> PulseCaches {
        let identitySource = rows.filter {
            $0.section != .scheduleQuality && $0.section != .dynacap && $0.section != .pickerScorecard
        }
        let roster = HeartbeatMath.storeRoster(
            identitySource.isEmpty ? rows.filter { $0.section != .pickerScorecard } : identitySource
        )
        var latest: [MetricSection: [MetricRow]] = [:]
        for section in MetricSection.allCases {
            let sectionRows = rows.filter { $0.section == section }
            if section == .dynacap {
                latest[section] = HeartbeatMath.materializeDistrictMetric(sectionRows, roster: roster)
            } else if section == .pickPath {
                latest[section] = HeartbeatMath.materializePickPath(sectionRows, roster: roster)
            } else if section == .scheduleQuality || section == .fiveStar || section == .prepNotReady || section == .pph {
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(sectionRows), roster: roster)
            } else if section == .pickerScorecard {
                latest[section] = HeartbeatMath.latestPerShopper(sectionRows)
            } else {
                latest[section] = HeartbeatMath.latestPerStore(sectionRows)
            }
        }
        return refilter(latest: latest, roster: roster, filters: filters, uploads: uploads)
    }

    static func refilter(
        latest: [MetricSection: [MetricRow]],
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters,
        uploads: [UploadRecord]
    ) -> PulseCaches {
        let universe = MetricSection.allCases
            .filter { $0 != .pickerScorecard }
            .flatMap { latest[$0] ?? [] }
        var nextLatest: [MetricSection: [MetricRow]] = [:]
        for section in MetricSection.allCases where section != .pickerScorecard {
            nextLatest[section] = HeartbeatMath.filtered(
                latest[section] ?? [],
                division: filters.division,
                district: filters.district,
                om: filters.om,
                store: filters.store,
                relaxUnknown: false,
                universe: universe
            )
        }
        let pickers = latest[.pickerScorecard] ?? []
        if let allowed = pickerStoreSet(roster: roster, filters: filters) {
            nextLatest[.pickerScorecard] = pickers.filter { allowed.contains(HeartbeatMath.canonicalStore($0.storeNumber)) }
        } else {
            nextLatest[.pickerScorecard] = pickers
        }
        let pickerBoard = HeartbeatMath.pickerBoard(nextLatest[.pickerScorecard] ?? [])
        let market = HeartbeatMath.marketBoard(
            universe,
            division: filters.division,
            district: filters.district,
            om: filters.om,
            store: filters.store
        )
        let districts = roster.values
            .filter { filters.division.isEmpty || HeartbeatMath.matches($0.division, filters.division) }
            .map(\.district)
            .filter { !$0.isEmpty }
            .uniqued()
            .sorted()
        let oms = roster.values
            .filter { filters.division.isEmpty || HeartbeatMath.matches($0.division, filters.division) }
            .filter { filters.district.isEmpty || HeartbeatMath.matches($0.district, filters.district) }
            .map(\.om)
            .filter { value in !value.isEmpty && value.rangeOfCharacter(from: .letters) != nil }
            .uniqued()
            .sorted()
        var seen: [String: String?] = [:]
        for (number, identity) in roster {
            if !filters.division.isEmpty, !HeartbeatMath.matches(identity.division, filters.division) { continue }
            if !filters.district.isEmpty, !HeartbeatMath.matches(identity.district, filters.district) { continue }
            if !filters.om.isEmpty, !HeartbeatMath.matches(identity.om, filters.om) { continue }
            if seen[number] == nil { seen[number] = identity.name }
        }
        let stores = seen.keys.sorted(by: HeartbeatFormat.storeOrder).map { ($0, seen[$0] ?? nil) }
        let summaries = MetricSection.dashboardCards.map { section -> SectionSummary in
            var summary = HeartbeatMath.summarize(
                section,
                rows: nextLatest[section] ?? [],
                upload: uploads.first { $0.section == section }
            )
            if summary.storeCount == 0, !market.isEmpty {
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
            cachedDivisions: roster.values.map(\.division).filter { !$0.isEmpty }.uniqued().sorted(),
            cachedDistricts: districts,
            cachedOMs: oms,
            cachedStores: stores,
            cachedSummaries: summaries,
            cachedPickerBoard: pickerBoard,
            cachedChecklistGroups: checklistGroups(from: nextLatest, roster: roster)
        )
    }

    private static func pickerStoreSet(
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters
    ) -> Set<String>? {
        if filters.division.isEmpty, filters.district.isEmpty, filters.om.isEmpty, filters.store.isEmpty {
            return nil
        }
        var allowed: Set<String> = []
        for (number, identity) in roster {
            if !filters.division.isEmpty, !HeartbeatMath.matches(identity.division, filters.division) { continue }
            if !filters.district.isEmpty, !HeartbeatMath.matches(identity.district, filters.district) { continue }
            if !filters.om.isEmpty, !HeartbeatMath.matches(identity.om, filters.om) { continue }
            if !filters.store.isEmpty, !HeartbeatMath.matches(number, filters.store) { continue }
            allowed.insert(number)
        }
        return allowed
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
                let cell = StoreCellViewModel.make(section: section, row: row)
                let health = HeartbeatMath.health(for: section, row: row)
                let division = row.division.isEmpty ? identity(roster, store: row.storeNumber).division : row.division
                return ChecklistDriverItem(
                    id: "store-\(HeartbeatMath.canonicalStore(row.storeNumber))",
                    title: "Store \(row.storeNumber)",
                    subtitle: division.isEmpty ? "Store" : division,
                    value: cell.primary,
                    health: health
                )
            }
            if !items.isEmpty {
                groups[section] = [ChecklistDriverGroup(title: "Top \(items.count) opportunity stores", items: items)]
            }
        }
        let pickerGroups = HeartbeatMath.topPickersByMetric(latest[.pickerScorecard] ?? [], limit: 10).map { board -> ChecklistDriverGroup in
            ChecklistDriverGroup(
                title: "Top \(board.rows.count) \(board.metric)",
                items: board.rows.map { row in
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
                        health: HeartbeatMath.pickerHealth(row)
                    )
                }
            )
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
