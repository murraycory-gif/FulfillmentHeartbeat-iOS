import SwiftUI

/// iPhone + iPad first-principles seat shell. Mac never mounts this.
struct SeatHubView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @StateObject private var router = HubRouter()

    var body: some View {
        NavigationStack {
            SeatPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .top, spacing: 0) {
                    SeatChromeBanner()
                        .environmentObject(store)
                        .environmentObject(router)
                }
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(removing: .sidebarToggle)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("")
        }
        .environmentObject(router)
        .sheet(isPresented: $router.showShare) {
            SharePulseSheet()
                .environmentObject(store)
                .environmentObject(router)
        }
        .onAppear {
            store.setVisibleDestination(.dashboard)
        }
        .onChange(of: store.needsRolePick) { _, needs in
            if !needs {
                store.setVisibleDestination(.dashboard)
            }
        }
        .overlay {
            if store.isImporting {
                ImportProgressCard(progress: store.importProgress)
            }
        }
    }
}

/// Memo v3 banner: Clear + tappable crumb only.
/// Soft FAIL Share / sibling pills / FilterSheet / Assist in this chrome.
struct SeatChromeBanner: View {
    @EnvironmentObject private var store: HeartbeatStore

    var body: some View {
        let _ = store.filters.summary
        HStack(spacing: 8) {
            Button("Clear") { applySeat(DashboardFilters()) }
                .font(.body.weight(.semibold))
                .foregroundStyle(store.filters.isActive ? AppTheme.blue : AppTheme.textTertiary)
                .frame(minWidth: HubLayout.phoneHitTarget, minHeight: HubLayout.phoneHitTarget)
                .disabled(!store.filters.isActive)
                .accessibilityLabel("Clear seat filters")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(
                        Array(PulseLaunch.seatSwitcherCrumbs(filters: store.filters).enumerated()),
                        id: \.offset
                    ) { index, crumb in
                        if index > 0 {
                            Text("›")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        Button(crumb.title) {
                            applySeat(PulseLaunch.popSeatFilters(current: store.filters, to: crumb.seat))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(minHeight: HubLayout.phoneHitTarget)
                        .accessibilityLabel("Switch to \(crumb.title)")
                    }
                }
            }
            .accessibilityLabel("Instant seat switcher")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.bg.ignoresSafeArea(edges: .top))
    }

    private func applySeat(_ next: DashboardFilters) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            if next.isActive {
                store.commitFilters(next)
            } else {
                store.clearFilters()
            }
        }
    }
}

/// Banner → seat identity → KPI scoreboard → child tables → Store pickers.
struct SeatPageView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @State private var pageWidth: CGFloat = 390
    @State private var storeLimit = 40
    @State private var pickerLimit = 24
    @State private var openShopper: String?
    @State private var showHeavy = false

    private var seat: PulseLaunch.SectionPageSeat {
        PulseLaunch.sectionPageSeat(filters: store.filters)
    }

    private var padCanvas: Bool { !HubLayout.isPhoneDevice }

    private var visibleScoreboardSections: [MetricSection] {
        if PulseLaunch.shouldPaintAllSeatKPIsAtAGlance() {
            return PulseLaunch.seatGlanceKPISections()
        }
        if PulseLaunch.shouldMountEverySeatMetricHostAtOnce() || showHeavy {
            return PulseLaunch.seatPageMetricSections()
        }
        return PulseLaunch.seatPageChromeSections()
    }

    private var glanceCards: [SectionSummary] {
        PulseLaunch.seatGlanceKPISections().map { section in
            store.paintedCommandCenterCard(store.summary(for: section))
        }
    }

    var body: some View {
        let _ = store.seatPaintStamp
        let _ = store.filters.summary
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                seatTitle
                scoreboard
                if showHeavy {
                    childTables
                    if PulseLaunch.shouldShowPickersOnSeatPage(filters: store.filters),
                       !PulseLaunch.shouldLoadFatCompanyPickers() {
                        storePickerBlock
                    }
                }
                stamp
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(PulseLaunch.shouldOfferPullToRefreshSeatPack() ? .always : .basedOnSize)
        .hubSeatPackRefreshable()
        .background(AppTheme.bg)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: HubWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(HubWidthKey.self) { value in
            if value > 0 { pageWidth = value }
        }
        .onAppear { armHeavy() }
        .onChange(of: store.filters.summary) { _, _ in
            showHeavy = false
            armHeavy()
        }
        .task(id: "\(store.filters.summary)|\(store.seatPaintStamp)|\(showHeavy)") {
            guard showHeavy else { return }
            await store.ensureSectionLoaded(.sales)
            guard PulseLaunch.shouldShowPickersOnSeatPage(filters: store.filters) else { return }
            guard !PulseLaunch.shouldLoadFatCompanyPickers() else { return }
            await store.ensureSectionLoaded(.pickerScorecard)
            await store.ensureSectionLoaded(.pickPathPicker)
        }
    }

    private var seatTitle: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(PulseLaunch.seatBannerTitle(filters: store.filters))
                .font(AppTheme.rounded(.title, weight: .bold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Text(PulseLaunch.seatLevelChip(seat))
                .font(.caption.weight(.heavy))
                .tracking(0.4)
                .foregroundStyle(AppTheme.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.blueSoft, in: Capsule(style: .continuous))
            Spacer(minLength: 0)
        }
    }

    private var scoreboard: some View {
        let cols = PulseLaunch.seatScoreboardColumns(width: pageWidth, pad: padCanvas)
        let cards = glanceCards
        let action = PulseLaunch.shouldShowSeatActionableStrip()
            ? PulseLaunch.seatActionableStripLine(cards)
            : ""
        let worst = PulseLaunch.seatActionableCards(cards).first.map {
            CommandCenterLayout.displayedHealth($0)
        } ?? .risk
        return VStack(alignment: .leading, spacing: 10) {
            SeatBlockHeading(title: "Scoreboard")
            if !action.isEmpty {
                Text(action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.healthInk(worst))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Actionable KPIs, \(action)")
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: cols),
                spacing: 10
            ) {
                ForEach(visibleScoreboardSections, id: \.self) { section in
                    SeatScoreTile(section: section)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Executive KPI scoreboard")
    }

    @ViewBuilder
    private var childTables: some View {
        let grains = PulseLaunch.sectionRollupGrains(filters: store.filters)
        ForEach(grains, id: \.self) { grain in
            childGrainTable(grain)
        }
        if PulseLaunch.shouldShowStoreTable(filters: store.filters) {
            storeChildTable
        }
    }

    @ViewBuilder
    private func childGrainTable(_ grain: DashScopeGrain) -> some View {
        let rows = salesRows(for: grain)
        VStack(alignment: .leading, spacing: 8) {
            SeatBlockHeading(title: grain.title)
            if rows.isEmpty {
                PhoneScorecardRow(
                    title: "No \(grain.unit) in this seat",
                    subtitle: "Adjust filters or wait for the Heartbeat pack.",
                    health: .none
                )
            } else {
                ForEach(rows) { row in
                    Button {
                        drill(grain: grain, rawLabel: row.label)
                    } label: {
                        OverviewSalesPhoneCard(
                            label: HeartbeatMath.displayGrainLabel(row.label),
                            count: grain == .store ? nil : row.storeCount,
                            pack: row.pack
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var storeChildTable: some View {
        let all = storeRows
        VStack(alignment: .leading, spacing: 8) {
            SeatBlockHeading(title: seat == .store ? "Store detail" : "Stores · \(all.count)")
            if all.isEmpty {
                PhoneScorecardRow(
                    title: "No stores in this view",
                    subtitle: "Adjust filters or wait for the Heartbeat pack.",
                    health: .none
                )
            } else {
                ForEach(Array(all.prefix(storeLimit))) { row in
                    storeChildRow(row)
                }
                if all.count > storeLimit {
                    Button {
                        storeLimit += 40
                    } label: {
                        Text("Show more · \(storeLimit) of \(all.count)")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                            .frame(maxWidth: .infinity, minHeight: HubLayout.phoneHitTarget, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func storeChildRow(_ row: MetricRow) -> some View {
        let pack = SalesPack(rows: [row])
        let number = HeartbeatMath.canonicalStore(row.storeNumber)
        return Button {
            guard seat != .store else { return }
            drill(grain: .store, rawLabel: number)
        } label: {
            OverviewSalesPhoneCard(
                label: HeartbeatMath.storeDisplayLabel(row),
                count: nil,
                pack: pack
            )
        }
        .buttonStyle(.plain)
        .disabled(seat == .store)
    }

    @ViewBuilder
    private var storePickerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SeatBlockHeading(title: "Shoppers · LDAP")
            PickerHighlightsPanel(
                showPictures: PulseLaunch.shouldShowPickerIndividualPictures(filters: store.filters)
            )
            pickerShoppers
        }
    }

    @ViewBuilder
    private var pickerShoppers: some View {
        let rows = store.pickerPage(focus: .all, sort: .pph, ascending: false, limit: pickerLimit)
        let total = store.pickerCount(for: .all)
        if rows.isEmpty {
            PhoneScorecardRow(
                title: store.pickerLoading ? "Loading shoppers…" : "No shoppers in this store",
                subtitle: "Shoppers fill from the Heartbeat pack after ready.",
                health: .none
            )
        } else {
            ForEach(rows) { row in
                PickerPhoneCard(
                    snap: PickerLineSnap(row, division: row.division.isEmpty ? "Store" : row.division),
                    expanded: openShopper == row.id.uuidString,
                    onToggle: {
                        openShopper = openShopper == row.id.uuidString ? nil : row.id.uuidString
                    }
                )
            }
            if total > pickerLimit {
                Button {
                    pickerLimit += 24
                } label: {
                    Text("Show more · \(pickerLimit) of \(total)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(maxWidth: .infinity, minHeight: HubLayout.phoneHitTarget, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stamp: some View {
        HStack(spacing: 12) {
            if store.shareReady {
                Button("Share") {
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        router.showShare = true
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
                .frame(minHeight: HubLayout.phoneHitTarget)
                .buttonStyle(.plain)
            }
            Text(BuildStamp.label)
                .font(.caption2.weight(.semibold).monospaced())
                .foregroundStyle(AppTheme.textTertiary)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Build \(BuildStamp.label)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(AppTheme.card, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
        .padding(.top, 8)
    }

    private func salesRows(for grain: DashScopeGrain) -> [SalesRollupRow] {
        var rows = SalesRollupBuilder.rows(
            from: store.rollupStores(for: .sales),
            grain: LaborRollupGrain(grain)
        )
        rows.removeAll { RollupMarketFill.hidesUnassignedMarket($0.label) }
        return rows
    }

    private var storeRows: [MetricRow] {
        store.seatRows(for: .sales).filter { !$0.storeNumber.isEmpty }
    }

    private func armHeavy() {
        if !PulseLaunch.shouldDeferSeatPageHeavyUntilAfterChrome() {
            showHeavy = true
            return
        }
        DispatchQueue.main.async {
            showHeavy = true
        }
    }

    private func drill(grain: DashScopeGrain, rawLabel: String) {
        let next = PulseLaunch.drillSeatFilters(
            current: store.filters,
            grain: grain,
            rawLabel: rawLabel
        )
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            store.commitFilters(next)
        }
    }
}

/// Label over value, big type, status/delta. Soft FAIL badges, symbols, charts.
struct SeatScoreTile: View {
    @EnvironmentObject private var store: HeartbeatStore
    let section: MetricSection

    private var painted: SectionSummary {
        store.paintedCommandCenterCard(store.summary(for: section))
    }

    var body: some View {
        let health = CommandCenterLayout.displayedHealth(painted)
        let action = PulseLaunch.shouldUseSeatKPIStatusDelta()
            ? PulseLaunch.seatKPIActionLine(painted)
            : ""
        VStack(alignment: .leading, spacing: 4) {
            Text(CommandCenterLayout.glanceTitle(section).uppercased())
                .font(.caption.weight(.heavy))
                .tracking(0.5)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
            Text(CommandCenterLayout.compactValue(painted))
                .font(AppTheme.rounded(size: 28, weight: .bold).monospacedDigit())
                .foregroundStyle(AppTheme.healthInk(health == .none ? .good : health))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if !action.isEmpty {
                Text(action)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.healthInk(health))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(CommandCenterLayout.glanceTitle(section)), \(CommandCenterLayout.compactValue(painted)), \(action)"
        )
    }
}

private struct SeatBlockHeading: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppTheme.rounded(.caption, weight: .heavy))
            .tracking(0.7)
            .foregroundStyle(AppTheme.textTertiary)
    }
}

#Preview {
    SeatHubView()
        .environmentObject(HeartbeatStore())
}
