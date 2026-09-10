import Foundation

enum PulseMail {
    struct Packet: Sendable {
        let subject: String
        let html: String
        let htmlFile: URL?
        let plain: String
        let brief: String
    }

    struct MailSums {
        var salesDollars: Double = 0
        var salesOrders: Double = 0
        var hdOrders: Double = 0
        var dugOrders: Double = 0
        var ecommSales: Double = 0
        var postSub: Double = 0
    }

    struct Snapshot {
        var filterSummary: String
        var grain: String?
        var summaries: [SectionSummary]
        var rows: [MetricSection: [MetricRow]]
        var pickerCounts: [String: Int]
        var generatedAt: Date
        var rowTotals: [MetricSection: Int] = [:]
        var grainTables: [MetricSection: [HeartbeatMath.DashboardGrainTableRow]] = [:]
        var flags: [MetricSection: [HeartbeatMath.FiveStarFlag]] = [:]
        var sums = MailSums()
    }

    enum SharePage: String, CaseIterable, Identifiable, Hashable, Sendable {
        case dashboard
        case sales
        case lostRevenue
        case missingItems
        case fiveStar
        case preSubOOS
        case pickPath
        case prepNotReady
        case dynacap
        case scheduleQuality
        case pickerScorecard
        case pph
        case labor

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .sales: return MetricSection.sales.bannerTitle
            case .lostRevenue: return "Loss Revenue ScoreCard"
            case .missingItems: return MetricSection.missingItems.bannerTitle
            case .fiveStar: return MetricSection.fiveStar.bannerTitle
            case .preSubOOS: return MetricSection.preSubOOS.bannerTitle
            case .pickPath: return MetricSection.pickPath.bannerTitle
            case .prepNotReady: return MetricSection.prepNotReady.bannerTitle
            case .dynacap: return MetricSection.dynacap.bannerTitle
            case .scheduleQuality: return MetricSection.scheduleQuality.bannerTitle
            case .pickerScorecard: return MetricSection.pickerScorecard.bannerTitle
            case .pph: return MetricSection.pph.bannerTitle
            case .labor: return MetricSection.labor.bannerTitle
            }
        }

        var symbol: String {
            switch self {
            case .dashboard: return "waveform.path.ecg"
            case .sales: return MetricSection.sales.symbol
            case .lostRevenue: return MetricSection.lostRevenue.symbol
            case .missingItems: return MetricSection.missingItems.symbol
            case .fiveStar: return MetricSection.fiveStar.symbol
            case .preSubOOS: return MetricSection.preSubOOS.symbol
            case .pickPath: return MetricSection.pickPath.symbol
            case .prepNotReady: return MetricSection.prepNotReady.symbol
            case .dynacap: return MetricSection.dynacap.symbol
            case .scheduleQuality: return MetricSection.scheduleQuality.symbol
            case .pickerScorecard: return MetricSection.pickerScorecard.symbol
            case .pph: return MetricSection.pph.symbol
            case .labor: return MetricSection.labor.symbol
            }
        }

        var section: MetricSection? {
            switch self {
            case .dashboard: return nil
            case .sales: return .sales
            case .lostRevenue: return .lostRevenue
            case .missingItems: return .missingItems
            case .fiveStar: return .fiveStar
            case .preSubOOS: return .preSubOOS
            case .pickPath: return .pickPath
            case .prepNotReady: return .prepNotReady
            case .dynacap: return .dynacap
            case .scheduleQuality: return .scheduleQuality
            case .pickerScorecard: return .pickerScorecard
            case .pph: return .pph
            case .labor: return .labor
            }
        }

        static func from(destination: HubDestination) -> SharePage {
            switch destination {
            case .dashboard: return .dashboard
            case .sales: return .sales
            case .lostRevenue: return .lostRevenue
            case .missingItems: return .missingItems
            case .fiveStar: return .fiveStar
            case .preSubOOS: return .preSubOOS
            case .pickPath: return .pickPath
            case .prepNotReady: return .prepNotReady
            case .dynacap: return .dynacap
            case .scheduleQuality: return .scheduleQuality
            case .pickerScorecard: return .pickerScorecard
            case .pph: return .pph
            case .labor: return .labor
            }
        }
    }

    static let pageOrder: [MetricSection] = [
        .sales, .lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .prepNotReady, .dynacap,
        .scheduleQuality, .pickerScorecard, .pph, .labor,
    ]

    /// Share sends the current filtered page: every grain/store row the user sees.
    /// Jetsam safety is the file-URL path, not truncating the view.
    static func pageRows(_ rows: [MetricRow], section: MetricSection) -> [MetricRow] {
        _ = section
        return rows
    }

    static func make(
        _ snap: Snapshot,
        pages: Set<SharePage> = Set(SharePage.allCases),
        persistHTML: Bool = true
    ) -> Packet {
        let chosen = pages.isEmpty ? Set(SharePage.allCases) : pages
        let names = SharePage.allCases.filter { chosen.contains($0) }.map(\.title)
        let subject = "Fulfillment Heartbeat — \(snap.filterSummary) — \(HeartbeatFormat.stamp(snap.generatedAt))"
        return autoreleasepool {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Fulfillment-Heartbeat-\(UUID().uuidString).html")
            let sink = HTMLSink(keepString: persistHTML, fileURL: url)
            writeHTML(snap, pages: chosen, to: sink)
            sink.close()
            let htmlString = persistHTML ? sink.string : ""
            let file: URL?
            if sink.wroteFile {
                file = url
            } else if persistHTML {
                file = writeHTMLStreaming(htmlString)
            } else {
                file = nil
            }
            return Packet(
                subject: subject,
                html: htmlString,
                htmlFile: file,
                plain: persistHTML ? plain(snap, pages: chosen) : "",
                brief: brief(snap, pages: chosen, names: names)
            )
        }
    }

    /// Stream HTML to a temp file in small UTF-8 chunks so Share never holds a second giant `Data`.
    static func writeHTMLStreaming(_ html: String) -> URL? {
        guard !html.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Fulfillment-Heartbeat-\(UUID().uuidString).html")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: url) else {
            guard let data = html.data(using: .utf8) else { return nil }
            do {
                try data.write(to: url, options: .atomic)
                return url
            } catch {
                return nil
            }
        }
        defer { try? handle.close() }
        let chunk = 24_576
        var start = html.startIndex
        while start < html.endIndex {
            let end = html.index(start, offsetBy: chunk, limitedBy: html.endIndex) ?? html.endIndex
            if let data = html[start..<end].data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
            start = end
        }
        return url
    }

    /// Activity-item payload: file URL or brief. Never the HTML string (Mail/Gmail attributed-string Jetsam).
    static func shareActivityItem(_ packet: Packet) -> Any {
        packet.htmlFile ?? packet.brief
    }

    /// HTML Mail can put in the message body. Reads the file when it fits the cap; never a giant string.
    static func html(from packet: Packet) -> String {
        if let url = packet.htmlFile {
            let bytes = PulseLaunch.fileBytes(at: url)
            if PulseLaunch.shouldSetHTMLMessageBody(utf8Count: bytes),
               let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
                return text
            }
        }
        if PulseLaunch.shouldSetHTMLMessageBody(utf8Count: packet.html.utf8.count) {
            return packet.html
        }
        return ""
    }

    /// Short in-body note when the full recap is too large for Mail's message body.
    static func overflowMailBody(_ brief: String) -> String {
        """
        <html><body style="margin:0;padding:20px;background:#F5F7FC;color:#141A29;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:16px;line-height:1.45">
        <p style="color:#003DA5;font-weight:700;font-size:18px;margin:0 0 12px">Fulfillment Heartbeat</p>
        <p style="margin:0 0 16px">The full recap is attached as HTML — open it to see the same cards, callouts, and tables as the app.</p>
        <pre style="white-space:pre-wrap;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:15px;color:#141A29">\(esc(brief))</pre>
        </body></html>
        """
    }

    static func briefPacket(_ snap: Snapshot, pages: Set<SharePage>) -> Packet {
        let chosen = pages.isEmpty ? Set(SharePage.allCases) : pages
        let names = SharePage.allCases.filter { chosen.contains($0) }.map(\.title)
        let subject = "Fulfillment Heartbeat — \(snap.filterSummary) — \(HeartbeatFormat.stamp(snap.generatedAt))"
        return Packet(
            subject: subject,
            html: "",
            htmlFile: nil,
            plain: "",
            brief: brief(snap, pages: chosen, names: names)
        )
    }

    /// Writes one section at a time so the full filtered page can land in a file
    /// without keeping the giant HTML string (or an attributed string) in RAM.
    private final class HTMLSink {
        private var chunks: [String] = []
        private let keepString: Bool
        private var handle: FileHandle?
        let fileURL: URL?
        private(set) var wroteFile = false

        init(keepString: Bool, fileURL: URL?) {
            self.keepString = keepString
            self.fileURL = fileURL
            if let fileURL {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                handle = try? FileHandle(forWritingTo: fileURL)
            }
        }

        func append(_ text: String) {
            if keepString { chunks.append(text) }
            if let handle, let data = text.data(using: .utf8) {
                try? handle.write(contentsOf: data)
                wroteFile = true
            }
        }

        func close() {
            try? handle?.synchronize()
            try? handle?.close()
            handle = nil
        }

        var string: String { chunks.joined() }

        deinit { close() }
    }

    private static func brief(_ snap: Snapshot, pages: Set<SharePage>, names: [String]) -> String {
        var lines = [
            "Fulfillment Heartbeat",
            snap.filterSummary,
            HeartbeatFormat.stamp(snap.generatedAt),
            "Pages: \(names.joined(separator: ", "))",
            "",
        ]
        if pages.contains(.dashboard) {
            lines.append("DASHBOARD")
            for card in snap.summaries {
                lines.append("\(card.section.title): \(card.headlineText) · \(card.health.label) · \(riskLine(card.section, card))")
            }
        }
        lines.append("")
        lines.append("Sent from Fulfillment Heartbeat")
        return lines.joined(separator: "\n")
    }

    /// One section at a time so Share can stream the full filtered page to a file.
    private static func writeHTML(_ snap: Snapshot, pages: Set<SharePage>, to sink: HTMLSink) {
        sink.append(htmlHead(snap))
        if pages.contains(.dashboard) {
            sink.append(dashboardHTML(snap))
        }
        for page in SharePage.allCases {
            guard page != .dashboard, pages.contains(page), let section = page.section else { continue }
            sink.append(sectionHTML(section, snap: snap))
        }
        sink.append("<p class=\"sub\" style=\"color:#3D4658;font-size:16px;margin:18px 0 0\">Sent from Fulfillment Heartbeat</p></div></body></html>")
    }

    private static func html(_ snap: Snapshot, pages: Set<SharePage>) -> String {
        let sink = HTMLSink(keepString: true, fileURL: nil)
        writeHTML(snap, pages: pages, to: sink)
        sink.close()
        return sink.string
    }

    private static func htmlHead(_ snap: Snapshot) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body{margin:0;padding:24px 20px;background:#F5F7FC;color:#141A29;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:16px;line-height:1.45}
        .wrap{width:100%;max-width:100%;margin:0 auto}
        h1{font-size:28px;line-height:1.2;margin:0 0 8px;color:#003DA5}
        .sub{color:#3D4658;font-size:16px;margin:0 0 22px;line-height:1.5}
        .block-title{font-size:18px;font-weight:700;color:#003DA5;margin:18px 0 8px}
        .block-title span{display:block;font-size:14px;font-weight:600;color:#5C677A;margin-top:2px}
        table.layout{width:100%;border-collapse:separate;border-spacing:10px 10px}
        table.layout td{vertical-align:top}
        .table-wrap{width:100%;overflow-x:auto;-webkit-overflow-scrolling:touch;margin:0 0 8px}
        table.data{width:100%;border-collapse:collapse;font-size:15px;min-width:680px}
        table.data th{text-align:left;font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:#003DA5;background:#EEF3FB;padding:8px 8px;border-bottom:2px solid #003DA5;white-space:nowrap;font-weight:700}
        table.data td{padding:8px;border-bottom:1px solid #E4E9F4;vertical-align:middle}
        table.data td.name{font-weight:700;font-size:16px;white-space:nowrap}
        table.data td.num,.num{text-align:right;font-variant-numeric:tabular-nums;font-weight:700;font-size:16px;white-space:nowrap}
        .dash-card{margin:0 0 14px;border-radius:16px;overflow:hidden}
        .page-banner{font-size:18px;font-weight:700;color:#003DA5;margin:0 0 12px}
        table.data td.status{text-align:right;white-space:nowrap;width:108px}
        table.data th.num,table.data th.status{text-align:right}
        .nw{text-align:right;font-variant-numeric:tabular-nums;font-weight:700}
        .pill{display:inline-block;padding:5px 12px;border-radius:999px;font-size:12px;line-height:1.2;font-weight:700;color:#fff;letter-spacing:.02em}
        .good{background:#059669;color:#fff}
        .watch{background:#D97706;color:#fff}
        .risk{background:#DC2626;color:#fff}
        .none{background:#8A93A3;color:#fff}
        .cell-good{background:#D1FAE5;color:#059669}
        .cell-watch{background:#FEF3C7;color:#D97706}
        .cell-risk{background:#FEE2E2;color:#DC2626}
        .muted{color:#5C677A}
        </style></head><body style="margin:0;padding:24px 20px;background:#F5F7FC;color:#141A29;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:16px;line-height:1.45"><div class="wrap" style="width:100%;max-width:100%;margin:0 auto">
        <h1 style="font-size:28px;line-height:1.2;margin:0 0 8px;color:#003DA5">Fulfillment Heartbeat</h1>
        <p class="sub" style="color:#3D4658;font-size:16px;margin:0 0 22px;line-height:1.5">\(esc(snap.filterSummary))<br>\(esc(HeartbeatFormat.stamp(snap.generatedAt))) · Same layout and columns as the in-app page · Upload is not included</p>
        """
    }

    private static func dashboardHTML(_ snap: Snapshot) -> String {
        var cards = """
        <div class="page-banner" style="font-size:18px;font-weight:700;color:#003DA5;margin:0 0 12px">Operational Heartbeat · \(esc(snap.filterSummary))</div>
        """
        let grain = dashGrain(snap)
        for card in snap.summaries {
            let flags = dashboardFlagModels(card.section, snap: snap)
            var flagHTML = ""
            if !flags.isEmpty {
                flagHTML = flagGridHTML(flags)
            }
            let title = card.section == .pickPath ? "Pick Path Compliance" : card.section.title
            let accent = ink(card.health)
            cards += """
            <table class="dash-card" width="100%" cellspacing="0" cellpadding="0" bgcolor="#FFFFFF" style="background:#FFFFFF;border:1px solid #E4E9F4;border-radius:16px;margin:0 0 14px">
            <tr>
            <td width="4" bgcolor="\(accent)" style="background:\(accent);width:4px;font-size:0;line-height:0">&nbsp;</td>
            <td style="padding:16px 18px">
            <table width="100%" cellspacing="0" cellpadding="0">
            <tr>
            <td valign="top">
            <div style="font-size:22px;font-weight:700;color:#141A29">\(esc(title))</div>
            <div style="color:#5C677A;font-size:15px;margin-top:4px">\(esc(card.headlineLabel))</div>
            <div style="font-weight:700;margin-top:6px;font-size:16px;color:\(card.riskCount == 0 ? ink(.good) : ink(.risk))">\(esc(riskLine(card.section, card)))</div>
            </td>
            <td valign="top" align="right" style="width:190px;white-space:nowrap">
            <div class="nw" style="font-size:32px;font-weight:700;color:\(accent);text-align:right">\(esc(card.headlineText))</div>
            <div style="margin-top:8px">\(pill(card.health))</div>
            </td>
            </tr>
            </table>
            \(flagHTML)
            \(grainHTML(card.section, snap: snap, grain: grain))
            </td>
            </tr>
            </table>
            """
        }
        return cards
    }

    private static func flagGridHTML(_ flags: [HeartbeatMath.FiveStarFlag]) -> String {
        guard !flags.isEmpty else { return "" }
        let perRow = HubLayout.calloutColumns(count: flags.count, width: HubLayout.SupportedCanvas.padLandscape)
        var rows = ""
        var index = 0
        while index < flags.count {
            let end = min(index + perRow, flags.count)
            var cells = ""
            let slice = Array(flags[index..<end])
            for flag in slice {
                let tone = flag.health == .none ? Health.good : flag.health
                let accent = ink(tone)
                let unit = flag.stores == 1 ? String(flag.unit.dropLast()) : flag.unit
                let stores = "\(HeartbeatFormat.num(Double(flag.stores)))&nbsp;\(esc(unit))"
                let valueLine = flag.value.isEmpty
                    ? ""
                    : "<div class=\"nw\" style=\"font-size:20px;font-weight:700;margin-top:6px;color:\(accent);text-align:left\">\(esc(flag.value))</div>"
                cells += """
                <td width="\(100 / perRow)%" valign="top" style="padding:4px">
                <table width="100%" cellspacing="0" cellpadding="0" bgcolor="#FFFFFF" style="background:#FFFFFF;border:1px solid #E4E9F4;border-radius:12px">
                <tr>
                <td width="4" bgcolor="\(accent)" style="background:\(accent);width:4px;font-size:0;line-height:0">&nbsp;</td>
                <td style="padding:10px 12px">
                <div style="font-size:14px;color:#141A29;font-weight:700">\(esc(flag.name))</div>
                \(valueLine)
                <div class="nw" style="font-size:14px;font-weight:600;margin-top:6px;color:#5C677A;text-align:left">\(stores)</div>
                <div style="margin-top:8px">\(pill(tone))</div>
                </td></tr>
                </table>
                </td>
                """
            }
            if slice.count < perRow {
                for _ in slice.count..<perRow {
                    cells += "<td width=\"\(100 / perRow)%\"></td>"
                }
            }
            rows += "<tr>\(cells)</tr>"
            index = end
        }
        return "<table class=\"layout\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"margin-top:12px\">\(rows)</table>"
    }

    private static func flagCaption(_ flag: HeartbeatMath.FiveStarFlag) -> String {
        var parts: [String] = []
        if !flag.value.isEmpty { parts.append(flag.value) }
        if flag.stores > 0 || flag.value.isEmpty {
            let unit = flag.stores == 1 ? String(flag.unit.dropLast()) : flag.unit
            parts.append("\(HeartbeatFormat.num(Double(flag.stores))) \(unit)")
        }
        return parts.joined(separator: " · ")
    }

    private static func dashGrain(_ snap: Snapshot) -> DashScopeGrain {
        switch snap.grain {
        case "store": return .store
        case "district": return .district
        case "division": return .division
        default: return .region
        }
    }

    private static func grainHTML(_ section: MetricSection, snap: Snapshot, grain: DashScopeGrain) -> String {
        if let cached = snap.grainTables[section], !cached.isEmpty,
           PulseLaunch.grainTableMatchesCurrent(labels: cached.map(\.label), grain: grain) {
            return grainTableHTML(cached, section: section, grain: grain)
        }
        let rows = (snap.rows[section] ?? []).filter { $0.textPayload["sales_grain"] != "company" }
        let lines = HeartbeatMath.dashboardScopeLines(section: section, rows: rows, grain: grain)
            .filter { $0.label != "Unassigned" && !$0.label.isEmpty }
        guard !lines.isEmpty else { return "" }
        if section == .sales {
            return salesGrainTable(rows: rows, grain: grain, order: lines.map(\.label))
        }
        let table = HeartbeatMath.dashboardGrainTableFilled(
            section: section,
            rows: rows,
            grain: grain,
            order: lines.map(\.label)
        )
        .filter { $0.label != "Unassigned" && !$0.label.isEmpty }
        return grainTableHTML(table, section: section, grain: grain)
    }

    private static func grainTableHTML(
        _ table: [HeartbeatMath.DashboardGrainTableRow],
        section: MetricSection,
        grain: DashScopeGrain
    ) -> String {
        let filtered = table.filter { $0.label != "Unassigned" && !$0.label.isEmpty }
        // Match DashScopeStrip: store expand paints 40 rows; region/district stay full.
        let shown = grain == .store ? Array(filtered.prefix(40)) : filtered
        guard !shown.isEmpty else { return "" }
        var headers = ["Scope"]
        if grain != .store { headers.append("Stores") }
        headers += HeartbeatMath.dashboardTableHeaders(section)
        headers.append("Status")
        var body = ""
        for line in shown {
            let health = line.health == .none && line.storeCount > 0 ? Health.good : line.health
            var cells = nameCell(HeartbeatMath.displayGrainLabel(line.label))
            if grain != .store {
                cells += numCell(HeartbeatFormat.num(Double(line.storeCount)), muted: true)
            }
            for value in line.values {
                cells += numCell(value)
            }
            cells += statusCell(health)
            body += "<tr>\(cells)</tr>"
        }
        let unit = shown.count == 1 ? String(grain.unit.dropLast()) : grain.unit
        return dataTable(
            title: "\(grain.title) · \(shown.count) \(unit)",
            detail: "Same columns as the dashboard expand",
            headers: headers,
            body: body,
            banner: true
        )
    }

    private static func salesGrainTable(rows: [MetricRow], grain: DashScopeGrain, order: [String]) -> String {
        var buckets: [String: [MetricRow]] = [:]
        for row in rows {
            if row.textPayload["sales_grain"] == "company" { continue }
            guard let key = HeartbeatMath.dashboardScopeKey(row, grain: grain) else { continue }
            buckets[key, default: []].append(row)
        }
        let labels = order.isEmpty ? buckets.keys.sorted() : order
        var headers = ["Scope"]
        if grain != .store { headers.append("Stores") }
        headers += ["Sales $", "YoY %", "Orders", "Ord YoY", "AOS", "AIV", "Items/Txn", "Items", "Status"]
        var body = ""
        var shown = 0
        for label in labels {
            let group = buckets[label] ?? []
            if group.isEmpty { continue }
            if grain == .store, shown >= 40 { break }
            shown += 1
            let pack = SalesPack(rows: group)
            let health = pack.health == .none && (pack.sales ?? 0) > 0 ? Health.good : pack.health
            var cells = nameCell(HeartbeatMath.displayGrainLabel(label))
            if grain != .store {
                cells += numCell(HeartbeatFormat.num(Double(group.count)), muted: true)
            }
            for value in [
                HeartbeatFormat.money(pack.sales),
                HeartbeatFormat.pct(pack.yoy),
                HeartbeatFormat.num(pack.orders, digits: 0),
                HeartbeatFormat.pct(pack.ordersYoy),
                HeartbeatFormat.money(pack.aos),
                HeartbeatFormat.num(pack.aiv, digits: 2),
                HeartbeatFormat.num(pack.ipt, digits: 1),
                HeartbeatFormat.num(pack.items, digits: 0),
            ] {
                cells += numCell(value)
            }
            cells += statusCell(health)
            body += "<tr>\(cells)</tr>"
        }
        guard shown > 0 else { return "" }
        let unit = shown == 1 ? String(grain.unit.dropLast()) : grain.unit
        return dataTable(
            title: "\(grain.title) · \(shown) \(unit)",
            detail: "Same columns as the dashboard Sales expand",
            headers: headers,
            body: body,
            banner: true
        )
    }

    private static func dashboardFlagModels(_ section: MetricSection, snap: Snapshot) -> [HeartbeatMath.FiveStarFlag] {
        let scoped = snap.summaries.first { $0.section == section }?.storeCount
            ?? (snap.rows[section] ?? []).filter { !HeartbeatMath.canonicalStore($0.storeNumber).isEmpty }.count
        if let cached = snap.flags[section], !cached.isEmpty,
           PulseLaunch.flagsMatchFilter(flagStores: cached.map(\.stores), scopedStores: scoped) {
            return cached
        }
        let rows = snap.rows[section] ?? []
        switch section {
        case .fiveStar: return HeartbeatMath.fiveStarActionFlags(rows)
        case .scheduleQuality: return HeartbeatMath.scheduleActionFlags(rows)
        case .pickPath:
            return HeartbeatMath.pickPathActionFlags(stores: rows, shoppers: snap.rows[.pickPathPicker] ?? [])
        case .pph:
            return HeartbeatMath.pphActionFlags(stores: rows, shoppers: snap.rows[.pickerScorecard] ?? [])
        case .dynacap: return HeartbeatMath.dynacapActionFlags(rows)
        case .pickerScorecard: return HeartbeatMath.pickerActionFlags(rows)
        case .labor: return HeartbeatMath.laborActionFlags(rows)
        case .missingItems, .preSubOOS: return HeartbeatMath.missingItemsActionFlags(rows)
        case .lostRevenue: return HeartbeatMath.lostRevenueActionFlags(rows)
        case .sales: return HeartbeatMath.salesActionFlags(rows)
        default: return []
        }
    }

    private static func dashboardFlags(_ section: MetricSection, snap: Snapshot) -> [(String, String, Health)] {
        dashboardFlagModels(section, snap: snap).map { ($0.name, flagCaption($0), $0.health) }
    }

    private static func sectionHTML(_ section: MetricSection, snap: Snapshot) -> String {
        let summary = snap.summaries.first { $0.section == section }
        let stores = snap.rows[section] ?? []
        let kpis = kpiTiles(section, summary: summary, rows: stores, snap: snap)
        let rollup = rollupTable(section, rows: stores, grain: snap.grain)
        let table = storeTable(section, rows: stores, pickerCounts: snap.pickerCounts, total: snap.rowTotals[section])
        let items = section == .preSubOOS
            ? storeTable(
                .preSubOOSItem,
                rows: snap.rows[.preSubOOSItem] ?? [],
                pickerCounts: [:],
                total: snap.rowTotals[.preSubOOSItem]
            )
            : ""
        let window = stores.first { !($0.textPayload["data_window"] ?? "").isEmpty }?.textPayload["data_window"]
        return pageWrap(
            title: section.bannerTitle,
            filter: snap.filterSummary,
            trailing: window,
            inner: kpis + rollup + table + items
        )
    }

    private static func pageWrap(title: String, filter: String, trailing: String? = nil, inner: String) -> String {
        let right: String
        if let trailing, !trailing.isEmpty {
            right = "<div style=\"font-weight:700;opacity:.95;font-size:13px;text-align:right;white-space:nowrap\">\(esc(trailing))</div>"
        } else {
            right = ""
        }
        return """
        <table width="100%" cellspacing="0" cellpadding="0" style="background:#fff;border:2.5px solid #003DA5;border-radius:16px;margin:0 0 22px">
        <tr>        <td style="background:#003DA5;color:#fff;padding:16px 20px;font-weight:700;font-size:22px">
        <table width="100%" cellspacing="0" cellpadding="0"><tr>
        <td style="color:#fff;font-weight:700;font-size:22px">
        \(esc(title))
        <div style="font-weight:600;opacity:.95;font-size:15px;margin-top:4px">\(esc(filter))</div>
        </td>
        <td valign="middle" style="color:#fff">\(right)</td>
        </tr></table>
        </td></tr>
        <tr><td style="padding:14px 16px">\(inner)</td></tr>
        </table>
        """
    }

    private static func sharedWindow(_ snap: Snapshot) -> String? {
        let labels = MetricSection.uploadOrder.compactMap { section in
            (snap.rows[section] ?? []).first { !($0.textPayload["data_window"] ?? "").isEmpty }?.textPayload["data_window"]
        }
        let unique = Array(Set(labels))
        if unique.count == 1 { return unique[0] }
        return labels.first
    }

    private static func ink(_ health: Health) -> String {
        switch health {
        case .good: return "#059669"
        case .watch: return "#D97706"
        case .risk: return "#DC2626"
        case .none: return "#141A29"
        }
    }

    private static func tileFill(_ health: Health, brand: Bool) -> (bg: String, border: String, ink: String) {
        if brand { return ("#EEF3FB", "#D6E2F5", "#141A29") }
        switch health {
        case .good: return ("#D1FAE5", "#A7F3D0", "#059669")
        case .watch: return ("#FEF3C7", "#FDE68A", "#D97706")
        case .risk: return ("#FEE2E2", "#FECACA", "#DC2626")
        case .none: return ("#FFFFFF", "#E4E9F4", "#141A29")
        }
    }

    private static func tile(_ label: String, _ value: String, _ detail: String, _ health: Health, brand: Bool = false, colPct: Int = 50) -> String {
        let fill = tileFill(health, brand: brand)
        let badge = health == .none ? "" : pill(health)
        return """
        <td valign="top" style="width:\(colPct)%;background:\(fill.bg);border:1px solid \(fill.border);border-radius:14px;padding:12px 14px">
        <div style="font-size:15px;font-weight:700;color:#141A29">\(esc(label)) \(badge)</div>
        <div style="font-size:28px;font-weight:700;margin-top:8px;color:\(fill.ink)">\(esc(value))</div>
        <div style="font-size:14px;color:#5C677A;margin-top:6px">\(esc(detail))</div>
        </td>
        """
    }

    private static func flagStores(_ flags: [HeartbeatMath.FiveStarFlag], _ names: String...) -> Int? {
        for name in names {
            if let flag = flags.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                return flag.stores
            }
        }
        return nil
    }

    private static func kpiTiles(_ section: MetricSection, summary: SectionSummary?, rows: [MetricRow], snap: Snapshot) -> String {
        let scored = rows.filter { !$0.storeNumber.isEmpty }
        let flags = snap.flags[section] ?? []
        var items: [String] = []
        switch section {
        case .sales:
            let useSums = (snap.rowTotals[.sales] ?? 0) > scored.count || snap.sums.salesDollars > 0
            let sales = useSums ? snap.sums.salesDollars : scored.compactMap { $0.number("sales_dollars") }.reduce(0, +)
            let orders = useSums ? snap.sums.salesOrders : scored.compactMap { $0.number("sales_orders") }.reduce(0, +)
            let hd = useSums ? snap.sums.hdOrders : scored.compactMap { $0.number("sales_hd_orders") }.reduce(0, +)
            let dug = useSums ? snap.sums.dugOrders : scored.compactMap { $0.number("sales_dug_orders") }.reduce(0, +)
            items = [
                tile("eComm sales", HeartbeatFormat.money(scored.isEmpty && !useSums ? nil : sales), "In this filter", summary?.health ?? .none),
                tile("Orders", HeartbeatFormat.num(orders, digits: 0), "DUG + Home Delivery", .none, brand: true),
                tile("AOV", HeartbeatFormat.money(orders > 0 ? sales / orders : nil), "Sales / orders", .none, brand: true),
                tile("HD orders", HeartbeatFormat.num(hd, digits: 0), "Home Delivery", .none),
                tile("DUG orders", HeartbeatFormat.num(dug, digits: 0), "Drive Up & Go", .none),
            ]
        case .lostRevenue:
            let healthy = flagStores(flags, "Healthy") ?? scored.filter { HeartbeatMath.lostRevenueHealth($0) == .good }.count
            let watch = flagStores(flags, "Watch") ?? scored.filter { HeartbeatMath.lostRevenueHealth($0) == .watch }.count
            let risk = flagStores(flags, "At Risk") ?? scored.filter { HeartbeatMath.lostRevenueHealth($0) == .risk }.count
            let useSums = (snap.rowTotals[.lostRevenue] ?? 0) > scored.count || snap.sums.ecommSales > 0
            let sales = useSums ? snap.sums.ecommSales : scored.compactMap { $0.number("ecomm_sales") }.reduce(0, +)
            let post = useSums ? snap.sums.postSub : scored.compactMap { $0.number("post_sub_oos_foregone") }.reduce(0, +)
            items = [
                tile("Total lost revenue", summary?.headlineText ?? "—", "Total Opportunity", summary?.health ?? .none),
                tile("Healthy", HeartbeatFormat.num(Double(healthy)), "3% or better", .good),
                tile("Watch", HeartbeatFormat.num(Double(watch)), "3.01% to 5%", watch == 0 ? .good : .watch),
                tile("At Risk", HeartbeatFormat.num(Double(risk)), "Stores over 5%", risk == 0 ? .good : .risk),
                tile("Lost revenue %", HeartbeatFormat.pct(summary?.lostRevenuePct), "Total Opportunity", summary?.health ?? .none),
                tile("eComm sales", HeartbeatFormat.money(scored.isEmpty && !useSums ? nil : sales), "In this filter", .none, brand: true),
                tile("Post Sub OOS", HeartbeatFormat.money(scored.isEmpty && !useSums ? nil : post), "Foregone revenue", .none),
            ]
        case .missingItems:
            let healthy = flagStores(flags, "Healthy") ?? scored.filter { HeartbeatMath.missingItemsHealth($0) == .good }.count
            let watch = flagStores(flags, "Watch") ?? scored.filter { HeartbeatMath.missingItemsHealth($0) == .watch }.count
            let risk = flagStores(flags, "At Risk") ?? scored.filter { HeartbeatMath.missingItemsHealth($0) == .risk }.count
            items = [
                tile("Avg missing items", summary?.headlineText ?? "—", "5% healthy · 5.01–6.50% watch · over 6.50% at risk", summary?.health ?? .none),
                tile("Healthy", HeartbeatFormat.num(Double(healthy)), "5% or less", .good),
                tile("Watch", HeartbeatFormat.num(Double(watch)), "5.01% to 6.50%", watch == 0 ? .good : .watch),
                tile("At Risk", HeartbeatFormat.num(Double(risk)), "Stores over 6.50%", risk == 0 ? .good : .risk),
                tile("Goal", "5%", "Or less is healthy", .none, brand: true),
                tile("Watch band", "5.01–6.50%", "Needs a look", .watch),
                tile("At risk band", "> 6.50%", "Items without an aisle tag", .risk),
            ]
        case .preSubOOS:
            let healthy = flagStores(flags, "Healthy") ?? scored.filter { HeartbeatMath.missingItemsHealth($0) == .good }.count
            let watch = flagStores(flags, "Watch") ?? scored.filter { HeartbeatMath.missingItemsHealth($0) == .watch }.count
            let risk = flagStores(flags, "At Risk") ?? scored.filter { HeartbeatMath.missingItemsHealth($0) == .risk }.count
            items = [
                tile("Avg Pre-Sub OOS", summary?.headlineText ?? "—", "5% healthy · 5.01–6.50% watch · over 6.50% at risk", summary?.health ?? .none),
                tile("Healthy", HeartbeatFormat.num(Double(healthy)), "5% or less", .good),
                tile("Watch", HeartbeatFormat.num(Double(watch)), "5.01% to 6.50%", watch == 0 ? .good : .watch),
                tile("At Risk", HeartbeatFormat.num(Double(risk)), "Stores over 6.50%", risk == 0 ? .good : .risk),
                tile("Goal", "5%", "Or less is healthy", .none, brand: true),
                tile("Watch band", "5.01–6.50%", "Needs a look", .watch),
                tile("At risk band", "> 6.50%", "Pre-substitution out of stock", .risk),
            ]
        case .fiveStar:
            let atFive = scored.filter { ($0.number("star_rating") ?? 0) >= 4.95 }.count
            let pass = scored.filter { ($0.number("star_rating") ?? 0) >= HeartbeatMath.fiveStarPass }.count
            let fail = scored.filter { ($0.number("star_rating") ?? .greatestFiniteMagnitude) < HeartbeatMath.fiveStarPass }.count
            let flash = HeartbeatMath.average(scored.compactMap { $0.number("flash_pct") })
            let presub = HeartbeatMath.average(scored.compactMap { $0.number("presub_pct") })
            let coe = HeartbeatMath.average(scored.compactMap { $0.number("coe_pct") })
            let ott = HeartbeatMath.average(scored.compactMap { $0.number("ott_pct") })
            let oth = HeartbeatMath.average(scored.compactMap { $0.number("oth5_pct") })
            items = [
                tile("Avg star rating", summary?.headlineText ?? "—", "5.00 goal · 4.0+ pass", summary?.health ?? .none),
                tile("Goal", "5.00", "Target store rating", .none, brand: true),
                tile("At 5.00", HeartbeatFormat.num(Double(atFive)), "Stores at a perfect 5", .good),
                tile("Pass 4.0+", HeartbeatFormat.num(Double(pass)), "Stores that pass", .good),
                tile("Fail", HeartbeatFormat.num(Double(fail)), "Stores under 4.0", fail == 0 ? .good : .risk),
                tile("Flash", HeartbeatFormat.pct(flash), HeartbeatMath.starMark(value: flash, full: 75, half: 55).label, HeartbeatMath.starMark(value: flash, full: 75, half: 55).health),
                tile("Presubs", HeartbeatFormat.pct(presub), HeartbeatMath.starMark(value: presub, full: 5, half: 6, invert: true).label, HeartbeatMath.starMark(value: presub, full: 5, half: 6, invert: true).health),
                tile("COE", HeartbeatFormat.pct(coe), HeartbeatMath.starMark(value: coe, full: 20, half: 0).label, HeartbeatMath.starMark(value: coe, full: 20, half: 0).health),
                tile("OTT", HeartbeatFormat.pct(ott), HeartbeatMath.starMark(value: ott, full: 95, half: 90).label, HeartbeatMath.starMark(value: ott, full: 95, half: 90).health),
                tile("OTH 5%", HeartbeatFormat.pct(oth), HeartbeatMath.starMark(value: oth, full: 92, half: 78).label, HeartbeatMath.starMark(value: oth, full: 92, half: 78).health),
            ]
        case .pickPath:
            let atGoal = scored.filter { ($0.number("compliance_pct") ?? 0) >= HeartbeatMath.pickPathGoal }.count
            let atRisk = scored.filter { ($0.number("compliance_pct") ?? .greatestFiniteMagnitude) < HeartbeatMath.pickPathRisk }.count
            items = [
                tile("Avg compliance", summary?.headlineText ?? "—", "90% goal · under 80% at risk", summary?.health ?? .none),
                tile("Goal", "90%", "Target for every store", .none, brand: true),
                tile("At goal", HeartbeatFormat.num(Double(atGoal)), "Stores at 90%+", .good),
                tile("Below 80%", HeartbeatFormat.num(Double(atRisk)), "At risk stores", atRisk == 0 ? .good : .risk),
            ]
        case .prepNotReady:
            let atGoal = scored.filter { ($0.number("pnr_rate_pct") ?? .greatestFiniteMagnitude) <= HeartbeatMath.pnrGoal }.count
            let atRisk = scored.filter { ($0.number("pnr_rate_pct") ?? 0) > HeartbeatMath.pnrWatch }.count
            items = [
                tile("Avg PNR hours", summary?.headlineText ?? "—", "1.9% healthy · over 2.5% at risk", summary?.health ?? .none),
                tile("Goal", "1.9%", "Or less", .none, brand: true),
                tile("At goal", HeartbeatFormat.num(Double(atGoal)), "Stores at 1.9% or better", .good),
                tile("Above 2.5%", HeartbeatFormat.num(Double(atRisk)), "At risk stores", atRisk == 0 ? .good : .risk),
            ]
        case .dynacap:
            let atGoal = scored.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? 0) >= HeartbeatMath.dynacapGoal }.count
            let atRisk = scored.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? .greatestFiniteMagnitude) < HeartbeatMath.dynacapRisk }.count
            let util = HeartbeatMath.average(scored.compactMap { $0.number("utilization_pct") })
            items = [
                tile("Avg pieces / hour", summary?.headlineText ?? "—", "65 goal · under 60 at risk", summary?.health ?? .none),
                tile("Goal", "65.0", "Target pieces per hour", .none, brand: true),
                tile("At goal", HeartbeatFormat.num(Double(atGoal)), "Stores at 65+", .good),
                tile("Below 60", HeartbeatFormat.num(Double(atRisk)), "At risk stores", atRisk == 0 ? .good : .risk),
                tile("Utilization", HeartbeatFormat.pct(util), "Used vs available capacity", .none),
            ]
        case .scheduleQuality:
            let efficiency = HeartbeatMath.average(scored.compactMap { $0.number("schedule_efficiency_pct") })
            let efficiencyHealth = HeartbeatMath.band(efficiency, good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch)
            let atGoal = scored.filter { ($0.number("schedule_efficiency_pct") ?? 0) >= HeartbeatMath.scheduleGoal }.count
            let underRisk = scored.filter { ($0.number("under_schedule_pct", "under_scheduled") ?? 0) > HeartbeatMath.scheduleVarianceWatch }.count
            let overRisk = scored.filter { ($0.number("over_schedule_pct", "over_scheduled") ?? 0) > HeartbeatMath.scheduleVarianceWatch }.count
            items = [
                tile("Avg schedule efficiency", HeartbeatFormat.pct(efficiency), "90% goal · zero over / under", efficiencyHealth),
                tile("Goal", "90%", "Target schedule efficiency", .none, brand: true),
                tile("At goal", HeartbeatFormat.num(Double(atGoal)), "Stores at 90%+", .good),
                tile("Under Scheduled", HeartbeatFormat.num(Double(underRisk)), "Underscheduled over 5%", underRisk == 0 ? .good : .risk),
                tile("Over Scheduled", HeartbeatFormat.num(Double(overRisk)), "Overscheduled over 5%", overRisk == 0 ? .good : .risk),
            ]
        case .pph:
            let atGoal = scored.filter { ($0.number("pph") ?? 0) >= HeartbeatMath.pphGoal }.count
            let atRisk = scored.filter { ($0.number("pph") ?? .greatestFiniteMagnitude) < HeartbeatMath.pphRisk }.count
            items = [
                tile("Week Pure PPH", summary?.headlineText ?? "—", "Goal 80 · watch under 74", summary?.health ?? .none),
                tile("Goal", "80.0", "Target pure PPH", .none, brand: true),
                tile("At goal", HeartbeatFormat.num(Double(atGoal)), "Stores at 80+", .good),
                tile("Below 74", HeartbeatFormat.num(Double(atRisk)), "At risk stores", atRisk == 0 ? .good : .risk),
            ]
        case .labor:
            let healthy = scored.filter { ($0.number("target_vs_actual_pct") ?? 1) <= 0 }.count
            let watch = scored.filter {
                let value = $0.number("target_vs_actual_pct") ?? 0
                return value > 0 && value <= HeartbeatMath.laborWatch
            }.count
            let risk = scored.filter { ($0.number("target_vs_actual_pct") ?? 0) > HeartbeatMath.laborWatch }.count
            let tva = HeartbeatMath.average(scored.compactMap { $0.number("target_vs_actual_pct") })
            items = [
                tile("Target vs Actual", HeartbeatFormat.pct(tva), "0% healthy · 0.01–3% watch · over 3% risk", HeartbeatMath.laborHealth(tva)),
                tile("Healthy", HeartbeatFormat.num(Double(healthy)), "0% or better", .good),
                tile("Watch", HeartbeatFormat.num(Double(watch)), "0.01% to 3%", watch == 0 ? .good : .watch),
                tile("At Risk", HeartbeatFormat.num(Double(risk)), "Over 3%", risk == 0 ? .good : .risk),
            ]
        case .pickerScorecard:
            let opportunity = summary?.riskCount ?? 0
            items = [
                tile("All Shoppers", HeartbeatFormat.num(Double(scored.count)), "Every shopper in this filter", .none, brand: true),
                tile("Opportunity", HeartbeatFormat.num(Double(opportunity)), "15+ orders · underperforming", opportunity == 0 ? .good : .risk),
            ]
        default:
            if let summary {
                items = [
                    tile(summary.headlineLabel, summary.headlineText, riskLine(section, summary), summary.health),
                ]
            }
        }
        guard !items.isEmpty else { return "" }
        let perRow = HubLayout.calloutColumns(count: items.count, width: HubLayout.SupportedCanvas.padLandscape)
        let pct = max(100 / perRow, 1)
        let sized = items.map { item in
            item.replacingOccurrences(of: "width:50%;", with: "width:\(pct)%;")
        }
        var rows = ""
        var index = 0
        while index < sized.count {
            let end = min(index + perRow, sized.count)
            var row = sized[index..<end].joined()
            if end - index < perRow {
                for _ in (end - index)..<perRow {
                    row += "<td width=\"\(pct)%\"></td>"
                }
            }
            rows += "<tr>" + row + "</tr>"
            index = end
        }
        return "<table class=\"layout\" width=\"100%\" cellspacing=\"8\" cellpadding=\"0\">\(rows)</table>"
    }

    private static func groupKey(_ row: MetricRow, grain: String) -> String {
        if grain == "district" {
            return RollupMarketFill.districtKey(row.district)
        }
        return RollupMarketFill.divisionKey(row.division)
    }

    private static func rollupTable(_ section: MetricSection, rows: [MetricRow], grain: String?) -> String {
        guard section != .pickerScorecard else { return "" }
        guard let grain, grain == "division" || grain == "district" else { return "" }
        var buckets: [String: [MetricRow]] = [:]
        for row in rows where !row.storeNumber.isEmpty {
            buckets[groupKey(row, grain: grain), default: []].append(row)
        }
        if grain == "division" {
            for extra in MarketRegion.officialDivisions where buckets[extra] == nil {
                buckets[extra] = []
            }
        }
        guard !buckets.isEmpty else { return "" }
        let title = grain == "district" ? "By District" : "Markets"
        let filled = buckets.filter { !$0.value.isEmpty }.count
        let headers = storeHeaders(section)
        var body = ""
        for key in buckets.keys.sorted() {
            let group = buckets[key] ?? []
            if group.isEmpty { continue }
            let sample = group.sorted { HeartbeatFormat.storeOrder($0.storeNumber, $1.storeNumber) }.first
            guard var fake = sample else { continue }
            fake.storeNumber = key
            fake.payload = averagedPayload(group)
            let health = worst(group, section: section)
            let count = group.count == 1 ? "1 store" : "\(group.count) stores"
            body += "<tr>\(nameCell(key, extra: "<div class=\"muted\" style=\"font-size:13px;font-weight:600;color:#5C677A\">\(esc(count))</div>"))\(storeCells(section, row: fake, pickerCount: group.count, health: health))</tr>"
        }
        guard !body.isEmpty else { return "" }
        return dataTable(
            title: title,
            detail: "\(filled) \(grain == "district" ? "districts" : "divisions") · same columns as the page",
            headers: headers,
            body: body
        )
    }

    private static func averagedPayload(_ rows: [MetricRow]) -> [String: Double] {
        var sums: [String: (total: Double, count: Double)] = [:]
        for row in rows {
            for (key, value) in row.payload where value.isFinite {
                let cur = sums[key] ?? (0, 0)
                sums[key] = (cur.total + value, cur.count + 1)
            }
        }
        var out: [String: Double] = [:]
        for (key, pair) in sums where pair.count > 0 {
            if key == "lost_revenue" || key == "ecomm_sales" || key == "refund_amt" || key == "orders" || key == "picks_total" || key == "post_sub_oos_foregone" || key == "refund_lost" || key == "missed_sales" {
                out[key] = pair.total
            } else {
                out[key] = pair.total / pair.count
            }
        }
        return out
    }

    private static func storeTable(
        _ section: MetricSection,
        rows: [MetricRow],
        pickerCounts: [String: Int],
        total: Int? = nil
    ) -> String {
        let title: String
        switch section {
        case .pickerScorecard: title = "Shopper"
        case .preSubOOSItem: title = "Pre-Sub OOS Items"
        default: title = "Store"
        }
        let usable = rows.filter {
            PulseQuery.isStoreFact($0)
                || !$0.storeNumber.isEmpty
                || section == .pickerScorecard
                || section == .preSubOOSItem
        }
        if usable.isEmpty {
            return bar(title, "No rows in this view")
        }
        let ordered: [MetricRow]
        if section == .pickerScorecard || section == .preSubOOSItem {
            ordered = usable
        } else {
            ordered = usable.sorted { HeartbeatFormat.storeOrder($0.storeNumber, $1.storeNumber) }
        }
        let shown = ordered
        var body = ""
        for row in shown {
            let health = HeartbeatMath.health(for: section, row: row)
            let label: String
            switch section {
            case .pickerScorecard:
                label = row.storeNumber.isEmpty ? row.shopperName : "\(row.shopperName)  |  Store \(row.storeNumber)"
            case .preSubOOSItem:
                label = placeLabel(row)
            default:
                label = placeLabel(row)
            }
            body += "<tr>\(nameCell(label))\(storeCells(section, row: row, pickerCount: pickerCounts[HeartbeatMath.canonicalStore(row.storeNumber)] ?? 0, health: health))</tr>"
        }
        let reported = max(total ?? 0, ordered.count)
        let unit: String
        switch section {
        case .pickerScorecard: unit = reported == 1 ? "shopper" : "shoppers"
        case .preSubOOSItem: unit = reported == 1 ? "item" : "items"
        default: unit = reported == 1 ? "store" : "stores"
        }
        let detail: String
        if shown.count < reported {
            detail = "\(HeartbeatFormat.num(Double(shown.count))) of \(HeartbeatFormat.num(Double(reported))) \(unit) · same columns as the page"
        } else {
            detail = "\(HeartbeatFormat.num(Double(reported))) \(unit) · every column from the page"
        }
        return dataTable(
            title: title,
            detail: detail,
            headers: storeHeaders(section),
            body: body
        )
    }

    private static func placeLabel(_ row: MetricRow) -> String {
        var parts = [row.storeNumber]
        let district = HeartbeatMath.canonicalDistrict(row.district)
        if !district.isEmpty { parts.append(district) }
        var market = MarketRegion.canonicalName(row.division)
        if market.isEmpty { market = row.division.trimmingCharacters(in: .whitespacesAndNewlines) }
        if !market.isEmpty, market.caseInsensitiveCompare(district) != .orderedSame {
            parts.append(market)
        }
        return parts.joined(separator: " | ")
    }

    private static func metricCard(title: String, detail: String?, metrics: String, health: Health) -> String {
        let extra = (detail?.isEmpty == false) ? " · \(esc(detail!))" : ""
        return """
        <table width="100%" cellspacing="0" cellpadding="0" style="border-bottom:1px solid #EEF1F6">
        <tr>
        <td style="padding:8px 4px 2px;font-weight:700;font-size:13px">\(esc(title))\(extra)</td>
        <td style="padding:8px 4px 2px;text-align:right;width:88px">\(pill(health))</td>
        </tr>
        <tr>
        <td colspan="2" style="padding:0 4px 8px;color:#5C677A;font-size:12px;line-height:1.45">\(esc(metrics))</td>
        </tr>
        </table>
        """
    }

    private static func metricLine(_ section: MetricSection, row: MetricRow, pickerCount: Int) -> String {
        switch section {
        case .sales:
            return [
                "Sales \(HeartbeatFormat.money(row.number("sales_dollars")))",
                "YoY \(HeartbeatFormat.pct(row.number("sales_yoy_pct")))",
                "Orders \(HeartbeatFormat.num(row.number("sales_orders"), digits: 0))",
                "AOS \(HeartbeatFormat.money(row.number("sales_aos") ?? row.number("sales_aov")))",
                "AIV \(HeartbeatFormat.num(row.number("sales_aiv"), digits: 2))",
                "Items \(HeartbeatFormat.num(row.number("sales_items"), digits: 0))",
            ].joined(separator: " · ")
        case .lostRevenue:
            return [
                "Lost \(HeartbeatFormat.money(row.number("lost_revenue")))",
                "Lost % \(HeartbeatFormat.pct(row.number("lost_revenue_pct")))",
                "Goal 3.00%",
                "Sales \(HeartbeatFormat.money(row.number("ecomm_sales")))",
                "Post \(HeartbeatFormat.money(row.number("post_sub_oos_foregone")))",
                "Refund \(HeartbeatFormat.money(row.number("refund_lost", "refund_amt")))",
                "Missed \(HeartbeatFormat.money(row.number("missed_sales")))",
            ].joined(separator: " · ")
        case .missingItems, .preSubOOS:
            var parts = ["Total \(HeartbeatFormat.pct(row.number(MissingItemDept.totalKey)))"]
            for dept in MissingItemDept.allCases {
                if let value = row.number(dept.rawValue) {
                    parts.append("\(dept.title) \(HeartbeatFormat.pct(value))")
                }
            }
            return parts.joined(separator: " · ")
        case .fiveStar:
            return [
                "Rating \(HeartbeatFormat.stars(row.number("star_rating")))",
                "Flash \(HeartbeatFormat.pct(row.number("flash_pct")))",
                "Presub \(HeartbeatFormat.pct(row.number("presub_pct")))",
                "COE \(HeartbeatFormat.pct(row.number("coe_pct")))",
                "OTT \(HeartbeatFormat.pct(row.number("ott_pct")))",
                "OTH5 \(HeartbeatFormat.pct(row.number("oth5_pct")))",
            ].joined(separator: " · ")
        case .pickPath, .pickPathPicker:
            return [
                "Pick path \(HeartbeatFormat.pct(row.number("compliance_pct")))",
                "PPH \(HeartbeatFormat.num(row.number("pph"), digits: 1))",
                "Orders \(HeartbeatFormat.num(row.number("orders") ?? row.number("picks_total")))",
                "Mapper \(HeartbeatFormat.shortDate(AisleMapperMath.mapperISO(row)))",
                "Sequence \(HeartbeatFormat.shortDate(AisleMapperMath.sequenceISO(row)))",
            ].joined(separator: " · ")
        case .prepNotReady:
            return "PNR \(HeartbeatFormat.pct(row.number("pnr_rate_pct"))) · Goal \(HeartbeatFormat.num(HeartbeatMath.pnrGoal, digits: 1))% · Watch \(HeartbeatFormat.num(HeartbeatMath.pnrWatch, digits: 1))%"
        case .dynacap:
            return [
                "Rate \(HeartbeatFormat.num(row.number("dynacap_rate", "pieces_per_hour"), digits: 1))",
                "PPH \(HeartbeatFormat.num(row.number("pph"), digits: 1))",
                "Goal \(HeartbeatFormat.num(HeartbeatMath.dynacapGoal, digits: 0))",
                "Util \(HeartbeatFormat.pct(row.number("utilization_pct")))",
            ].joined(separator: " · ")
        case .scheduleQuality:
            return [
                "Eff \(HeartbeatFormat.pct(row.number("schedule_efficiency_pct")))",
                "Staffing \(HeartbeatFormat.pct(row.number("staffing_efficiency_pct")))",
                "Goal 90%",
                "Under \(HeartbeatFormat.pct(row.number("under_schedule_pct", "under_scheduled")))",
                "Over \(HeartbeatFormat.pct(row.number("over_schedule_pct", "over_scheduled")))",
            ].joined(separator: " · ")
        case .pph:
            return "PPH \(HeartbeatFormat.num(row.number("pph"), digits: 1)) · Pickers \(HeartbeatFormat.num(Double(pickerCount))) · Goal 80.0"
        case .labor:
            return [
                "Tgt vs Act \(HeartbeatFormat.pct(row.number("target_vs_actual_pct")))",
                "CostTrgt \(HeartbeatFormat.pct(row.number("cost_trgt_pct")))",
                "ActCost \(HeartbeatFormat.pct(row.number("act_cost_pct")))",
                "Sch Eff \(HeartbeatFormat.pct(row.number("schedule_efficiency_pct")))",
                "UPLH \(HeartbeatFormat.pct(row.number("uplh_impact_pct")))",
                "Wage \(HeartbeatFormat.pct(row.number("wage_impact_pct")))",
                "AIV \(HeartbeatFormat.pct(row.number("aiv_impact_pct")))",
            ].joined(separator: " · ")
        case .pickerScorecard:
            return [
                "PPH \(HeartbeatFormat.num(row.number("pph"), digits: 1))",
                "Presub \(HeartbeatFormat.pct(row.number("presub_pct")))",
                "OOS \(HeartbeatFormat.pct(row.number("oos_pct")))",
                "OTT \(HeartbeatFormat.pct(row.number("ott_pct")))",
                "OTH5 \(HeartbeatFormat.pct(row.number("oth5_pct")))",
                "Refund \(HeartbeatFormat.money(row.number("refund_amt")))",
            ].joined(separator: " · ")
        case .preSubOOSItem:
            return [
                row.textPayload["bpn"] ?? "",
                "Pre-Sub \(HeartbeatFormat.pct(row.number("presub_pct")))",
                "Units \(HeartbeatFormat.num(row.number("presub_count"), digits: 0))",
                "$ Pre-Sub \(HeartbeatFormat.money(row.number("presub_dollars")))",
                "OOS \(HeartbeatFormat.pct(row.number("oos_pct")))",
                "$ OOS \(HeartbeatFormat.money(row.number("oos_dollars")))",
            ].filter { !$0.isEmpty }.joined(separator: " · ")
        case .aisleMapper:
            return "Mapper \(HeartbeatFormat.shortDate(AisleMapperMath.mapperISO(row))) · Sequence \(HeartbeatFormat.shortDate(AisleMapperMath.sequenceISO(row)))"
        case .storeRoster:
            return [row.division, row.district, row.operationsOM].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }

    private static func storeHeaders(_ section: MetricSection) -> [String] {
        switch section {
        case .fiveStar:
            return ["Store", "Rating", "Flash", "Presubs", "COE", "OTT", "OTH 5%", "Status"]
        case .pickPath, .pickPathPicker:
            return ["Store", "Pick Path", "Avg PPH", "Orders", "Mapper", "Sequence", "Status"]
        case .prepNotReady:
            return ["Store", "PNR Hours %", "Goal", "Watch", "Status"]
        case .dynacap:
            return ["Store", "Pieces / hr", "Store PPH", "Goal", "Utilization", "Status"]
        case .scheduleQuality:
            return ["Store", "Efficiency", "Staffing % (Pch vs Tgt)", "Goal", "Under", "Over", "Status"]
        case .pph:
            return ["Store", "Pure PPH", "Pickers", "Goal", "Status"]
        case .labor:
            return ["Store", "Tgt vs Act", "CostTrgt%", "ActCost%", "Sch Effi%", "UPLH", "Wage", "AIV", "Status"]
        case .lostRevenue:
            return ["Store", "Lost $", "Lost %", "Goal %", "eComm $", "Post Sub", "Refund", "Missed", "Cancel", "Kill", "Status"]
        case .sales:
            return ["Store", "Sales $", "YoY %", "Orders", "Ord YoY", "AOS", "AIV", "Items/Txn", "Items", "Status"]
        case .missingItems, .preSubOOS:
            return ["Store", "Total"] + MissingItemDept.allCases.map(\.title) + ["Status"]
        case .preSubOOSItem:
            return ["Store", "Item", "Pre-Sub %", "Units", "$ Pre-Sub", "OOS %", "$ OOS", "Status"]
        case .aisleMapper:
            return ["Store", "Mapper", "Sequence", "Status"]
        case .pickerScorecard:
            return ["Shopper", "Hours", "PPH", "Orders", "Presub", "OTT", "OTH5", "COE", "Status"]
        case .storeRoster:
            return ["Store", "Division", "District", "OM"]
        }
    }

    private static func storeCells(_ section: MetricSection, row: MetricRow, pickerCount: Int, health: Health) -> String {
        func cell(_ text: String, _ metricHealth: Health? = nil) -> String {
            let cls = metricHealth.map { "num cell-\($0.rawValue)" } ?? "num"
            var style = "text-align:right;font-variant-numeric:tabular-nums;font-weight:700;font-size:16px;white-space:nowrap;padding:8px;border-bottom:1px solid #E4E9F4"
            if let metricHealth {
                switch metricHealth {
                case .good: style += ";background:#D1FAE5;color:#059669"
                case .watch: style += ";background:#FEF3C7;color:#D97706"
                case .risk: style += ";background:#FEE2E2;color:#DC2626"
                case .none: break
                }
            }
            return "<td class=\"\(cls)\" style=\"\(style)\">\(esc(text))</td>"
        }
        var html = ""
        switch section {
        case .fiveStar:
            html += cell(HeartbeatFormat.stars(row.number("star_rating")), HeartbeatMath.health(for: .fiveStar, row: row))
            html += cell(HeartbeatFormat.pct(row.number("flash_pct")))
            html += cell(HeartbeatFormat.pct(row.number("presub_pct")))
            html += cell(HeartbeatFormat.pct(row.number("coe_pct")))
            html += cell(HeartbeatFormat.pct(row.number("ott_pct")))
            html += cell(HeartbeatFormat.pct(row.number("oth5_pct")))
        case .pickPath, .pickPathPicker:
            html += cell(HeartbeatFormat.pct(row.number("compliance_pct")), HeartbeatMath.band(row.number("compliance_pct"), good: HeartbeatMath.pickPathGoal, watch: HeartbeatMath.pickPathRisk))
            html += cell(HeartbeatFormat.num(row.number("pph"), digits: 1))
            html += cell(HeartbeatFormat.num(row.number("orders") ?? row.number("picks_total")))
            html += cell(HeartbeatFormat.shortDate(AisleMapperMath.mapperISO(row)), AisleMapperMath.health(AisleMapperMath.mapperISO(row)))
            html += cell(HeartbeatFormat.shortDate(AisleMapperMath.sequenceISO(row)), AisleMapperMath.health(AisleMapperMath.sequenceISO(row)))
        case .prepNotReady:
            html += cell(HeartbeatFormat.pct(row.number("pnr_rate_pct", "pnr_hours", "prep_not_ready_pct")), HeartbeatMath.health(for: .prepNotReady, row: row))
            html += cell("\(HeartbeatFormat.num(HeartbeatMath.pnrGoal, digits: 1))%")
            html += cell("\(HeartbeatFormat.num(HeartbeatMath.pnrWatch, digits: 1))%")
        case .dynacap:
            html += cell(HeartbeatFormat.num(row.number("dynacap_rate", "pieces_per_hour"), digits: 1))
            html += cell(HeartbeatFormat.num(row.number("pph"), digits: 1))
            html += cell(HeartbeatFormat.num(HeartbeatMath.dynacapGoal, digits: 0))
            html += cell(HeartbeatFormat.pct(row.number("utilization_pct", "pickup_util_pct")))
        case .scheduleQuality:
            html += cell(HeartbeatFormat.pct(row.number("schedule_efficiency_pct")), HeartbeatMath.band(row.number("schedule_efficiency_pct"), good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch))
            html += cell(HeartbeatFormat.pct(row.number("staffing_efficiency_pct")), HeartbeatMath.band(row.number("staffing_efficiency_pct"), good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch))
            html += cell("90%")
            html += cell(HeartbeatFormat.pct(row.number("under_schedule_pct", "under_scheduled", "under_staffing_pct")), HeartbeatMath.varianceHealth(row.number("under_schedule_pct", "under_scheduled", "under_staffing_pct")))
            html += cell(HeartbeatFormat.pct(row.number("over_schedule_pct", "over_scheduled", "over_staffing_pct")), HeartbeatMath.varianceHealth(row.number("over_schedule_pct", "over_scheduled", "over_staffing_pct")))
        case .pph:
            html += cell(HeartbeatFormat.num(row.number("pph", "pure_pph"), digits: 1), HeartbeatMath.pphHealth(row))
            html += cell(HeartbeatFormat.num(Double(pickerCount)))
            html += cell("80.0")
        case .labor:
            html += cell(HeartbeatFormat.pct(row.number("target_vs_actual_pct")))
            html += cell(HeartbeatFormat.pct(row.number("cost_trgt_pct")))
            html += cell(HeartbeatFormat.pct(row.number("act_cost_pct")))
            html += cell(HeartbeatFormat.pct(row.number("schedule_efficiency_pct")))
            html += cell(HeartbeatFormat.pct(row.number("uplh_impact_pct")))
            html += cell(HeartbeatFormat.pct(row.number("wage_impact_pct")))
            html += cell(HeartbeatFormat.pct(row.number("aiv_impact_pct")))
        case .lostRevenue:
            html += cell(HeartbeatFormat.money(row.number("lost_revenue")), HeartbeatMath.health(for: .lostRevenue, row: row))
            html += cell(HeartbeatFormat.pct(row.number("lost_revenue_pct")))
            html += cell(HeartbeatFormat.pct(HeartbeatMath.lostRevenueGoalPct(row)))
            html += cell(HeartbeatFormat.money(row.number("ecomm_sales")))
            html += cell(HeartbeatFormat.money(row.number("post_sub_oos_foregone")))
            html += cell(HeartbeatFormat.money(row.number("refund_lost", "refund_amt")))
            html += cell(HeartbeatFormat.money(row.number("missed_sales")))
            html += cell(HeartbeatFormat.money(row.number("cancelled_lost")))
            html += cell(HeartbeatFormat.money(row.number("kill_switch_lost")))
        case .sales:
            let pack = SalesPack(row)
            html += cell(HeartbeatFormat.money(pack.sales), pack.health)
            html += cell(HeartbeatFormat.pct(pack.yoy), pack.health)
            html += cell(HeartbeatFormat.num(pack.orders, digits: 0))
            html += cell(HeartbeatFormat.pct(pack.ordersYoy))
            html += cell(HeartbeatFormat.money(pack.aos))
            html += cell(HeartbeatFormat.num(pack.aiv, digits: 2))
            html += cell(HeartbeatFormat.num(pack.ipt, digits: 1))
            html += cell(HeartbeatFormat.num(pack.items, digits: 0))
        case .missingItems, .preSubOOS:
            html += cell(HeartbeatFormat.pct(row.number(MissingItemDept.totalKey)), HeartbeatMath.health(for: section, row: row))
            for dept in MissingItemDept.allCases {
                html += cell(HeartbeatFormat.pct(row.number(dept.rawValue)))
            }
        case .aisleMapper:
            html += cell(HeartbeatFormat.shortDate(AisleMapperMath.mapperISO(row)), AisleMapperMath.health(AisleMapperMath.mapperISO(row)))
            html += cell(HeartbeatFormat.shortDate(AisleMapperMath.sequenceISO(row)), AisleMapperMath.health(AisleMapperMath.sequenceISO(row)))
        case .preSubOOSItem:
            html += cell(row.textPayload["bpn"] ?? row.textPayload["item"] ?? "")
            html += cell(HeartbeatFormat.pct(row.number("presub_pct")), HeartbeatMath.health(for: .preSubOOSItem, row: row))
            html += cell(HeartbeatFormat.num(row.number("presub_count"), digits: 0))
            html += cell(HeartbeatFormat.money(row.number("presub_dollars")))
            html += cell(HeartbeatFormat.pct(row.number("oos_pct")))
            html += cell(HeartbeatFormat.money(row.number("oos_dollars")))
        case .pickerScorecard:
            html += cell(HeartbeatFormat.num(row.number("pick_hours"), digits: 1))
            html += cell(HeartbeatFormat.num(row.number("pph", "pure_pph"), digits: 1), HeartbeatMath.pickerHealth(row))
            html += cell(HeartbeatFormat.num(row.number("orders")))
            html += cell(HeartbeatFormat.pct(row.number("presub_pct", "presub_oos_pct")))
            html += cell(HeartbeatFormat.pct(row.number("ott_pct")))
            html += cell(HeartbeatFormat.pct(row.number("oth5_pct")))
            html += cell(HeartbeatFormat.pct(row.number("coe_pct")))
        case .storeRoster:
            html += cell(row.division)
            html += cell(row.district)
            html += cell(row.operationsOM)
        }
        html += statusCell(health)
        return html
    }

    private static func worst(_ rows: [MetricRow], section: MetricSection) -> Health {
        let ranks: [Health: Int] = [.none: 0, .good: 1, .watch: 2, .risk: 3]
        return rows.map { HeartbeatMath.health(for: section, row: $0) }.max { (ranks[$0] ?? 0) < (ranks[$1] ?? 0) } ?? .none
    }

    private static func riskLine(_ section: MetricSection, _ summary: SectionSummary?) -> String {
        let n = summary?.riskCount ?? 0
        if section == .pickerScorecard {
            return n == 0 ? "0 pickers at risk" : "\(HeartbeatFormat.num(Double(n))) pickers at risk"
        }
        return n == 0 ? "0 stores at risk" : "\(HeartbeatFormat.num(Double(n))) stores at risk"
    }

    private static func nameCell(_ text: String, extra: String = "") -> String {
        "<td class=\"name\" style=\"font-weight:700;font-size:16px;white-space:nowrap;padding:8px;border-bottom:1px solid #E4E9F4\">\(esc(text))\(extra)</td>"
    }

    private static func numCell(_ text: String, muted: Bool = false) -> String {
        let color = muted ? "#5C677A" : "#141A29"
        let cls = muted ? "num muted" : "num"
        return "<td class=\"\(cls)\" style=\"text-align:right;font-variant-numeric:tabular-nums;font-weight:700;font-size:16px;white-space:nowrap;padding:8px;border-bottom:1px solid #E4E9F4;color:\(color)\">\(esc(text))</td>"
    }

    private static func statusCell(_ health: Health) -> String {
        "<td class=\"status\" style=\"text-align:right;white-space:nowrap;width:108px;padding:8px;border-bottom:1px solid #E4E9F4\">\(pill(health))</td>"
    }

    private static func pill(_ health: Health) -> String {
        let bg: String
        switch health {
        case .good: bg = "#059669"
        case .watch: bg = "#D97706"
        case .risk: bg = "#DC2626"
        case .none: bg = "#8A93A3"
        }
        return "<span class=\"pill\" style=\"display:inline-block;padding:5px 12px;border-radius:999px;font-size:12px;line-height:1.2;font-weight:700;color:#fff;letter-spacing:.02em;background:\(bg)\">\(esc(health.label.uppercased()))</span>"
    }

    private static func dataTable(title: String, detail: String, headers: [String], body: String, banner: Bool = false) -> String {
        let heads = headers.enumerated().map { index, name -> String in
            let cls: String
            let align: String
            if index == 0 {
                cls = ""
                align = "left"
            } else if name == "Status" {
                cls = " class=\"status\""
                align = "right"
            } else {
                cls = " class=\"num\""
                align = "right"
            }
            return "<th\(cls) bgcolor=\"#EEF3FB\" style=\"text-align:\(align);font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:#003DA5;background:#EEF3FB;padding:8px;border-bottom:2px solid #003DA5;white-space:nowrap;font-weight:700\">\(esc(name))</th>"
        }.joined()
        let heading = banner
            ? bar(title, detail)
            : "<div class=\"block-title\" style=\"font-size:18px;font-weight:700;color:#003DA5;margin:18px 0 8px\">\(esc(title))<span style=\"display:block;font-size:14px;font-weight:600;color:#5C677A;margin-top:2px\">\(esc(detail))</span></div>"
        return """
        \(heading)
        <div class="table-wrap" style="width:100%;overflow-x:auto;-webkit-overflow-scrolling:touch;margin:0 0 8px">
        <table class="data" cellspacing="0" cellpadding="0" bgcolor="#FFFFFF" style="width:100%;border-collapse:collapse;font-size:15px;min-width:680px;background:#FFFFFF">
        <thead><tr>\(heads)</tr></thead>
        <tbody>\(body)</tbody>
        </table>
        </div>
        """
    }

    private static func bar(_ title: String, _ detail: String) -> String {
        """
        <table width="100%" cellspacing="0" cellpadding="0" bgcolor="#003DA5" style="background:#003DA5;color:#fff;border-radius:14px;margin:8px 0">
        <tr><td style="padding:10px 14px;font-weight:700;color:#fff">
        \(esc(title))
        <div style="font-weight:600;opacity:.9;font-size:12px;margin-top:2px;color:#fff">\(esc(detail))</div>
        </td></tr>
        </table>
        """
    }

    private static func plain(_ snap: Snapshot, pages: Set<SharePage>) -> String {
        var lines = [
            "Fulfillment Heartbeat",
            snap.filterSummary,
            HeartbeatFormat.stamp(snap.generatedAt),
            "Same layout and columns as the in-app page. Upload is not included.",
            "",
        ]
        if pages.contains(.dashboard) {
            lines.append("DASHBOARD")
            for card in snap.summaries {
                lines.append("\(card.section.title): \(card.headlineText) · \(card.health.label) · \(riskLine(card.section, card))")
                let grain = dashGrain(snap)
                let cached = snap.grainTables[card.section] ?? []
                let grainRows: [HeartbeatMath.DashboardGrainTableRow]
                if !cached.isEmpty, PulseLaunch.grainTableMatchesCurrent(labels: cached.map(\.label), grain: grain) {
                    grainRows = cached
                } else {
                    grainRows = HeartbeatMath.dashboardGrainTable(
                        section: card.section,
                        rows: snap.rows[card.section] ?? [],
                        grain: grain,
                        order: []
                    )
                }
                if !grainRows.isEmpty {
                    lines.append(HeartbeatMath.dashboardTableHeaders(card.section).joined(separator: " | "))
                    for line in grainRows {
                        lines.append("\(HeartbeatMath.displayGrainLabel(line.label)) | \(line.values.joined(separator: " | ")) | \(line.health.label)")
                    }
                }
            }
        }
        for page in SharePage.allCases {
            guard page != .dashboard, pages.contains(page), let section = page.section else { continue }
            let rows = snap.rows[section] ?? []
            lines.append("")
            lines.append(section.bannerTitle.uppercased())
            lines.append(storeHeaders(section).joined(separator: " | "))
            lines.append("\(rows.count) rows")
            for row in rows {
                let name = section == .pickerScorecard ? "\(row.shopperName) \(row.storeNumber)" : placeLabel(row)
                lines.append("\(name) · \(metricLine(section, row: row, pickerCount: snap.pickerCounts[HeartbeatMath.canonicalStore(row.storeNumber)] ?? 0)) · \(HeartbeatMath.health(for: section, row: row).label)")
            }
            if section == .preSubOOS, let items = snap.rows[.preSubOOSItem], !items.isEmpty {
                lines.append("")
                lines.append("PRE-SUB OOS ITEMS")
                lines.append(storeHeaders(.preSubOOSItem).joined(separator: " | "))
                for row in items {
                    lines.append("\(placeLabel(row)) · \(metricLine(.preSubOOSItem, row: row, pickerCount: 0))")
                }
            }
        }
        lines.append("")
        lines.append("Sent from Fulfillment Heartbeat")
        return lines.joined(separator: "\n")
    }

    private static func esc(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "\u{0026}amp;")
            .replacingOccurrences(of: "<", with: "\u{0026}lt;")
            .replacingOccurrences(of: ">", with: "\u{0026}gt;")
            .replacingOccurrences(of: "\"", with: "\u{0026}quot;")
    }
}
