import Foundation

/// On-device Heartbeat Assist: ranked problem cards, then playbook checks.
/// Check wording lives only in AssistPlaybook.json (playbook v2).
enum AssistPlaybook {
    struct Check: Codable, Equatable {
        enum Kind: String, Codable {
            case floor
            case auto
        }

        enum Combine: String, Codable {
            case first
            case any
        }

        enum Rollup: String, Codable {
            case avg
            case countFailing
        }

        var order: Int
        var type: Kind
        var question: String?
        var detail: String?
        var label: String?
        var packFields: [String]
        var combine: Combine
        var supportFields: [String]
        var comparator: String?
        var threshold: Double?
        var thresholdSource: String?
        var rollup: Rollup?
        var passText: String?
        var failText: String?
        var scopePassText: String?
        var scopeFailText: String?
        var owner: String
        var destination: String
        var fallback: String
        var confirm: Bool

        enum CodingKeys: String, CodingKey {
            case order, type, question, detail, label, packFields, combine, supportFields
            case comparator, threshold, thresholdSource, rollup
            case passText, failText, scopePassText, scopeFailText
            case owner, destination, fallback, confirm
        }

        init(
            order: Int,
            type: Kind,
            question: String? = nil,
            detail: String? = nil,
            label: String? = nil,
            packFields: [String] = [],
            combine: Combine = .first,
            supportFields: [String] = [],
            comparator: String? = nil,
            threshold: Double? = nil,
            thresholdSource: String? = nil,
            rollup: Rollup? = nil,
            passText: String? = nil,
            failText: String? = nil,
            scopePassText: String? = nil,
            scopeFailText: String? = nil,
            owner: String = "",
            destination: String,
            fallback: String = "none",
            confirm: Bool = false
        ) {
            self.order = order
            self.type = type
            self.question = question
            self.detail = detail
            self.label = label
            self.packFields = packFields
            self.combine = combine
            self.supportFields = supportFields
            self.comparator = comparator
            self.threshold = threshold
            self.thresholdSource = thresholdSource
            self.rollup = rollup
            self.passText = passText
            self.failText = failText
            self.scopePassText = scopePassText
            self.scopeFailText = scopeFailText
            self.owner = owner
            self.destination = destination
            self.fallback = fallback
            self.confirm = confirm
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            order = try container.decode(Int.self, forKey: .order)
            type = try container.decode(Kind.self, forKey: .type)
            question = try container.decodeIfPresent(String.self, forKey: .question)
            detail = try container.decodeIfPresent(String.self, forKey: .detail)
            label = try container.decodeIfPresent(String.self, forKey: .label)
            packFields = try container.decodeIfPresent([String].self, forKey: .packFields) ?? []
            combine = try container.decodeIfPresent(Combine.self, forKey: .combine) ?? .first
            supportFields = try container.decodeIfPresent([String].self, forKey: .supportFields) ?? []
            comparator = try container.decodeIfPresent(String.self, forKey: .comparator)
            threshold = try container.decodeIfPresent(Double.self, forKey: .threshold)
            thresholdSource = try container.decodeIfPresent(String.self, forKey: .thresholdSource)
            rollup = try container.decodeIfPresent(Rollup.self, forKey: .rollup)
            passText = try container.decodeIfPresent(String.self, forKey: .passText)
            failText = try container.decodeIfPresent(String.self, forKey: .failText)
            scopePassText = try container.decodeIfPresent(String.self, forKey: .scopePassText)
            scopeFailText = try container.decodeIfPresent(String.self, forKey: .scopeFailText)
            owner = try container.decodeIfPresent(String.self, forKey: .owner) ?? ""
            destination = try container.decode(String.self, forKey: .destination)
            fallback = try container.decodeIfPresent(String.self, forKey: .fallback) ?? "none"
            confirm = try container.decodeIfPresent(Bool.self, forKey: .confirm) ?? false
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(order, forKey: .order)
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(question, forKey: .question)
            try container.encodeIfPresent(detail, forKey: .detail)
            try container.encodeIfPresent(label, forKey: .label)
            if !packFields.isEmpty { try container.encode(packFields, forKey: .packFields) }
            try container.encode(combine, forKey: .combine)
            if !supportFields.isEmpty { try container.encode(supportFields, forKey: .supportFields) }
            try container.encodeIfPresent(comparator, forKey: .comparator)
            try container.encodeIfPresent(threshold, forKey: .threshold)
            try container.encodeIfPresent(thresholdSource, forKey: .thresholdSource)
            try container.encodeIfPresent(rollup, forKey: .rollup)
            try container.encodeIfPresent(passText, forKey: .passText)
            try container.encodeIfPresent(failText, forKey: .failText)
            try container.encodeIfPresent(scopePassText, forKey: .scopePassText)
            try container.encodeIfPresent(scopeFailText, forKey: .scopeFailText)
            try container.encode(owner, forKey: .owner)
            try container.encode(destination, forKey: .destination)
            try container.encode(fallback, forKey: .fallback)
            try container.encode(confirm, forKey: .confirm)
        }
    }

    struct Metric: Codable, Equatable {
        var metricId: String
        var parentId: String?
        var displayName: String
        var ownerName: String?
        var section: String
        var packField: String
        var trigger: String
        var level: String
        var ownerDefault: String
        var confirm: Bool
        var causes: [String]
        var causesConfirm: [String]
        var checks: [Check]
    }

    struct File: Codable, Equatable {
        var version: String
        var line: String
        var metrics: [Metric]

        func metric(_ id: String) -> Metric? {
            metrics.first { $0.metricId == id }
        }
    }

    static func load(from data: Data) throws -> File {
        try JSONDecoder().decode(File.self, from: data)
    }

    static func bundled() -> File? {
        guard let url = Bundle.main.url(forResource: "AssistPlaybook", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? load(from: data)
    }

    static let rankedMetricIDs: [String] = MetricSection.dashboardCards
        .filter { $0 != .pickerScorecard }
        .map(\.rawValue)
}

/// On-device auto check. Reads named pack fields for the scope in view.
/// Returns nil when the tested field is absent, so the card hides the check.
enum AssistAutoCheck {
    struct Evaluation: Equatable {
        var value: Double
        var failing: Bool
        var sentence: String
        var statusMark: String
        var statusSymbol: String
    }

    static func sentence(
        _ check: AssistPlaybook.Check,
        rows: [MetricSection: [MetricRow]],
        summaries: [MetricSection: SectionSummary] = [:],
        level: AssistScopeLevel
    ) -> String? {
        evaluate(check, rows: rows, summaries: summaries, level: level)?.sentence
    }

    static func evaluate(
        _ check: AssistPlaybook.Check,
        rows: [MetricSection: [MetricRow]],
        summaries: [MetricSection: SectionSummary] = [:],
        level: AssistScopeLevel
    ) -> Evaluation? {
        guard check.type == .auto else { return nil }
        guard let threshold = check.threshold, threshold.isFinite,
              let comparator = check.comparator?.trimmingCharacters(in: .whitespacesAndNewlines),
              !comparator.isEmpty,
              let breaks = comparison(comparator) else { return nil }
        let readings = readings(check, rows: rows, breaks: breaks, threshold: threshold)
        guard !readings.isEmpty else { return nil }

        let failingCount = readings.filter(\.failing).count
        let storeCount = readings.count
        let storeScope = level == .store
        let support = storeScope ? readings[0].support : supportValues(readings)
        let failing: Bool
        let numeric: Double
        let valueText: String
        let template: String?

        if storeScope {
            let reading = readings[0]
            failing = reading.failing
            numeric = reading.value
            valueText = format(reading.value)
            template = failing ? check.failText : check.passText
        } else if check.rollup == .countFailing {
            failing = failingCount > 0
            numeric = HeartbeatMath.average(readings.map(\.value)) ?? readings[0].value
            valueText = format(numeric)
            template = failing ? check.scopeFailText : check.scopePassText
        } else {
            if let section = HubDestination(rawValue: check.destination)?.section,
               let summary = summaries[section],
               let headline = summary.headline, headline.isFinite {
                numeric = headline
                valueText = summary.headlineText
            } else if let average = HeartbeatMath.average(readings.map(\.value)) {
                numeric = average
                valueText = String(format: "%.1f", average)
            } else {
                return nil
            }
            failing = breaks(numeric, threshold)
            template = failing ? check.scopeFailText : check.scopePassText
        }
        guard let template, !template.isEmpty else { return nil }
        var values = [
            "value": valueText,
            "threshold": format(threshold),
            "k": AssistCopy.grouped(failingCount),
            "n": AssistCopy.grouped(storeCount),
        ]
        for (key, number) in support {
            values["field:\(key)"] = format(number)
        }
        guard let sentence = render(template, values: values, failingCount: failingCount) else { return nil }
        let mark = failing ? "Check" : "OK"
        let symbol = failing ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
        return Evaluation(value: numeric, failing: failing, sentence: sentence, statusMark: mark, statusSymbol: symbol)
    }

    private struct Reading {
        var store: String
        var value: Double
        var failing: Bool
        var support: [String: Double]
    }

    private static func readings(
        _ check: AssistPlaybook.Check,
        rows: [MetricSection: [MetricRow]],
        breaks: (Double, Double) -> Bool,
        threshold: Double
    ) -> [Reading] {
        var grouped: [String: [MetricRow]] = [:]
        for sectionRows in rows.values {
            for row in AssistRank.scoringRows(sectionRows) {
                let store = HeartbeatMath.canonicalStore(row.storeNumber)
                guard !store.isEmpty else { continue }
                grouped[store, default: []].append(row)
            }
        }
        var readings: [Reading] = []
        for store in grouped.keys.sorted() {
            guard let storeRows = grouped[store] else { continue }
            guard let resolved = resolve(check, rows: storeRows, breaks: breaks, threshold: threshold) else { continue }
            var support: [String: Double] = [:]
            for key in check.supportFields {
                if let value = firstNumber([key], in: storeRows) {
                    support[key] = value
                }
            }
            readings.append(Reading(store: store, value: resolved.value, failing: resolved.failing, support: support))
        }
        return readings
    }

    private static func resolve(
        _ check: AssistPlaybook.Check,
        rows: [MetricRow],
        breaks: (Double, Double) -> Bool,
        threshold: Double
    ) -> (value: Double, failing: Bool)? {
        if check.combine == .any {
            var chosen: Double?
            var failing = false
            for key in check.packFields {
                guard let value = firstNumber([key], in: rows) else { continue }
                if chosen == nil { chosen = value }
                if breaks(value, threshold) {
                    failing = true
                    chosen = value
                }
            }
            guard let chosen else { return nil }
            return (chosen, failing)
        }
        guard let value = firstNumber(check.packFields, in: rows) else { return nil }
        return (value, breaks(value, threshold))
    }

    private static func firstNumber(_ keys: [String], in rows: [MetricRow]) -> Double? {
        for key in keys {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            for row in rows {
                if let value = row.number(trimmed), value.isFinite { return value }
            }
        }
        return nil
    }

    private static func supportValues(_ readings: [Reading]) -> [String: Double] {
        var buckets: [String: [Double]] = [:]
        for reading in readings {
            for (key, value) in reading.support {
                buckets[key, default: []].append(value)
            }
        }
        var result: [String: Double] = [:]
        for (key, values) in buckets {
            if let average = HeartbeatMath.average(values) {
                result[key] = average
            }
        }
        return result
    }

    private static func comparison(_ comparator: String) -> ((Double, Double) -> Bool)? {
        switch comparator.lowercased() {
        case "lt", "<": return { $0 < $1 }
        case "gt", ">": return { $0 > $1 }
        case "lte", "<=", "le": return { $0 <= $1 }
        case "gte", ">=", "ge": return { $0 >= $1 }
        default: return nil
        }
    }

    static func format(_ value: Double) -> String {
        let text = String(format: "%.1f", value)
        guard text.hasSuffix(".0"), let whole = text.split(separator: ".").first else { return text }
        return String(whole)
    }

    static func render(_ template: String, values: [String: String], failingCount: Int) -> String? {
        guard let brackets = try? NSRegularExpression(pattern: "\\[([^\\]]*)\\]"),
              let tokens = try? NSRegularExpression(pattern: "\\{([^{}]+)\\}") else { return nil }
        let source = template as NSString
        let matches = brackets.matches(in: template, range: NSRange(location: 0, length: source.length))
        var text = ""
        var cursor = 0
        for match in matches {
            let full = match.range
            if full.location < cursor { continue }
            text += source.substring(with: NSRange(location: cursor, length: full.location - cursor))
            let inner = source.substring(with: match.range(at: 1))
            let drop = (inner.contains("{k}") && failingCount == 0) || missingToken(inner, values: values, tokens: tokens)
            if !drop { text += inner }
            cursor = full.location + full.length
        }
        if cursor < source.length {
            text += source.substring(from: cursor)
        }
        guard !missingToken(text, values: values, tokens: tokens) else { return nil }
        return substitute(text, values: values, tokens: tokens)
    }

    private static func missingToken(_ text: String, values: [String: String], tokens: NSRegularExpression) -> Bool {
        let ns = text as NSString
        let matches = tokens.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            let key = ns.substring(with: match.range(at: 1))
            if values[key]?.isEmpty != false { return true }
        }
        return false
    }

    private static func substitute(_ text: String, values: [String: String], tokens: NSRegularExpression) -> String {
        let ns = text as NSString
        let matches = tokens.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var result = text
        for match in matches.reversed() {
            let key = ns.substring(with: match.range(at: 1))
            guard let value = values[key], let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: value)
        }
        return result
    }
}

/// Loss Revenue Why line. Only the owner's chain is used.
/// causesConfirm links are ignored until the owner confirms them.
enum AssistCauses {
    struct Report: Equatable {
        var why: String
        var checks: [AssistAction]
        var namedIDs: [String]
    }

    static func report(
        section: MetricSection,
        playbook: AssistPlaybook.File,
        rows: [MetricSection: [MetricRow]],
        summaries: [MetricSection: SectionSummary],
        stay: DashboardFilters?,
        level: AssistScopeLevel
    ) -> Report? {
        guard section == .lostRevenue else { return nil }
        guard let capacity = reducedCapacity(rows[.lostRevenue] ?? []), capacity.failing else { return nil }

        let ott = ottReading(rows: rows[.fiveStar] ?? [], level: level)
        let pphCheck = playbook.metric("pph")?.checks.first { $0.label == "PPH under 65" }
            ?? playbook.metric("five_star_ott")?.checks.first { $0.label == "PPH under 65" }
        let pph = pphCheck.flatMap {
            AssistAutoCheck.evaluate($0, rows: rows, summaries: summaries, level: level)
        }
        let ottFailing = ott?.failing == true && ott?.percent != nil
        let pphFailing = pph?.failing == true

        let why: String
        if ottFailing, pphFailing, let percent = ott?.percent, let pph {
            why = "Why: low capacity, from late orders (OTT \(one(percent))%) and slow picking (PPH \(one(pph.value)))."
        } else if ottFailing, let percent = ott?.percent {
            why = "Why: low capacity, from late orders (OTT \(one(percent))%)."
        } else if pphFailing, let pph {
            why = "Why: low capacity, from slow picking (PPH \(one(pph.value)))."
        } else if let missed = capacity.missed, missed != "—" {
            why = "Why: low capacity (\(missed) missed sales)."
        } else {
            return nil
        }

        var checks: [AssistAction] = []
        var seen: Set<String> = []
        if ottFailing, let metric = playbook.metric("five_star_ott") {
            appendFailingAutos(metric, playbookRows: rows, summaries: summaries, level: level, stay: stay, into: &checks, seen: &seen)
        }
        if pphFailing, let metric = playbook.metric("pph") {
            appendFailingAutos(metric, playbookRows: rows, summaries: summaries, level: level, stay: stay, into: &checks, seen: &seen)
        }
        var named: [String] = []
        if ottFailing { named.append("five_star_ott") }
        if pphFailing { named.append("pph") }
        return Report(why: why, checks: checks, namedIDs: named)
    }

    private struct Capacity {
        var failing: Bool
        var missed: String?
    }

    private struct OTTReading {
        var failing: Bool
        var percent: Double?
    }

    private static func reducedCapacity(_ rows: [MetricRow]) -> Capacity? {
        let scored = AssistRank.scoringRows(rows)
        let flags = HeartbeatMath.lostRevenueMetricFlags(scored, includeAll: true)
        guard let flag = flags.first(where: { $0.name == "Reduced Capacity Missed Sales" }) else { return nil }
        let failing = flag.health == .watch || flag.health == .risk
        let missed = flag.value == "—" ? nil : flag.value
        return Capacity(failing: failing, missed: missed)
    }

    private static func ottReading(rows: [MetricRow], level: AssistScopeLevel) -> OTTReading? {
        let scored = AssistRank.scoringRows(rows)
        let present = scored.filter { $0.number("ott_pct") != nil || $0.number("ott_star") != nil }
        guard !present.isEmpty else { return nil }
        let percent = HeartbeatMath.average(present.compactMap { $0.number("ott_pct") })
        if level == .store {
            let failing = present.contains { HeartbeatMath.ottStar($0) != .full }
            return OTTReading(failing: failing, percent: percent)
        }
        let flags = HeartbeatMath.fiveStarActionFlags(scored, includeAll: true)
        let health = flags.first { $0.name == "OTT" }?.health ?? .none
        let failing = health == .watch || health == .risk
        return OTTReading(failing: failing, percent: percent)
    }

    private static func one(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func appendFailingAutos(
        _ metric: AssistPlaybook.Metric,
        playbookRows rows: [MetricSection: [MetricRow]],
        summaries: [MetricSection: SectionSummary],
        level: AssistScopeLevel,
        stay: DashboardFilters?,
        into checks: inout [AssistAction],
        seen: inout Set<String>
    ) {
        for check in metric.checks where check.type == .auto {
            guard let evaluation = AssistAutoCheck.evaluate(check, rows: rows, summaries: summaries, level: level),
                  evaluation.failing else { continue }
            guard seen.insert(evaluation.sentence).inserted else { continue }
            let destination = HubDestination(rawValue: check.destination) ?? .dashboard
            let owner = level == .store ? check.owner : AssistScope.levelOwner(level)
            checks.append(AssistAction.open(
                id: "why-\(metric.metricId)-\(check.order)",
                question: evaluation.sentence,
                owner: owner,
                buttonTitle: AssistCopy.screenTitle(destination),
                filters: stay,
                destination: destination,
                detail: "",
                statusMark: evaluation.statusMark,
                statusSymbol: evaluation.statusSymbol
            ))
        }
    }
}

enum AssistRank {
    struct Input: Equatable {
        var section: MetricSection
        var health: Health
        var risk: Int
        var watch: Int
        var distance: Double
        var storeCount: Int
    }

    struct Scored: Equatable {
        var section: MetricSection
        var health: Health
        var risk: Int
        var watch: Int
        var distance: Double
        var storeCount: Int
        var score: Double
    }

    static func round4(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }

    /// Assist-only PPH ranking band. Healthy >= goal, Watch risk..<goal, At risk < risk.
    /// Other pages keep HeartbeatMath.pphGoal 80 / pphRisk 74. Change this one line to move Assist.
    static let pphRankingBand = (goal: 80.0, risk: 65.0)

    static func pphHealth(_ value: Double) -> Health {
        let band = pphRankingBand
        if value >= band.goal { return .good }
        if value >= band.risk { return .watch }
        return .risk
    }

    /// Risk and watch store counts for Assist, from the ranking band. Empty when no PPH values are in view.
    static func pphCounts(rows: [MetricRow]) -> (risk: Int, watch: Int)? {
        let values = scoringRows(rows).compactMap { HeartbeatMath.pphNumber($0) }
        guard !values.isEmpty else { return nil }
        let risk = values.filter { pphHealth($0) == .risk }.count
        let watch = values.filter { pphHealth($0) == .watch }.count
        return (risk, watch)
    }

    /// Gap/band for one store row. Nil when the row has no comparable value.
    /// Schedule under/over uses the spec ratio on the stored field. This base
    /// treats values at or under 0.05 as on goal (`varianceHealth`).
    static func offBand(section: MetricSection, row: MetricRow) -> Double? {
        let ratio: Double?
        switch section {
        case .pickPath, .pickPathPicker:
            guard let value = row.number("compliance_pct") else { return nil }
            ratio = max(0, HeartbeatMath.pickPathGoal - value) / 10
        case .missingItems, .preSubOOS:
            guard let value = row.number(MissingItemDept.totalKey) else { return nil }
            ratio = max(0, value - HeartbeatMath.missingItemsGoal) / 1.5
        case .prepNotReady:
            guard let value = row.number("pnr_rate_pct") else { return nil }
            ratio = max(0, value - HeartbeatMath.pnrGoal) / 0.6
        case .dynacap:
            if let value = row.number("dynacap_rate", "pieces_per_hour") {
                ratio = max(0, HeartbeatMath.dynacapGoal - value) / 5
            } else if HeartbeatMath.dynacapAligned(row) == false {
                ratio = 1
            } else {
                return nil
            }
        case .scheduleQuality:
            ratio = scheduleRatio(row)
        case .pph:
            guard let value = HeartbeatMath.pphNumber(row) else { return nil }
            let band = pphRankingBand
            ratio = max(0, band.goal - value) / (band.goal - band.risk)
        case .labor:
            guard let value = row.number("target_vs_actual_pct") else { return nil }
            ratio = max(0, value - 0) / HeartbeatMath.laborWatch
        case .fiveStar:
            guard let value = row.number("star_rating") else { return nil }
            ratio = max(0, 4.5 - value) / 0.5
        case .lostRevenue:
            guard let value = row.number("lost_revenue_pct") else { return nil }
            ratio = max(0, value - HeartbeatMath.lostRevenueGood) / 2
        case .sales:
            if let yoy = row.number("sales_yoy_pct") {
                ratio = max(0, 0 - yoy) / 3
            } else if let plan = row.number("sales_plan_pct") {
                ratio = max(0, HeartbeatMath.salesPlanGood - plan) / 5
            } else {
                return nil
            }
        default:
            return nil
        }
        guard let ratio, ratio.isFinite else { return nil }
        return min(3, ratio)
    }

    private static func scheduleRatio(_ row: MetricRow) -> Double? {
        var terms: [Double] = []
        if let efficiency = row.number("schedule_efficiency_pct") {
            terms.append(max(0, (HeartbeatMath.scheduleGoal - efficiency) / 5))
        }
        if let staffing = row.number("staffing_efficiency_pct") {
            terms.append(max(0, (HeartbeatMath.scheduleGoal - staffing) / 5))
        }
        if let under = row.number("under_schedule_pct", "under_scheduled") {
            terms.append(max(0, (under - 0.05) / 4.95))
        }
        if let over = row.number("over_schedule_pct", "over_scheduled") {
            terms.append(max(0, (over - 0.05) / 4.95))
        }
        guard let worst = terms.max(), worst.isFinite else { return nil }
        return worst
    }

    static func distance(section: MetricSection, rows: [MetricRow]) -> Double {
        let samples = scoringRows(rows).compactMap { row -> Double? in
            let health = section == .pph
                ? HeartbeatMath.pphNumber(row).map(pphHealth) ?? .none
                : HeartbeatMath.health(for: section, row: row)
            guard health == .risk || health == .watch else { return nil }
            return offBand(section: section, row: row)
        }
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Double(samples.count)
    }

    static func scoringRows(_ rows: [MetricRow]) -> [MetricRow] {
        rows.filter {
            let store = $0.storeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !store.isEmpty else { return false }
            if HeartbeatMath.isIgnoredStore(store) { return false }
            if $0.textPayload["lost_grain"] == "market" { return false }
            return true
        }
    }

    static func score(_ input: Input) -> Scored? {
        guard input.section != .pickerScorecard else { return nil }
        guard input.health != .none, input.storeCount > 0 else { return nil }
        guard input.risk + input.watch > 0 else { return nil }
        let severity: Int
        switch input.health {
        case .risk: severity = 3
        case .watch: severity = 2
        case .good: severity = 1
        case .none: return nil
        }
        let hit = Double(input.risk) + 0.5 * Double(input.watch)
        let raw = Double(severity) * hit * (1 + input.distance)
        guard raw.isFinite else { return nil }
        return Scored(
            section: input.section,
            health: input.health,
            risk: input.risk,
            watch: input.watch,
            distance: input.distance,
            storeCount: input.storeCount,
            score: round4(raw)
        )
    }

    static func ordered(_ items: [Scored]) -> [Scored] {
        let order = Dictionary(uniqueKeysWithValues: MetricSection.dashboardCards.enumerated().map { ($0.element, $0.offset) })
        return items.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.risk != rhs.risk { return lhs.risk > rhs.risk }
            if lhs.watch != rhs.watch { return lhs.watch > rhs.watch }
            if lhs.distance != rhs.distance { return lhs.distance > rhs.distance }
            return (order[lhs.section] ?? 99) < (order[rhs.section] ?? 99)
        }
    }

    static func rank(_ inputs: [Input]) -> [Scored] {
        ordered(inputs.compactMap(score))
    }
}

enum AssistChildGrain: Equatable {
    case region, division, district, om, store
}

enum AssistScopeLevel: Equatable {
    case company, region, division, district, om, store
}

enum AssistFilterChange: Equatable {
    case none
    case clear
    case region(String)
    case division(String)
    case district(String)
    case om(String)
    case store(String)
    case commit(DashboardFilters)
}

enum AssistScope {
    static func level(_ filters: DashboardFilters) -> AssistScopeLevel {
        if !filters.store.isEmpty { return .store }
        if !filters.om.isEmpty { return .om }
        if !filters.district.isEmpty { return .district }
        if !filters.division.isEmpty { return .division }
        if !filters.region.isEmpty { return .region }
        return .company
    }

    static func label(_ filters: DashboardFilters, roster: [(number: String, name: String?)]) -> String {
        switch level(filters) {
        case .company:
            return "Total company"
        case .region:
            return DashboardFilters.display(filters.region, empty: "Total company")
        case .division:
            let shown = DashboardFilters.display(filters.division, empty: "")
            if DashboardFilters.parts(filters.division).count == 1 {
                return "\(shown) market"
            }
            return shown
        case .district:
            return DashboardFilters.display(filters.district, empty: "District", prefix: "District ")
        case .om:
            let shown = DashboardFilters.display(filters.om, empty: "")
            return shown.hasPrefix("OM ") ? shown : "OM \(shown)"
        case .store:
            let numbers = DashboardFilters.parts(filters.store).map { HeartbeatMath.canonicalStore($0) }
            if numbers.count == 1, let number = numbers.first {
                if let name = rosterName(number, roster: roster) {
                    return "Store \(number), \(name)"
                }
                return "Store \(number)"
            }
            return "Store \(DashboardFilters.display(filters.store, empty: ""))"
        }
    }

    static func scopeLine(_ filters: DashboardFilters, roster: [(number: String, name: String?)]) -> String {
        let text = label(filters, roster: roster)
        if level(filters) == .company {
            return "\(text) (all regions, divisions, districts, OMs, stores)"
        }
        return text
    }

    static func levelOwner(_ level: AssistScopeLevel) -> String {
        switch level {
        case .company: return "Region EVPs"
        case .region: return "Market directors"
        case .division: return "District managers"
        case .district: return "Operations managers"
        case .om, .store: return "Store leaders"
        }
    }

    static func childOwner(_ grain: AssistChildGrain) -> String {
        switch grain {
        case .region: return "Region EVPs"
        case .division: return "Market directors"
        case .district: return "District managers"
        case .om: return "Operations managers"
        case .store: return "Store leaders"
        }
    }

    static func naturalChild(_ level: AssistScopeLevel) -> AssistChildGrain? {
        switch level {
        case .company: return .region
        case .region: return .division
        case .division: return .district
        case .district: return .om
        case .om: return .store
        case .store: return nil
        }
    }

    static func childUnitWord(_ level: AssistScopeLevel) -> String? {
        switch naturalChild(level) {
        case .region: return "region"
        case .division: return "market"
        case .district: return "district"
        case .om: return "OM"
        case .store: return "store"
        case nil: return nil
        }
    }

    static func grainKey(_ row: MetricRow, grain: AssistChildGrain) -> String? {
        switch grain {
        case .region:
            return MarketRegion.containing(row.division)?.rawValue
        case .division:
            let name = row.division.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        case .district:
            let name = row.district.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        case .om:
            let name = row.operationsOM.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        case .store:
            let name = HeartbeatMath.canonicalStore(row.storeNumber)
            return name.isEmpty ? nil : name
        }
    }

    static func childLabel(grain: AssistChildGrain, key: String, storeName: String?) -> String {
        switch grain {
        case .region:
            return key
        case .division:
            return "\(key) market"
        case .district:
            return "District \(HeartbeatMath.displayGrainLabel(key))"
        case .om:
            return "OM \(key)"
        case .store:
            if let storeName, !storeName.isEmpty {
                return "Store \(key), \(storeName)"
            }
            return "Store \(key)"
        }
    }

    static func rosterName(_ number: String, roster: [(number: String, name: String?)]) -> String? {
        let want = HeartbeatMath.canonicalStore(number)
        guard let name = roster.first(where: { HeartbeatMath.canonicalStore($0.number) == want })?.name else {
            return nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func slice(_ rows: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        rows.filter { row in
            if !filters.includesDivision(row.division) { return false }
            if !filters.includesDistrict(row.district) { return false }
            if !filters.includesOM(row.operationsOM) { return false }
            if !filters.includesStore(row.storeNumber) { return false }
            return true
        }
    }
}

enum AssistIntent: Equatable {
    case fix
    case children(AssistChildGrain?)
    case metric(MetricSection)
    case shoppers
    case watch
    case healthy
    case store(String)
    case district(String)
    case division(String)
    case region(String)
    case om(String)
    case shopper(String)
    case unknown
}

struct AssistFact: Equatable, Identifiable {
    var label: String
    var value: String
    var id: String { label }
}

struct AssistAction: Equatable, Identifiable {
    var id: String
    var question: String
    var owner: String
    var buttonTitle: String
    var filters: DashboardFilters?
    var clearsFilters: Bool
    var destination: HubDestination
    var detail: String
    var statusMark: String
    var statusSymbol: String
    var accessibilityLabel: String

    static func open(
        id: String,
        question: String,
        owner: String,
        buttonTitle: String,
        filters: DashboardFilters?,
        destination: HubDestination,
        detail: String = "",
        statusMark: String = "",
        statusSymbol: String = ""
    ) -> AssistAction {
        let ownerBit = owner.isEmpty ? "" : " Owner \(owner)."
        let mark = statusMark.isEmpty ? "" : "\(statusMark). "
        return AssistAction(
            id: id,
            question: question,
            owner: owner,
            buttonTitle: buttonTitle,
            filters: filters,
            clearsFilters: false,
            destination: destination,
            detail: detail,
            statusMark: statusMark,
            statusSymbol: statusSymbol,
            accessibilityLabel: "\(mark)\(question).\(ownerBit) Opens \(destination.title)."
        )
    }
}

struct AssistHeaderLine: Equatable, Identifiable {
    var text: String
    var issueID: String
    var id: String { issueID }
}

struct AssistIssue: Equatable, Identifiable {
    var id: String
    var rank: Int
    var title: String
    var statusText: String
    var statusSymbol: String
    var statusHealth: Health
    var headline: String
    var numberLabel: String
    var numberValue: String
    var facts: [AssistFact]
    var scope: String
    var footer: String
    var footerAction: AssistAction
    var checks: [AssistAction]
    var moreChecks: [AssistAction]
    var why: String?
    var causeChecks: [AssistAction]
    var failingCauseIDs: [String]
    var drivenBy: [AssistHeaderLine]
    var rankedLine: String
    var accessibilityLabel: String
}

struct AssistAnswer: Equatable {
    var scopeLabel: String
    var dataWindow: String?
    var staleBanner: String?
    var headerTitle: String?
    var headerLines: [AssistHeaderLine]
    var issues: [AssistIssue]
    var rankedLines: [String]
    var emptyNote: String?
    var noticeTitle: String?
    var noticeBody: String?
    var noticeAction: AssistAction?
    var healthyFacts: [AssistFact]
    var chips: [String]

    static let empty = AssistAnswer(
        scopeLabel: "Total company",
        dataWindow: nil,
        staleBanner: nil,
        headerTitle: nil,
        headerLines: [],
        issues: [],
        rankedLines: [],
        emptyNote: nil,
        noticeTitle: nil,
        noticeBody: nil,
        noticeAction: nil,
        healthyFacts: [],
        chips: []
    )
}

struct AssistSnapshot {
    var seeded: Bool
    var filters: DashboardFilters
    var summaries: [MetricSection: SectionSummary]
    var rows: [MetricSection: [MetricRow]]
    var history: [MetricSection: [HistoryPoint]]
    var dataWindow: String?
    var rosterStores: [(number: String, name: String?)]
    var districts: [String]
    var divisions: [String]
    var operationsOMs: [String]
    var now: Date
    var warehouse: [MetricSection: [MetricRow]]
    var packUploads: [Date]

    static let needed: [MetricSection] = MetricSection.dashboardCards + [
        .pickPathPicker, .aisleMapper, .preSubOOSItem, .storeRoster,
    ]
}

extension AssistSnapshot {
    @MainActor
    static func live(_ store: HeartbeatStore, section: MetricSection?) -> AssistSnapshot {
        var summaries: [MetricSection: SectionSummary] = [:]
        var rows: [MetricSection: [MetricRow]] = [:]
        var warehouse: [MetricSection: [MetricRow]] = [:]
        var history: [MetricSection: [HistoryPoint]] = [:]
        var uploads: [Date] = []
        for item in store.summaries {
            summaries[item.section] = item
            if let uploaded = item.lastUploadedAt {
                uploads.append(uploaded)
            }
        }
        for section in AssistSnapshot.needed {
            if summaries[section] == nil {
                summaries[section] = store.summary(for: section)
            }
            rows[section] = store.displayRows(for: section)
            warehouse[section] = store.rows(for: section)
            history[section] = store.history(for: section)
            if let uploaded = store.upload(for: section)?.uploadedAt {
                uploads.append(uploaded)
            }
        }
        let window = section.flatMap { store.dataWindow(for: $0) } ?? store.sharedDataWindow()
        return AssistSnapshot(
            seeded: store.seeded,
            filters: store.filters,
            summaries: summaries,
            rows: rows,
            history: history,
            dataWindow: window,
            rosterStores: store.stores,
            districts: store.districts,
            divisions: store.divisions,
            operationsOMs: store.operationsOMs,
            now: Date(),
            warehouse: warehouse,
            packUploads: uploads
        )
    }
}

enum AssistCopy {
    static let headlineLimit = 90
    static let actionLimit = 110
    static let headerLimit = 48
    static let chipLimit = 40
    static let staleInterval: TimeInterval = 36 * 60 * 60

    static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func stores(_ count: Int) -> String {
        count == 1 ? "1 store" : "\(grouped(count)) stores"
    }

    static func fill(_ template: String, _ values: [String: String], limit: Int) -> String? {
        guard let expression = try? NSRegularExpression(pattern: "\\{([A-Za-z0-9]+)\\}") else { return nil }
        let ns = template as NSString
        let matches = expression.matches(in: template, range: NSRange(location: 0, length: ns.length))
        var result = template
        for match in matches.reversed() {
            let key = ns.substring(with: match.range(at: 1))
            guard let value = values[key], !value.isEmpty else { return nil }
            guard let range = Range(match.range, in: result) else { return nil }
            result.replaceSubrange(range, with: value)
        }
        guard result.count <= limit else { return nil }
        return result
    }

    static func headerTitle(issueCount: Int) -> String? {
        switch issueCount {
        case 0: return nil
        case 1: return "Fix this first"
        case 2: return "Fix these 2 first"
        default: return "Fix these 3 first"
        }
    }

    static func headerLine(rank: Int, shortName: String, risk: Int, total: Int) -> String {
        let line = "\(rank). \(shortName): \(grouped(risk)) of \(grouped(total)) \(total == 1 ? "store" : "stores")"
        if line.count <= headerLimit { return line }
        return "\(rank). \(shortName): \(grouped(risk)) of \(grouped(total))"
    }

    static func storeHeaderLine(rank: Int, shortName: String, value: String, goal: String) -> String {
        let line = "\(rank). \(shortName): \(value) (goal \(goal))"
        if line.count <= headerLimit { return line }
        let shorter = "\(rank). \(shortName): \(value)"
        return shorter.count <= headerLimit ? shorter : "\(rank). \(shortName)"
    }

    static func goalShort(_ section: MetricSection) -> String {
        switch section {
        case .scheduleQuality: return "90%"
        case .missingItems, .preSubOOS: return "5%"
        case .pickPath: return "90%"
        case .fiveStar: return "4.50"
        case .prepNotReady: return "1.9%"
        case .dynacap: return "65"
        case .pph: return String(Int(AssistRank.pphRankingBand.goal))
        case .labor: return "0%"
        case .lostRevenue: return "3%"
        case .sales: return "100%"
        default: return ""
        }
    }

    static func goalFact(_ section: MetricSection) -> String {
        switch section {
        case .scheduleQuality, .pickPath: return "90%"
        case .missingItems, .preSubOOS: return "5% or less"
        case .fiveStar: return "4.50+"
        case .prepNotReady: return "1.9% or less"
        case .dynacap: return "65"
        case .pph: return String(Int(AssistRank.pphRankingBand.goal))
        case .labor: return "0% or less"
        case .lostRevenue: return "3% or less"
        case .sales: return "Up vs last year"
        default: return ""
        }
    }

    static func one(_ value: Double) -> String { String(format: "%.1f", value) }
    static func onePct(_ value: Double) -> String { String(format: "%.1f%%", value) }

    static func status(_ health: Health) -> (text: String, symbol: String, ink: Health) {
        switch health {
        case .risk: return ("At risk", "exclamationmark.triangle.fill", .risk)
        case .watch: return ("Watch", "eye.fill", .watch)
        case .good: return ("Stores failing", "exclamationmark.circle.fill", .watch)
        case .none: return ("No data", "questionmark.circle", .none)
        }
    }

    static func rankedLine(_ scored: AssistRank.Scored) -> String {
        let statusWord: String
        switch scored.health {
        case .risk: statusWord = "at risk"
        case .watch: statusWord = "watch"
        case .good: statusWord = "stores failing"
        case .none: statusWord = "no data"
        }
        let distance = one(scored.distance)
        return "\(scored.section.title): \(statusWord), \(grouped(scored.risk)) at-risk and \(grouped(scored.watch)) watch stores, on average \(distance) of a band past goal."
    }

    static func screenTitle(_ destination: HubDestination) -> String {
        "Open \(destination.title) ›"
    }

    static func chip(_ text: String) -> String? {
        guard !text.isEmpty, text.count <= chipLimit else { return nil }
        return text
    }
}

struct AssistChild: Equatable {
    var key: String
    var label: String
    var score: Double
    var storesAtRisk: Int
    var storeCount: Int
    var worstMetric: MetricSection?
    var worstRisk: Int
    var worstStores: Int
    var grain: AssistChildGrain
}

enum AssistComposer {
    static func chips(for snapshot: AssistSnapshot, book: AssistPlaybook.File? = nil) -> [String] {
        answer(question: "What should we fix first?", snapshot: snapshot, book: book).chips
    }

    static func answer(
        question: String,
        snapshot: AssistSnapshot,
        book: AssistPlaybook.File? = nil
    ) -> AssistAnswer {
        let playbook = book ?? AssistPlaybook.bundled()
        if !snapshot.seeded || snapshot.summaries.isEmpty {
            return noPack(snapshot)
        }
        let base = snapshot.filters
        let intent = resolve(question, snapshot: snapshot)
        let lens = narrowed(snapshot, intent: intent)
        if lens.filters.isActive && MetricSection.dashboardCards.allSatisfy({ (lens.summaries[$0]?.storeCount ?? 0) == 0 }) {
            return noScope(lens)
        }
        if lens.summaries.values.allSatisfy({ $0.health == .none }) {
            return noPack(lens)
        }
        switch intent {
        case .unknown:
            return unknown(lens, playbook: playbook, base: base)
        case .healthy:
            return healthy(lens, playbook: playbook, base: base)
        case .shoppers, .shopper:
            return shoppers(lens, intent: intent, playbook: playbook, base: base)
        case .children(let grain):
            return children(lens, grain: grain, playbook: playbook, base: base)
        case .metric(let section):
            return metrics(lens, sections: [section], watchOnly: false, showHeader: false, playbook: playbook, base: base, single: true)
        case .watch:
            return metrics(lens, sections: nil, watchOnly: true, showHeader: false, playbook: playbook, base: base, single: false)
        case .fix, .store, .district, .division, .region, .om:
            return metrics(lens, sections: nil, watchOnly: false, showHeader: true, playbook: playbook, base: base, single: false)
        }
    }

    static func resolve(_ question: String, snapshot: AssistSnapshot) -> AssistIntent {
        let normalized = normalize(question)
        guard !normalized.isEmpty else { return .unknown }
        if let store = namedStore(in: normalized, roster: snapshot.rosterStores) {
            return .store(store)
        }
        if let unit = namedUnit(in: normalized, snapshot: snapshot) {
            return unit
        }
        if let shopper = namedShopper(in: normalized, snapshot: snapshot) {
            return .shopper(shopper)
        }
        switch worstAsk(in: normalized) {
        case .unspecified:
            return .children(nil)
        case .grain(let grain):
            return .children(grain)
        case nil:
            break
        }
        if contains(normalized, ["fix", "first", "wrong", "priority", "do today", "start"]) {
            return .fix
        }
        if let section = metric(in: normalized) {
            return .metric(section)
        }
        if contains(normalized, ["shopper", "picker", "ldap", "coach"]) {
            return .shoppers
        }
        if normalized.contains("watch") {
            return .watch
        }
        if contains(normalized, ["healthy", "green", "holding", "good"]) {
            return .healthy
        }
        return .unknown
    }

    static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func contains(_ haystack: String, _ keys: [String]) -> Bool {
        keys.contains { haystack.contains($0) }
    }

    private static func namedStore(in question: String, roster: [(number: String, name: String?)]) -> String? {
        let known = Set(roster.map { HeartbeatMath.canonicalStore($0.number) })
        let tokens = question.split(whereSeparator: { !$0.isNumber }).map(String.init)
        for token in tokens where token.count >= 3 && token.count <= 5 {
            let canonical = HeartbeatMath.canonicalStore(token)
            if known.contains(canonical) { return canonical }
        }
        return nil
    }

    private static func namedUnit(in question: String, snapshot: AssistSnapshot) -> AssistIntent? {
        let padded = " \(question.replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)) "
        func hit(_ name: String) -> Bool {
            let phrase = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard phrase.count >= 2 else { return false }
            return padded.contains(" \(phrase) ")
        }
        for name in MarketRegion.allCases.map(\.rawValue) where hit(name) {
            return .region(name)
        }
        for name in MarketRegion.allCases.map(\.rawValue) {
            let short = name.replacingOccurrences(of: " Region", with: "")
            if short.count >= 4 && hit(short) { return .region(name) }
        }
        for name in snapshot.divisions where hit(name) { return .division(name) }
        for name in snapshot.districts where hit(name) { return .district(name) }
        for name in snapshot.operationsOMs where hit(name) { return .om(name) }
        return nil
    }

    private static func namedShopper(in question: String, snapshot: AssistSnapshot) -> String? {
        let stops: Set<String> = [
            "what", "whats", "what's", "should", "which", "first", "worst", "store", "stores",
            "district", "fix", "watch", "coach", "shopper", "shoppers", "picker", "pickers",
            "about", "more", "tell", "need", "needs", "coaching", "here", "this", "today",
            "labor", "sales", "schedule", "missing", "items", "path", "prep", "ready",
        ]
        let tokens = question.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let rows = (snapshot.rows[.pickerScorecard] ?? []) + (snapshot.rows[.pickPathPicker] ?? [])
        for token in tokens where token.count >= 4 && !stops.contains(token) {
            for row in rows {
                let name = cleanName(row)
                let id = row.shopperId?.lowercased()
                if id == token { return name ?? token }
                if let name {
                    let words = name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
                    if words.contains(token) || name.lowercased() == token { return name }
                }
            }
        }
        return nil
    }

    private enum WorstAsk {
        case unspecified
        case grain(AssistChildGrain)
    }

    /// Nil when the question is not a worst-child ask. `.unspecified` when it is, but names no grain.
    private static func worstAsk(in question: String) -> WorstAsk? {
        let asks = contains(question, ["worst", "bottom", "lowest", "who is"])
        guard asks else { return nil }
        let padded = " \(question) "
        if padded.contains(" district") { return .grain(.district) }
        if padded.contains(" market") { return .grain(.division) }
        if padded.contains(" region") { return .grain(.region) }
        if padded.contains(" store") { return .grain(.store) }
        if padded.contains(" om") || padded.contains(" oms") { return .grain(.om) }
        return .unspecified
    }

    private static func metric(in question: String) -> MetricSection? {
        let pairs: [(MetricSection, [String])] = [
            (.prepNotReady, ["prep not ready", "pnr", "prep"]),
            (.preSubOOS, ["pre-sub", "pre sub", "oos"]),
            (.missingItems, ["missing items", "missing", "aisle tag"]),
            (.pickPath, ["pick path", "aisle map", "path"]),
            (.fiveStar, ["5 star", "five star", "flash", "presub", "ott", "oth", "coe"]),
            (.dynacap, ["dynacap", "capacity"]),
            (.scheduleQuality, ["schedule"]),
            (.pph, ["picks per hour", "pph"]),
            (.labor, ["labor", "tva"]),
            (.lostRevenue, ["lost revenue", "lost", "loss", "refund", "cancel", "kill switch"]),
            (.sales, ["sales", "yoy"]),
        ]
        for (section, keys) in pairs {
            for key in keys where containsToken(question, key) {
                return section
            }
        }
        return nil
    }

    private static func containsToken(_ question: String, _ key: String) -> Bool {
        if key.contains(" ") || key.contains("-") { return question.contains(key) }
        if key.count >= 5 { return question.contains(key) }
        let padded = " \(question.replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)) "
        return padded.contains(" \(key) ")
    }

    private static func narrowed(_ snapshot: AssistSnapshot, intent: AssistIntent) -> AssistSnapshot {
        var filters = snapshot.filters
        switch intent {
        case .store(let number):
            filters = DashboardFilters()
            filters.store = number
        case .district(let name):
            filters.district = name
            filters.om = ""
            filters.store = ""
        case .division(let name):
            filters.region = MarketRegion.containing(name)?.rawValue ?? filters.region
            filters.division = name
            filters.district = ""
            filters.om = ""
            filters.store = ""
        case .region(let name):
            filters = DashboardFilters()
            filters.region = name
        case .om(let name):
            filters.om = name
            filters.store = ""
        default:
            return snapshot
        }
        guard filters != snapshot.filters else { return snapshot }
        var next = snapshot
        next.filters = filters
        let source = snapshot.warehouse.isEmpty ? snapshot.rows : snapshot.warehouse
        var rows: [MetricSection: [MetricRow]] = [:]
        var summaries: [MetricSection: SectionSummary] = [:]
        var history: [MetricSection: [HistoryPoint]] = [:]
        for section in AssistSnapshot.needed {
            let sliced = AssistScope.slice(source[section] ?? [], filters: filters)
            rows[section] = sliced
            summaries[section] = HeartbeatMath.summarize(section, rows: sliced, upload: nil)
            history[section] = HeartbeatMath.history(section, rows: sliced)
        }
        for (section, summary) in snapshot.summaries where next.summaries[section] == nil {
            summaries[section] = summary
        }
        next.rows = rows
        next.summaries = summaries
        next.history = history
        next.warehouse = source
        return next
    }

    private static func noPack(_ snapshot: AssistSnapshot) -> AssistAnswer {
        var answer = AssistAnswer.empty
        answer.scopeLabel = AssistScope.label(snapshot.filters, roster: snapshot.rosterStores)
        answer.noticeTitle = "No Heartbeat data on this device yet."
        answer.noticeBody = "Assist answers only from the Heartbeat pack on this device. Wait for today's pack to download."
        return answer
    }

    private static func noScope(_ snapshot: AssistSnapshot) -> AssistAnswer {
        var answer = AssistAnswer.empty
        let scope = AssistScope.label(snapshot.filters, roster: snapshot.rosterStores)
        answer.scopeLabel = scope
        answer.dataWindow = snapshot.dataWindow
        answer.noticeTitle = "No Heartbeat numbers for \(scope)."
        answer.noticeBody = "The pack has no rows for this filter. Clear it or pick another area."
        answer.noticeAction = AssistAction(
            id: "clear-filters",
            question: "Clear filters",
            owner: "",
            buttonTitle: "Clear filters",
            filters: nil,
            clearsFilters: true,
            destination: .dashboard,
            accessibilityLabel: "Clear filters. Opens Dashboard."
        )
        return answer
    }

    private static func unknown(_ snapshot: AssistSnapshot, playbook: AssistPlaybook.File?, base: DashboardFilters) -> AssistAnswer {
        var answer = shell(snapshot, playbook: playbook, base: base, showHeader: false)
        answer.issues = []
        answer.headerTitle = nil
        answer.headerLines = []
        answer.rankedLines = []
        answer.noticeTitle = "I can answer from the numbers on this device. Try one of these:"
        answer.noticeBody = nil
        return answer
    }

    private static func healthy(_ snapshot: AssistSnapshot, playbook: AssistPlaybook.File?, base: DashboardFilters) -> AssistAnswer {
        let ranked = rank(snapshot)
        let withData = MetricSection.dashboardCards.filter { section in
            guard section != .pickerScorecard else { return false }
            let summary = snapshot.summaries[section]
            return (summary?.storeCount ?? 0) > 0 && summary?.health != .none
        }
        let healthyOnes = withData.filter { section in
            !ranked.contains { $0.section == section }
        }
        var answer = AssistAnswer.empty
        answer.scopeLabel = AssistScope.label(snapshot.filters, roster: snapshot.rosterStores)
        answer.dataWindow = snapshot.dataWindow
        answer.staleBanner = staleBanner(snapshot)
        answer.chips = chipList(snapshot, ranked: ranked, level: AssistScope.level(snapshot.filters))
        if ranked.isEmpty && !withData.isEmpty {
            let scope = answer.scopeLabel
            answer.noticeTitle = "Nothing needs fixing in \(scope)."
            answer.noticeBody = "All \(withData.count) scorecards with data are at goal."
            if let closest = closestToGoal(snapshot, sections: healthyOnes) {
                answer.noticeBody = (answer.noticeBody ?? "") + " Closest to its goal: \(closest)."
            }
            answer.healthyFacts = healthyOnes.compactMap { section in
                guard let summary = snapshot.summaries[section], summary.headline != nil else { return nil }
                return AssistFact(label: section.overviewLead, value: "\(summary.headlineText) (goal \(AssistCopy.goalFact(section)))")
            }
        } else {
            answer.noticeTitle = "Scorecards at goal"
            answer.noticeBody = "These scorecards are at goal in \(answer.scopeLabel)."
            answer.healthyFacts = healthyOnes.compactMap { section in
                guard let summary = snapshot.summaries[section], summary.headline != nil else { return nil }
                return AssistFact(label: section.overviewLead, value: "\(summary.headlineText) (goal \(AssistCopy.goalFact(section)))")
            }
        }
        answer.emptyNote = emptyNote(snapshot)
        return answer
    }

    private static func shoppers(
        _ snapshot: AssistSnapshot,
        intent: AssistIntent,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters
    ) -> AssistAnswer {
        var answer = shell(snapshot, playbook: playbook, base: base, showHeader: false)
        let people = shopperRows(snapshot)
        let wanted: String?
        if case .shopper(let name) = intent { wanted = name } else { wanted = nil }
        let chosen = people.filter { row in
            guard let wanted else { return true }
            let name = cleanName(row)?.lowercased() ?? ""
            return name == wanted.lowercased() || (row.shopperId?.lowercased() == wanted.lowercased())
        }.prefix(5)
        if chosen.isEmpty {
            answer.noticeTitle = "No shopper in \(answer.scopeLabel) needs coaching."
            answer.noticeBody = "Picker rows in this scope are at goal, or the pack has no shopper name."
            return answer
        }
        let level = AssistScope.level(snapshot.filters)
        answer.issues = chosen.enumerated().compactMap { index, row in
            shopperIssue(row, rank: index + 1, snapshot: snapshot, playbook: playbook, base: base, level: level)
        }
        return answer
    }

    private static func children(
        _ snapshot: AssistSnapshot,
        grain: AssistChildGrain?,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters
    ) -> AssistAnswer {
        var answer = shell(snapshot, playbook: playbook, base: base, showHeader: false)
        let level = AssistScope.level(snapshot.filters)
        let resolved = grain ?? AssistScope.naturalChild(level)
        guard let resolved else {
            answer.noticeTitle = "This store is the floor."
            answer.noticeBody = "Ask which shoppers need coaching, or which scorecard to fix first."
            return answer
        }
        let ranked = rankChildren(snapshot, grain: resolved).filter { $0.score > 0 || $0.storesAtRisk > 0 }
        let top = Array(ranked.prefix(3))
        guard !top.isEmpty, let playbook else {
            answer.noticeTitle = "No \(resolvedWord(resolved)) breakdown for \(answer.scopeLabel)."
            answer.noticeBody = "The pack has no \(resolvedWord(resolved)) names with stores off goal in this filter."
            return answer
        }
        let scope = AssistScope.scopeLine(snapshot.filters, roster: snapshot.rosterStores)
        answer.issues = top.enumerated().map { index, child in
            childIssue(child, rank: index + 1, snapshot: snapshot, playbook: playbook, base: base, scope: scope, first: index == 0)
        }
        answer.rankedLines = top.map { child in
            "\(child.label): score \(AssistCopy.one(child.score)), \(AssistCopy.grouped(child.storesAtRisk)) stores with an at-risk scorecard."
        }
        return answer
    }

    private static func metrics(
        _ snapshot: AssistSnapshot,
        sections: [MetricSection]?,
        watchOnly: Bool,
        showHeader: Bool,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters,
        single: Bool,
        forceInclude: Bool = false
    ) -> AssistAnswer {
        var answer = shell(snapshot, playbook: playbook, base: base, showHeader: false)
        var ranked = rank(snapshot)
        if let sections {
            ranked = ranked.filter { sections.contains($0.section) }
            if single {
                for section in sections where !ranked.contains(where: { $0.section == section }) {
                    if let summary = snapshot.summaries[section], summary.storeCount > 0, summary.health != .none {
                        let distance = AssistRank.distance(section: section, rows: snapshot.rows[section] ?? [])
                        if let scored = AssistRank.score(AssistRank.Input(
                            section: section,
                            health: summary.health == .good ? .good : summary.health,
                            risk: max(summary.riskCount, summary.health == .good ? 0 : summary.riskCount),
                            watch: summary.watchCount,
                            distance: distance,
                            storeCount: summary.storeCount
                        )) {
                            ranked.append(scored)
                        } else if forceInclude || single {
                            ranked.append(AssistRank.Scored(
                                section: section,
                                health: summary.health,
                                risk: summary.riskCount,
                                watch: summary.watchCount,
                                distance: distance,
                                storeCount: summary.storeCount,
                                score: 0
                            ))
                        }
                    }
                }
            }
        }
        if watchOnly {
            ranked = ranked.filter { $0.watch > 0 }
        }
        if ranked.isEmpty && !watchOnly && !single {
            let healthyAnswer = healthy(snapshot, playbook: playbook, base: base)
            return healthyAnswer
        }
        let level = AssistScope.level(snapshot.filters)
        let children = level == .store ? [] : rankChildren(snapshot, grain: AssistScope.naturalChild(level) ?? .region)
        let worst = children.first { $0.score > 0 || $0.storesAtRisk > 0 }
        let scope = AssistScope.scopeLine(snapshot.filters, roster: snapshot.rosterStores)
        answer.issues = ranked.enumerated().map { index, scored in
            issue(
                scored,
                rank: index + 1,
                snapshot: snapshot,
                playbook: playbook,
                base: base,
                level: level,
                scope: scope,
                worst: worst,
                watchOnly: watchOnly,
                singleHealthy: single && scored.risk + scored.watch == 0
            )
        }
        if showHeader && !answer.issues.isEmpty {
            answer.headerTitle = AssistCopy.headerTitle(issueCount: answer.issues.count)
            answer.headerLines = answer.issues.prefix(3).map { item in
                AssistHeaderLine(text: headerText(for: item, snapshot: snapshot, level: level), issueID: item.id)
            }
        }
        answer.rankedLines = ranked.map(AssistCopy.rankedLine)
        answer.emptyNote = emptyNote(snapshot)
        if answer.issues.isEmpty && watchOnly {
            answer.noticeTitle = "Nothing is on watch in \(answer.scopeLabel)."
            answer.noticeBody = "No scorecard has stores close to missing the goal."
        }
        return answer
    }

    private static func shell(
        _ snapshot: AssistSnapshot,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters,
        showHeader: Bool
    ) -> AssistAnswer {
        let ranked = rank(snapshot)
        var answer = AssistAnswer.empty
        answer.scopeLabel = AssistScope.label(snapshot.filters, roster: snapshot.rosterStores)
        answer.dataWindow = blank(snapshot.dataWindow)
        answer.staleBanner = staleBanner(snapshot)
        answer.chips = chipList(snapshot, ranked: ranked, level: AssistScope.level(snapshot.filters))
        _ = playbook
        _ = base
        _ = showHeader
        return answer
    }

    private static func rank(_ snapshot: AssistSnapshot) -> [AssistRank.Scored] {
        let inputs: [AssistRank.Input] = MetricSection.dashboardCards.compactMap { section in
            guard section != .pickerScorecard else { return nil }
            guard let summary = snapshot.summaries[section] else { return nil }
            let rows = snapshot.rows[section] ?? []
            let distance = AssistRank.distance(section: section, rows: rows)
            var health = summary.health
            var risk = summary.riskCount
            var watch = summary.watchCount
            if section == .pph {
                if let headline = summary.headline {
                    health = AssistRank.pphHealth(headline)
                }
                if let counts = AssistRank.pphCounts(rows: rows) {
                    risk = counts.risk
                    watch = counts.watch
                }
            }
            return AssistRank.Input(
                section: section,
                health: health,
                risk: risk,
                watch: watch,
                distance: distance,
                storeCount: summary.storeCount
            )
        }
        return AssistRank.rank(inputs)
    }

    private static func headerText(for issue: AssistIssue, snapshot: AssistSnapshot, level: AssistScopeLevel) -> String {
        guard let section = MetricSection(rawValue: issue.id), let summary = snapshot.summaries[section] else {
            return issue.rank <= 3 ? "\(issue.rank). \(issue.title)" : issue.title
        }
        if level == .store {
            let value = summary.headline == nil ? issue.numberValue : summary.headlineText
            return AssistCopy.storeHeaderLine(
                rank: issue.rank,
                shortName: section.overviewLead,
                value: value,
                goal: AssistCopy.goalShort(section)
            )
        }
        let risk = section == .pph
            ? (AssistRank.pphCounts(rows: snapshot.rows[section] ?? [])?.risk ?? summary.riskCount)
            : summary.riskCount
        return AssistCopy.headerLine(
            rank: issue.rank,
            shortName: section.overviewLead,
            risk: risk,
            total: summary.storeCount
        )
    }

    private static func issue(
        _ scored: AssistRank.Scored,
        rank: Int,
        snapshot: AssistSnapshot,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters,
        level: AssistScopeLevel,
        scope: String,
        worst: AssistChild?,
        watchOnly: Bool,
        singleHealthy: Bool
    ) -> AssistIssue {
        let section = scored.section
        let summary = snapshot.summaries[section]
        let rows = snapshot.rows[section] ?? []
        let status = AssistCopy.status(scored.health)
        let headline = headlineText(
            section: section,
            summary: summary,
            scored: scored,
            rows: rows,
            level: level,
            watchOnly: watchOnly,
            singleHealthy: singleHealthy
        )
        let number = numberPair(section: section, summary: summary, scored: scored, level: level)
        let facts = factRow(section: section, summary: summary, rows: rows, snapshot: snapshot, scored: scored)
        let stay = snapshot.filters == base ? nil : snapshot.filters
        let destination = HubDestination.from(section: section)
        let footer = footerTitle(section: section, scored: scored, level: level)
        let footerAction = AssistAction.open(
            id: "\(section.rawValue)-footer",
            question: footer,
            owner: "",
            buttonTitle: footer,
            filters: stay,
            destination: destination
        )
        let deck = resolutionChecks(
            section: section,
            snapshot: snapshot,
            playbook: playbook,
            level: level,
            worst: worst,
            stay: stay
        )
        let causes = playbook.flatMap {
            AssistCauses.report(
                section: section,
                playbook: $0,
                rows: snapshot.rows,
                summaries: snapshot.summaries,
                stay: stay,
                level: level
            )
        }
        let storesAtRisk = level == .store ? (summary?.headlineText ?? "") : "\(AssistCopy.grouped(scored.risk)) of \(AssistCopy.grouped(scored.storeCount)) stores at risk"
        let whySentence = causes?.why
        return AssistIssue(
            id: section.rawValue,
            rank: rank,
            title: section.title,
            statusText: status.text,
            statusSymbol: status.symbol,
            statusHealth: status.ink,
            headline: headline,
            numberLabel: number.label,
            numberValue: number.value,
            facts: facts,
            scope: "Scope: \(scope)",
            footer: footer,
            footerAction: footerAction,
            checks: deck.actions,
            moreChecks: deck.more,
            why: whySentence,
            causeChecks: causes?.checks ?? [],
            failingCauseIDs: causes?.namedIDs ?? [],
            drivenBy: [],
            rankedLine: AssistCopy.rankedLine(scored),
            accessibilityLabel: "Rank \(rank), \(section.title), \(status.text). \(headline). \(storesAtRisk).\(whySentence.map { " Why \($0)." } ?? "") Scope \(scope)."
        )
    }

    private static func headlineText(
        section: MetricSection,
        summary: SectionSummary?,
        scored: AssistRank.Scored,
        rows: [MetricRow],
        level: AssistScopeLevel,
        watchOnly: Bool,
        singleHealthy: Bool
    ) -> String {
        if singleHealthy, let summary, summary.headline != nil {
            let line = "\(section.overviewLead) is at goal: \(summary.headlineText) (goal \(AssistCopy.goalFact(section)))"
            return clip(line, AssistCopy.headlineLimit)
        }
        if watchOnly || (scored.health == .watch && scored.risk == 0) {
            let line = "\(AssistCopy.stores(scored.watch)) are close to missing \(section.overviewLead)"
            return clip(line.replacingOccurrences(of: "1 store are", with: "1 store is"), AssistCopy.headlineLimit)
        }
        let risk = AssistCopy.grouped(scored.risk)
        let total = AssistCopy.grouped(scored.storeCount)
        let value = summary?.headlineText ?? ""
        let above = scored.risk == 1 ? "1 of \(total) stores" : "\(risk) of \(total) stores"
        let text: String
        if level == .store {
            text = storeHeadline(section, value: value, rows: rows, summary: summary)
        } else {
            text = aboveHeadline(section, above: above, rows: rows, summary: summary)
        }
        return clip(text, AssistCopy.headlineLimit)
    }

    private static func aboveHeadline(_ section: MetricSection, above: String, rows: [MetricRow], summary: SectionSummary?) -> String {
        switch section {
        case .scheduleQuality:
            return "Schedules don't fit the work at \(above)"
        case .missingItems:
            return "Items are missing aisle tags at \(above)"
        case .pickPath:
            return "Shoppers are off the pick path at \(above)"
        case .fiveStar:
            return "\(above) are below 4.0 stars"
        case .preSubOOS:
            return "Items are out before substitution at \(above)"
        case .prepNotReady:
            return "Prep isn't ready when shoppers pick at \(above)"
        case .dynacap:
            if summary?.headline == nil {
                return "Capacity doesn't match the recommended setting at \(above)"
            }
            return "Capacity is set below 60 pieces an hour at \(above)"
        case .pph:
            return "Shoppers pick fewer than \(Int(AssistRank.pphRankingBand.risk)) an hour at \(above)"
        case .labor:
            return "Labor is more than 3% over target at \(above)"
        case .lostRevenue:
            let money = summary?.headlineText ?? ""
            if money.isEmpty || money == "—" {
                return "\(above) are above 5% lost sales"
            }
            return "\(money) in lost sales. \(above) are above 5%."
        case .sales:
            if rows.contains(where: { $0.number("sales_yoy_pct") != nil }) {
                return "Sales are down versus last year at \(above)"
            }
            return "Sales are off the plan at \(above)"
        default:
            return "\(section.overviewLead) is off goal at \(above)"
        }
    }

    private static func storeHeadline(_ section: MetricSection, value: String, rows: [MetricRow], summary: SectionSummary?) -> String {
        let shown = value == "—" ? "" : value
        switch section {
        case .scheduleQuality:
            return shown.isEmpty ? "Your schedule efficiency is off the 90% goal" : "Your schedule efficiency is \(shown) (goal 90%)"
        case .missingItems:
            return shown.isEmpty ? "Your items are missing aisle tags (goal 5% or less)" : "\(shown) of your items have no aisle tag (goal 5% or less)"
        case .pickPath:
            return shown.isEmpty ? "Your pick path is off the 90% goal" : "Your pick path is \(shown) (goal 90%)"
        case .fiveStar:
            return shown.isEmpty ? "Your store is off a 4.50 star rating" : "Your store is at \(shown) stars (healthy is 4.50+)"
        case .preSubOOS:
            return shown.isEmpty ? "Your ordered items were out before sub (goal 5% or less)" : "\(shown) of your ordered items were out before sub (goal 5% or less)"
        case .prepNotReady:
            return shown.isEmpty ? "Your pick hours were lost to prep (goal 1.9% or less)" : "\(shown) of your pick hours were lost to prep (goal 1.9% or less)"
        case .dynacap:
            if summary?.headline == nil {
                return "Your capacity doesn't match the recommended setting"
            }
            return "Your capacity is \(shown) pieces an hour (goal 65)"
        case .pph:
            let goal = Int(AssistRank.pphRankingBand.goal)
            return shown.isEmpty ? "Your pure PPH is off the goal of \(goal)" : "Your pure PPH is \(shown) (goal \(goal))"
        case .labor:
            return shown.isEmpty ? "Your labor is off the target (goal 0% or less)" : "Your labor is \(shown) vs target (goal 0% or less)"
        case .lostRevenue:
            let money = summary?.headlineText ?? shown
            if let pct = summary?.lostRevenuePct {
                return "Your store lost \(money), \(AssistCopy.onePct(pct)) of eComm sales (goal 3% or less)"
            }
            return money.isEmpty ? "Your store is above the 3% lost-sales goal" : "Your store lost \(money) (goal 3% or less)"
        case .sales:
            let money = summary?.headlineText ?? shown
            if let yoy = summary?.salesYoyPct ?? rows.compactMap({ $0.number("sales_yoy_pct") }).first {
                return "Your eComm sales are \(money), \(AssistCopy.one(yoy))% vs last year"
            }
            return money.isEmpty ? "Your eComm sales are off goal" : "Your eComm sales are \(money)"
        default:
            return shown.isEmpty ? "\(section.overviewLead) is off goal" : "Your \(section.overviewLead) is \(shown)"
        }
    }

    private static func numberPair(
        section: MetricSection,
        summary: SectionSummary?,
        scored: AssistRank.Scored,
        level: AssistScopeLevel
    ) -> (label: String, value: String) {
        if level == .store {
            let value = summary?.headlineText ?? "—"
            return (section.title, value == "—" ? section.overviewLead : value)
        }
        return ("Stores at risk", "\(AssistCopy.grouped(scored.risk)) of \(AssistCopy.grouped(scored.storeCount))")
    }

    private static func factRow(
        section: MetricSection,
        summary: SectionSummary?,
        rows: [MetricRow],
        snapshot: AssistSnapshot,
        scored: AssistRank.Scored
    ) -> [AssistFact] {
        guard let summary else { return [] }
        var facts: [AssistFact] = []
        if summary.headline != nil {
            let label: String
            switch section {
            case .labor: label = "Target vs Actual"
            case .lostRevenue: label = "Total lost"
            case .sales: label = "eComm sales"
            default: label = "Average"
            }
            facts.append(AssistFact(label: label, value: summary.headlineText))
        }
        let goal = AssistCopy.goalFact(section)
        if section != .sales && !goal.isEmpty {
            facts.append(AssistFact(label: "Goal", value: goal))
        }
        if let trend = trendFact(section: section, rows: rows, snapshot: snapshot) {
            facts.append(trend)
        } else if let third = thirdFact(section: section, summary: summary, rows: rows, scored: scored) {
            facts.append(third)
        }
        if section == .sales, let plan = salesPlanFact(rows) {
            facts.append(plan)
        }
        return Array(facts.prefix(3))
    }

    private static func thirdFact(
        section: MetricSection,
        summary: SectionSummary,
        rows: [MetricRow],
        scored: AssistRank.Scored
    ) -> AssistFact? {
        switch section {
        case .scheduleQuality:
            return AssistFact(
                label: "Under / over",
                value: "\(AssistCopy.grouped(summary.underScheduledCount)) / \(AssistCopy.grouped(summary.overScheduledCount))"
            )
        case .fiveStar:
            let flags = HeartbeatMath.fiveStarActionFlags(rows, includeAll: true)
            guard let weakest = flags.max(by: { $0.stores < $1.stores }), weakest.stores > 0 else {
                return AssistFact(label: "On watch", value: AssistCopy.grouped(scored.watch))
            }
            return AssistFact(label: "Weakest part", value: "\(weakest.name): \(AssistCopy.stores(weakest.stores))")
        case .lostRevenue:
            guard let pct = summary.lostRevenuePct else { return nil }
            return AssistFact(label: "Lost %", value: AssistCopy.onePct(pct))
        default:
            return AssistFact(label: "On watch", value: AssistCopy.grouped(scored.watch))
        }
    }

    private static func salesPlanFact(_ rows: [MetricRow]) -> AssistFact? {
        let plans = rows.compactMap { $0.number("sales_plan_pct") }
        guard let avg = HeartbeatMath.average(plans) else { return nil }
        return AssistFact(label: "Plan", value: AssistCopy.onePct(avg))
    }

    private static func trendFact(section: MetricSection, rows: [MetricRow], snapshot: AssistSnapshot) -> AssistFact? {
        if section == .sales {
            var current: [Double] = []
            var yoy: [Double?] = []
            for row in rows {
                guard let dollars = row.number("sales_dollars") else { continue }
                current.append(dollars)
                yoy.append(row.number("sales_yoy_pct"))
            }
            guard let pct = HeartbeatMath.salesRollupYoY(current: current, yoyPct: yoy) else {
                return nil
            }
            let direction = pct >= 0 ? "Up" : "Down"
            return AssistFact(label: "Trend", value: "\(direction) \(AssistCopy.one(abs(pct)))% vs last year")
        }
        let points = snapshot.history[section] ?? []
        guard points.count >= 2 else { return nil }
        let previous = points[points.count - 2]
        let latest = points[points.count - 1]
        let delta = latest.value - previous.value
        let direction = delta >= 0 ? "Up" : "Down"
        return AssistFact(label: "Trend", value: "\(direction) \(AssistCopy.one(abs(delta))) since \(shortDate(previous.date))")
    }

    private struct CheckDeck {
        var actions: [AssistAction]
        var more: [AssistAction]
    }

    private struct PreparedCheck {
        var order: Int
        var action: AssistAction
        var showable: Bool
    }

    private static func resolutionChecks(
        section: MetricSection,
        snapshot: AssistSnapshot,
        playbook: AssistPlaybook.File?,
        level: AssistScopeLevel,
        worst: AssistChild?,
        stay: DashboardFilters?
    ) -> CheckDeck {
        guard let playbook, let book = playbook.metric(section.rawValue) else { return CheckDeck(actions: [], more: []) }
        var slotItems = preparedChecks(book, snapshot: snapshot, level: level, stay: stay)
        var moreOnly: [PreparedCheck] = []
        if section == .fiveStar, let childID = weakestFiveStarMetric(snapshot.rows[.fiveStar] ?? []),
           let child = playbook.metric(childID) {
            moreOnly = slotItems
            slotItems = preparedChecks(child, snapshot: snapshot, level: level, stay: stay)
        }
        if section == .lostRevenue,
           let bucketID = largestBucketMetric(AssistRank.scoringRows(snapshot.rows[.lostRevenue] ?? [])),
           let child = playbook.metric(bucketID),
           let promoted = preparedChecks(child, snapshot: snapshot, level: level, stay: stay).first(where: \.showable) {
            slotItems.removeAll { $0.action.question == promoted.action.question }
            slotItems.insert(promoted, at: 0)
        }

        let cap = level == .store ? 3 : 2
        var actions: [AssistAction] = []
        var more: [AssistAction] = []
        for item in slotItems {
            if item.showable, actions.count < cap {
                actions.append(item.action)
            } else {
                more.append(item.action)
            }
        }
        more.append(contentsOf: moreOnly.map(\.action))
        if level != .store, let worst, let summary = snapshot.summaries[section] {
            let counts = childMetricCounts(section: section, child: worst, snapshot: snapshot) ?? (summary.riskCount, summary.storeCount)
            let values = [
                "child": worst.label,
                "childRisk": AssistCopy.grouped(counts.0),
                "childStores": AssistCopy.grouped(counts.1),
            ]
            if let question = AssistCopy.fill(
                "Start with {child}: {childRisk} of {childStores} stores at risk",
                values,
                limit: AssistCopy.actionLimit
            ) {
                var filters = stay ?? snapshot.filters
                filters = applying(childChange(worst), on: filters)
                actions.append(AssistAction.open(
                    id: "\(section.rawValue)-child",
                    question: question,
                    owner: AssistScope.childOwner(worst.grain),
                    buttonTitle: AssistCopy.screenTitle(.dashboard),
                    filters: filters,
                    destination: .dashboard
                ))
            }
        }
        return CheckDeck(actions: actions, more: more)
    }

    private static func preparedChecks(
        _ metric: AssistPlaybook.Metric,
        snapshot: AssistSnapshot,
        level: AssistScopeLevel,
        stay: DashboardFilters?
    ) -> [PreparedCheck] {
        metric.checks.sorted { $0.order < $1.order }.compactMap { check in
            let destination = HubDestination(rawValue: check.destination) ?? .dashboard
            let owner = level == .store ? (check.owner.isEmpty ? "Store lead" : check.owner) : AssistScope.levelOwner(level)
            switch check.type {
            case .floor:
                guard let question = check.question?.trimmingCharacters(in: .whitespacesAndNewlines), !question.isEmpty else { return nil }
                let action = AssistAction.open(
                    id: "\(metric.metricId)-\(check.order)",
                    question: question,
                    owner: owner,
                    buttonTitle: AssistCopy.screenTitle(destination),
                    filters: stay,
                    destination: destination,
                    detail: check.detail ?? ""
                )
                return PreparedCheck(order: check.order, action: action, showable: true)
            case .auto:
                guard let evaluation = AssistAutoCheck.evaluate(
                    check,
                    rows: snapshot.rows,
                    summaries: snapshot.summaries,
                    level: level
                ) else { return nil }
                let action = AssistAction.open(
                    id: "\(metric.metricId)-\(check.order)",
                    question: evaluation.sentence,
                    owner: owner,
                    buttonTitle: AssistCopy.screenTitle(destination),
                    filters: stay,
                    destination: destination,
                    statusMark: evaluation.statusMark,
                    statusSymbol: evaluation.statusSymbol
                )
                return PreparedCheck(order: check.order, action: action, showable: evaluation.failing)
            }
        }
    }

    private static func weakestFiveStarMetric(_ rows: [MetricRow]) -> String? {
        let flags = HeartbeatMath.fiveStarActionFlags(AssistRank.scoringRows(rows), includeAll: true)
        guard let weakest = flags.filter({ $0.stores > 0 }).max(by: { $0.stores < $1.stores }) else { return nil }
        switch weakest.name {
        case "Flash": return "five_star_flash"
        case "Pre Sub OOS%": return "five_star_presub"
        case "COE": return "five_star_coe"
        case "OTT": return "five_star_ott"
        case "OTH 5%": return "five_star_oth5"
        default: return nil
        }
    }

    private static func largestBucketMetric(_ rows: [MetricRow]) -> String? {
        guard let bucket = largestLossBucket(rows) else { return nil }
        switch bucket.name {
        case "Post Sub OOS Foregone": return "lost_post_sub_oos"
        case "Refund $ Fulfillment": return "lost_refund"
        case "Cancelled Orders LDAP": return "lost_cancelled"
        case "Kill Switch Lost Sales": return "lost_kill_switch"
        case "Reduced Capacity Missed Sales": return "lost_reduced_capacity"
        default: return nil
        }
    }

    private static func largestLossBucket(_ rows: [MetricRow]) -> (name: String, dollars: Double, flag: String)? {
        let specs: [(String, String, String)] = [
            ("Post Sub OOS Foregone", "post_sub_oos_foregone", "bucketOOS"),
            ("Refund $ Fulfillment", "refund_lost", "bucketRefund"),
            ("Cancelled Orders LDAP", "cancelled_lost", "bucketCancel"),
            ("Kill Switch Lost Sales", "kill_switch_lost", "bucketKill"),
            ("Reduced Capacity Missed Sales", "missed_sales", "bucketCapacity"),
        ]
        var best: (String, Double, String)?
        for spec in specs {
            var dollars = HeartbeatMath.lostRevenueTODollars(rows, key: spec.1)
            if dollars == 0, spec.1 == "missed_sales" {
                dollars = HeartbeatMath.lostRevenueTODollars(rows, key: "reduced_capacity")
            }
            guard dollars > 0 else { continue }
            if best == nil || dollars > best!.1 {
                best = (spec.0, dollars, spec.2)
            }
        }
        return best
    }

    private static func childMetricCounts(
        section: MetricSection,
        child: AssistChild,
        snapshot: AssistSnapshot
    ) -> (Int, Int)? {
        let rows = AssistRank.scoringRows(snapshot.rows[section] ?? []).filter {
            AssistScope.grainKey($0, grain: child.grain) == child.key
        }
        guard !rows.isEmpty else { return nil }
        let summary = HeartbeatMath.summarize(section, rows: rows, upload: nil)
        return (summary.riskCount, summary.storeCount)
    }

    private static func childChange(_ child: AssistChild) -> AssistFilterChange {
        switch child.grain {
        case .region: return .region(child.key)
        case .division: return .division(child.key)
        case .district: return .district(child.key)
        case .om: return .om(child.key)
        case .store: return .store(child.key)
        }
    }

    private static func applying(_ change: AssistFilterChange, on lens: DashboardFilters) -> DashboardFilters {
        switch change {
        case .none, .clear:
            return lens
        case .region(let name):
            var next = DashboardFilters()
            next.region = name
            return next
        case .division(let name):
            var next = DashboardFilters()
            next.region = MarketRegion.containing(name)?.rawValue ?? ""
            next.division = name
            return next
        case .district(let name):
            var next = lens
            next.district = name
            next.om = ""
            next.store = ""
            return next
        case .om(let name):
            var next = lens
            next.om = name
            next.store = ""
            return next
        case .store(let name):
            var next = lens
            next.store = HeartbeatMath.canonicalStore(name)
            return next
        case .commit(let filters):
            return filters
        }
    }

    static func rankChildren(_ snapshot: AssistSnapshot, grain: AssistChildGrain) -> [AssistChild] {
        let metrics = MetricSection.dashboardCards.filter { $0 != .pickerScorecard }
        var groups: [String: [MetricSection: [MetricRow]]] = [:]
        var names: [String: String] = [:]
        for section in metrics {
            for row in AssistRank.scoringRows(snapshot.rows[section] ?? []) {
                guard let key = AssistScope.grainKey(row, grain: grain) else { continue }
                if names[key] == nil, let storeName = row.storeName, !storeName.isEmpty {
                    names[key] = storeName
                }
                groups[key, default: [:]][section, default: []].append(row)
            }
        }
        var ranked: [AssistChild] = []
        for (key, bySection) in groups {
            var total = 0.0
            var riskStores = Set<String>()
            var allStores = Set<String>()
            var best: (MetricSection, Double, Int, Int)?
            for section in metrics {
                let rows = bySection[section] ?? []
                guard !rows.isEmpty else { continue }
                let summary = HeartbeatMath.summarize(section, rows: rows, upload: nil)
                for row in rows {
                    let store = HeartbeatMath.canonicalStore(row.storeNumber)
                    guard !store.isEmpty else { continue }
                    allStores.insert(store)
                    if HeartbeatMath.health(for: section, row: row) == .risk {
                        riskStores.insert(store)
                    }
                }
                let distance = AssistRank.distance(section: section, rows: rows)
                guard let scored = AssistRank.score(AssistRank.Input(
                    section: section,
                    health: summary.health,
                    risk: summary.riskCount,
                    watch: summary.watchCount,
                    distance: distance,
                    storeCount: summary.storeCount
                )) else { continue }
                total += scored.score
                if best == nil || scored.score > best!.1 {
                    best = (section, scored.score, summary.riskCount, summary.storeCount)
                }
            }
            let label = AssistScope.childLabel(
                grain: grain,
                key: key,
                storeName: names[key] ?? AssistScope.rosterName(key, roster: snapshot.rosterStores)
            )
            ranked.append(AssistChild(
                key: key,
                label: label,
                score: AssistRank.round4(total),
                storesAtRisk: riskStores.count,
                storeCount: max(allStores.count, 1),
                worstMetric: best?.0,
                worstRisk: best?.2 ?? 0,
                worstStores: best?.3 ?? 0,
                grain: grain
            ))
        }
        ranked.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.storesAtRisk != rhs.storesAtRisk { return lhs.storesAtRisk > rhs.storesAtRisk }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
        return ranked
    }

    private static func childIssue(
        _ child: AssistChild,
        rank: Int,
        snapshot: AssistSnapshot,
        playbook: AssistPlaybook.File,
        base: DashboardFilters,
        scope: String,
        first: Bool
    ) -> AssistIssue {
        let filters = applying(childChange(child), on: snapshot.filters == base ? snapshot.filters : snapshot.filters)
        _ = playbook
        let openText = AssistCopy.fill("Open {child}", ["child": child.label], limit: AssistCopy.actionLimit) ?? "Open \(child.label)"
        let metricName = child.worstMetric?.overviewLead ?? "the worst scorecard"
        let workText = AssistCopy.fill(
            "Work {metric} first",
            ["metric": metricName, "child": child.label],
            limit: AssistCopy.actionLimit
        )
        let destination = child.worstMetric.map { HubDestination.from(section: $0) } ?? .dashboard
        var checks: [AssistAction] = [
            AssistAction.open(
                id: "\(child.key)-open",
                question: openText,
                owner: AssistScope.childOwner(child.grain),
                buttonTitle: AssistCopy.screenTitle(.dashboard),
                filters: filters,
                destination: .dashboard
            ),
        ]
        if let workText, child.worstMetric != nil {
            checks.append(AssistAction.open(
                id: "\(child.key)-work",
                question: workText,
                owner: AssistScope.childOwner(child.grain),
                buttonTitle: AssistCopy.screenTitle(destination),
                filters: filters,
                destination: destination
            ))
        }
        var facts: [AssistFact] = []
        if let metric = child.worstMetric {
            facts.append(AssistFact(label: "Worst scorecard", value: metric.overviewLead))
            facts.append(AssistFact(
                label: "Its stores at risk",
                value: "\(AssistCopy.grouped(child.worstRisk)) of \(AssistCopy.grouped(child.worstStores))"
            ))
        }
        let headline = first ? "\(child.label) has the most stores in trouble" : "\(child.label) is next"
        let footer = "\(openText) ›"
        let footerAction = AssistAction.open(
            id: "\(child.key)-footer",
            question: footer,
            owner: "",
            buttonTitle: footer,
            filters: filters,
            destination: .dashboard
        )
        return AssistIssue(
            id: "child-\(child.grain)-\(child.key)",
            rank: rank,
            title: child.label,
            statusText: child.storesAtRisk > 0 ? "At risk" : "Watch",
            statusSymbol: child.storesAtRisk > 0 ? "exclamationmark.triangle.fill" : "eye.fill",
            statusHealth: child.storesAtRisk > 0 ? .risk : .watch,
            headline: clip(headline, AssistCopy.headlineLimit),
            numberLabel: "Stores with an at-risk scorecard",
            numberValue: "\(AssistCopy.grouped(child.storesAtRisk)) of \(AssistCopy.grouped(child.storeCount))",
            facts: facts,
            scope: "Scope: \(scope)",
            footer: footer,
            footerAction: footerAction,
            checks: checks,
            moreChecks: [],
            why: nil,
            causeChecks: [],
            failingCauseIDs: [],
            drivenBy: [],
            rankedLine: "\(child.label): \(AssistCopy.grouped(child.storesAtRisk)) stores with an at-risk scorecard.",
            accessibilityLabel: "Rank \(rank), \(child.label). \(headline). \(child.storesAtRisk) of \(child.storeCount) stores with an at-risk scorecard."
        )
    }

    private static func shopperRows(_ snapshot: AssistSnapshot) -> [MetricRow] {
        let rows = (snapshot.rows[.pickerScorecard] ?? []).filter {
            HeartbeatMath.isRealPicker($0) && HeartbeatMath.pickerHasVolume($0)
        }
        return rows.filter { row in
            HeartbeatMath.pickerMetricReadout(row).contains { $0.health.needsAction }
        }.sorted { lhs, rhs in
            let left = lhs.number("pph") ?? .greatestFiniteMagnitude
            let right = rhs.number("pph") ?? .greatestFiniteMagnitude
            return left < right
        }
    }

    private static func shopperIssue(
        _ row: MetricRow,
        rank: Int,
        snapshot: AssistSnapshot,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters,
        level: AssistScopeLevel
    ) -> AssistIssue? {
        _ = base
        guard let name = cleanName(row) else { return nil }
        let failing = HeartbeatMath.pickerMetricReadout(row).filter { $0.health.needsAction }.map(\.name)
        guard !failing.isEmpty else { return nil }
        let store = HeartbeatMath.canonicalStore(row.storeNumber)
        let items = failing.prefix(3).joined(separator: ", ")
        var filters = snapshot.filters
        filters.store = store
        let stay: DashboardFilters? = filters
        var checks: [AssistAction] = []
        if let check = playbook?.metric(MetricSection.pickerScorecard.rawValue)?.checks.first,
           let raw = check.question, !raw.isEmpty {
            let filled = AssistCopy.fill(raw, ["shopper": name, "items": items, "store": store], limit: AssistCopy.actionLimit)
            let question = filled ?? (raw.contains("{") ? nil : raw)
            if let question {
                checks.append(AssistAction.open(
                    id: "shopper-\(rank)",
                    question: question,
                    owner: level == .store ? (check.owner.isEmpty ? "Store lead" : check.owner) : AssistScope.levelOwner(level),
                    buttonTitle: AssistCopy.screenTitle(.pickerScorecard),
                    filters: stay ?? filters,
                    destination: .pickerScorecard
                ))
            }
        }
        let headline = clip("\(name) at store \(store)", AssistCopy.headlineLimit)
        let footer = AssistCopy.screenTitle(.pickerScorecard)
        return AssistIssue(
            id: "shopper-\(store)-\(name)",
            rank: rank,
            title: "Picker",
            statusText: "At risk",
            statusSymbol: "person.fill",
            statusHealth: .risk,
            headline: headline,
            numberLabel: "Failing",
            numberValue: items,
            facts: [AssistFact(label: "Store", value: store)],
            scope: "Scope: \(AssistScope.scopeLine(snapshot.filters, roster: snapshot.rosterStores))",
            footer: footer,
            footerAction: AssistAction.open(
                id: "shopper-footer-\(rank)",
                question: footer,
                owner: "",
                buttonTitle: footer,
                filters: stay ?? filters,
                destination: .pickerScorecard
            ),
            checks: checks,
            moreChecks: [],
            why: nil,
            causeChecks: [],
            failingCauseIDs: [],
            drivenBy: [],
            rankedLine: "\(name) at store \(store): \(items).",
            accessibilityLabel: "\(name) at store \(store). \(items)."
        )
    }

    private static func chipList(_ snapshot: AssistSnapshot, ranked: [AssistRank.Scored], level: AssistScopeLevel) -> [String] {
        let storeScope = level == .store
        var chips: [String] = []
        func add(_ text: String) {
            guard chips.count < 4, let chip = AssistCopy.chip(text), !chips.contains(chip) else { return }
            chips.append(chip)
        }
        let opportunity = pickerOpportunity(snapshot)
        if ranked.isEmpty {
            if rankedWatch(snapshot) > 0 {
                add(storeScope ? "What's on watch here?" : "What's on watch?")
            }
            if let unit = AssistScope.childUnitWord(level) {
                add("Which \(unit) is worst?")
            }
            if opportunity > 0 {
                add(storeScope ? "Which shoppers need coaching here?" : "Which shoppers need coaching?")
            }
            return chips
        }
        add(storeScope ? "What should this store fix first?" : "What should we fix first?")
        if storeScope {
            if opportunity > 0 {
                add("Which shoppers need coaching here?")
            } else {
                add("What's on watch here?")
            }
        } else if let unit = AssistScope.childUnitWord(level) {
            add("Which \(unit) is worst?")
        }
        if let top = ranked.first {
            add("Tell me more about \(top.section.overviewLead)")
        }
        if storeScope {
            if chips.contains("What's on watch here?") == false {
                add("What's on watch here?")
            }
        } else if opportunity > 0 {
            add("Which shoppers need coaching?")
        } else {
            add("What's on watch?")
        }
        return chips
    }

    private static func rankedWatch(_ snapshot: AssistSnapshot) -> Int {
        MetricSection.dashboardCards.reduce(0) { partial, section in
            guard section != .pickerScorecard else { return partial }
            return partial + (snapshot.summaries[section]?.watchCount ?? 0)
        }
    }

    private static func pickerOpportunity(_ snapshot: AssistSnapshot) -> Int {
        let rows = snapshot.rows[.pickerScorecard] ?? []
        if rows.isEmpty {
            return snapshot.summaries[.pickerScorecard]?.riskCount ?? 0
        }
        return HeartbeatMath.pickerBoard(rows).opportunityCount
    }

    private static func emptyNote(_ snapshot: AssistSnapshot) -> String? {
        let missing = MetricSection.dashboardCards.filter { section in
            section != .pickerScorecard && (snapshot.summaries[section]?.storeCount ?? 0) == 0
        }.map(\.overviewLead)
        guard !missing.isEmpty else { return nil }
        return "No data here for: \(missing.joined(separator: ", "))."
    }

    private static func staleBanner(_ snapshot: AssistSnapshot) -> String? {
        guard let newest = snapshot.packUploads.max() else { return nil }
        guard snapshot.now.timeIntervalSince(newest) > AssistCopy.staleInterval else { return nil }
        let when = blank(snapshot.dataWindow) ?? shortDate(isoOrDate(newest))
        return "These numbers are from \(when). Today's pack hasn't loaded yet."
    }

    private static func closestToGoal(_ snapshot: AssistSnapshot, sections: [MetricSection]) -> String? {
        var best: (String, Double)?
        for section in sections {
            guard let summary = snapshot.summaries[section], let room = headroom(section, summary), room >= 0 else { continue }
            let text = "\(section.overviewLead) at \(summary.headlineText) (goal \(AssistCopy.goalFact(section)))"
            if best == nil || room < best!.1 { best = (text, room) }
        }
        return best?.0
    }

    private static func headroom(_ section: MetricSection, _ summary: SectionSummary) -> Double? {
        guard let avg = summary.headline else { return nil }
        switch section {
        case .pickPath: return (avg - HeartbeatMath.pickPathGoal) / 10
        case .missingItems, .preSubOOS: return (HeartbeatMath.missingItemsGoal - avg) / 1.5
        case .prepNotReady: return (HeartbeatMath.pnrGoal - avg) / 0.6
        case .dynacap: return (avg - HeartbeatMath.dynacapGoal) / 5
        case .scheduleQuality: return (avg - HeartbeatMath.scheduleGoal) / 5
        case .pph:
            let band = AssistRank.pphRankingBand
            return (avg - band.goal) / (band.goal - band.risk)
        case .labor: return (0 - avg) / HeartbeatMath.laborWatch
        case .fiveStar: return (avg - 4.5) / 0.5
        case .lostRevenue:
            guard let pct = summary.lostRevenuePct else { return nil }
            return (HeartbeatMath.lostRevenueGood - pct) / 2
        case .sales:
            guard let yoy = summary.salesYoyPct else { return nil }
            return yoy / 3
        default:
            return nil
        }
    }

    private static func footerTitle(section: MetricSection, scored: AssistRank.Scored, level: AssistScopeLevel) -> String {
        if level == .store || scored.risk == 0 {
            return AssistCopy.screenTitle(HubDestination.from(section: section))
        }
        return "See all \(AssistCopy.stores(scored.risk)) ›"
    }

    private static func resolvedWord(_ grain: AssistChildGrain) -> String {
        switch grain {
        case .region: return "region"
        case .division: return "market"
        case .district: return "district"
        case .om: return "OM"
        case .store: return "store"
        }
    }

    private static func cleanName(_ row: MetricRow) -> String? {
        let name = row.shopperName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.compare("Unknown shopper", options: .caseInsensitive) == .orderedSame {
            return nil
        }
        return name
    }

    private static func clip(_ text: String, _ limit: Int) -> String {
        if text.count <= limit { return text }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: limit)
        var cut = String(trimmed[..<end])
        if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) > 24 {
            cut = String(cut[..<space])
        }
        return cut
    }

    private static func blank(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func shortDate(_ raw: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(raw.prefix(10))) else { return raw }
        return isoOrDate(date)
    }

    private static func isoOrDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
