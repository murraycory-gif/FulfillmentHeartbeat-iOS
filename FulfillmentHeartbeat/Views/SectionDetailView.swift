import SwiftUI

struct SectionDetailView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @StateObject private var laborHeaderPin = LaborHeaderPin()
    let section: MetricSection
    @State private var pickerFocus: PickerFocus = .all
    @State private var pickPathFocus: PickPathFocus = .all
    @State private var dynacapFocus: DynacapFocus = .all
    @State private var pphFocus: PPHFocus = .all
    @State private var scheduleFocus: ScheduleFocus = .all
    @State private var prepFocus: PrepFocus = .all
    @State private var fiveStarFocus: FiveStarFocus = .all
    @State private var laborFocus: LaborFocus = .all
    @State private var lostRevenueFocus: LostRevenueFocus = .all

    private var summary: SectionSummary { store.summary(for: section) }
    private var snapshots: [MetricRow] { store.displayRows(for: section) }
    private var missingInFile: Bool {
        store.latest(for: section).isEmpty && !store.marketStores().isEmpty
    }

    var body: some View {
        List {
            Section {
                pageIntro
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
            } else if section == .fiveStar {
                FiveStarTable(rows: fiveStarRows)
            } else if section == .labor {
                Section {
                    LaborRollupTable()
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                LaborTable(rows: laborRows)
            } else if section == .lostRevenue {
                Section {
                    LostRevenueRollupTable()
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                LostRevenueTable(rows: lostRevenueRows)
            } else {
                StoreTable(section: section, rows: snapshots)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg.ignoresSafeArea())
        .environment(\.defaultMinListRowHeight, 1)
        .environmentObject(laborHeaderPin)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: LaborListTopKey.self,
                    value: geo.frame(in: .global).minY
                )
            }
        )
        .onPreferenceChange(LaborListTopKey.self) { top in
            laborHeaderPin.listTop = top
        }
        .onPreferenceChange(LaborHeaderMinYKey.self) { minY in
            laborHeaderPin.updatePin(headerMinY: minY)
        }
        .overlay(alignment: .top) {
            if laborHeaderPin.storesExpanded && laborHeaderPin.pinned {
                if section == .labor {
                    LaborStickyStoreHeader()
                        .environmentObject(laborHeaderPin)
                } else if section == .lostRevenue {
                    LostRevenueStickyStoreHeader()
                        .environmentObject(laborHeaderPin)
                }
            }
        }
        .onAppear {
            if section == .labor || section == .lostRevenue {
                laborHeaderPin.openOnPageEnter()
            }
        }
    }

    @ViewBuilder
    private var pageIntro: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                if section == .pickerScorecard {
                    PageHeadline(lead: "Picker", accent: "ScoreCard", blurb: section.blurb)
                } else if section == .labor {
                    PageHeadline(lead: "Labor", accent: "ScoreCard", blurb: section.blurb)
                } else if section == .pph {
                    PageHeadline(lead: "PPH Pure Picks Per Hour", accent: "ScoreCard", blurb: section.blurb)
                } else if section == .scheduleQuality {
                    PageHeadline(lead: "Schedule Quality", accent: "ScoreCard", blurb: section.blurb)
                } else if section == .dynacap {
                    PageHeadline(lead: "Dynacap Settings", accent: "ScoreCard", blurb: section.blurb)
                } else if section == .prepNotReady {
                    PageHeadline(lead: "Prep Not Ready", accent: "ScoreCard", blurb: section.blurb)
                } else if section == .pickPath {
                    PageHeadline(lead: "Pick Path Compliance", accent: "ScoreCard", blurb: section.blurb)
                } else if section == .fiveStar {
                    PageHeadline(lead: "5 Star", accent: "ScoreCard", blurb: section.blurb)
                } else if section == .lostRevenue {
                    PageHeadline(lead: "Loss Revenue", accent: "ScoreCard", blurb: section.blurb)
                } else {
                    PageHeadline(
                        lead: section == .pickPath ? "Pick Path Compliance" : section.title,
                        blurb: section.blurb
                    )
                }
            }

            if section == .labor, store.laborNeedsReload() {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.warn)
                    Text("Re-upload LABOR Store View Thru Week.xlsx. The Power BI Total row is missing, so company tiles cannot match -0.04% Target vs Actual.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.warnSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
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

            if section == .labor {
                laborStatusTiles
            } else if section == .lostRevenue {
                lostRevenueStatusTiles
            } else {
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
        }
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
        case .labor:
            let risk = rows.filter { ($0.number("target_vs_actual_pct") ?? 0) > HeartbeatMath.laborWatch }.count
            let dollars = rows.compactMap { $0.number("act_cost_dollar") }.reduce(0, +)
            return [
                ("Weeks", store.laborWeekSpan()),
                ("Cost target", HeartbeatFormat.pct(avg("cost_trgt_pct"))),
                ("Act cost", HeartbeatFormat.money(dollars)),
                ("At risk", HeartbeatFormat.num(Double(risk))),
            ]
        case .pickerScorecard:
            let board = HeartbeatMath.pickerBoard(rows)
            return [
                ("Shoppers", HeartbeatFormat.num(Double(rows.count))),
                ("Opportunity", HeartbeatFormat.num(Double(board.opportunity.count))),
                ("Doing well", HeartbeatFormat.num(Double(board.strong.count))),
            ]
        case .lostRevenue:
            let dollars = rows.compactMap { $0.number("lost_revenue") }.reduce(0, +)
            let sales = rows.compactMap { $0.number("ecomm_sales") }.reduce(0, +)
            return [
                ("Lost revenue", HeartbeatFormat.money(dollars)),
                ("Lost %", HeartbeatFormat.pct(sales > 0 ? dollars / sales * 100 : summary.lostRevenuePct)),
                ("eComm sales", HeartbeatFormat.money(sales)),
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

    private var fiveStarRows: [MetricRow] {
        let scored = snapshots.filter { $0.number("star_rating") != nil }
        switch fiveStarFocus {
        case .all:
            return scored
        case .atFive:
            return scored.filter { ($0.number("star_rating") ?? 0) >= 4.95 }
        case .pass:
            return scored.filter { ($0.number("star_rating") ?? 0) >= HeartbeatMath.fiveStarPass }
        case .fail:
            return scored.filter { ($0.number("star_rating") ?? .greatestFiniteMagnitude) < HeartbeatMath.fiveStarPass }
        case .flash:
            return scored.filter { HeartbeatMath.flashStar($0).health != .good }
        case .presub:
            return scored.filter { HeartbeatMath.presubStar($0).health != .good }
        case .coe:
            return scored.filter { HeartbeatMath.coeStar($0).health != .good }
        case .ott:
            return scored.filter { HeartbeatMath.ottStar($0).health != .good }
        case .oth:
            return scored.filter { HeartbeatMath.othStar($0).health != .good }
        }
    }

    private var laborRows: [MetricRow] {
        let scored = snapshots.filter { $0.number("target_vs_actual_pct") != nil }
        switch laborFocus {
        case .all:
            return scored
        case .healthy:
            return scored.filter { ($0.number("target_vs_actual_pct") ?? 1) <= 0 }
        case .watch:
            return scored.filter {
                let value = $0.number("target_vs_actual_pct") ?? 0
                return value > 0 && value <= HeartbeatMath.laborWatch
            }
        case .risk:
            return scored.filter { ($0.number("target_vs_actual_pct") ?? 0) > HeartbeatMath.laborWatch }
        }
    }

    private var lostRevenueRows: [MetricRow] {
        let scored = snapshots.filter { $0.textPayload["lost_grain"] != "market" && !$0.storeNumber.isEmpty }
        switch lostRevenueFocus {
        case .all:
            return scored
        case .healthy:
            return scored.filter { HeartbeatMath.lostRevenueHealth($0) == .good }
        case .watch:
            return scored.filter { HeartbeatMath.lostRevenueHealth($0) == .watch }
        case .risk:
            return scored.filter { HeartbeatMath.lostRevenueHealth($0) == .risk }
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
    private var lostRevenueStatusTiles: some View {
        let rows = snapshots.filter { $0.textPayload["lost_grain"] != "market" && !$0.storeNumber.isEmpty }
        let dollars = summary.headline
        let pct = summary.lostRevenuePct
        let healthy = rows.filter { HeartbeatMath.lostRevenueHealth($0) == .good }.count
        let watch = rows.filter { HeartbeatMath.lostRevenueHealth($0) == .watch }.count
        let risk = rows.filter { HeartbeatMath.lostRevenueHealth($0) == .risk }.count
        let sales: Double? = {
            if !store.filters.isActive, let market = store.lostRevenueMarketRow() {
                return market.number("ecomm_sales")
            }
            let sum = rows.compactMap { $0.number("ecomm_sales") }.reduce(0, +)
            return rows.isEmpty ? nil : sum
        }()
        let goalPct: Double? = {
            if !store.filters.isActive, let market = store.lostRevenueMarketRow() {
                return market.number("lost_revenue_goal_pct")
            }
            let goal = rows.compactMap { $0.number("lost_revenue_goal") }.reduce(0, +)
            let sumSales = rows.compactMap { $0.number("ecomm_sales") }.reduce(0, +)
            return sumSales > 0 ? goal / sumSales * 100 : nil
        }()
        let post = rows.compactMap { $0.number("post_sub_oos_foregone") }.reduce(0, +)
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                callout("Total lost revenue", HeartbeatFormat.money(dollars), "Total Opportunity", summary.health, selected: lostRevenueFocus == .all) {
                    lostRevenueFocus = .all
                }
                callout("Healthy", HeartbeatFormat.num(Double(healthy)), "3% or better", .good, unit: "stores", selected: lostRevenueFocus == .healthy) {
                    lostRevenueFocus = .healthy
                }
                callout("Watch", HeartbeatFormat.num(Double(watch)), "3.01% to 5%", watch == 0 ? .good : .watch, unit: "stores", selected: lostRevenueFocus == .watch) {
                    lostRevenueFocus = .watch
                }
                callout("At Risk", HeartbeatFormat.num(Double(risk)), "Stores over 5%", risk == 0 ? .good : .risk, unit: "stores", selected: lostRevenueFocus == .risk) {
                    lostRevenueFocus = .risk
                }
            }
            HStack(spacing: 12) {
                callout("Lost revenue %", HeartbeatFormat.pct(pct), "Total Opportunity", summary.health)
                callout("eComm sales", HeartbeatFormat.money(sales), "In this filter", .none, brand: true)
                callout("FY2026 Goal", HeartbeatFormat.pct(goalPct), "Lost revenue goal", .none, brand: true)
                callout("Post Sub OOS", HeartbeatFormat.money(rows.isEmpty ? nil : post), "Foregone revenue", .none)
            }
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
        let efficiency = HeartbeatMath.average(rows.compactMap { $0.number("schedule_efficiency_pct") })
        let efficiencyHealth = HeartbeatMath.band(efficiency, good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch)
        let atGoal = rows.filter { ($0.number("schedule_efficiency_pct") ?? 0) >= HeartbeatMath.scheduleGoal }.count
        let underRisk = rows.filter { ($0.number("under_schedule_pct", "under_scheduled") ?? 0) > HeartbeatMath.scheduleVarianceWatch }.count
        let overRisk = rows.filter { ($0.number("over_schedule_pct", "over_scheduled") ?? 0) > HeartbeatMath.scheduleVarianceWatch }.count
        callout("Avg schedule efficiency", HeartbeatFormat.pct(efficiency), "90% goal · zero over / under", efficiencyHealth, selected: scheduleFocus == .all) {
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
        callout("Avg star rating", summary.headlineText, "5.00 goal · 4.0+ pass", summary.health, selected: fiveStarFocus == .all) {
            fiveStarFocus = .all
        }
        callout("Goal", "5.00", "Target store rating", .none, brand: true)
        callout("At 5.00", HeartbeatFormat.num(Double(atFive)), "Stores at a perfect 5", .good, unit: "stores", selected: fiveStarFocus == .atFive) {
            fiveStarFocus = .atFive
        }
        callout("Pass 4.0+", HeartbeatFormat.num(Double(pass)), "Stores that pass", .good, unit: "stores", selected: fiveStarFocus == .pass) {
            fiveStarFocus = .pass
        }
        callout("Fail", HeartbeatFormat.num(Double(fail)), "Stores under 4.0", fail == 0 ? .good : .risk, unit: "stores", selected: fiveStarFocus == .fail) {
            fiveStarFocus = .fail
        }
        callout("Flash", HeartbeatFormat.pct(flash), flashMark.label, flashMark.health, selected: fiveStarFocus == .flash) {
            fiveStarFocus = .flash
        }
        callout("Presubs", HeartbeatFormat.pct(presub), presubMark.label, presubMark.health, selected: fiveStarFocus == .presub) {
            fiveStarFocus = .presub
        }
        callout("COE", HeartbeatFormat.pct(coe), coeMark.label, coeMark.health, selected: fiveStarFocus == .coe) {
            fiveStarFocus = .coe
        }
        callout("OTT", HeartbeatFormat.pct(ott), ottMark.label, ottMark.health, selected: fiveStarFocus == .ott) {
            fiveStarFocus = .ott
        }
        callout("OTH 5%", HeartbeatFormat.pct(oth), othMark.label, othMark.health, selected: fiveStarFocus == .oth) {
            fiveStarFocus = .oth
        }
    }

    @ViewBuilder
    private var laborStatusTiles: some View {
        let rows = snapshots
        let healthy = rows.filter { ($0.number("target_vs_actual_pct") ?? 1) <= 0 }.count
        let watch = rows.filter {
            let value = $0.number("target_vs_actual_pct") ?? 0
            return value > 0 && value <= HeartbeatMath.laborWatch
        }.count
        let risk = rows.filter { ($0.number("target_vs_actual_pct") ?? 0) > HeartbeatMath.laborWatch }.count
        let tva = laborRollup("target_vs_actual_pct")
        let cost = laborRollup("cost_trgt_pct")
        let act = laborRollup("act_cost_pct")
        let efficiency = laborRollup("schedule_efficiency_pct")
        let uplh = laborRollup("uplh_impact_pct")
        let wage = laborRollup("wage_impact_pct")
        let aiv = laborRollup("aiv_impact_pct")
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                callout("Target vs Actual", HeartbeatFormat.pct(tva), "0% healthy · 0.01–3% watch · over 3% risk", HeartbeatMath.laborHealth(tva), selected: laborFocus == .all) {
                    laborFocus = .all
                }
                callout("Healthy", HeartbeatFormat.num(Double(healthy)), "0% or better", .good, unit: "stores", selected: laborFocus == .healthy) {
                    laborFocus = .healthy
                }
                callout("Watch", HeartbeatFormat.num(Double(watch)), "0.01% to 3%", watch == 0 ? .good : .watch, unit: "stores", selected: laborFocus == .watch) {
                    laborFocus = .watch
                }
                callout("At Risk", HeartbeatFormat.num(Double(risk)), "Over 3%", risk == 0 ? .good : .risk, unit: "stores", selected: laborFocus == .risk) {
                    laborFocus = .risk
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    laborMetricCallouts(cost: cost, act: act, efficiency: efficiency, uplh: uplh, wage: wage, aiv: aiv)
                }
                .frame(minWidth: 1080)
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        laborCostCallouts(cost: cost, act: act, efficiency: efficiency)
                    }
                    HStack(spacing: 12) {
                        laborImpactCallouts(uplh: uplh, wage: wage, aiv: aiv)
                    }
                }
            }
        }
    }

    private func laborImpactHealth(_ value: Double?) -> Health {
        guard let value else { return .none }
        return value <= 0 ? .good : .risk
    }

    private func laborActCostHealth(_ act: Double?, _ cost: Double?) -> Health {
        guard let act, let cost else { return .none }
        return act <= cost ? .good : .risk
    }

    private func laborActCostDetail(_ act: Double?, _ cost: Double?) -> String {
        guard let act, let cost else { return "Actual cost" }
        return act <= cost ? "At or below target" : "Above cost target"
    }

    @ViewBuilder
    private func laborMetricCallouts(cost: Double?, act: Double?, efficiency: Double?, uplh: Double?, wage: Double?, aiv: Double?) -> some View {
        laborCostCallouts(cost: cost, act: act, efficiency: efficiency)
        laborImpactCallouts(uplh: uplh, wage: wage, aiv: aiv)
    }

    @ViewBuilder
    private func laborCostCallouts(cost: Double?, act: Double?, efficiency: Double?) -> some View {
        callout("CostTrgt%", HeartbeatFormat.pct(cost), "Cost target", .none, brand: true, compact: true)
        callout("ActCost%", HeartbeatFormat.pct(act), laborActCostDetail(act, cost), laborActCostHealth(act, cost), compact: true)
        callout("Sch Effi%", HeartbeatFormat.pct(efficiency), "90% goal · 85% watch", HeartbeatMath.band(efficiency, good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch), compact: true)
    }

    @ViewBuilder
    private func laborImpactCallouts(uplh: Double?, wage: Double?, aiv: Double?) -> some View {
        callout("UPLH", HeartbeatFormat.pct(uplh), "UPLH impact", laborImpactHealth(uplh), compact: true)
        callout("Wage", HeartbeatFormat.pct(wage), "Wage impact", laborImpactHealth(wage), compact: true)
        callout("AIV", HeartbeatFormat.pct(aiv), "AIV impact", laborImpactHealth(aiv), compact: true)
    }

    private func laborRollup(_ key: String) -> Double? {
        if !store.filters.isActive, let value = store.laborMarketRow()?.number(key) {
            return value
        }
        return HeartbeatMath.laborRollup(snapshots, key: key)
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
        compact: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        PickerFocusTile(title: title, value: value, detail: detail, health: health, selected: selected, brand: brand, unit: unit, compact: compact, action: action)
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
    var compact: Bool = false
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
        .frame(maxWidth: .infinity, minHeight: compact ? 148 : 176, maxHeight: compact ? 148 : 176)
        .onAppear {
            guard shouldPulse else { return }
            pulseOn = false
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pulseOn = true
            }
        }
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            HStack(alignment: .center, spacing: compact ? 6 : 8) {
                Text(title)
                    .font((compact ? Font.headline : Font.title3).weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if health != .none {
                    HealthBadge(health: health, prominent: true, compact: compact)
                        .layoutPriority(1)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: compact ? 26 : 34, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                if let unit, !unit.isEmpty {
                    Text(unit)
                        .font((compact ? Font.subheadline : Font.title3).weight(.semibold))
                        .foregroundStyle(ink.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: compact ? 28 : 40, alignment: .bottomLeading)
            Text(detail)
                .font(compact ? .caption.weight(.medium) : .subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: compact ? 24 : 36, alignment: .topLeading)
        }
        .padding(compact ? 12 : 16)
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
