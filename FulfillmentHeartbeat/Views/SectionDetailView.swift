import SwiftUI

struct SectionDetailView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
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
    @State private var missingItemsFocus: MissingItemsFocus = .all
    @State private var miCategories: Set<MissingItemDept> = []
    @State private var showTables = false
    @State private var pageWidth: CGFloat = 980

    private var summary: SectionSummary { store.summary(for: section) }
    private var snapshots: [MetricRow] { store.seatRows(for: section) }
    private var showStoreTable: Bool { PulseLaunch.shouldShowStoreTable(filters: store.filters) }
    private var missingInFile: Bool {
        store.latest(for: section).isEmpty && !store.marketStores().isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if !HubLayout.isPhone(sizeClass) {
                HubStickyPageBanner(
                    icon: section.symbol,
                    title: section.bannerTitle,
                    accessory: store.filters.summary,
                    trailing: store.dataWindow(for: section)
                )
            }
            List {
            Section {
                pageIntro
                    .listRowInsets(EdgeInsets(top: 8, leading: HubLayout.isPhone(sizeClass) ? 12 : 20, bottom: 4, trailing: HubLayout.isPhone(sizeClass) ? 12 : 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
            }

            if showTables {
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
                if showStoreTable {
                    PickerScoreTable(focus: pickerFocus)
                }
            } else if section == .pickPath {
                Section {
                    PickPathRollupTable()
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                if showStoreTable {
                    PickPathTable(rows: pickPathRows)
                }
            } else if section == .dynacap {
                Section {
                    DynacapRollupTable()
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                if showStoreTable {
                    DynacapTable(rows: dynacapRows)
                }
            } else if section == .pph {
                Section {
                    PPHRollupTable()
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                if showStoreTable {
                    PPHTable(rows: pphRows)
                }
            } else if section == .scheduleQuality {
                Section {
                    ScheduleRollupTable()
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                if showStoreTable {
                    ScheduleTable(rows: scheduleRows)
                }
            } else if section == .prepNotReady {
                Section {
                    PrepRollupTable()
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                if showStoreTable {
                    PrepTable(rows: prepRows)
                }
            } else if section == .fiveStar {
                Section {
                    FiveStarRollupTable()
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                if showStoreTable {
                    FiveStarTable(rows: fiveStarRows)
                }
            } else if section == .labor {
                Section {
                    LaborRollupTable()
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                if showStoreTable {
                    LaborTable(rows: laborRows)
                }
            } else if section == .lostRevenue {
                Section {
                    LostRevenueRollupTable()
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                if showStoreTable {
                    LostRevenueTable(rows: lostRevenueRows)
                }
            } else if section == .sales {
                Section {
                    SalesRollupTable()
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                if showStoreTable {
                    SalesTable(rows: snapshots)
                }
            } else if section == .missingItems || section == .preSubOOS {
                Section {
                    MissingItemsRollupTable(depts: visibleMIDepts, pageWidth: pageWidth, section: section)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                if showStoreTable {
                    MissingItemsTable(rows: missingItemsRows, depts: visibleMIDepts, pageWidth: pageWidth, section: section)
                    if section == .preSubOOS {
                        PreSubItemTable(rows: store.seatRows(for: .preSubOOSItem), pageWidth: pageWidth)
                    }
                }
            } else if showStoreTable {
                StoreTable(section: section, rows: snapshots)
            }
            }
            }
            .listStyle(.plain)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 1)
            .transaction { $0.animation = nil }
            .background {
                if sizeClass == .regular {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: LaborListTopKey.self,
                            value: geo.frame(in: .global).minY
                        )
                    }
                }
            }
            .onPreferenceChange(LaborHeaderMinYKey.self) { minY in
                guard sizeClass == .regular else { return }
                laborHeaderPin.updatePin(headerMinY: minY)
            }
            .overlay(alignment: .top) {
                if showStoreTable, sizeClass == .regular, laborHeaderPin.storesExpanded && laborHeaderPin.pinned {
                    if section == .labor {
                        LaborStickyStoreHeader()
                            .environmentObject(laborHeaderPin)
                    } else if section == .lostRevenue {
                        LostRevenueStickyStoreHeader()
                            .environmentObject(laborHeaderPin)
                    } else if section == .fiveStar {
                        FiveStarStickyStoreHeader()
                            .environmentObject(laborHeaderPin)
                    } else if section == .pickPath {
                        PickPathStickyStoreHeader()
                            .environmentObject(laborHeaderPin)
                    } else if section == .prepNotReady {
                        PrepStickyStoreHeader()
                            .environmentObject(laborHeaderPin)
                    } else if section == .dynacap {
                        DynacapStickyStoreHeader()
                            .environmentObject(laborHeaderPin)
                    } else if section == .scheduleQuality {
                        ScheduleStickyStoreHeader()
                            .environmentObject(laborHeaderPin)
                    } else if section == .pph {
                        PPHStickyStoreHeader()
                            .environmentObject(laborHeaderPin)
                    } else if section == .pickerScorecard {
                        PickerStickyStoreHeader()
                            .environmentObject(laborHeaderPin)
                    }
                }
            }
        }
        .background(AppTheme.bg.ignoresSafeArea(edges: .bottom))
        .environmentObject(laborHeaderPin)
        .readWidth($pageWidth)
        .onPreferenceChange(LaborListTopKey.self) { top in
            laborHeaderPin.listTop = top
        }
        .onAppear {
            armPage()
        }
        .task(id: PulseLaunch.sectionOpenToken(
            visible: router.current,
            pushed: router.pushedSection,
            section: section
        ) + "-\(store.filters.summary)-\(store.seatPaintStamp)") {
            guard PulseLaunch.shouldLoadSection(
                visible: router.current,
                section: section,
                pushed: router.pushedSection
            ) else { return }
            if PulseLaunch.shouldDeferSectionSQLUntilAfterChrome() {
                await Task.yield()
                try? await Task.sleep(nanoseconds: PulseLaunch.pageSectionLoadDelayNanoseconds)
                guard PulseLaunch.shouldLoadSection(
                    visible: self.router.current,
                    section: section,
                    pushed: self.router.pushedSection
                ) else { return }
            }
            await store.ensureSectionLoaded(section)
            if section == .preSubOOS {
                await store.ensureSectionLoaded(.preSubOOSItem)
            }
            if section == .pickPath {
                await store.ensureSectionLoaded(.pickPathPicker)
            }
        }
        .onChange(of: router.current) { _, _ in
            armPage()
        }
        .onChange(of: router.pushedSection) { _, _ in
            armPage()
        }
    }

    private var isActivePage: Bool {
        PulseLaunch.isActiveScorecardPage(
            visible: router.current,
            section: section,
            pushed: router.pushedSection
        )
    }

    private func armPage() {
        if isActivePage {
            if !showTables {
                if PulseLaunch.shouldPaintScorecardTablesAfterChrome() {
                    DispatchQueue.main.async {
                        showTables = true
                    }
                } else {
                    showTables = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [self] in
                guard isActivePage else { return }
                laborHeaderPin.openOnPageEnter()
            }
        } else if PulseLaunch.shouldKeepVisitedScorecardHostsWarm() {
            laborHeaderPin.pinned = false
        } else {
            showTables = false
            laborHeaderPin.rollupExpanded = false
            laborHeaderPin.tableOpen = false
            laborHeaderPin.storesExpanded = false
            laborHeaderPin.pinned = false
        }
    }

    @ViewBuilder
    private var pageIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            CommandCenterSectionHero(card: summary)
            CommandCenterStatusPills(card: summary, flags: store.dashboardFlags(for: section))

            if section == .labor, store.laborNeedsReload() {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.warn)
                    Text("The Labor pack is missing the Power BI Total row, so company tiles cannot match -0.04% Target vs Actual.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.warnSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
            }

            if section == .dynacap, let coverage = store.dynacapCoverageNote() {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.warn)
                    Text(coverage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.warnSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
            }

            if showStoreTable, missingInFile {
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

            if showStoreTable, section == .preSubOOS, snapshots.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.warn)
                    Text("No Pre-Sub OOS rows loaded. The Heartbeat pack should include a Pre-Sub OOS tab (DEPARTMENT_NM + STORE_ID). Do not use the 5 Star Pre-Sub column — that is a different report.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.warnSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
            }

            if section == .labor { LaborWeekFilterBar() }
            if showStoreTable {
                if HubLayout.isPhone(sizeClass) {
                    pageCallouts
                    if section == .missingItems || section == .preSubOOS {
                        MissingItemsCategoryFilter(selected: $miCategories, width: pageWidth)
                    }
                } else if section == .labor {
                    laborStatusTiles
                } else if section == .sales {
                    salesStatusTiles
                } else if section == .lostRevenue {
                    lostRevenueStatusTiles
                } else if section == .missingItems || section == .preSubOOS {
                    missingItemsStatusTiles
                    MissingItemsCategoryFilter(selected: $miCategories, width: pageWidth)
                } else {
                    pageCallouts
                }
            }
        }
    }

    @ViewBuilder
    private var pageCallouts: some View {
        switch section {
        case .pph:
            HubCalloutGrid(width: pageWidth, count: 4) { pphStatusTiles }
        case .pickPath, .pickPathPicker:
            HubCalloutGrid(width: pageWidth, count: 4) { pickPathStatusTiles }
        case .dynacap:
            HubCalloutGrid(width: pageWidth, count: 5) { dynacapStatusTiles }
        case .scheduleQuality:
            HubCalloutGrid(width: pageWidth, count: 5) { scheduleStatusTiles }
        case .fiveStar:
            HubCalloutGrid(width: pageWidth, count: 10) { fiveStarStatusTiles }
        case .prepNotReady:
            HubCalloutGrid(width: pageWidth, count: 4) { prepStatusTiles }
        case .pickerScorecard:
            HubCalloutGrid(width: pageWidth, count: 4) { pickerStatusTiles }
        case .labor:
            laborStatusTiles
        case .sales:
            salesStatusTiles
        case .lostRevenue:
            lostRevenueStatusTiles
        case .missingItems, .preSubOOS:
            missingItemsStatusTiles
        default:
            EmptyView()
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
                ("Staffing %", HeartbeatFormat.pct(avg("staffing_efficiency_pct"))),
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
        case .sales:
            let dollars = rows.compactMap { $0.number("sales_dollars") }.reduce(0, +)
            let orders = rows.compactMap { $0.number("sales_orders") }.reduce(0, +)
            return [
                ("eComm sales", HeartbeatFormat.money(dollars)),
                ("Orders", HeartbeatFormat.num(orders, digits: 0)),
                ("AOV", HeartbeatFormat.money(orders > 0 ? dollars / orders : nil)),
            ]
        case .missingItems, .preSubOOS:
            let healthy = rows.filter { HeartbeatMath.missingItemsHealth($0) == .good }.count
            let watch = rows.filter { HeartbeatMath.missingItemsHealth($0) == .watch }.count
            let risk = rows.filter { HeartbeatMath.missingItemsHealth($0) == .risk }.count
            return [
                ("Goal", "5%"),
                ("Healthy", HeartbeatFormat.num(Double(healthy))),
                ("Watch", HeartbeatFormat.num(Double(watch))),
                ("At risk", HeartbeatFormat.num(Double(risk))),
            ]
        case .aisleMapper:
            return [
                ("Mapper", "Latest map"),
                ("Sequence", "Latest sequence"),
            ]
        case .preSubOOSItem:
            return [
                ("Items", HeartbeatFormat.num(Double(rows.count))),
                ("Units", HeartbeatFormat.num(rows.compactMap { $0.number("presub_count") }.reduce(0, +), digits: 0)),
            ]
        case .storeRoster:
            return [
                ("Stores", HeartbeatFormat.num(Double(rows.count))),
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
        let joined = snapshots
        switch fiveStarFocus {
        case .all:
            return joined
        case .atFive:
            return joined.filter { ($0.number("star_rating") ?? 0) >= 4.95 }
        case .pass:
            return joined.filter { ($0.number("star_rating") ?? 0) >= HeartbeatMath.fiveStarPass }
        case .fail:
            return joined.filter { ($0.number("star_rating") ?? .greatestFiniteMagnitude) < HeartbeatMath.fiveStarPass }
        case .flash:
            return joined.filter { HeartbeatMath.flashStar($0).health != .good }
        case .presub:
            return joined.filter { HeartbeatMath.presubStar($0).health != .good }
        case .coe:
            return joined.filter { HeartbeatMath.coeStar($0).health != .good }
        case .ott:
            return joined.filter { HeartbeatMath.ottStar($0).health != .good }
        case .oth:
            return joined.filter { HeartbeatMath.othStar($0).health != .good }
        }
    }

    private var laborRows: [MetricRow] {
        let joined = store.rosterJoined(for: .labor)
        switch laborFocus {
        case .all:
            return joined
        case .healthy:
            return joined.filter { ($0.number("target_vs_actual_pct") ?? 1) <= 0 }
        case .watch:
            return joined.filter {
                let value = $0.number("target_vs_actual_pct") ?? 0
                return value > 0 && value <= HeartbeatMath.laborWatch
            }
        case .risk:
            return joined.filter { ($0.number("target_vs_actual_pct") ?? 0) > HeartbeatMath.laborWatch }
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

    private var visibleMIDepts: [MissingItemDept] {
        MissingItemDept.visible(from: miCategories)
    }

    private var missingItemsRows: [MetricRow] {
        let scored = snapshots.filter { !$0.storeNumber.isEmpty }
        switch missingItemsFocus {
        case .all:
            return scored
        case .healthy:
            return scored.filter { HeartbeatMath.missingItemsHealth($0) == .good }
        case .watch:
            return scored.filter { HeartbeatMath.missingItemsHealth($0) == .watch }
        case .risk:
            return scored.filter { HeartbeatMath.missingItemsHealth($0) == .risk }
        }
    }

    private var prepRows: [MetricRow] {
        let joined = store.rosterJoined(for: .prepNotReady)
        switch prepFocus {
        case .all:
            return joined
        case .atGoal:
            return joined.filter { ($0.number("pnr_rate_pct") ?? .greatestFiniteMagnitude) <= HeartbeatMath.pnrGoal }
        case .above25:
            return joined.filter { ($0.number("pnr_rate_pct") ?? 0) > HeartbeatMath.pnrWatch }
        }
    }

    private var scheduleRows: [MetricRow] {
        let joined = snapshots
        switch scheduleFocus {
        case .all:
            return joined
        case .atGoal:
            return joined.filter { ($0.number("schedule_efficiency_pct") ?? 0) >= HeartbeatMath.scheduleGoal }
        case .underRisk:
            return joined.filter { ($0.number("under_schedule_pct", "under_scheduled") ?? 0) > HeartbeatMath.scheduleVarianceWatch }
        case .overRisk:
            return joined.filter { ($0.number("over_schedule_pct", "over_scheduled") ?? 0) > HeartbeatMath.scheduleVarianceWatch }
        }
    }

    private var pphRows: [MetricRow] {
        let joined = snapshots
        switch pphFocus {
        case .all:
            return joined
        case .atGoal:
            return joined.filter { ($0.number("pph") ?? 0) >= HeartbeatMath.pphGoal }
        case .below74:
            return joined.filter { ($0.number("pph") ?? .greatestFiniteMagnitude) < HeartbeatMath.pphRisk }
        }
    }

    private var dynacapRows: [MetricRow] {
        let joined = snapshots
        switch dynacapFocus {
        case .all:
            return joined
        case .atGoal:
            return joined.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? 0) >= HeartbeatMath.dynacapGoal }
        case .below60:
            return joined.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? .greatestFiniteMagnitude) < HeartbeatMath.dynacapRisk }
        }
    }

    @ViewBuilder
    private var pphStatusTiles: some View {
        let rows = snapshots
        let atGoal = rows.filter { (HeartbeatMath.pphNumber($0) ?? 0) >= HeartbeatMath.pphGoal }.count
        let atRisk = rows.filter { (HeartbeatMath.pphNumber($0) ?? .greatestFiniteMagnitude) < HeartbeatMath.pphRisk }.count
        callout("Week Pure PPH", summary.headlineText, "Goal 80 · watch under 74", summary.health, selected: pphFocus == .all) {
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
    private var salesStatusTiles: some View {
        let rows = snapshots.filter { !$0.storeNumber.isEmpty }
        let sales = rows.compactMap { $0.number("sales_dollars") }.reduce(0, +)
        let orders = rows.compactMap { $0.number("sales_orders") }.reduce(0, +)
        let up = rows.filter { HeartbeatMath.salesHealth($0) == .good }.count
        let flat = rows.filter { HeartbeatMath.salesHealth($0) == .watch }.count
        let down = rows.filter { HeartbeatMath.salesHealth($0) == .risk }.count
        HubCalloutGrid(width: pageWidth, count: 7) {
            callout("eComm sales", HeartbeatFormat.money(rows.isEmpty ? nil : sales), "In this filter", summary.health)
            callout("Healthy", HeartbeatFormat.num(Double(up)), "Sales YoY over 0%", .good, unit: "stores")
            callout("Watch", HeartbeatFormat.num(Double(flat)), "Flat YoY", flat == 0 ? .good : .watch, unit: "stores")
            callout("At Risk", HeartbeatFormat.num(Double(down)), "Sales YoY below 0%", down == 0 ? .good : .risk, unit: "stores")
            callout("Orders", HeartbeatFormat.num(orders, digits: 0), "DUG + Home Delivery", .none, brand: true)
            callout("AOS", HeartbeatFormat.money(orders > 0 ? sales / orders : nil), "Average order size", .none, brand: true)
            callout("Stores", HeartbeatFormat.num(Double(rows.count)), "With sales this week", .none)
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
        let pool: [MetricRow] = {
            if store.filters.isActive { return rows }
            if let market = store.lostRevenueMarketRow() { return rows + [market] }
            return rows
        }()
        let sales: Double? = {
            let value = HeartbeatMath.lostRevenueTODollars(pool, key: "ecomm_sales")
            return rows.isEmpty && HeartbeatMath.lostRevenueMarketRow(in: pool) == nil ? nil : value
        }()
        let goalPct = HeartbeatMath.lostRevenueGoalPct(rows: rows, market: store.filters.isActive ? nil : store.lostRevenueMarketRow())
        let post = HeartbeatMath.lostRevenueTODollars(pool, key: "post_sub_oos_foregone")
        HubCalloutGrid(width: pageWidth, count: 8) {
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
            callout("Lost revenue %", HeartbeatFormat.pct(pct), "Total Opportunity", summary.health)
            callout("eComm sales", HeartbeatFormat.money(sales), "In this filter", .none, brand: true)
            callout("FY2026 Goal", HeartbeatFormat.pct(goalPct), "Lost revenue goal", .none, brand: true)
            callout("Post Sub OOS", HeartbeatFormat.money(rows.isEmpty ? nil : post), "Foregone revenue", .none)
        }
    }

    @ViewBuilder
    private var missingItemsStatusTiles: some View {
        let rows = snapshots.filter { !$0.storeNumber.isEmpty }
        let healthy = rows.filter { HeartbeatMath.missingItemsHealth($0) == .good }.count
        let watch = rows.filter { HeartbeatMath.missingItemsHealth($0) == .watch }.count
        let risk = rows.filter { HeartbeatMath.missingItemsHealth($0) == .risk }.count
        HubCalloutGrid(width: pageWidth, count: 7) {
            callout(section == .preSubOOS ? "Avg Pre-Sub OOS" : "Avg missing items", summary.headlineText, "5% healthy · 5.01–6.50% watch · over 6.50% at risk", summary.health, selected: missingItemsFocus == .all) {
                missingItemsFocus = .all
            }
            callout("Healthy", HeartbeatFormat.num(Double(healthy)), "5% or less", .good, unit: "stores", selected: missingItemsFocus == .healthy) {
                missingItemsFocus = .healthy
            }
            callout("Watch", HeartbeatFormat.num(Double(watch)), "5.01% to 6.50%", watch == 0 ? .good : .watch, unit: "stores", selected: missingItemsFocus == .watch) {
                missingItemsFocus = .watch
            }
            callout("At Risk", HeartbeatFormat.num(Double(risk)), "Stores over 6.50%", risk == 0 ? .good : .risk, unit: "stores", selected: missingItemsFocus == .risk) {
                missingItemsFocus = .risk
            }
            callout("Goal", "5%", "Or less is healthy", .none, brand: true)
            callout("Watch band", "5.01–6.50%", "Needs a look", .watch)
            callout("At risk band", "> 6.50%", section == .preSubOOS ? "Pre-substitution out of stock" : "Items without an aisle tag", .risk)
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
        VStack(spacing: 10) {
            HubCalloutGrid(width: pageWidth, count: 4) {
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
        pickerTile(.healthy, health: .good)
        pickerTile(.watchList, health: store.pickerCount(for: .watchList) == 0 ? .good : .watch)
        pickerTile(.riskList, health: store.pickerCount(for: .riskList) == 0 ? .good : .risk)
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
        PickerFocusTile(title: title, value: value, detail: detail, health: health, selected: selected, brand: brand, unit: unit, action: action)
    }

    private func pickerTileDetail(_ focus: PickerFocus) -> String {
        switch focus {
        case .all: return "Every shopper in this filter"
        case .healthy: return "Hitting the metric mix"
        case .watchList: return "Close to goal"
        case .riskList: return "Below goal"
        case .opportunity: return "Underperforming vs the metric mix"
        case .strong: return "Hitting the metric mix"
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

struct HubCalloutGrid<Content: View>: View {
    var width: CGFloat
    var count: Int
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ViewBuilder var content: Content

    var body: some View {
        let columns = HubLayout.calloutColumns(count: count, width: width, sizeClass: sizeClass)
        let phone = HubLayout.isPhone(sizeClass)
        let tileMin = HubLayout.calloutTileMinWidth(columns: columns, width: width, phone: phone)
        LazyVGrid(
            columns: HubLayout.grid(columns, spacing: HubLayout.calloutGridSpacing, minWidth: tileMin),
            spacing: HubLayout.calloutGridSpacing
        ) {
            content
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
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var phone: Bool { HubLayout.isPhone(sizeClass) }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { tile }
                    .buttonStyle(CalloutLiftStyle())
            } else {
                tile
            }
        }
        .frame(maxWidth: .infinity, minHeight: HubLayout.calloutMinHeight(phone: phone))
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 6) {
                Text(title)
                    .font(AppTheme.rounded(phone ? .subheadline : .headline, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if health != .none {
                    HealthBadge(health: health, prominent: true, compact: true)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: HubLayout.calloutValueSize(phone: phone), weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let unit, !unit.isEmpty {
                    Text(unit)
                        .font(AppTheme.rounded(phone ? .caption : .subheadline, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: phone ? 22 : 26, alignment: .bottomLeading)
            Text(detail)
                .font(AppTheme.rounded(.caption, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(phone ? 10 : 11)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(wash.opacity(0.42))
                }
        }
        .overlay(alignment: .leading) {
            Capsule()
                .fill(stripe)
                .frame(width: 4)
                .padding(.vertical, 10)
        }
        .overlay {
            if shouldPulse && !selected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255), lineWidth: 2)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(stroke, lineWidth: selected ? 2 : 1)
            }
        }
        .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
    }

    private var shouldPulse: Bool { health == .risk }

    private var wash: Color {
        if brand { return AppTheme.blueSoft }
        switch health {
        case .good: return AppTheme.okSoft
        case .watch: return AppTheme.warnSoft
        case .risk: return AppTheme.badSoft
        case .none: return selected ? AppTheme.blueSoft : Color.clear
        }
    }

    private var stripe: Color {
        if selected { return AppTheme.blue }
        if brand { return AppTheme.blue }
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.blue.opacity(0.35)
        }
    }

    private var stroke: Color {
        if selected { return AppTheme.blue }
        if brand { return AppTheme.blue.opacity(0.35) }
        switch health {
        case .good: return Color.black.opacity(0.05)
        case .watch: return AppTheme.warn.opacity(0.35)
        case .risk: return AppTheme.bad
        case .none: return Color.black.opacity(0.05)
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

private struct CalloutLiftStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

#Preview {
    SectionDetailView(section: .fiveStar)
        .environmentObject(HeartbeatStore())
        .environmentObject(HubRouter())
}
