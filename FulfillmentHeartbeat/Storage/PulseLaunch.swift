import Foundation

/// Launch and refresh rules for the on-device SQLite pack.
/// Keep this off the network and off SwiftUI so the boot path can be tested.
enum PulseLaunch {
    static let minimumPackBytes = 50_000
    static let stagingFileName = "heartbeat-cloud.sqlite"
    static let bootDownloadTimeout: TimeInterval = 25
    /// Let the hub settle before expanding grains. Cards already painted.
    static let grainPaintDelayNanoseconds: UInt64 = 2_800_000_000
    /// First scroll / nav after Dashboard lands must not fight pack/grain/picker work.
    static let hubFirstInteractionNanoseconds: UInt64 = 1_200_000_000
    /// Stream shoppers after splash so the dashboard card fills. Never on splash.
    static let streamPickerAfterReady = true
    /// After ready, first chunk only — do not await the rest of the pack.
    static let streamPickerSnappyAfterReady = true
    /// Shopper SQL stays off Dashboard. Streaming the full pack after ready
    /// plus per-store `sameStore` scans Jetsamed ~5GB on iPad (build 672).
    static func shouldStreamPickerOnDashboard() -> Bool { false }
    /// Hard cap so a join-page stream cannot grow without bound.
    static let pickerWarehouseCap = 4_000
    /// Do not start shopper streaming until Who's looking is done and the hub can scroll.
    static func shouldDeferPickerStreamUntilHubQuiet() -> Bool { true }
    /// Expand-table prefetch waits so it cannot steal the first scroll/nav turn.
    static func shouldDeferGrainTablesUntilHubQuiet() -> Bool { true }
    static let loadPageOnlyOnReady = false
    /// First shoppers so Picker / dashboard paint before the rest of the pack.
    static let pickerFirstPaintCount = 80
    static let pickerChunkCount = 250
    static let pickerUIStampStride = 800
    /// Yield so post-ready streaming cannot peg the CPU.
    static let pickerChunkPauseNanoseconds: UInt64 = 120_000_000

    /// Pages that join shopper rows into store tables after the pack is ready.
    static func needsShopperJoin(_ dest: HubDestination) -> Bool {
        dest == .pickerScorecard || dest == .pph || dest == .dynacap || dest == .pickPath
    }

    static func shouldStampPicker(
        replace: Bool,
        dest: HubDestination,
        count: Int,
        lastStampCount: Int
    ) -> Bool {
        guard needsShopperJoin(dest) else { return false }
        if replace { return true }
        return count - lastStampCount >= pickerUIStampStride
    }

    /// Heavy picker chrome only on join pages. Dashboard parks the warehouse without a SwiftUI stamp.
    static func shouldRefreshPickerChrome(replace: Bool, dest: HubDestination, stamp: Bool) -> Bool {
        guard needsShopperJoin(dest) else { return false }
        return replace || stamp
    }

    /// Skip SwiftUI / filterStamp work when a background chunk has nothing new to show.
    static func shouldTouchPickerUI(stamp: Bool, chrome: Bool) -> Bool {
        stamp || chrome
    }

    static func pickerRowKey(_ row: MetricRow) -> String {
        "\(row.storeNumber)|\(HeartbeatMath.canonicalShopper(row.shopperKey))"
    }

    static func mergePickerRows(existing: [MetricRow], incoming: [MetricRow]) -> [MetricRow] {
        guard !existing.isEmpty else { return incoming }
        guard !incoming.isEmpty else { return existing }
        var map: [String: MetricRow] = [:]
        map.reserveCapacity(existing.count + incoming.count)
        for row in existing {
            map[pickerRowKey(row)] = row
        }
        for row in incoming {
            map[pickerRowKey(row)] = row
        }
        return Array(map.values)
    }

    struct PPHPickerIndex: Equatable {
        var rows: [String: [MetricRow]] = [:]
        var counts: [String: Int] = [:]
    }

    /// One pass over shoppers. Keys include store aliases so "304" / "0304" hit the same bucket.
    static func pphPickerIndex(_ scorecard: [MetricRow]) -> PPHPickerIndex {
        var canonical: [String: [MetricRow]] = [:]
        canonical.reserveCapacity(min(scorecard.count, 2_048))
        for row in scorecard where row.number("pph") != nil {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            canonical[store, default: []].append(row)
        }
        var rows: [String: [MetricRow]] = [:]
        var counts: [String: Int] = [:]
        let aliases = canonical.count * 4
        rows.reserveCapacity(aliases)
        counts.reserveCapacity(aliases)
        for (store, group) in canonical {
            let n = group.count
            for alias in HeartbeatMath.storeAliases(store) {
                rows[alias] = group
                counts[alias] = n
            }
        }
        return PPHPickerIndex(rows: rows, counts: counts)
    }

    /// O(1). Missing key is 0 — never scan the shopper pack on the UI path.
    static func pphPickerCount(store: String, counts: [String: Int]) -> Int {
        let want = HeartbeatMath.canonicalStore(store)
        if want.isEmpty { return 0 }
        return counts[want] ?? counts[store] ?? 0
    }

    /// Sum O(1) lookups. Used by PPH rollup so body/rebuild never calls `pphPickers`.
    static func pphPickerTotal(storeNumbers: [String], counts: [String: Int]) -> Int {
        var total = 0
        for store in storeNumbers {
            total += pphPickerCount(store: store, counts: counts)
        }
        return total
    }

    /// Do not restart grain expand just because the user swiped back to Dashboard.
    static func shouldRestartGrainPaint(alreadySettled: Bool, dest: HubDestination) -> Bool {
        dest == .dashboard && !alreadySettled
    }

    static func shopperEmptyDetail(loading: Bool) -> String {
        loading
            ? "Loading shoppers…"
            : "Shoppers fill from the Heartbeat pack after ready."
    }

    /// Drop a paint or grain job when the user picked another filter.
    static func acceptPaint(generation: Int, current: Int, cancelled: Bool) -> Bool {
        !cancelled && generation == current
    }

    static func shouldPaintGrains(dashboardVisible: Bool, ready: Bool, rolePicked: Bool) -> Bool {
        dashboardVisible && ready && rolePicked
    }

    static func shouldRefreshPageOnly(pageVisible: Bool) -> Bool {
        pageVisible
    }

    /// Clear-all must flip pills / filterStamp on the same turn as the tap.
    static func shouldAcknowledgeFilterClearImmediately(previousActive: Bool, nextActive: Bool) -> Bool {
        previousActive && !nextActive
    }

    /// Company-wide chrome is always Regions 4 — never the last seat's store grain.
    static func shouldUseCompanyGrainWhenFiltersClear() -> Bool { true }

    /// Unfiltered pulse / Clear restore must paint East / South / California / West.
    static func unfilteredDashboardGrain() -> DashScopeGrain { .region }

    /// Seat grain only while a filter is on. Clear returns the 4-region book.
    static func dashboardGrain(filters: DashboardFilters, sessionRole: HeartbeatRole?) -> DashScopeGrain {
        if !filters.store.isEmpty || !filters.om.isEmpty || !filters.district.isEmpty {
            return .store
        }
        if !filters.division.isEmpty { return .district }
        if !filters.region.isEmpty { return .division }
        if shouldUseCompanyGrainWhenFiltersClear() { return .region }
        return sessionRole?.dashboardGrain ?? .region
    }

    /// Last-seat pending filters apply once. Clear / a new seat pick must not bounce them back.
    static func shouldDiscardPendingLaunchFiltersOnClear() -> Bool { true }

    static func shouldDiscardPendingLaunchFiltersOnRolePick() -> Bool { true }

    static func consumePendingLaunchFilters(
        pending: DashboardFilters?,
        filtersActive: Bool,
        needsRolePick: Bool
    ) -> (apply: DashboardFilters?, remaining: DashboardFilters?) {
        if needsRolePick { return (nil, pending) }
        guard let pending, pending.isActive else { return (nil, nil) }
        if filtersActive { return (nil, nil) }
        return (pending, nil)
    }

    /// Changing filters can coalesce; clear-all paints with no extra wait.
    static func filterPaintDelayNanoseconds(clearingAll: Bool) -> UInt64 {
        clearingAll ? 0 : 32_000_000
    }

    /// Restore the last company-wide pulse so tables are not stuck on the old filter.
    static func shouldRestoreUnfilteredPulseOnClear(hasCompanyWideCache: Bool) -> Bool {
        hasCompanyWideCache
    }

    /// Sidebar open/close must flip on the tap. Detail width stays put (no dashboard reflow).
    static func shouldAcknowledgeSidebarToggleImmediately() -> Bool { true }

    /// Keep the dashboard at full width while the pages drawer is open.
    static func shouldKeepDetailWidthWhenSidebarOpens() -> Bool { true }

    /// Paint cached banner + callouts on the tap. Do not leave a blank host.
    static func shouldPaintDestinationChromeImmediately() -> Bool { true }

    /// Scorecard store tables wait one turn so the new page's chrome can paint first.
    static func shouldPaintScorecardTablesAfterChrome() -> Bool { true }

    /// Grain paint / picker stream wait until the destination's first paint has committed.
    static func shouldDeferDestinationWorkOnNav() -> Bool { true }

    /// Who's looking is the directed start. Seats stay locked until the warehouse is on the floor.
    static func shouldHoldSeatPickerUntilWarehouseReady() -> Bool { true }

    /// Hub fill banner is for post-seat hydrate only. Who's looking owns the centered load UI.
    static func shouldShowHubFillBanner(needsRolePick: Bool, warehouseHydrating: Bool) -> Bool {
        warehouseHydrating && !needsRolePick
    }

    /// Dashboard under Who's looking must not rebuild on every wave paint.
    static func shouldStampUIDuringRolePick() -> Bool { false }

    /// Who's looking is a full page — never a veil over a live hub.
    /// Overlaying MainHubView kept the pager + dashboard mounted and invalidating
    /// under the picker; that is the lag on the first vertical swipe after Continue.
    static func shouldMountHubUnderRoleGate() -> Bool { false }

    /// Horizontal UIPageViewController wrapping SwiftUI ScrollView fights vertical
    /// drags (nested UIScrollView). Sidebar / page taps still switch via HubRouter.
    static func shouldUsePagingScroll() -> Bool { false }

    /// Remounting every page with `.id` rebuilds the whole List on each sidebar tap.
    static func shouldRemountPageOnDestinationChange() -> Bool { false }

    /// Store row trees stay unbuilt until the chevron opens.
    static func shouldDeferStoreRowBuildUntilExpanded() -> Bool { true }

    /// Expand reads cache/packs only. Never walk the warehouse on the tap turn.
    static func shouldBuildExpandTableOffMain() -> Bool { true }

    /// Filling expand cache must not `filterStamp` the hub.
    static func shouldStampHubWhenExpandCacheFills() -> Bool { false }

    /// Sales Regions/Stores expand uses the sales rollup cache, not grain packs.
    /// Prefetch it with grain tables so the chevron is not headers-only.
    static func shouldPrefetchSalesExpandWithGrainTables() -> Bool { true }

    /// Real $ / orders only. An empty sales cache must not look like "Regions 4".
    static func salesExpandIsLive(_ rows: [SalesRollupRow]) -> Bool {
        rows.contains { ($0.pack.sales ?? 0) > 0 || ($0.pack.orders ?? 0) > 0 }
    }

    /// Chevron / table gate. Never open a header shell over an empty body.
    static func dashboardExpandIsLive(
        section: MetricSection,
        salesRows: [SalesRollupRow],
        grainRows: [HeartbeatMath.DashboardGrainTableRow]
    ) -> Bool {
        if section == .sales { return salesExpandIsLive(salesRows) }
        return HeartbeatMath.grainRowsAreLive(grainRows)
    }

    /// Live expand caches only. Never `packs.count` — `placeholderGrainPacks`
    /// seeds four region lines with value "—" and paints "Regions 4" over headers.
    static func dashboardBannerCount(
        section: MetricSection,
        salesRows: [SalesRollupRow],
        grainRows: [HeartbeatMath.DashboardGrainTableRow]
    ) -> Int {
        guard dashboardExpandIsLive(section: section, salesRows: salesRows, grainRows: grainRows) else {
            return 0
        }
        return section == .sales ? salesRows.count : grainRows.count
    }

    /// Apply the seat filter while Who's looking is still up, then mount the hub
    /// so Continue does not land on a mid-paint dashboard.
    static func shouldRevealHubAfterSeatPaint() -> Bool { true }

    /// Horizontal page swipe must not steal vertical dashboard drags.
    /// Kept for the unused pager path; paging itself is off.
    static func shouldLockPagerScrollDirection() -> Bool { true }

    static var seatLoadTitle: String { "Setting the floor" }

    static var seatLoadDirective: String {
        "Wait until this finishes — then pick a seat."
    }

    /// Neighbor scorecards stay blank. Hydrating them makes filterStamp rebuild two extra full tables.
    static func shouldKeepNeighborPagesHydrated() -> Bool { false }

    /// SQLite / picker stream only for the page the user actually landed on — never mid-swipe.
    static func shouldLoadSection(visible: HubDestination, section: MetricSection) -> Bool {
        if visible == .dashboard { return false }
        if visible.section == section { return true }
        if visible == .preSubOOS, section == .preSubOOSItem { return true }
        if visible == .pickPath, section == .pickPathPicker { return true }
        return false
    }

    /// Picker filterStamp / board rebuild is join-page work. Dashboard already has cards.
    static func shouldRefreshPickersAfterFilter(dest: HubDestination) -> Bool {
        needsShopperJoin(dest)
    }

    /// Do not rebuild the PPH picker index during Dashboard paint — that re-walks shoppers on main.
    static func shouldRebuildPPHIndexDuringPaint(dest: HubDestination) -> Bool {
        needsShopperJoin(dest)
    }

    /// Clear-all already restored company-wide chrome. Do not re-paint the warehouse on that tap.
    static func shouldSkipWarehousePaintOnClear(restoredCompanyWide: Bool) -> Bool {
        restoredCompanyWide
    }

    /// Clear never walks the warehouse again. latestBySection is already company-wide.
    static func shouldPaintWarehouseOnClear() -> Bool { false }

    /// Company-wide region tables must not ride along with a district/store filter.
    static func grainTableMatchesCurrent(labels: [String], grain: DashScopeGrain) -> Bool {
        let regions = Set(MarketRegion.allCases.map(\.rawValue))
        let looksLikeRegions = labels.contains { regions.contains($0) }
        switch grain {
        case .region:
            return looksLikeRegions || labels.isEmpty
        case .division, .district, .store:
            return !looksLikeRegions
        }
    }

    /// Flag tiles from the unfiltered book (1,800 stores) must not appear on a 20-store district page.
    static func flagsMatchFilter(flagStores: [Int], scopedStores: Int) -> Bool {
        guard scopedStores > 0 else { return true }
        let biggest = flagStores.max() ?? 0
        return biggest <= max(scopedStores * 3, scopedStores + 24)
    }

    /// After the hub can scroll, pack I/O and section fill stay utility.
    /// userInitiated is only for a filter the user just saved — not wave 2, not hydrate.
    static func warehousePaintPriority(
        light: Bool,
        hubReady: Bool,
        firstSectionWave: Bool = false,
        filterPaint: Bool = false
    ) -> TaskPriority {
        if filterPaint { return .userInitiated }
        if hubReady { return .utility }
        if firstSectionWave { return .userInitiated }
        return light ? .userInitiated : .utility
    }

    /// SQLite / PulseCaches.build must not steal the first scroll after Who's looking.
    static func warehouseReadPriority(hubInteractive: Bool) -> TaskPriority {
        hubInteractive ? .utility : .userInitiated
    }

    /// Keep scorecard headers on screen while the new filter paint is in flight.
    static func shouldKeepLiveCalloutsUntilFilterPaint() -> Bool { true }

    /// Stamping before paint blanks every onChange(filterStamp) rebuild and remounts pills.
    static func shouldStampFilterBeforePaint() -> Bool { false }

    /// Roster option lists are filter-commit work, not every warehouse paint.
    static func shouldRefreshFilterOptionsOnEveryPaint() -> Bool { false }

    /// Facts / raw tape only when the warehouse is still thin. Never copy the full pack on filter.
    static func shouldPassRawRowsToPaint(needFacts: Bool, warehouseHasScoredStores: Bool) -> Bool {
        needFacts || !warehouseHasScoredStores
    }

    /// Filter slice already has latestBySection. prepareWarehouse overlays fight the Save tap.
    static func shouldPrepareWarehouseOnFilterPaint() -> Bool { false }

    /// Publishing the raw row tape during hydrate invalidates the whole hub on every wave.
    static func shouldPublishWarehouseRowsDuringHydrate() -> Bool { false }

    /// Excel facts adopt after the aisle can scroll — not on the wave-2 paint the user is dragging through.
    static func shouldAdoptFactsDuringInteractivePaint() -> Bool { false }

    /// Light filter paint still needs flag tiles so callout boxes are not empty headers.
    static func shouldIncludeFlagsOnFilterPaint() -> Bool { true }

    /// PPH patch walks shoppers. Skip when the filtered week already has a Pure PPH.
    static func shouldPatchPPHOnPaint(hasFilteredPPH: Bool) -> Bool { !hasFilteredPPH }

    /// Do not wait for the full pack before the first scorecards paint.
    static func shouldPaintDashboardSectionsProgressively() -> Bool { true }

    /// Roster + the cards at the top of the dashboard. Paint these first.
    static var dashboardFirstWave: [MetricSection] {
        [.storeRoster, .sales, .lostRevenue, .missingItems, .fiveStar]
    }

    /// Remaining dashboard scorecards. Picker stays deferred.
    static var dashboardSecondWave: [MetricSection] {
        [.preSubOOS, .pickPath, .aisleMapper, .prepNotReady, .dynacap, .scheduleQuality, .pph, .labor]
    }

    /// Keep a live chrome/filter card when this paint has not loaded that section yet.
    static func mergeDashboardSummaries(painted: [SectionSummary], live: [SectionSummary]) -> [SectionSummary] {
        let kept = Dictionary(uniqueKeysWithValues: live.map { ($0.section, $0) })
        return painted.map { card in
            guard card.storeCount == 0, (card.headline ?? 0) == 0,
                  let liveCard = kept[card.section],
                  liveCard.storeCount > 0 || (liveCard.headline ?? 0) > 0
            else { return card }
            return liveCard
        }
    }

    /// O(1) store membership. Never `allowed.contains { sameStore }`.
    static func storeInScope(_ raw: String, allowed: Set<String>?) -> Bool {
        guard let allowed else { return true }
        return HeartbeatMath.storeInAllowed(raw, allowed: allowed)
    }

    /// Share picker appears before any HTML is built.
    static func shouldPresentShareSheetWithoutBuildingHTML() -> Bool { true }

    /// iOS Mail shows this HTML in the message body. Over this, attach the file instead.
    static let mailBodyMaxBytes = 400_000

    static func shouldSetHTMLMessageBody(utf8Count: Int) -> Bool {
        utf8Count > 80 && utf8Count <= mailBodyMaxBytes
    }

    /// Over the body cap, Mail gets a short HTML note plus the full HTML file.
    static func shouldAttachHTMLFile(utf8Count: Int) -> Bool {
        utf8Count > mailBodyMaxBytes
    }

    /// Who's looking wait is the safe time to swap a newer cloud pack (hub is not mounted).
    static func shouldCheckCloudPackDuringSeatWait() -> Bool { true }

    /// Pin the brand / greeting / filter bar in flow above the page. safeAreaInset
    /// loses to page `ignoresSafeArea` after the pager was removed — cards hide under chrome.
    static func shouldPinHubChromeAboveContent() -> Bool { true }

    /// Cloud facts/pack after Who's looking — not on splash, not in the first breath.
    static let cloudHydrateDelayNanoseconds: UInt64 = 12_000_000_000
    static let foregroundCloudQuietSeconds: TimeInterval = 90

    static func shouldPullCloudOnForeground(secondsSinceReady: TimeInterval) -> Bool {
        secondsSinceReady >= foregroundCloudQuietSeconds
    }

    /// Skip another facts.json parse when the warehouse already has the store tables.
    static func shouldLoadPublishedFacts(lostStores: Int, salesStores: Int, minimum: Int = 200) -> Bool {
        lostStores < minimum && salesStores < minimum
    }

    static func fileBytes(at url: URL) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    }

    static func isUsableFileSize(_ bytes: Int) -> Bool {
        bytes >= minimumPackBytes
    }

    /// Seat UI (Who's looking) must not wait on the warehouse walk.
    static func shouldPresentSeatBeforeWarehouse() -> Bool { true }

    /// Keep the seat they just picked when the pack finishes after the hub is already up.
    static func shouldKeepLastSeatOnPackLoad(seatPresented: Bool) -> Bool { seatPresented }

    /// Cold open always presents Who's looking. Never auto-restore last dashboard.
    static func shouldSkipRoleGateOnRelaunch(role: HeartbeatRole?, filtersActive: Bool) -> Bool {
        false
    }

    /// After they pick a seat, offer last book for that seat. They still tap Continue.
    static func suggestedSeatValues(role: HeartbeatRole, pending: DashboardFilters?) -> [String] {
        guard let pending, pending.isActive else { return [] }
        switch role {
        case .backstage: return []
        case .evp: return pending.regions
        case .director: return pending.divisions
        case .districtManager: return pending.districts
        case .om: return pending.oms
        case .store: return pending.stores
        }
    }

    /// Share needs filtered warehouse rows. Chrome-only District 03 would leak company grain.
    static func shouldAllowShare(warehouseHydrating: Bool) -> Bool { !warehouseHydrating }

    /// Boot copy that must move. One spinner phrase for 15s fails the reliability bar.
    enum BootPhase: Int, CaseIterable {
        case openingFloor = 1
        case readingChrome = 2
        case presentingSeat = 3
        case readingPack = 4
        case buildingTables = 5
        case paintingAisle = 6
        case ready = 7

        var label: String {
            switch self {
            case .openingFloor: return "Opening the floor"
            case .readingChrome: return "Reading dashboard chrome"
            case .presentingSeat: return "Choosing a seat"
            case .readingPack: return "Reading the store pack"
            case .buildingTables: return "Building store tables"
            case .paintingAisle: return "Setting the aisle"
            case .ready: return "Ready"
            }
        }

        var fraction: Double {
            Double(rawValue) / Double(BootPhase.ready.rawValue)
        }
    }

    /// Chrome cards are enough to leave splash. Warehouse fill continues behind the seat UI.
    static func leaveSplashAfterChrome(paintedStoreCards: Int) -> Bool {
        paintedStoreCards > 0
    }

    /// Leave the splash when a real pack is in memory, or when Excel store
    /// facts already painted dashboard cards (bundled or cloud).
    static func leaveSplash(localPackBytes: Int, loadedRows: Int, paintedStoreCards: Int = 0) -> Bool {
        if paintedStoreCards > 0 { return true }
        return isUsableFileSize(localPackBytes) && loadedRows > 0
    }

    static func usablePaintedCards(_ summaries: [SectionSummary]) -> Int {
        summaries.filter { $0.storeCount >= 8 || ($0.headline ?? 0) > 0 }.count
    }

    /// Fetch when the device has nothing usable, the cloud file is a different
    /// size, or storage `updated_at` moved. SQLite page alignment often keeps
    /// the same byte length after Wednesday lands — size-only compare skipped it.
    /// A new app stamp must not force a download by itself (jetsam on 4GB).
    static func shouldFetchRemotePack(
        remoteBytes: Int,
        localBytes: Int,
        localRowsLoaded: Int,
        remoteUpdated: String = "",
        knownUpdated: String = ""
    ) -> Bool {
        guard isUsableFileSize(remoteBytes) else { return false }
        if localRowsLoaded == 0 { return true }
        if !remoteUpdated.isEmpty, remoteUpdated != knownUpdated { return true }
        return remoteBytes != localBytes
    }

    /// A promoted newer pack must paint in this session. iPad is `constrained`
    /// (skipExcel); skipping the reload left Wednesday on disk and old Sales on screen.
    static func reloadInSessionAfterFetch(constrained: Bool, localRowsLoaded: Int) -> Bool {
        true
    }

    static func missingPackMessage() -> String {
        "No Heartbeat pack is on this device, and the cloud pack did not load. Check the network and tap Try again."
    }
}
