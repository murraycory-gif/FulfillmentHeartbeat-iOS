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
    }

    static let pageOrder: [MetricSection] = [
        .sales, .lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .prepNotReady, .dynacap,
        .scheduleQuality, .pickerScorecard, .pph, .labor,
    ]

    static func make(_ snap: Snapshot, pages: Set<SharePage> = Set(SharePage.allCases)) -> Packet {
        let chosen = pages.isEmpty ? Set(SharePage.allCases) : pages
        let names = SharePage.allCases.filter { chosen.contains($0) }.map(\.title)
        let subject = "Fulfillment Heartbeat — \(snap.filterSummary) — \(HeartbeatFormat.stamp(snap.generatedAt))"
        return Packet(
            subject: subject,
            html: html(snap, pages: chosen),
            plain: plain(snap, pages: chosen),
            brief: brief(snap, pages: chosen, names: names)
        )
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

    private static func html(_ snap: Snapshot, pages: Set<SharePage>) -> String {
        var out = """
        <!DOCTYPE html><html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body{margin:0;padding:16px;background:#F5F7FC;color:#141A29;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif}
        .wrap{max-width:1100px;margin:0 auto}
        h1{font-size:22px;margin:0 0 4px;color:#003DA5}
        .sub{color:#5C677A;font-size:13px;margin:0 0 18px}
        table.layout{width:100%;border-collapse:separate;border-spacing:8px 8px}
        table.data{width:100%;border-collapse:collapse;font-size:12px}
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
        <p class="sub">\(esc(snap.filterSummary))<br>\(esc(HeartbeatFormat.stamp(snap.generatedAt))) · Matches the in-app pages · Checklist not included</p>
        """
        if pages.contains(.dashboard) {
            out += dashboardHTML(snap)
        }
        for page in SharePage.allCases {
            guard page != .dashboard, pages.contains(page), let section = page.section else { continue }
            out += sectionHTML(section, snap: snap)
        }
        out += "<p class=\"sub\">Sent from Fulfillment Heartbeat</p></div></body></html>"
        return out
    }

    private static func dashboardHTML(_ snap: Snapshot) -> String {
        var cards = ""
        let grain = dashGrain(snap)
        for card in snap.summaries {
            let flags = dashboardFlagModels(card.section, snap: snap)
            let fill = cardFill(card.health)
            var flagHTML = ""
            if !flags.isEmpty {
                var cells = ""
                for flag in flags {
                    cells += """
                    <td style="background:#fff;border:1px solid #E4E9F4;border-radius:10px;padding:8px 10px">
                    <div style="font-size:11px;color:#5C677A;font-weight:700">\(esc(flag.name))</div>
                    <div style="font-size:16px;font-weight:700;margin-top:2px;color:\(ink(flag.health))">\(esc(flagCaption(flag))) \(pill(flag.health))</div>
                    </td>
                    """
                }
                flagHTML = "<table class=\"layout\" width=\"100%\" cellspacing=\"8\" cellpadding=\"0\"><tr>\(cells)</tr></table>"
            }
            let title = card.section == .pickPath ? "Pick Path Compliance" : card.section.title
            cards += """
            <table width="100%" cellspacing="0" cellpadding="0" style="margin:0 0 10px;background:\(fill.bg);border:1px solid \(fill.border);border-radius:14px">
            <tr>
            <td style="padding:12px 14px">
            <div style="font-size:18px;font-weight:700;color:#141A29">\(esc(title))</div>
            <div style="color:#5C677A;font-size:13px">\(esc(card.headlineLabel))</div>
            <div style="font-weight:700;margin-top:4px;color:\(card.riskCount == 0 ? ink(.good) : ink(.risk))">\(esc(riskLine(card.section, card)))</div>
            \(flagHTML)
            \(grainHTML(card.section, snap: snap, grain: grain))
            </td>
            <td valign="top" style="padding:12px 14px;text-align:right;white-space:nowrap">
            <div style="font-size:28px;font-weight:700;color:\(ink(card.health))">\(esc(card.headlineText))</div>
            \(pill(card.health))
            </td>
            </tr>
            </table>
            """
        }
        return pageWrap(title: "Operational Heartbeat", filter: snap.filterSummary, trailing: sharedWindow(snap), inner: cards)
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
        default: return .division
        }
    }

    private static func grainHTML(_ section: MetricSection, snap: Snapshot, grain: DashScopeGrain) -> String {
        let rows = (snap.rows[section] ?? []).filter { $0.textPayload["sales_grain"] != "company" }
        let lines = HeartbeatMath.dashboardScopeLines(section: section, rows: rows, grain: grain)
            .filter { $0.label != "Unassigned" && !$0.label.isEmpty }
        guard !lines.isEmpty else { return "" }
        var body = ""
        for line in lines {
            let count = grain == .store ? "" : (line.count == 1 ? "1 store" : "\(line.count) stores")
            body += """
            <tr>
            <td style="padding:6px 8px;font-weight:700">\(esc(line.label))</td>
            <td class="num" style="padding:6px 8px;color:\(ink(line.health))">\(esc(line.value))</td>
            <td class="muted" style="padding:6px 8px">\(esc(count))</td>
            <td style="padding:6px 8px;text-align:right">\(pill(line.health))</td>
            </tr>
            """
        }
        return """
        <div style="margin-top:10px;font-size:12px;font-weight:700;color:#003DA5">\(esc(grain.title)) · \(lines.count) \(lines.count == 1 ? String(grain.unit.dropLast()) : grain.unit)</div>
        <table class="data" width="100%" cellspacing="0" cellpadding="0" style="margin-top:6px">
        <tr><th>\(esc(String(grain.title.dropLast())))</th><th class="num">Value</th><th></th><th></th></tr>
        \(body)
        </table>
        """
    }

    private static func dashboardFlagModels(_ section: MetricSection, snap: Snapshot) -> [HeartbeatMath.FiveStarFlag] {
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
        let table = storeTable(section, rows: stores, pickerCounts: snap.pickerCounts)
        let window = stores.first { !($0.textPayload["data_window"] ?? "").isEmpty }?.textPayload["data_window"]
        return pageWrap(
            title: section.bannerTitle,
            filter: snap.filterSummary,
            trailing: window,
            inner: kpis + rollup + table
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
        <tr><td style="background:#003DA5;color:#fff;padding:12px 16px;font-weight:700;font-size:18px">
        <table width="100%" cellspacing="0" cellpadding="0"><tr>
        <td style="color:#fff;font-weight:700;font-size:18px">
        \(esc(title))
        <div style="font-weight:600;opacity:.9;font-size:12px;margin-top:2px">\(esc(filter))</div>
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

    private static func cardFill(_ health: Health) -> (bg: String, border: String) {
        switch health {
        case .good: return ("#ECFDF5", "#A7F3D0")
        case .watch: return ("#FFFBEB", "#FDE68A")
        case .risk: return ("#FEF2F2", "#FECACA")
        case .none: return ("#FFFFFF", "#E4E9F4")
        }
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

    private static func tile(_ label: String, _ value: String, _ detail: String, _ health: Health, brand: Bool = false) -> String {
        let fill = tileFill(health, brand: brand)
        let badge = health == .none ? "" : pill(health)
        return """
        <td valign="top" style="width:25%;background:\(fill.bg);border:1px solid \(fill.border);border-radius:14px;padding:12px 14px">
        <div style="font-size:12px;font-weight:700;color:#141A29">\(esc(label)) \(badge)</div>
        <div style="font-size:26px;font-weight:700;margin-top:6px;color:\(fill.ink)">\(esc(value))</div>
        <div style="font-size:12px;color:#5C677A;margin-top:4px">\(esc(detail))</div>
        </td>
        """
    }

    private static func kpiTiles(_ section: MetricSection, summary: SectionSummary?, rows: [MetricRow], snap: Snapshot) -> String {
        let scored = rows.filter { !$0.storeNumber.isEmpty }
        var items: [String] = []
        switch section {
        case .sales:
            let sales = scored.compactMap { $0.number("sales_dollars") }.reduce(0, +)
            let orders = scored.compactMap { $0.number("sales_orders") }.reduce(0, +)
            let hd = scored.compactMap { $0.number("sales_hd_orders") }.reduce(0, +)
            let dug = scored.compactMap { $0.number("sales_dug_orders") }.reduce(0, +)
            items = [
                tile("eComm sales", HeartbeatFormat.money(scored.isEmpty ? nil : sales), "In this filter", summary?.health ?? .none),
                tile("Orders", HeartbeatFormat.num(orders, digits: 0), "DUG + Home Delivery", .none, brand: true),
                tile("AOV", HeartbeatFormat.money(orders > 0 ? sales / orders : nil), "Sales / orders", .none, brand: true),
                tile("HD orders", HeartbeatFormat.num(hd, digits: 0), "Home Delivery", .none),
                tile("DUG orders", HeartbeatFormat.num(dug, digits: 0), "Drive Up & Go", .none),
            ]
        case .lostRevenue:
            let healthy = scored.filter { HeartbeatMath.lostRevenueHealth($0) == .good }.count
            let watch = scored.filter { HeartbeatMath.lostRevenueHealth($0) == .watch }.count
            let risk = scored.filter { HeartbeatMath.lostRevenueHealth($0) == .risk }.count
            let sales = scored.compactMap { $0.number("ecomm_sales") }.reduce(0, +)
            let post = scored.compactMap { $0.number("post_sub_oos_foregone") }.reduce(0, +)
            items = [
                tile("Total lost revenue", summary?.headlineText ?? "—", "Total Opportunity", summary?.health ?? .none),
                tile("Healthy", HeartbeatFormat.num(Double(healthy)), "3% or better", .good),
                tile("Watch", HeartbeatFormat.num(Double(watch)), "3.01% to 5%", watch == 0 ? .good : .watch),
                tile("At Risk", HeartbeatFormat.num(Double(risk)), "Stores over 5%", risk == 0 ? .good : .risk),
                tile("Lost revenue %", HeartbeatFormat.pct(summary?.lostRevenuePct), "Total Opportunity", summary?.health ?? .none),
                tile("eComm sales", HeartbeatFormat.money(scored.isEmpty ? nil : sales), "In this filter", .none, brand: true),
                tile("Post Sub OOS", HeartbeatFormat.money(scored.isEmpty ? nil : post), "Foregone revenue", .none),
            ]
        case .missingItems:
            let healthy = scored.filter { HeartbeatMath.missingItemsHealth($0) == .good }.count
            let watch = scored.filter { HeartbeatMath.missingItemsHealth($0) == .watch }.count
            let risk = scored.filter { HeartbeatMath.missingItemsHealth($0) == .risk }.count
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
            let healthy = scored.filter { HeartbeatMath.missingItemsHealth($0) == .good }.count
            let watch = scored.filter { HeartbeatMath.missingItemsHealth($0) == .watch }.count
            let risk = scored.filter { HeartbeatMath.missingItemsHealth($0) == .risk }.count
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
                tile("Avg pure PPH", summary?.headlineText ?? "—", "Goal 80 · watch under 74", summary?.health ?? .none),
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
        var rows = ""
        var index = 0
        let perRow = 4
        while index < items.count {
            let end = min(index + perRow, items.count)
            rows += "<tr>" + items[index..<end].joined() + "</tr>"
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
        let headers = [grain == "district" ? "District" : "Division", "Stores"] + storeHeaders(section).filter { $0 != "Store" && $0 != "Shopper" }
        let head = headers.map { "<th>\(esc($0))</th>" }.joined()
        var body = ""
        let ordered = buckets.keys.sorted()
        for key in ordered {
            let group = buckets[key] ?? []
            if group.isEmpty {
                body += "<tr><td><b>\(esc(key))</b></td><td class=\"num\">0</td>"
                body += String(repeating: "<td class=\"num\">—</td>", count: max(0, headers.count - 2))
                body += "</tr>"
                continue
            }
            let sample = group.sorted { HeartbeatFormat.storeOrder($0.storeNumber, $1.storeNumber) }.first
            guard var fake = sample else { continue }
            fake.storeNumber = key
            fake.payload = averagedPayload(group)
            let health = worst(group, section: section)
            body += "<tr><td><b>\(esc(key))</b></td><td class=\"num\">\(group.count)</td>"
            body += storeCells(section, row: fake, pickerCount: group.count, health: health)
            body += "</tr>"
        }
        let title = grain == "district" ? "By district" : "Markets"
        return bar(title, "\(buckets.count) \(grain == "district" ? "districts" : "divisions")")
            + "<table class=\"data\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\"><tr>\(head)</tr>\(body)</table>"
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

    private static func storeTable(_ section: MetricSection, rows: [MetricRow], pickerCounts: [String: Int]) -> String {
        let title = section == .pickerScorecard ? "Shopper" : "Store"
        if rows.isEmpty {
            return bar(title, "No rows in this view")
        }
        let cap = section == .pickerScorecard ? 200 : rows.count
        let headers = storeHeaders(section)
        let head = headers.map { "<th>\(esc($0))</th>" }.joined()
        var body = ""
        let ordered: [MetricRow]
        if section == .pickerScorecard {
            ordered = Array(rows.prefix(cap))
        } else {
            ordered = Array(rows.sorted { HeartbeatFormat.storeOrder($0.storeNumber, $1.storeNumber) }.prefix(cap))
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
        var note = "\(HeartbeatFormat.num(Double(rows.count))) \(title.lowercased())s · showing \(ordered.count)"
        if rows.count > ordered.count {
            note += " of \(HeartbeatFormat.num(Double(rows.count))) · open the app for the rest"
        }
        return bar(title, note)
            + "<table class=\"data\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\"><tr>\(head)</tr>\(body)</table>"
    }

    private static func storeHeaders(_ section: MetricSection) -> [String] {
        switch section {
        case .fiveStar: return ["Store", "Rating", "Flash", "Presub", "COE", "OTT", "OTH5", "Status"]
        case .pickPath, .pickPathPicker: return ["Store", "Pick Path", "PPH", "Orders", "Mapper", "Sequence", "Status"]
        case .prepNotReady: return ["Store", "PNR %", "Goal", "Watch", "Status"]
        case .dynacap: return ["Store", "Rate", "PPH", "Goal", "Util", "Status"]
        case .scheduleQuality: return ["Store", "Efficiency", "Staffing % (Pch vs Tgt)", "Goal", "Under", "Over", "Status"]
        case .pph: return ["Store", "PPH", "Pickers", "Goal", "Status"]
        case .labor: return ["Store", "Tgt vs Act", "CostTrgt%", "ActCost%", "Sch Effi%", "UPLH", "Wage", "AIV", "Status"]
        case .lostRevenue: return ["Store", "Lost $", "Lost %", "Goal", "Sales", "Post", "Refund", "Missed", "Status"]
        case .sales: return ["Store", "Sales $", "YoY %", "Orders", "AOS", "AIV", "Items", "Status"]
        case .missingItems, .preSubOOS:
            return ["Store"] + MissingItemDept.allCases.map(\.title) + ["Total", "Status"]
        case .preSubOOSItem:
            return ["Store", "Item", "Pre-Sub %", "Units", "$ Pre-Sub", "OOS %", "$ OOS", "Status"]
        case .aisleMapper:
            return ["Store", "Mapper", "Sequence", "Status"]
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
            html += cell(HeartbeatFormat.shortDate(AisleMapperMath.mapperISO(row)), AisleMapperMath.health(AisleMapperMath.mapperISO(row)))
            html += cell(HeartbeatFormat.shortDate(AisleMapperMath.sequenceISO(row)), AisleMapperMath.health(AisleMapperMath.sequenceISO(row)))
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
        case .sales:
            html += cell(HeartbeatFormat.money(row.number("sales_dollars")), HeartbeatMath.salesHealth(row))
            html += cell(HeartbeatFormat.pct(row.number("sales_yoy_pct")), HeartbeatMath.salesHealth(row))
            html += cell(HeartbeatFormat.num(row.number("sales_orders"), digits: 0))
            html += cell(HeartbeatFormat.money(row.number("sales_aos") ?? row.number("sales_aov")))
            html += cell(HeartbeatFormat.num(row.number("sales_aiv"), digits: 2))
            html += cell(HeartbeatFormat.num(row.number("sales_items"), digits: 0))
        case .missingItems, .preSubOOS:
            for dept in MissingItemDept.allCases {
                let value = row.number(dept.rawValue)
                html += cell(HeartbeatFormat.pct(value), HeartbeatMath.missingItemsHealth(pct: value))
            }
            html += cell(HeartbeatFormat.pct(row.number(MissingItemDept.totalKey)), HeartbeatMath.health(for: section, row: row))
        case .aisleMapper:
            html += cell(HeartbeatFormat.shortDate(AisleMapperMath.mapperISO(row)), AisleMapperMath.health(AisleMapperMath.mapperISO(row)))
            html += cell(HeartbeatFormat.shortDate(AisleMapperMath.sequenceISO(row)), AisleMapperMath.health(AisleMapperMath.sequenceISO(row)))
        case .preSubOOSItem:
            html += cell(row.textPayload["bpn"] ?? "")
            html += cell(HeartbeatFormat.pct(row.number("presub_pct")), HeartbeatMath.health(for: .preSubOOSItem, row: row))
            html += cell(HeartbeatFormat.num(row.number("presub_count"), digits: 0))
            html += cell(HeartbeatFormat.money(row.number("presub_dollars")))
            html += cell(HeartbeatFormat.pct(row.number("oos_pct")))
            html += cell(HeartbeatFormat.money(row.number("oos_dollars")))
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
        let bg: String
        switch health {
        case .good: bg = "#059669"
        case .watch: bg = "#D97706"
        case .risk: bg = "#DC2626"
        case .none: bg = "#8A93A3"
        }
        return "<span style=\"display:inline-block;padding:2px 8px;border-radius:999px;font-size:10px;font-weight:700;color:#fff;background:\(bg)\">\(esc(health.label.uppercased()))</span>"
    }

    private static func bar(_ title: String, _ detail: String) -> String {
        """
        <table width="100%" cellspacing="0" cellpadding="0" style="background:#003DA5;color:#fff;border-radius:14px;margin:8px 0">
        <tr><td style="padding:10px 14px;font-weight:700">
        \(esc(title))
        <div style="font-weight:600;opacity:.9;font-size:12px;margin-top:2px">\(esc(detail))</div>
        </td></tr>
        </table>
        """
    }

    private static func plain(_ snap: Snapshot, pages: Set<SharePage>) -> String {
        var lines = [
            "Fulfillment Heartbeat",
            snap.filterSummary,
            HeartbeatFormat.stamp(snap.generatedAt),
            "Matches the in-app pages. Checklist not included.",
            "",
        ]
        if pages.contains(.dashboard) {
            lines.append("DASHBOARD")
            for card in snap.summaries {
                lines.append("\(card.section.title): \(card.headlineText) · \(card.health.label) · \(riskLine(card.section, card))")
            }
        }
        for page in SharePage.allCases {
            guard page != .dashboard, pages.contains(page), let section = page.section else { continue }
            let rows = snap.rows[section] ?? []
            lines.append("")
            lines.append(section.bannerTitle.uppercased())
            lines.append("\(rows.count) rows")
            for row in rows.prefix(50) {
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
