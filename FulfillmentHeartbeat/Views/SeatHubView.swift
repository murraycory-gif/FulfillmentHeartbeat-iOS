import SwiftUI

/// iPhone + iPad first-principles seat shell. Mac never mounts this.
struct SeatHubView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @StateObject private var router = HubRouter()
    @State private var showAssist = false

    var body: some View {
        NavigationStack {
            SeatPageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .top, spacing: 0) {
                    SeatChromeBanner(showAssist: $showAssist)
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
        .fullScreenCover(isPresented: $showAssist) {
            HeartbeatAssistSheet()
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

/// Sticky compact banner only: Clear, filter chips, grain crumb.
/// Soft FAIL a second HubBanner / Pages header over the scoreboard.
struct SeatChromeBanner: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Binding var showAssist: Bool
    @State private var sheetFocus: FilterFocus?

    var body: some View {
        let _ = store.filters.summary
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("Clear") { clearNow() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(store.filters.isActive ? AppTheme.blue : AppTheme.textTertiary)
                        .frame(minWidth: HubLayout.phoneHitTarget, minHeight: HubLayout.phoneHitTarget)
                        .disabled(!store.filters.isActive)
                    ForEach(FilterFocus.allCases) { focus in
                        HubChromePill(
                            title: store.filters.chipTitle(for: focus),
                            symbol: focus.symbol,
                            selected: !store.filters.values(for: focus).isEmpty
                        ) {
                            sheetFocus = focus
                        }
                    }
                    HubChromePill(
                        title: store.shareReady ? "Share" : "Share…",
                        symbol: "square.and.arrow.up",
                        showsChevron: false
                    ) {
                        guard store.shareReady else { return }
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            router.showShare = true
                        }
                    }
                    Button {
                        showAssist = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: HubLayout.phoneHitTarget, height: HubLayout.phoneHitTarget)
                            .background(AppTheme.blue, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Heartbeat Assist, build \(BuildStamp.label)")
                }
            }
            Text(PulseLaunch.seatGrainCrumb(filters: store.filters))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.bg.ignoresSafeArea(edges: .top))
        .fullScreenCover(item: $sheetFocus) { focus in
            FilterSheet(initialFocus: focus)
                .environmentObject(store)
        }
    }

    private func clearNow() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            store.clearFilters()
        }
    }
}

/// Banner → title → scoreboard → child tables → Store pickers.
struct SeatPageView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @State private var pageWidth: CGFloat = 390
    @State private var storeLimit = 40
    @State private var pickerLimit = 24
    @State private var openShopper: String?

    private var seat: PulseLaunch.SectionPageSeat {
        PulseLaunch.sectionPageSeat(filters: store.filters)
    }

    private var padCanvas: Bool { !HubLayout.isPhoneDevice }

    var body: some View {
        let _ = store.seatPaintStamp
        let _ = store.filters.summary
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                seatTitle
                scoreboard
                childTables
                if PulseLaunch.shouldShowPickersOnSeatPage(filters: store.filters) {
                    storePickerBlock
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
        .task(id: "\(store.filters.summary)|\(store.seatPaintStamp)") {
            await store.ensureSectionLoaded(.sales)
            if PulseLaunch.shouldShowPickersOnSeatPage(filters: store.filters) {
                await store.ensureSectionLoaded(.pickerScorecard)
                await store.ensureSectionLoaded(.pickPathPicker)
            }
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
        return VStack(alignment: .leading, spacing: 10) {
            SeatBlockHeading(title: "Scoreboard")
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: cols),
                spacing: 10
            ) {
                ForEach(PulseLaunch.seatPageMetricSections(), id: \.self) { section in
                    SeatScoreTile(section: section)
                }
            }
        }
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
        Text(BuildStamp.label)
            .font(.caption2.weight(.semibold).monospaced())
            .foregroundStyle(AppTheme.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(AppTheme.card, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
            .padding(.top, 8)
            .accessibilityLabel("Build \(BuildStamp.label)")
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

/// Label over value. Not a section destination.
struct SeatScoreTile: View {
    @EnvironmentObject private var store: HeartbeatStore
    let section: MetricSection

    private var painted: SectionSummary {
        store.paintedCommandCenterCard(store.summary(for: section))
    }

    var body: some View {
        let health = CommandCenterLayout.displayedHealth(painted)
        VStack(alignment: .leading, spacing: 6) {
            Text(CommandCenterLayout.glanceTitle(section).uppercased())
                .font(.caption.weight(.heavy))
                .tracking(0.5)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
            Text(CommandCenterLayout.compactValue(painted))
                .font(AppTheme.rounded(.title, weight: .bold).monospacedDigit())
                .foregroundStyle(AppTheme.healthInk(health == .none ? .good : health))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            HealthBadge(health: health, prominent: true, compact: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(CommandCenterLayout.glanceTitle(section)), \(CommandCenterLayout.compactValue(painted))")
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
