import SwiftUI

struct SectionDetailView: View {
    @EnvironmentObject private var store: HeartbeatStore
    let section: MetricSection
    @State private var pickerFocus: PickerFocus = .all
    @State private var pickPathFocus: PickPathFocus = .all
    @State private var dynacapFocus: DynacapFocus = .all
    @State private var pphFocus: PPHFocus = .all
    @State private var scheduleFocus: ScheduleFocus = .all
    @State private var prepFocus: PrepFocus = .all

    private var summary: SectionSummary { store.summary(for: section) }
    private var snapshots: [MetricRow] { store.displayRows(for: section) }
    private var missingInFile: Bool {
        store.latest(for: section).isEmpty && !store.marketStores().isEmpty
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        if section == .pickerScorecard {
                            PickerScoreCardTitle(font: .largeTitle.weight(.semibold))
                        } else {
                            Text(section == .pickPath ? "Pick Path Compliance" : section.title)
                                .font(.largeTitle.weight(.semibold))
                        }
                        Text(section.blurb)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    if missingInFile {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(AppTheme.blue)
                            Text("\(store.filters.division.isEmpty ? "This filter" : store.filters.division) isn’t in the \(section.short) workbook. Stores below come from PPH so the same division still shows across the app.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
                    }

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(minimum: 140), spacing: 14), count: 5),
                        spacing: 14
                    ) {
                        if section == .pph {
                            pphStatusTiles
                        } else if section == .pickPath {
                            pickPathStatusTiles
                        } else if section == .dynacap {
                            dynacapStatusTiles
                        } else if section == .scheduleQuality {
                            scheduleStatusTiles
                        } else if section == .fiveStar {
                            fiveStarStatusTiles
                        } else if section == .pickerScorecard {
                            pickerStatusTiles
                        } else if section == .prepNotReady {
                            prepStatusTiles
                        } else {
                            HubCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(summary.headlineLabel)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    HStack(alignment: .bottom) {
                                        Text(summary.headlineText)
                                            .font(.system(size: 32, weight: .semibold).monospacedDigit())
                                        Spacer()
                                        HealthBadge(health: summary.health)
                                    }
                                }
                            }
                            ForEach(tiles, id: \.label) { tile in
                                KpiTile(label: tile.label, value: tile.value)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 4, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }

            if section == .pickerScorecard {
                Section {
                    PickerHighlightsPanel(
                        onSelectOpportunity: { pickerFocus = .opportunity },
                        onSelectStrong: { pickerFocus = .strong }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                }
                PickerScoreTable(focus: pickerFocus)
            } else if section == .pickPath {
                PickPathTable(rows: pickPathRows)
            } else if section == .dynacap {
                DynacapTable(rows: dynacapRows)
            } else if section == .pph {
                PPHTable(rows: pphRows)
            } else if section == .scheduleQuality {
                ScheduleTable(rows: scheduleRows)
            } else if section == .prepNotReady {
                PrepTable(rows: prepRows)
            } else {
                StoreTable(section: section, rows: snapshots)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg.ignoresSafeArea())
        .environment(\.defaultMinListRowHeight, 1)
    }

    private var tiles: [(label: String, value: String)] {
        let rows = snapshots
        func avg(_ key: String) -> Double? {
            HeartbeatMath.average(rows.compactMap { $0.number(key) })
        }
        switch section {
        case .fiveStar:
            return [
                ("On-time promise", HeartbeatFormat.pct(avg("otp_pct"))),
                ("Fill rate", HeartbeatFormat.pct(avg("fill_rate_pct"))),
                ("Quality", HeartbeatFormat.pct(avg("quality_score"))),
            ]
        case .pickPath, .pickPathPicker:
            return [
                ("Compliant picks", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("picks_compliant") ?? 0) })),
                ("Total picks", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("picks_total") ?? 0) })),
                ("Exceptions", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("exception_count") ?? 0) })),
            ]
        case .prepNotReady:
            return [
                ("Not ready", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("pnr_count") ?? 0) })),
                ("Orders due", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("orders_due") ?? 0) })),
                ("Avg late", "\(HeartbeatFormat.num(avg("avg_late_min"), digits: 1)) min"),
            ]
        case .dynacap:
            let aligned = rows.filter { HeartbeatMath.dynacapAligned($0) == true }.count
            return [
                ("Aligned stores", HeartbeatFormat.num(Double(aligned))),
                ("Pickup util", HeartbeatFormat.pct(avg("pickup_util_pct"))),
                ("Delivery util", HeartbeatFormat.pct(avg("delivery_util_pct"))),
            ]
        case .scheduleQuality:
            return [
                ("Efficiency", HeartbeatFormat.pct(avg("schedule_efficiency_pct"))),
                ("Over scheduled", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("over_scheduled") ?? 0) })),
                ("Under scheduled", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("under_scheduled") ?? 0) })),
            ]
        case .pph:
            let atGoal = rows.filter { ($0.number("pph") ?? 0) >= HeartbeatMath.pphGoal }.count
            let atRisk = rows.filter { ($0.number("pph") ?? .greatestFiniteMagnitude) < HeartbeatMath.pphRisk }.count
            let week = rows.compactMap(\.recordedOn).sorted().last
            return [
                ("Goal", "80.0"),
                ("At goal", HeartbeatFormat.num(Double(atGoal))),
                ("Below 74", HeartbeatFormat.num(Double(atRisk))),
                ("Week", week ?? "—"),
            ]
        case .pickerScorecard:
            let board = HeartbeatMath.pickerBoard(rows)
            return [
                ("Shoppers", HeartbeatFormat.num(Double(rows.count))),
                ("Opportunity", HeartbeatFormat.num(Double(board.opportunity.count))),
                ("Doing well", HeartbeatFormat.num(Double(board.strong.count))),
            ]
        }
    }

    private var pickPathRows: [MetricRow] {
        switch pickPathFocus {
        case .all:
            return snapshots
        case .atGoal:
            return snapshots.filter { ($0.number("compliance_pct") ?? 0) >= HeartbeatMath.pickPathGoal }
        case .below80:
            return snapshots.filter { ($0.number("compliance_pct") ?? .greatestFiniteMagnitude) < HeartbeatMath.pickPathRisk }
        }
    }

    private var prepRows: [MetricRow] {
        let scored = snapshots.filter { $0.number("pnr_rate_pct") != nil }
        switch prepFocus {
        case .all:
            return scored
        case .atGoal:
            return scored.filter { ($0.number("pnr_rate_pct") ?? .greatestFiniteMagnitude) <= HeartbeatMath.pnrGoal }
        case .above25:
            return scored.filter { ($0.number("pnr_rate_pct") ?? 0) > HeartbeatMath.pnrWatch }
        }
    }

    private var scheduleRows: [MetricRow] {
        let scored = snapshots.filter { $0.number("schedule_efficiency_pct") != nil }
        switch scheduleFocus {
        case .all:
            return scored
        case .atGoal:
            return scored.filter { ($0.number("schedule_efficiency_pct") ?? 0) >= HeartbeatMath.scheduleGoal }
        case .underRisk:
            return scored.filter { ($0.number("under_schedule_pct", "under_scheduled") ?? 0) > HeartbeatMath.scheduleVarianceWatch }
        case .overRisk:
            return scored.filter { ($0.number("over_schedule_pct", "over_scheduled") ?? 0) > HeartbeatMath.scheduleVarianceWatch }
        }
    }

    private var pphRows: [MetricRow] {
        let scored = snapshots.filter { $0.number("pph") != nil }
        switch pphFocus {
        case .all:
            return scored
        case .atGoal:
            return scored.filter { ($0.number("pph") ?? 0) >= HeartbeatMath.pphGoal }
        case .below74:
            return scored.filter { ($0.number("pph") ?? .greatestFiniteMagnitude) < HeartbeatMath.pphRisk }
        }
    }

    private var dynacapRows: [MetricRow] {
        let scored = snapshots.filter { $0.number("dynacap_rate", "pieces_per_hour") != nil }
        switch dynacapFocus {
        case .all:
            return scored
        case .atGoal:
            return scored.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? 0) >= HeartbeatMath.dynacapGoal }
        case .below60:
            return scored.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? .greatestFiniteMagnitude) < HeartbeatMath.dynacapRisk }
        }
    }

    @ViewBuilder
    private var pphStatusTiles: some View {
        let rows = snapshots
        let atGoal = rows.filter { ($0.number("pph") ?? 0) >= HeartbeatMath.pphGoal }.count
        let atRisk = rows.filter { ($0.number("pph") ?? .greatestFiniteMagnitude) < HeartbeatMath.pphRisk }.count
        callout("Avg pure PPH", summary.headlineText, "Goal 80 · watch under 74", summary.health, selected: pphFocus == .all) {
            pphFocus = .all
        }
        callout("Goal", "80.0", "Target pure PPH", .none, brand: true)
        callout("At goal", HeartbeatFormat.num(Double(atGoal)), "Stores at 80+", .good, unit: "stores", selected: pphFocus == .atGoal) {
            pphFocus = .atGoal
        }
        callout("Below 74", HeartbeatFormat.num(Double(atRisk)), "At risk stores", atRisk == 0 ? .good : .risk, unit: "stores", selected: pphFocus == .below74) {
            pphFocus = .below74
        }
    }

    @ViewBuilder
    private var prepStatusTiles: some View {
        let rows = snapshots
        let atGoal = rows.filter { ($0.number("pnr_rate_pct") ?? .greatestFiniteMagnitude) <= HeartbeatMath.pnrGoal }.count
        let atRisk = rows.filter { ($0.number("pnr_rate_pct") ?? 0) > HeartbeatMath.pnrWatch }.count
        callout("Avg PNR hours", summary.headlineText, "1.9% healthy · over 2.5% at risk", summary.health, selected: prepFocus == .all) {
            prepFocus = .all
        }
        callout("Goal", "1.9%", "Or less", .none, brand: true)
        callout("At goal", HeartbeatFormat.num(Double(atGoal)), "Stores at 1.9% or better", .good, unit: "stores", selected: prepFocus == .atGoal) {
            prepFocus = .atGoal
        }
        callout("Above 2.5%", HeartbeatFormat.num(Double(atRisk)), "At risk stores", atRisk == 0 ? .good : .risk, unit: "stores", selected: prepFocus == .above25) {
            prepFocus = .above25
        }
    }

    @ViewBuilder
    private var pickPathStatusTiles: some View {
        let rows = snapshots
        let atGoal = rows.filter { ($0.number("compliance_pct") ?? 0) >= HeartbeatMath.pickPathGoal }.count
        let atRisk = rows.filter { ($0.number("compliance_pct") ?? .greatestFiniteMagnitude) < HeartbeatMath.pickPathRisk }.count
        callout("Avg compliance", summary.headlineText, "90% goal · under 80% at risk", summary.health, selected: pickPathFocus == .all) {
            pickPathFocus = .all
        }
        callout("Goal", "90%", "Target for every store", .none, brand: true)
        callout("At goal", HeartbeatFormat.num(Double(atGoal)), "Stores at 90%+", .good, unit: "stores", selected: pickPathFocus == .atGoal) {
            pickPathFocus = .atGoal
        }
        callout("Below 80%", HeartbeatFormat.num(Double(atRisk)), "At risk stores", atRisk == 0 ? .good : .risk, unit: "stores", selected: pickPathFocus == .below80) {
            pickPathFocus = .below80
        }
    }

    @ViewBuilder
    private var dynacapStatusTiles: some View {
        let rows = snapshots
        let atGoal = rows.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? 0) >= HeartbeatMath.dynacapGoal }.count
        let atRisk = rows.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? .greatestFiniteMagnitude) < HeartbeatMath.dynacapRisk }.count
        let util = HeartbeatMath.average(rows.compactMap { $0.number("utilization_pct") })
        callout("Avg pieces / hour", summary.headlineText, "65 goal · under 60 at risk", summary.health, selected: dynacapFocus == .all) {
            dynacapFocus = .all
        }
        callout("Goal", "65.0", "Target pieces per hour", .none, brand: true)
        callout("At goal", HeartbeatFormat.num(Double(atGoal)), "Stores at 65+", .good, unit: "stores", selected: dynacapFocus == .atGoal) {
            dynacapFocus = .atGoal
        }
        callout("Below 60", HeartbeatFormat.num(Double(atRisk)), "At risk stores", atRisk == 0 ? .good : .risk, unit: "stores", selected: dynacapFocus == .below60) {
            dynacapFocus = .below60
        }
        callout("Utilization", HeartbeatFormat.pct(util), "Used vs available capacity", .none)
    }

    @ViewBuilder
    private var scheduleStatusTiles: some View {
        let rows = snapshots
        let atGoal = rows.filter { ($0.number("schedule_efficiency_pct") ?? 0) >= HeartbeatMath.scheduleGoal }.count
        let underRisk = rows.filter { ($0.number("under_schedule_pct", "under_scheduled") ?? 0) > HeartbeatMath.scheduleVarianceWatch }.count
        let overRisk = rows.filter { ($0.number("over_schedule_pct", "over_scheduled") ?? 0) > HeartbeatMath.scheduleVarianceWatch }.count
        callout("Avg efficiency", summary.headlineText, "90% goal · zero over / under", summary.health, selected: scheduleFocus == .all) {
            scheduleFocus = .all
        }
        callout("Goal", "90%", "Target schedule efficiency", .none, brand: true)
        callout("At goal", HeartbeatFormat.num(Double(atGoal)), "Stores at 90%+", .good, unit: "stores", selected: scheduleFocus == .atGoal) {
            scheduleFocus = .atGoal
        }
        callout("Under Scheduled", HeartbeatFormat.num(Double(underRisk)), "Underscheduled over 5%", underRisk == 0 ? .good : .risk, unit: "stores", selected: scheduleFocus == .underRisk) {
            scheduleFocus = .underRisk
        }
        callout("Over Scheduled", HeartbeatFormat.num(Double(overRisk)), "Overscheduled over 5%", overRisk == 0 ? .good : .risk, unit: "stores", selected: scheduleFocus == .overRisk) {
            scheduleFocus = .overRisk
        }
    }

    @ViewBuilder
    private var fiveStarStatusTiles: some View {
        let rows = snapshots
        let atFive = rows.filter { ($0.number("star_rating") ?? 0) >= 4.95 }.count
        let pass = rows.filter { ($0.number("star_rating") ?? 0) >= HeartbeatMath.fiveStarPass }.count
        let fail = rows.filter { ($0.number("star_rating") ?? .greatestFiniteMagnitude) < HeartbeatMath.fiveStarPass }.count
        let flash = HeartbeatMath.average(rows.compactMap { $0.number("flash_pct") })
        let presub = HeartbeatMath.average(rows.compactMap { $0.number("presub_pct") })
        let coe = HeartbeatMath.average(rows.compactMap { $0.number("coe_pct") })
        let ott = HeartbeatMath.average(rows.compactMap { $0.number("ott_pct") })
        let oth = HeartbeatMath.average(rows.compactMap { $0.number("oth5_pct") })
        let flashMark = HeartbeatMath.starMark(value: flash, full: 75, half: 55)
        let presubMark = HeartbeatMath.starMark(value: presub, full: 5, half: 6, invert: true)
        let coeMark = HeartbeatMath.starMark(value: coe, full: 20, half: 0)
        let ottMark = HeartbeatMath.starMark(value: ott, full: 95, half: 90)
        let othMark = HeartbeatMath.starMark(value: oth, full: 92, half: 78)
        callout("Avg star rating", summary.headlineText, "5.00 goal · 4.0+ pass", summary.health)
        callout("Goal", "5.00", "Target store rating", .none, brand: true)
        callout("At 5.00", HeartbeatFormat.num(Double(atFive)), "Stores at a perfect 5", .good, unit: "stores")
        callout("Pass 4.0+", HeartbeatFormat.num(Double(pass)), "Stores that pass", .good, unit: "stores")
        callout("Fail", HeartbeatFormat.num(Double(fail)), "Stores under 4.0", fail == 0 ? .good : .risk, unit: "stores")
        callout("Flash", HeartbeatFormat.pct(flash), flashMark.label, flashMark.health)
        callout("Presubs", HeartbeatFormat.pct(presub), presubMark.label, presubMark.health)
        callout("COE", HeartbeatFormat.pct(coe), coeMark.label, coeMark.health)
        callout("OTT", HeartbeatFormat.pct(ott), ottMark.label, ottMark.health)
        callout("OTH 5%", HeartbeatFormat.pct(oth), othMark.label, othMark.health)
    }

    @ViewBuilder
    private var pickerStatusTiles: some View {
        pickerTile(.all, health: .none)
        pickerTile(.opportunity, health: store.pickerCount(for: .opportunity) == 0 ? .good : .risk)
        pickerTile(.strong, health: .good)
        pickerTile(.pph, health: falloutHealth(.pph))
        pickerTile(.presub, health: falloutHealth(.presub))
        pickerTile(.oos, health: falloutHealth(.oos))
        pickerTile(.ott, health: falloutHealth(.ott))
        pickerTile(.oth, health: falloutHealth(.oth))
        pickerTile(.coe, health: falloutHealth(.coe))
        pickerTile(.refund, health: falloutHealth(.refund))
    }

    private func pickerTile(_ focus: PickerFocus, health: Health) -> some View {
        PickerFocusTile(
            title: focus.title,
            value: HeartbeatFormat.num(Double(store.pickerCount(for: focus))),
            detail: pickerTileDetail(focus),
            health: health,
            selected: pickerFocus == focus,
            unit: "shoppers",
            action: { pickerFocus = focus }
        )
    }

    private func callout(
        _ title: String,
        _ value: String,
        _ detail: String,
        _ health: Health,
        brand: Bool = false,
        unit: String? = nil,
        selected: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        PickerFocusTile(title: title, value: value, detail: detail, health: health, selected: selected, brand: brand, unit: unit, action: action)
    }

    private func pickerTileDetail(_ focus: PickerFocus) -> String {
        switch focus {
        case .all: return "Every shopper in this filter"
        case .opportunity: return "15+ orders · underperforming"
        case .strong: return "15+ orders · hitting the mix"
        case .refund: return "$0 healthy · $1–20 watch · $20+ risk"
        default: return "Below goal in this metric"
        }
    }

    private func falloutHealth(_ focus: PickerFocus) -> Health {
        if store.pickerCount(for: focus) == 0 { return .good }
        return store.pickerFocusHealth(for: focus)
    }

    private func tone(for health: Health) -> KpiTile.Tone {
        switch health {
        case .good: return .good
        case .watch: return .watch
        case .risk: return .risk
        case .none: return .plain
        }
    }
}

struct PickerFocusTile: View {
    let title: String
    let value: String
    let detail: String
    let health: Health
    var selected: Bool = false
    var brand: Bool = false
    var unit: String? = nil
    var action: (() -> Void)? = nil
    @State private var pulseOn = false

    var body: some View {
        Group {
            if let action {
                Button(action: action) { tile }
                    .buttonStyle(.plain)
            } else {
                tile
            }
        }
        .frame(maxWidth: .infinity, minHeight: 176, maxHeight: 176)
        .onAppear {
            guard shouldPulse else { return }
            pulseOn = false
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pulseOn = true
            }
        }
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                if health != .none {
                    HealthBadge(health: health, prominent: true)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit, !unit.isEmpty {
                    Text(unit)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(ink.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 40, alignment: .bottomLeading)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(stroke, lineWidth: selected || shouldPulse ? 2.4 : 1)
                .opacity(shouldPulse && !selected ? (pulseOn ? 1 : 0.22) : 1)
        )
    }

    private var shouldPulse: Bool { health == .risk || health == .watch }

    private var fill: Color {
        if brand { return AppTheme.blueSoft }
        switch health {
        case .good: return AppTheme.okSoft
        case .watch: return AppTheme.warnSoft
        case .risk: return AppTheme.badSoft
        case .none: return selected ? AppTheme.blueSoft : AppTheme.card
        }
    }

    private var stroke: Color {
        if selected || brand { return AppTheme.blue.opacity(selected ? 1 : 0.35) }
        switch health {
        case .good: return AppTheme.ok.opacity(0.28)
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.cardBorder
        }
    }

    private var ink: Color {
        if brand { return AppTheme.blue }
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.text
        }
    }
}

#Preview {
    SectionDetailView(section: .fiveStar)
        .environmentObject(HeartbeatStore())
        .environmentObject(HubRouter())
}
