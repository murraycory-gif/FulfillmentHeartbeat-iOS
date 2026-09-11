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
        var pickerShoppers: Int = 0
        var pickerStrong: Int = 0
        var pickerOpportunity: Int = 0
    }

    private struct MailTableRow {
        var label: String
        var detail: String = ""
        var values: [String]
        var tones: [Health?] = []
        var health: Health = .none
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
        let blocks = brief
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { "<p style=\"margin:0 0 10px;padding:0;font-size:16px;line-height:1.5;color:#141A29\">\(esc($0))</p>" }
            .joined()
        return """
        <html><body style="margin:0;padding:24px 20px;background:#F5F7FC;color:#141A29;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:16px;line-height:1.5">
        <table width="100%" cellspacing="0" cellpadding="0" style="max-width:720px;margin:0 auto;background:#FFFFFF;border:1px solid #E4E9F4;border-radius:16px">
        <tr><td style="padding:22px 24px">
        <p style="color:#003DA5;font-weight:700;font-size:20px;margin:0 0 12px;line-height:1.3">Fulfillment Heartbeat</p>
        <p style="margin:0 0 18px;padding:0;font-size:16px;line-height:1.5">The full recap is attached as HTML — open it to see the same cards, callouts, and tables as the app.</p>
        \(blocks)
        </td></tr>
        </table>
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
            "",
            snap.filterSummary,
            HeartbeatFormat.stamp(snap.generatedAt),
            "Pages: \(names.joined(separator: ", "))",
            "",
        ]
        if pages.contains(.dashboard) {
            lines.append("DASHBOARD")
            lines.append("")
            for card in snap.summaries {
                lines.append(card.section.title)
                lines.append("  \(card.headlineText)    \(card.health.label)    \(riskLine(card.section, card))")
                lines.append("")
            }
        }
        lines.append("Sent from Fulfillment Heartbeat")
        return lines.joined(separator: "\n")
    }

    /// One section at a time so Share can stream the full filtered page to a file.
    /// Dashboard cards and every selected SharePage use the same `dataTable` mail-stack
    /// plus `dashboardFlagModels` / picker buckets — individual or multi-select.
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
        .wrap{width:100%;max-width:1100px;margin:0 auto}
        h1{font-size:28px;line-height:1.2;margin:0 0 8px;color:#003DA5}
        .sub{color:#3D4658;font-size:16px;margin:0 0 22px;line-height:1.5}
        .block-title{font-size:18px;font-weight:700;color:#003DA5;margin:22px 0 12px}
        .block-title span{display:block;font-size:14px;font-weight:600;color:#5C677A;margin-top:4px}
        table.layout{width:100%;border-collapse:separate;border-spacing:0}
        table.layout td{vertical-align:top}
        .mail-stack{width:100%;max-width:100%;margin:0 0 22px}
        table.data{width:100%;max-width:100%;border-collapse:separate;border-spacing:0;font-size:15px;line-height:1.45}
        table.data th{text-align:left;font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:#003DA5;background:#EEF3FB;padding:10px 14px;border-bottom:2px solid #003DA5;border-right:1px solid #D6E2F5;font-weight:700}
        table.data td{padding:10px 14px;border-bottom:1px solid #E4E9F4;border-right:1px solid #EEF1F6;vertical-align:middle}
        table.data td.name{font-weight:700;font-size:16px;padding:10px 16px 10px 14px}
        table.data td.num,.num{text-align:right;font-variant-numeric:tabular-nums;font-weight:700;font-size:16px;padding:10px 14px}
        .dash-card{margin:0 0 14px;border-radius:16px;overflow:hidden}
        .page-banner{font-size:18px;font-weight:700;color:#003DA5;margin:0 0 12px}
        table.data td.status{text-align:right}
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
        </style></head><body style="margin:0;padding:24px 20px;background:#F5F7FC;color:#141A29;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:16px;line-height:1.45"><div class="wrap" style="width:100%;max-width:1100px;margin:0 auto">
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
            <table class="dash-card" width="100%" cellspacing="0" cellpadding="0" bgcolor="#FFFFFF" style="background:#FFFFFF;border:1px solid #E4E9F4;border-radius:16px;margin:0 0 22px">
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

    /// Mail/Outlook ignore CSS padding and crush 4-up grids. Two columns, nested cellpadding.
    private static let mailGridColumns = 2

    private static func mailGutter() -> String {
        "<td width=\"12\" style=\"width:12px;font-size:0;line-height:0;padding:0\">&nbsp;</td>"
    }

    private static func flagGridHTML(_ flags: [HeartbeatMath.FiveStarFlag]) -> String {
        guard !flags.isEmpty else { return "" }
        let perRow = mailGridColumns
        var rows = ""
        var index = 0
        while index < flags.count {
            let end = min(index + perRow, flags.count)
            var cells = ""
            let slice = Array(flags[index..<end])
            for (offset, flag) in slice.enumerated() {
                if offset > 0 { cells += mailGutter() }
                let tone = flag.health == .none ? Health.good : flag.health
                let accent = ink(tone)
                let unit = flag.stores == 1 ? String(flag.unit.dropLast()) : flag.unit
                let stores = "\(HeartbeatFormat.num(Double(flag.stores)))&nbsp;\(esc(unit))"
                let valueLine = flag.value.isEmpty
                    ? ""
                    : "<div class=\"nw\" style=\"font-size:20px;font-weight:700;margin:8px 0;color:\(accent);text-align:left;line-height:1.3\">\(esc(flag.value))</div>"
                cells += """
                <td width="\(100 / perRow)%" valign="top" style="width:\(100 / perRow)%">
                <table width="100%" cellspacing="0" cellpadding="14" bgcolor="#FFFFFF" style="width:100%;background:#FFFFFF;border:1px solid #E4E9F4;border-radius:12px">
                <tr>
                <td width="4" bgcolor="\(accent)" style="background:\(accent);width:4px;font-size:0;line-height:0">&nbsp;</td>
                <td style="padding:14px 16px">
                <div style="font-size:15px;color:#141A29;font-weight:700;line-height:1.35">\(esc(flag.name))</div>
                \(valueLine)
                <div class="nw" style="font-size:14px;font-weight:600;margin-top:8px;color:#5C677A;text-align:left;line-height:1.4">\(stores)</div>
                <div style="margin-top:10px">\(pill(tone))</div>
                </td></tr>
                </table>
                </td>
                """
            }
            if slice.count < perRow {
                cells += mailGutter()
                cells += "<td width=\"\(100 / perRow)%\"></td>"
            }
            rows += "<tr>\(cells)</tr>"
            if end < flags.count {
                rows += "<tr><td colspan=\"3\" height=\"12\" style=\"height:12px;font-size:0;line-height:0\">&nbsp;</td></tr>"
            }
            index = end
        }
        return "<table class=\"layout\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"margin:16px 0 8px;border-collapse:separate\">\(rows)</table>"
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
        let rows = (snap.rows[section] ?? []).filter { $0.textPayload["sales_grain"] != "company" }
        if let cached = snap.grainTables[section], !cached.isEmpty,
           PulseLaunch.grainTableMatchesCurrent(labels: cached.map(\.label), grain: grain) {
            let filled = HeartbeatMath.fillingGrainTable(
                cached,
                section: section,
                metricRows: rows,
                grain: grain
            )
            return grainTableHTML(shareGrainTable(filled, section: section, snap: snap, grain: grain), section: section, grain: grain)
        }
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
        return grainTableHTML(shareGrainTable(table, section: section, snap: snap, grain: grain), section: section, grain: grain)
    }

    /// Prefer live shopper buckets on share. Never expand company grainTables into RAM.
    private static func shareGrainTable(
        _ table: [HeartbeatMath.DashboardGrainTableRow],
        section: MetricSection,
        snap: Snapshot,
        grain: DashScopeGrain
    ) -> [HeartbeatMath.DashboardGrainTableRow] {
        guard section == .pickerScorecard else { return table }
        if PulseLaunch.pickerExpandHasStatusBuckets(table) { return table }
        let rows = snap.rows[.pickerScorecard] ?? []
        if !rows.isEmpty {
            let rebuilt = HeartbeatMath.dashboardGrainTableFilled(
                section: .pickerScorecard,
                rows: rows,
                grain: grain,
                order: table.map(\.label)
            )
            if PulseLaunch.pickerExpandHasStatusBuckets(rebuilt) { return rebuilt }
        }
        return table
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
        var rows: [MailTableRow] = []
        for line in shown {
            let health = line.health == .none && line.storeCount > 0 ? Health.good : line.health
            var values: [String] = []
            var tones: [Health?] = []
            if grain != .store {
                values.append(HeartbeatFormat.num(Double(line.storeCount)))
                tones.append(nil)
            }
            let metrics = HeartbeatMath.dashboardTableHeaders(section)
            let metricValues = HeartbeatMath.mergedGrainValues(
                current: line.values,
                incoming: [],
                headerCount: metrics.count
            )
            for (header, value) in zip(metrics, metricValues) {
                values.append(value)
                tones.append(
                    HeartbeatMath.dashboardExpandCellHealth(
                        section: section,
                        header: header,
                        text: value,
                        rowHealth: health,
                        values: metricValues,
                        headers: metrics
                    )
                )
            }
            rows.append(
                MailTableRow(
                    label: HeartbeatMath.displayGrainLabel(line.label),
                    values: values,
                    tones: tones,
                    health: health
                )
            )
        }
        let unit = shown.count == 1 ? String(grain.unit.dropLast()) : grain.unit
        return dataTable(
            title: "\(grain.title) · \(shown.count) \(unit)",
            detail: "Same columns as the dashboard expand",
            headers: headers,
            rows: rows,
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
        let metrics = ["Sales $", "YoY %", "Orders", "Ord YoY", "AOS", "AIV", "Items/Txn", "Items"]
        headers += metrics + ["Status"]
        var rows: [MailTableRow] = []
        for label in labels {
            let group = buckets[label] ?? []
            if group.isEmpty { continue }
            if grain == .store, rows.count >= 40 { break }
            let pack = SalesPack(rows: group)
            let health = pack.health == .none && (pack.sales ?? 0) > 0 ? Health.good : pack.health
            var values: [String] = []
            var tones: [Health?] = []
            if grain != .store {
                values.append(HeartbeatFormat.num(Double(group.count)))
                tones.append(nil)
            }
            let metricValues = [
                HeartbeatFormat.money(pack.sales),
                HeartbeatFormat.pct(pack.yoy),
                HeartbeatFormat.num(pack.orders, digits: 0),
                HeartbeatFormat.pct(pack.ordersYoy),
                HeartbeatFormat.money(pack.aos),
                HeartbeatFormat.num(pack.aiv, digits: 2),
                HeartbeatFormat.num(pack.ipt, digits: 1),
                HeartbeatFormat.num(pack.items, digits: 0),
            ]
            for (header, value) in zip(metrics, metricValues) {
                values.append(value)
                tones.append(
                    HeartbeatMath.dashboardExpandCellHealth(
                        section: .sales,
                        header: header,
                        text: value,
                        rowHealth: health,
                        values: metricValues,
                        headers: metrics
                    )
                )
            }
            rows.append(
                MailTableRow(
                    label: HeartbeatMath.displayGrainLabel(label),
                    values: values,
                    tones: tones,
                    health: health
                )
            )
        }
        guard !rows.isEmpty else { return "" }
        let unit = rows.count == 1 ? String(grain.unit.dropLast()) : grain.unit
        return dataTable(
            title: "\(grain.title) · \(rows.count) \(unit)",
            detail: "Same columns as the dashboard Sales expand",
            headers: headers,
            rows: rows,
            banner: true
        )
    }

    /// Live `dashboardActionFlags` / picker buckets for every SharePage.
    /// Stale Healthy / Watch / At Risk of 0 never win while the page has rows.
    private static func dashboardFlagModels(_ section: MetricSection, snap: Snapshot) -> [HeartbeatMath.FiveStarFlag] {
        if section == .pickerScorecard {
            return pickerShareFlags(snap)
        }
        let rows = snap.rows[section] ?? []
        let liveCount = max(
            snap.summaries.first { $0.section == section }?.storeCount ?? 0,
            rows.filter { !HeartbeatMath.canonicalStore($0.storeNumber).isEmpty }.count
        )
        let cached = snap.flags[section] ?? []
        if PulseLaunch.shouldShareLiveActionFlags(), !rows.isEmpty {
            return HeartbeatMath.dashboardActionFlags(
                section: section,
                rows: rows,
                pickers: snap.rows[.pickerScorecard] ?? [],
                pathPickers: snap.rows[.pickPathPicker] ?? [],
                items: snap.rows[.preSubOOSItem] ?? [],
                pphRows: snap.rows[.pph] ?? [],
                includeAll: true
            )
        }
        if PulseLaunch.shouldRejectZeroBandFlags(cached, liveCount: liveCount) {
            return []
        }
        return cached
    }

    private static func dashboardFlags(_ section: MetricSection, snap: Snapshot) -> [(String, String, Health)] {
        dashboardFlagModels(section, snap: snap).map { ($0.name, flagCaption($0), $0.health) }
    }

    private static func pickerShareBuckets(_ snap: Snapshot) -> (shoppers: Int, healthy: Int, watch: Int, risk: Int) {
        PulseLaunch.pickerShareBuckets(
            rows: snap.rows[.pickerScorecard] ?? [],
            chromeShoppers: max(
                snap.pickerShoppers,
                Int(snap.summaries.first { $0.section == .pickerScorecard }?.headline ?? 0)
            ),
            chromeStrong: snap.pickerStrong,
            chromeOpportunity: max(
                snap.pickerOpportunity,
                snap.summaries.first { $0.section == .pickerScorecard }?.riskCount ?? 0
            ),
            grain: snap.grainTables[.pickerScorecard] ?? []
        )
    }

    private static func pickerShareFlags(_ snap: Snapshot) -> [HeartbeatMath.FiveStarFlag] {
        let cached = snap.flags[.pickerScorecard] ?? []
        let shoppers = max(
            snap.pickerShoppers,
            Int(snap.summaries.first { $0.section == .pickerScorecard }?.headline ?? 0)
        )
        if !PulseLaunch.shouldRejectZeroPickerFlags(cached, chromeShoppers: shoppers),
           cached.contains(where: { $0.stores > 0 }) {
            let names = Set(cached.map { $0.name.lowercased() })
            if names.contains("healthy"), names.contains("watch"), names.contains("at risk") {
                return cached
            }
        }
        return PulseLaunch.pickerShareActionFlags(
            rows: snap.rows[.pickerScorecard] ?? [],
            chromeShoppers: shoppers,
            chromeStrong: snap.pickerStrong,
            chromeOpportunity: max(
                snap.pickerOpportunity,
                snap.summaries.first { $0.section == .pickerScorecard }?.riskCount ?? 0
            ),
            grain: snap.grainTables[.pickerScorecard] ?? []
        )
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
        <tr><td style="padding:18px 20px">\(inner)</td></tr>
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
        <td valign="top" width="\(colPct)%" style="width:\(colPct)%">
        <table width="100%" cellspacing="0" cellpadding="14" bgcolor="\(fill.bg)" style="width:100%;background:\(fill.bg);border:1px solid \(fill.border);border-radius:14px">
        <tr><td style="padding:14px 16px">
        <div style="font-size:15px;font-weight:700;color:#141A29;line-height:1.35">\(esc(label)) \(badge)</div>
        <div style="font-size:26px;font-weight:700;margin:10px 0 8px;color:\(fill.ink);line-height:1.25">\(esc(value))</div>
        <div style="font-size:14px;color:#5C677A;line-height:1.4">\(esc(detail))</div>
        </td></tr>
        </table>
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
        let flags = dashboardFlagModels(section, snap: snap)
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
            let buckets = pickerShareBuckets(snap)
            let shoppers = max(buckets.shoppers, scored.count)
            items = [
                tile("All Shoppers", HeartbeatFormat.num(Double(shoppers)), "Every shopper in this filter", .none, brand: true),
                tile("Healthy", HeartbeatFormat.num(Double(buckets.healthy)), "Doing well", .good),
                tile("Watch", HeartbeatFormat.num(Double(buckets.watch)), "Needs a look", buckets.watch == 0 ? .good : .watch),
                tile("At Risk", HeartbeatFormat.num(Double(buckets.risk)), "Underperforming", buckets.risk == 0 ? .good : .risk),
            ]
        default:
            if let summary {
                items = [
                    tile(summary.headlineLabel, summary.headlineText, riskLine(section, summary), summary.health),
                ]
            }
        }
        guard !items.isEmpty else { return "" }
        let perRow = mailGridColumns
        let pct = 50
        var rows = ""
        var index = 0
        while index < items.count {
            let end = min(index + perRow, items.count)
            let slice = Array(items[index..<end])
            var row = ""
            for (offset, item) in slice.enumerated() {
                if offset > 0 { row += mailGutter() }
                row += item
            }
            if slice.count < perRow {
                row += mailGutter()
                row += "<td width=\"\(pct)%\"></td>"
            }
            rows += "<tr>" + row + "</tr>"
            if end < items.count {
                rows += "<tr><td colspan=\"3\" height=\"12\" style=\"height:12px;font-size:0;line-height:0\">&nbsp;</td></tr>"
            }
            index = end
        }
        return "<table class=\"layout\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"margin:0 0 22px;border-collapse:separate\">\(rows)</table>"
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
        let metricHeaders = Array(headers.dropFirst().filter { $0 != "Status" })
        var rows: [MailTableRow] = []
        for key in buckets.keys.sorted() {
            let group = buckets[key] ?? []
            if group.isEmpty { continue }
            let sample = group.sorted { HeartbeatFormat.storeOrder($0.storeNumber, $1.storeNumber) }.first
            guard var fake = sample else { continue }
            fake.storeNumber = key
            fake.payload = averagedPayload(group)
            let health = worst(group, section: section)
            let values = metricCellsPlain(section, row: fake, pickerCount: group.count)
            rows.append(
                MailTableRow(
                    label: key,
                    detail: group.count == 1 ? "1 store" : "\(group.count) stores",
                    values: values,
                    tones: stackTones(section: section, headers: metricHeaders, values: values, rowHealth: health),
                    health: health
                )
            )
        }
        guard !rows.isEmpty else { return "" }
        return dataTable(
            title: title,
            detail: "\(filled) \(grain == "district" ? "districts" : "divisions") · same columns as the page",
            headers: headers,
            rows: rows
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
        let headers = storeHeaders(section)
        let metricHeaders = Array(headers.dropFirst().filter { $0 != "Status" })
        var lines: [MailTableRow] = []
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
            let values = metricCellsPlain(
                section,
                row: row,
                pickerCount: pickerCounts[HeartbeatMath.canonicalStore(row.storeNumber)] ?? 0
            )
            lines.append(
                MailTableRow(
                    label: label,
                    values: values,
                    tones: stackTones(section: section, headers: metricHeaders, values: values, rowHealth: health),
                    health: health
                )
            )
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
            headers: headers,
            rows: lines
        )
    }

    private static func stackTones(
        section: MetricSection,
        headers: [String],
        values: [String],
        rowHealth: Health
    ) -> [Health?] {
        zip(headers, values).map { header, value in
            HeartbeatMath.dashboardExpandCellHealth(
                section: section,
                header: header,
                text: value,
                rowHealth: rowHealth,
                values: values,
                headers: headers
            )
        }
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

    private static func numCell(_ text: String, muted: Bool = false, health: Health? = nil) -> String {
        let tone = muted ? Health.none : (health ?? .none)
        let color: String
        var fill = ""
        var cls = muted ? "num muted" : "num"
        switch (muted, tone) {
        case (true, _):
            color = "#5C677A"
        case (false, .good):
            color = "#059669"
            fill = "background:#D1FAE5;"
            cls += " cell-good"
        case (false, .watch):
            color = "#D97706"
            fill = "background:#FEF3C7;"
            cls += " cell-watch"
        case (false, .risk):
            color = "#DC2626"
            fill = "background:#FEE2E2;"
            cls += " cell-risk"
        default:
            color = "#141A29"
        }
        let width = PulseLaunch.shouldUseFixedNowrapShareTableColumns()
            ? "width=\"108\" style=\"width:108px;text-align:right;font-variant-numeric:tabular-nums;font-weight:700;font-size:16px;white-space:nowrap;padding:12px 14px;border-bottom:1px solid #E4E9F4;border-right:1px solid #EEF1F6;\(fill)color:\(color)\""
            : "style=\"width:50%;text-align:right;font-variant-numeric:tabular-nums;font-weight:700;font-size:16px;padding:12px 14px;border-bottom:1px solid #E4E9F4;border-right:1px solid #EEF1F6;\(fill)color:\(color)\""
        return "<td class=\"\(cls)\" \(width)>\(esc(text))</td>"
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

    private static func dataTable(
        title: String,
        detail: String,
        headers: [String],
        rows: [MailTableRow],
        banner: Bool = false
    ) -> String {
        guard PulseLaunch.shouldStackShareTablesForMailClients(),
              !PulseLaunch.shouldClipShareTablesInMailClients(),
              !PulseLaunch.shouldUseFixedNowrapShareTableColumns() else {
            return ""
        }
        let heading = banner
            ? bar(title, detail)
            : "<div class=\"block-title\" style=\"font-size:18px;font-weight:700;color:#003DA5;margin:22px 0 12px\">\(esc(title))<span style=\"display:block;font-size:14px;font-weight:600;color:#5C677A;margin-top:4px\">\(esc(detail))</span></div>"
        let valueHeaders = Array(headers.dropFirst().filter { $0 != "Status" })
        var cards = ""
        for row in rows {
            var lines = ""
            for (index, header) in valueHeaders.enumerated() {
                let value = index < row.values.count ? row.values[index] : "—"
                let tone = index < row.tones.count ? row.tones[index] : nil
                lines += """
                <tr>
                <th bgcolor="#EEF3FB" style="text-align:left;font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:#003DA5;background:#EEF3FB;padding:12px 14px;border-bottom:2px solid #003DA5;border-right:1px solid #D6E2F5;font-weight:700;width:50%;white-space:normal">\(esc(header))</th>
                \(numCell(value, health: tone))
                </tr>
                """
            }
            let extra = row.detail.isEmpty
                ? ""
                : "<div class=\"muted\" style=\"font-size:13px;font-weight:600;color:#5C677A;margin-top:4px\">\(esc(row.detail))</div>"
            cards += """
            <table class="data mail-stack" width="100%" cellspacing="0" cellpadding="12" bgcolor="#FFFFFF" style="width:100%;max-width:100%;border-collapse:separate;border-spacing:0;font-size:15px;line-height:1.45;background:#FFFFFF;border:1px solid #E4E9F4;margin:0 0 12px">
            <tr>
            <td class="name" style="font-weight:700;font-size:16px;padding:12px 14px;border-bottom:1px solid #E4E9F4;border-right:1px solid #EEF1F6">\(esc(row.label))\(extra)</td>
            <td class="status" style="width:30%;text-align:right;padding:12px 14px;border-bottom:1px solid #E4E9F4">\(pill(row.health))</td>
            </tr>
            \(lines)
            </table>
            """
        }
        return """
        \(heading)
        <div class="mail-stack" style="width:100%;max-width:100%;margin:0 0 22px">
        \(cards)
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

    private static func plainColumns(headers: [String], rows: [[String]]) -> String {
        let cols = headers.count
        guard cols > 0 else { return "" }
        var widths = headers.map { max($0.count, 6) }
        for row in rows {
            for (index, cell) in row.enumerated() where index < cols {
                widths[index] = max(widths[index], min(cell.count, 28))
            }
        }
        func pad(_ cell: String, _ width: Int) -> String {
            let clipped = cell.count > 28 ? String(cell.prefix(27)) + "…" : cell
            return clipped + String(repeating: " ", count: max(0, width - clipped.count))
        }
        func line(_ cells: [String]) -> String {
            zip(cells, widths).map { pad($0, $1) }.joined(separator: "  ")
        }
        var out = [line(headers)]
        out.append(widths.map { String(repeating: "-", count: $0) }.joined(separator: "  "))
        for row in rows {
            var padded = row
            if padded.count < cols {
                padded.append(contentsOf: Array(repeating: "", count: cols - padded.count))
            }
            out.append(line(Array(padded.prefix(cols))))
        }
        return out.joined(separator: "\n")
    }

    private static func plain(_ snap: Snapshot, pages: Set<SharePage>) -> String {
        var lines = [
            "Fulfillment Heartbeat",
            "",
            snap.filterSummary,
            HeartbeatFormat.stamp(snap.generatedAt),
            "Same layout and columns as the in-app page. Upload is not included.",
            "",
        ]
        if pages.contains(.dashboard) {
            lines.append("DASHBOARD")
            lines.append("")
            for card in snap.summaries {
                lines.append(card.section.title)
                lines.append("  \(card.headlineText)    \(card.health.label)    \(riskLine(card.section, card))")
                lines.append("")
                let grain = dashGrain(snap)
                let cached = snap.grainTables[card.section] ?? []
                let grainRows: [HeartbeatMath.DashboardGrainTableRow]
                if !cached.isEmpty, PulseLaunch.grainTableMatchesCurrent(labels: cached.map(\.label), grain: grain) {
                    grainRows = HeartbeatMath.fillingGrainTable(
                        cached,
                        section: card.section,
                        metricRows: snap.rows[card.section] ?? [],
                        grain: grain
                    )
                } else {
                    grainRows = HeartbeatMath.dashboardGrainTable(
                        section: card.section,
                        rows: snap.rows[card.section] ?? [],
                        grain: grain,
                        order: []
                    )
                }
                if !grainRows.isEmpty {
                    var headers = ["Scope"]
                    if grain != .store { headers.append("Stores") }
                    headers += HeartbeatMath.dashboardTableHeaders(card.section)
                    headers.append("Status")
                    let table = grainRows.map { line -> [String] in
                        var cells = [HeartbeatMath.displayGrainLabel(line.label)]
                        if grain != .store {
                            cells.append(HeartbeatFormat.num(Double(line.storeCount)))
                        }
                        cells += line.values
                        cells.append(line.health.label)
                        return cells
                    }
                    lines.append(plainColumns(headers: headers, rows: table))
                    lines.append("")
                }
            }
        }
        for page in SharePage.allCases {
            guard page != .dashboard, pages.contains(page), let section = page.section else { continue }
            let rows = snap.rows[section] ?? []
            lines.append(section.bannerTitle.uppercased())
            lines.append("")
            lines.append(storeHeaders(section).joined(separator: "  "))
            lines.append("\(rows.count) rows")
            lines.append("")
            let headers = storeHeaders(section)
            var table: [[String]] = []
            for row in rows {
                let name = section == .pickerScorecard ? "\(row.shopperName) \(row.storeNumber)" : placeLabel(row)
                let metrics = metricCellsPlain(section, row: row, pickerCount: snap.pickerCounts[HeartbeatMath.canonicalStore(row.storeNumber)] ?? 0)
                table.append([name] + metrics + [HeartbeatMath.health(for: section, row: row).label])
            }
            if !table.isEmpty {
                lines.append(plainColumns(headers: headers, rows: table))
            }
            lines.append("")
            if section == .preSubOOS, let items = snap.rows[.preSubOOSItem], !items.isEmpty {
                lines.append("PRE-SUB OOS ITEMS")
                lines.append("")
                var itemRows: [[String]] = []
                for row in items {
                    let metrics = metricCellsPlain(.preSubOOSItem, row: row, pickerCount: 0)
                    itemRows.append([placeLabel(row)] + metrics + [HeartbeatMath.health(for: .preSubOOSItem, row: row).label])
                }
                lines.append(plainColumns(headers: storeHeaders(.preSubOOSItem), rows: itemRows))
                lines.append("")
            }
        }
        lines.append("Sent from Fulfillment Heartbeat")
        return lines.joined(separator: "\n")
    }

    private static func metricCellsPlain(_ section: MetricSection, row: MetricRow, pickerCount: Int) -> [String] {
        switch section {
        case .sales:
            let pack = SalesPack(row)
            return [
                HeartbeatFormat.money(pack.sales),
                HeartbeatFormat.pct(pack.yoy),
                HeartbeatFormat.num(pack.orders, digits: 0),
                HeartbeatFormat.pct(pack.ordersYoy),
                HeartbeatFormat.money(pack.aos),
                HeartbeatFormat.num(pack.aiv, digits: 2),
                HeartbeatFormat.num(pack.ipt, digits: 1),
                HeartbeatFormat.num(pack.items, digits: 0),
            ]
        case .lostRevenue:
            return [
                HeartbeatFormat.money(row.number("lost_revenue")),
                HeartbeatFormat.pct(row.number("lost_revenue_pct")),
                HeartbeatFormat.pct(HeartbeatMath.lostRevenueGoalPct(row)),
                HeartbeatFormat.money(row.number("ecomm_sales")),
                HeartbeatFormat.money(row.number("post_sub_oos_foregone")),
                HeartbeatFormat.money(row.number("refund_lost", "refund_amt")),
                HeartbeatFormat.money(row.number("missed_sales")),
                HeartbeatFormat.money(row.number("cancelled_lost")),
                HeartbeatFormat.money(row.number("kill_switch_lost")),
            ]
        case .fiveStar:
            return [
                HeartbeatFormat.stars(row.number("star_rating")),
                HeartbeatFormat.pct(row.number("flash_pct")),
                HeartbeatFormat.pct(row.number("presub_pct")),
                HeartbeatFormat.pct(row.number("coe_pct")),
                HeartbeatFormat.pct(row.number("ott_pct")),
                HeartbeatFormat.pct(row.number("oth5_pct")),
            ]
        case .pickPath, .pickPathPicker:
            return [
                HeartbeatFormat.pct(row.number("compliance_pct")),
                HeartbeatFormat.num(row.number("pph"), digits: 1),
                HeartbeatFormat.num(row.number("orders") ?? row.number("picks_total")),
                HeartbeatFormat.shortDate(AisleMapperMath.mapperISO(row)),
                HeartbeatFormat.shortDate(AisleMapperMath.sequenceISO(row)),
            ]
        case .prepNotReady:
            return [
                HeartbeatFormat.pct(row.number("pnr_rate_pct")),
                "\(HeartbeatFormat.num(HeartbeatMath.pnrGoal, digits: 1))%",
                "\(HeartbeatFormat.num(HeartbeatMath.pnrWatch, digits: 1))%",
            ]
        case .dynacap:
            return [
                HeartbeatFormat.num(row.number("dynacap_rate", "pieces_per_hour"), digits: 1),
                HeartbeatFormat.num(row.number("pph"), digits: 1),
                HeartbeatFormat.num(HeartbeatMath.dynacapGoal, digits: 0),
                HeartbeatFormat.pct(row.number("utilization_pct")),
            ]
        case .scheduleQuality:
            return [
                HeartbeatFormat.pct(row.number("schedule_efficiency_pct")),
                HeartbeatFormat.pct(row.number("staffing_efficiency_pct")),
                "90%",
                HeartbeatFormat.pct(row.number("under_schedule_pct", "under_scheduled")),
                HeartbeatFormat.pct(row.number("over_schedule_pct", "over_scheduled")),
            ]
        case .pph:
            return [
                HeartbeatFormat.num(row.number("pph"), digits: 1),
                HeartbeatFormat.num(Double(pickerCount)),
                "80.0",
            ]
        case .labor:
            return [
                HeartbeatFormat.pct(row.number("target_vs_actual_pct")),
                HeartbeatFormat.pct(row.number("cost_trgt_pct")),
                HeartbeatFormat.pct(row.number("act_cost_pct")),
                HeartbeatFormat.pct(row.number("schedule_efficiency_pct")),
                HeartbeatFormat.pct(row.number("uplh_impact_pct")),
                HeartbeatFormat.pct(row.number("wage_impact_pct")),
                HeartbeatFormat.pct(row.number("aiv_impact_pct")),
            ]
        case .pickerScorecard:
            return [
                HeartbeatFormat.num(row.number("pick_hours"), digits: 1),
                HeartbeatFormat.num(row.number("pph", "pure_pph"), digits: 1),
                HeartbeatFormat.num(row.number("orders")),
                HeartbeatFormat.pct(row.number("presub_pct", "presub_oos_pct")),
                HeartbeatFormat.pct(row.number("ott_pct")),
                HeartbeatFormat.pct(row.number("oth5_pct")),
                HeartbeatFormat.pct(row.number("coe_pct")),
            ]
        case .missingItems, .preSubOOS:
            return [HeartbeatFormat.pct(row.number(MissingItemDept.totalKey))]
                + MissingItemDept.allCases.map { HeartbeatFormat.pct(row.number($0.rawValue)) }
        case .preSubOOSItem:
            return [
                row.textPayload["bpn"] ?? row.textPayload["item"] ?? "",
                HeartbeatFormat.pct(row.number("presub_pct")),
                HeartbeatFormat.num(row.number("presub_count"), digits: 0),
                HeartbeatFormat.money(row.number("presub_dollars")),
                HeartbeatFormat.pct(row.number("oos_pct")),
                HeartbeatFormat.money(row.number("oos_dollars")),
            ]
        case .aisleMapper:
            return [
                HeartbeatFormat.shortDate(AisleMapperMath.mapperISO(row)),
                HeartbeatFormat.shortDate(AisleMapperMath.sequenceISO(row)),
            ]
        case .storeRoster:
            return [row.division, row.district, row.operationsOM]
        }
    }

    private static func esc(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "\u{0026}amp;")
            .replacingOccurrences(of: "<", with: "\u{0026}lt;")
            .replacingOccurrences(of: ">", with: "\u{0026}gt;")
            .replacingOccurrences(of: "\"", with: "\u{0026}quot;")
    }
}
