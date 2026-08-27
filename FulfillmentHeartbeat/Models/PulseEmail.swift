import Foundation

enum PulseMail {
    struct Packet: Sendable {
        let subject: String
        let html: String
        let plain: String
        let brief: String
    }

    struct Snapshot {
        var filterSummary: String
        var grain: String?
        var summaries: [SectionSummary]
        var rows: [MetricSection: [MetricRow]]
        var pickerCounts: [String: Int]
        var generatedAt: Date
    }

    static let pageOrder: [MetricSection] = [
        .lostRevenue, .fiveStar, .pickPath, .prepNotReady, .dynacap,
        .scheduleQuality, .pickerScorecard, .pph, .labor,
    ]

    static func make(_ snap: Snapshot) -> Packet {
        let subject = "Fulfillment Heartbeat — \(snap.filterSummary) — \(HeartbeatFormat.stamp(snap.generatedAt))"
        return Packet(subject: subject, html: html(snap), plain: plain(snap), brief: brief(snap))
    }

    private static func brief(_ snap: Snapshot) -> String {
        var lines = [
            "Fulfillment Heartbeat",
            snap.filterSummary,
            HeartbeatFormat.stamp(snap.generatedAt),
            "",
            "DASHBOARD",
        ]
        for card in snap.summaries {
            lines.append("\(card.section.title): \(card.headlineText) · \(card.health.label) · \(riskLine(card.section, card))")
        }
        lines.append("")
        lines.append("Sent from Fulfillment Heartbeat")
        return lines.joined(separator: "\n")
    }

    private static func html(_ snap: Snapshot) -> String {
        var out = """
        <!DOCTYPE html><html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body{margin:0;padding:16px;background:#F5F7FC;color:#141A29;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif}
        .wrap{max-width:1100px;margin:0 auto}
        h1{font-size:22px;margin:0 0 4px}
        .sub{color:#5C677A;font-size:13px;margin:0 0 18px}
        .page{background:#fff;border:2.5px solid #003DA5;border-radius:16px;overflow:hidden;margin:0 0 18px}
        .banner{background:#003DA5;color:#fff;padding:12px 16px;font-weight:700;font-size:18px}
        .banner small{display:block;font-weight:600;opacity:.9;font-size:12px;margin-top:2px}
        .pad{padding:14px 16px}
        .kpis{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 12px}
        .kpi{flex:1 1 140px;background:#F5F7FC;border-radius:10px;padding:10px 12px}
        .kpi .l{font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:#8A93A3;font-weight:700}
        .kpi .v{font-size:22px;font-weight:700;margin-top:2px}
        table{width:100%;border-collapse:collapse;font-size:12px}
        th{text-align:left;font-size:10px;letter-spacing:.06em;text-transform:uppercase;color:#8A93A3;padding:6px 8px;border-bottom:1px solid #E4E9F4}
        td{padding:6px 8px;border-bottom:1px solid #EEF1F6;white-space:nowrap}
        td.num{text-align:right;font-variant-numeric:tabular-nums;font-weight:700}
        .pill{display:inline-block;padding:2px 8px;border-radius:999px;font-size:10px;font-weight:700;color:#fff}
        .good{background:#059669;color:#fff}
        .watch{background:#D97706;color:#fff}
        .risk{background:#DC2626;color:#fff}
        .none{background:#8A93A3;color:#fff}
        .cell-good{background:#D1FAE5;color:#059669}
        .cell-watch{background:#FEF3C7;color:#D97706}
        .cell-risk{background:#FEE2E2;color:#DC2626}
        .muted{color:#5C677A}
        </style></head><body><div class="wrap">
        <h1>Fulfillment Heartbeat</h1>
        <p class="sub">\(esc(snap.filterSummary))<br>\(esc(HeartbeatFormat.stamp(snap.generatedAt))) · Store tables expanded · Checklist not included</p>
        """
        out += dashboardHTML(snap)
        for section in pageOrder {
            out += sectionHTML(section, snap: snap)
        }
        out += "<p class=\"sub\">Sent from Fulfillment Heartbeat</p></div></body></html>"
        return out
    }

    private static func dashboardHTML(_ snap: Snapshot) -> String {
        var rows = ""
        if let lost = snap.summaries.first(where: { $0.section == .lostRevenue }) {
            rows += dashRow(lost, extra: "Lost % \(HeartbeatFormat.pct(lost.lostRevenuePct))")
        }
        for card in snap.summaries where card.section != .lostRevenue {
            rows += dashRow(card, extra: nil)
        }
        return """
        <div class="page">
        <div class="banner">Dashboard<small>Operational Heartbeat · \(esc(snap.filterSummary))</small></div>
        <div class="pad"><table>\(rows)</table></div>
        </div>
        """
    }

    private static func dashRow(_ card: SectionSummary, extra: String?) -> String {
        let risk: String
        if card.section == .pickerScorecard {
            risk = card.riskCount == 0 ? "0 pickers at risk" : "\(HeartbeatFormat.num(Double(card.riskCount))) pickers at risk"
        } else {
            risk = card.riskCount == 0 ? "0 stores at risk" : "\(HeartbeatFormat.num(Double(card.riskCount))) stores at risk"
        }
        let more = extra.map { "<div class=\"muted\">\(esc($0))</div>" } ?? ""
        return """
        <tr>
        <td><b>\(esc(card.section.title))</b><div class="muted">\(esc(card.headlineLabel))</div></td>
        <td class="num">\(esc(card.headlineText))</td>
        <td>\(esc(risk))\(more)</td>
        <td>\(pill(card.health))</td>
        </tr>
        """
    }

    private static func sectionHTML(_ section: MetricSection, snap: Snapshot) -> String {
        let summary = snap.summaries.first { $0.section == section }
        let stores = snap.rows[section] ?? []
        let kpis = kpiStrip(section, summary: summary, rows: stores)
        let rollup = rollupTable(section, rows: stores, grain: snap.grain)
        let table = storeTable(section, rows: stores, pickerCounts: snap.pickerCounts)
        return """
        <div class="page">
        <div class="banner">\(esc(section.bannerTitle))<small>\(esc(summary?.headlineLabel ?? section.title)) · \(esc(summary?.headlineText ?? "—")) · \(esc(riskLine(section, summary)))</small></div>
        <div class="pad">
        \(kpis)
        \(rollup)
        \(table)
        </div>
        </div>
        """
    }

    private static func kpiStrip(_ section: MetricSection, summary: SectionSummary?, rows: [MetricRow]) -> String {
        func avg(_ key: String) -> Double? {
            HeartbeatMath.average(rows.compactMap { $0.number(key) })
        }
        var items: [(String, String)] = []
        if let summary {
            items.append((summary.headlineLabel, summary.headlineText))
            items.append(("Status", summary.health.label))
            items.append((section == .pickerScorecard ? "At risk pickers" : "Stores at risk", HeartbeatFormat.num(Double(summary.riskCount))))
        }
        switch section {
        case .lostRevenue:
            items.append(("Lost %", HeartbeatFormat.pct(summary?.lostRevenuePct)))
        case .scheduleQuality:
            items.append(("Staffing %", HeartbeatFormat.pct(avg("staffing_efficiency_pct"))))
        case .pph:
            items.append(("Goal", "80.0"))
        default:
            break
        }
        guard !items.isEmpty else { return "" }
        let cells = items.map { "<div class=\"kpi\"><div class=\"l\">\(esc($0.0))</div><div class=\"v\">\(esc($0.1))</div></div>" }.joined()
        return "<div class=\"kpis\">\(cells)</div>"
    }

    private static func groupKey(_ row: MetricRow, grain: String) -> String {
        if grain == "district" {
            return row.district.isEmpty ? "Unassigned" : row.district
        }
        return row.division.isEmpty ? "Unassigned" : MarketRegion.canonicalName(row.division)
    }

    private static func rollupTable(_ section: MetricSection, rows: [MetricRow], grain: String?) -> String {
        guard section != .pickerScorecard else { return "" }
        guard let grain, grain == "division" || grain == "district" else { return "" }
        var buckets: [String: [MetricRow]] = [:]
        for row in rows where !row.storeNumber.isEmpty {
            buckets[groupKey(row, grain: grain), default: []].append(row)
        }
        guard !buckets.isEmpty else { return "" }
        let headers = [grain == "district" ? "District" : "Division", "Stores"] + storeHeaders(section).filter { $0 != "Store" }
        let head = headers.map { "<th>\(esc($0))</th>" }.joined()
        var body = ""
        let ordered = buckets.keys.sorted()
        for key in ordered {
            let group = buckets[key] ?? []
            let sample = group.sorted { HeartbeatFormat.storeOrder($0.storeNumber, $1.storeNumber) }.first
            guard let sample else { continue }
            var fake = sample
            fake.storeNumber = key
            fake.payload = averagedPayload(group)
            let health = worst(group, section: section)
            body += "<tr><td><b>\(esc(key))</b></td><td class=\"num\">\(group.count)</td>"
            body += storeCells(section, row: fake, pickerCount: group.count, health: health)
            body += "</tr>"
        }
        let title = grain == "district" ? "By district" : "Markets"
        return "<p class=\"l muted\" style=\"font-size:11px;letter-spacing:.06em;text-transform:uppercase;font-weight:700\">\(esc(title)) · \(buckets.count)</p><table><tr>\(head)</tr>\(body)</table><br>"
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
            if key == "lost_revenue" || key == "ecomm_sales" || key == "refund_amt" || key == "orders" || key == "picks_total" {
                out[key] = pair.total
            } else {
                out[key] = pair.total / pair.count
            }
        }
        return out
    }

    private static func storeTable(_ section: MetricSection, rows: [MetricRow], pickerCounts: [String: Int]) -> String {
        let title = section == .pickerScorecard ? "Shoppers" : "Store"
        if rows.isEmpty {
            return "<p class=\"muted\">No \(title.lowercased()) in this view.</p>"
        }
        let headers = storeHeaders(section)
        let head = headers.map { "<th>\(esc($0))</th>" }.joined()
        var body = ""
        let ordered: [MetricRow]
        if section == .pickerScorecard {
            ordered = Array(rows.prefix(2500))
        } else {
            ordered = rows.sorted { HeartbeatFormat.storeOrder($0.storeNumber, $1.storeNumber) }
        }
        for row in ordered {
            let health = HeartbeatMath.health(for: section, row: row)
            let label = section == .pickerScorecard
                ? "\(row.shopperName) · \(row.storeNumber)"
                : (row.division.isEmpty ? row.storeNumber : "\(row.storeNumber)  |  \(row.division)")
            body += "<tr><td>\(esc(label))</td>"
            body += storeCells(section, row: row, pickerCount: pickerCounts[HeartbeatMath.canonicalStore(row.storeNumber)] ?? 0, health: health)
            body += "</tr>"
        }
        var note = "\(title) · \(HeartbeatFormat.num(Double(rows.count))) rows expanded"
        if section == .pickerScorecard, rows.count > 2500 {
            note += " · email shows first 2,500 of \(HeartbeatFormat.num(Double(rows.count)))"
        }
        return "<p class=\"l muted\" style=\"font-size:11px;letter-spacing:.06em;text-transform:uppercase;font-weight:700\">\(esc(note))</p><table><tr>\(head)</tr>\(body)</table>"
    }

    private static func storeHeaders(_ section: MetricSection) -> [String] {
        switch section {
        case .fiveStar: return ["Store", "Rating", "Flash", "Presub", "COE", "OTT", "OTH5", "Status"]
        case .pickPath, .pickPathPicker: return ["Store", "Pick Path", "PPH", "Orders", "Status"]
        case .prepNotReady: return ["Store", "PNR %", "Goal", "Watch", "Status"]
        case .dynacap: return ["Store", "Rate", "PPH", "Goal", "Util", "Status"]
        case .scheduleQuality: return ["Store", "Efficiency", "Staffing % (Pch vs Tgt)", "Goal", "Under", "Over", "Status"]
        case .pph: return ["Store", "PPH", "Pickers", "Goal", "Status"]
        case .labor: return ["Store", "Tgt vs Act", "CostTrgt%", "ActCost%", "Sch Effi%", "UPLH", "Wage", "AIV", "Status"]
        case .lostRevenue: return ["Store", "Lost $", "Lost %", "Goal", "Sales", "Post", "Refund", "Missed", "Status"]
        case .pickerScorecard: return ["Shopper", "PPH", "Presub", "OOS%", "OTT", "OTH5", "Refund", "Status"]
        }
    }

    private static func storeCells(_ section: MetricSection, row: MetricRow, pickerCount: Int, health: Health) -> String {
        func cell(_ text: String, _ metricHealth: Health? = nil) -> String {
            let cls = metricHealth.map { "num cell-\($0.rawValue)" } ?? "num"
            return "<td class=\"\(cls)\">\(esc(text))</td>"
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
        case .prepNotReady:
            html += cell(HeartbeatFormat.pct(row.number("pnr_rate_pct")), HeartbeatMath.health(for: .prepNotReady, row: row))
            html += cell("\(HeartbeatFormat.num(HeartbeatMath.pnrGoal, digits: 1))%")
            html += cell("\(HeartbeatFormat.num(HeartbeatMath.pnrWatch, digits: 1))%")
        case .dynacap:
            html += cell(HeartbeatFormat.num(row.number("dynacap_rate", "pieces_per_hour"), digits: 1))
            html += cell(HeartbeatFormat.num(row.number("pph"), digits: 1))
            html += cell(HeartbeatFormat.num(HeartbeatMath.dynacapGoal, digits: 0))
            html += cell(HeartbeatFormat.pct(row.number("utilization_pct")))
        case .scheduleQuality:
            html += cell(HeartbeatFormat.pct(row.number("schedule_efficiency_pct")), HeartbeatMath.band(row.number("schedule_efficiency_pct"), good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch))
            html += cell(HeartbeatFormat.pct(row.number("staffing_efficiency_pct")), HeartbeatMath.band(row.number("staffing_efficiency_pct"), good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch))
            html += cell("90%")
            html += cell(HeartbeatFormat.pct(row.number("under_schedule_pct", "under_scheduled")), HeartbeatMath.varianceHealth(row.number("under_schedule_pct", "under_scheduled")))
            html += cell(HeartbeatFormat.pct(row.number("over_schedule_pct", "over_scheduled")), HeartbeatMath.varianceHealth(row.number("over_schedule_pct", "over_scheduled")))
        case .pph:
            html += cell(HeartbeatFormat.num(row.number("pph"), digits: 1), HeartbeatMath.pphHealth(row))
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
            html += cell("3.00%")
            html += cell(HeartbeatFormat.money(row.number("ecomm_sales")))
            html += cell(HeartbeatFormat.money(row.number("post_sub_oos_foregone")))
            html += cell(HeartbeatFormat.money(row.number("refund_lost", "refund_amt")))
            html += cell(HeartbeatFormat.money(row.number("missed_sales")))
        case .pickerScorecard:
            html += cell(HeartbeatFormat.num(row.number("pph"), digits: 1), HeartbeatMath.pickerHealth(row))
            html += cell(HeartbeatFormat.pct(row.number("presub_pct")))
            html += cell(HeartbeatFormat.pct(row.number("oos_pct")))
            html += cell(HeartbeatFormat.pct(row.number("ott_pct")))
            html += cell(HeartbeatFormat.pct(row.number("oth5_pct")))
            html += cell(HeartbeatFormat.money(row.number("refund_amt")))
        }
        html += "<td>\(pill(health))</td>"
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

    private static func pill(_ health: Health) -> String {
        "<span class=\"pill \(health.rawValue)\">\(esc(health.label.uppercased()))</span>"
    }

    private static func plain(_ snap: Snapshot) -> String {
        var lines = [
            "Fulfillment Heartbeat",
            snap.filterSummary,
            HeartbeatFormat.stamp(snap.generatedAt),
            "Store tables expanded. Checklist not included.",
            "",
        ]
        lines.append("DASHBOARD")
        for card in snap.summaries {
            lines.append("\(card.section.title): \(card.headlineText) · \(card.health.label) · \(riskLine(card.section, card))")
        }
        for section in pageOrder {
            let rows = snap.rows[section] ?? []
            lines.append("")
            lines.append(section.bannerTitle.uppercased())
            lines.append("\(rows.count) rows")
            for row in rows.prefix(section == .pickerScorecard ? 2500 : rows.count) {
                let name = section == .pickerScorecard ? "\(row.shopperName) \(row.storeNumber)" : row.storeNumber
                lines.append("\(name) · \(HeartbeatMath.health(for: section, row: row).label)")
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
