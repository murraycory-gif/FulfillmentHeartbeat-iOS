import SwiftUI

struct CoachStep: Equatable {
    let icon: String
    let heading: String
    let body: String
}

enum CoachTour: Equatable {
    case welcome
    case page(HubDestination)

    var eyebrow: String {
        switch self {
        case .welcome: return "Welcome"
        case .page(let dest): return dest.title
        }
    }

    var steps: [CoachStep] {
        switch self {
        case .welcome: return Self.welcomeSteps
        case .page(let dest): return Self.steps(for: dest)
        }
    }

    private static let welcomeSteps: [CoachStep] = [
        CoachStep(
            icon: "heart.fill",
            heading: "Fulfillment Heartbeat",
            body: "This is the operational pulse for every eCommerce store. Dashboard cards, scorecard tables, and the checklist all read from the workbooks you load — nothing is hardcoded."
        ),
        CoachStep(
            icon: "square.and.arrow.up",
            heading: "Data comes first",
            body: "We start on Upload because the files feed every page. Use Master load for the full weekly .xlsx, or drop one KPI at a time. Until a workbook is in, the rest of the app has nothing to show."
        ),
        CoachStep(
            icon: "square.grid.2x2.fill",
            heading: "How the app is laid out",
            body: "Dashboard is the heartbeat. Swipe between scorecards (Loss Revenue → Missing Items → 5 Star → Pick Path → Prep → Dynacap → Schedule → Picker → PPH → Labor → Checklist). Filters in the header apply everywhere. Share sends the recap. Upload lives in Settings — it is not in the swipe path."
        ),
        CoachStep(
            icon: "hand.tap.fill",
            heading: "Page walkthroughs",
            body: "Each page explains itself the first time you open it. You can skip a tour or skip all of them. Let’s walk Upload now so you can load the pulse."
        ),
    ]

    private static func steps(for dest: HubDestination) -> [CoachStep] {
        switch dest {
        case .upload:
            return [
                CoachStep(
                    icon: "doc.badge.plus",
                    heading: "Master load",
                    body: "Pick one .xlsx that has a tab per KPI. Name the sheets Lost Revenue, MI, 5 Star, Pick Path, Path Picker, Prep, Dynacap, Schedule, PPH, Labor, and Picker ScoreCard — or leave the Power BI headers and we map them. Link the file so next week you can reload from the same place."
                ),
                CoachStep(
                    icon: "square.grid.2x2",
                    heading: "One KPI at a time",
                    body: "The cards below replace a single scorecard if you only have one export. That KPI updates; the others stay as they are."
                ),
                CoachStep(
                    icon: "waveform.path.ecg",
                    heading: "Then the pulse fills",
                    body: "Once a file lands, Dashboard, every scorecard, and the checklist populate. Open Dashboard or swipe from there. Filters and Share work after data is in."
                ),
            ]
        case .dashboard:
            return [
                CoachStep(
                    icon: "square.grid.2x2.fill",
                    heading: "Operational Heartbeat",
                    body: "Each card is a KPI. The wash matches health: green healthy, amber watch, red at risk. At-risk cards pulse so the problems jump out."
                ),
                CoachStep(
                    icon: "hand.tap.fill",
                    heading: "Tap a card to open it",
                    body: "That jumps to the scorecard. Region, Division, District, OM, and Store pills in the header filter every page. Share sends the recap through Mail, Messages, Notes, or Teams."
                ),
                CoachStep(
                    icon: "arrow.left.arrow.right",
                    heading: "Swipe the scorecards",
                    body: "Swipe left or right to the next page. Upload / Settings is not in the swipe path — use the sidebar for that."
                ),
            ]
        case .lostRevenue:
            return [
                CoachStep(
                    icon: "chart.line.downtrend.xyaxis",
                    heading: "Callouts",
                    body: "Tiles at the top are Total lost revenue, Healthy (≤3%), Watch (3.01–5%), At Risk (over 5%), plus Lost % and eComm sales. Tap a tile to filter the tables below."
                ),
                CoachStep(
                    icon: "tablecells",
                    heading: "Markets and stores",
                    body: "Markets roll up first, then every store. Expand a store for the dollars behind the loss. Same header filters apply."
                ),
            ]
        case .missingItems:
            return [
                CoachStep(
                    icon: "tag.slash.fill",
                    heading: "Callouts",
                    body: "Avg missing items, Healthy (≤5%), Watch (5.01–6.50%), and At Risk (over 6.50%). Tap a tile to filter the tables. Use the category chips to show all departments or only the ones you need."
                ),
                CoachStep(
                    icon: "tablecells",
                    heading: "Departments",
                    body: "Both tables show 301 Grocery through 336 Bakery Pkgd plus Total. Filter categories on this page only — region filters in the header still apply everywhere."
                ),
            ]
        case .fiveStar:
            return [
                CoachStep(
                    icon: "star.fill",
                    heading: "Callouts",
                    body: "Avg star rating, Goal 5.00, Fail under 4.0, plus Flash, Presubs, COE, OTT, and OTH 5%. Tap a tile to filter the store table to that cut."
                ),
                CoachStep(
                    icon: "person.2.fill",
                    heading: "Stores and shoppers",
                    body: "Markets, then stores. Expand a store to see shoppers with the 5 Star metrics: OTT, Flash, OTH5, COE, Presub, and OOS%."
                ),
            ]
        case .pickPath:
            return [
                CoachStep(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    heading: "Callouts",
                    body: "Avg compliance, 90% goal, stores at goal, and stores below 80% (at risk). Tap a tile to filter."
                ),
                CoachStep(
                    icon: "person.2.fill",
                    heading: "Shoppers under each store",
                    body: "Expand a store for that shopper’s pick path compliance, presub, OOS%, and PPH — only on this page."
                ),
            ]
        case .prepNotReady:
            return [
                CoachStep(
                    icon: "shippingbox",
                    heading: "Callouts",
                    body: "Avg PNR hours, 1.9% goal, stores at goal, and stores above 2.5% (at risk). Tap to filter the tables."
                ),
                CoachStep(
                    icon: "tablecells",
                    heading: "Markets and stores",
                    body: "Rollup first, then stores. This is hours the customer waited because product was not ready."
                ),
            ]
        case .dynacap:
            return [
                CoachStep(
                    icon: "slider.horizontal.3",
                    heading: "Callouts",
                    body: "Avg pieces / hour, 65 goal, stores below 60 (at risk), and utilization. Tap a tile to filter."
                ),
                CoachStep(
                    icon: "speedometer",
                    heading: "PPH on the store",
                    body: "Store tables include PPH. Expand a store for the shoppers grouped to that store with their PPH."
                ),
            ]
        case .scheduleQuality:
            return [
                CoachStep(
                    icon: "calendar.badge.clock",
                    heading: "Callouts",
                    body: "Avg schedule efficiency (90% goal), under scheduled over 5%, and over scheduled over 5%. Tap to filter."
                ),
                CoachStep(
                    icon: "tablecells",
                    heading: "Why this matters",
                    body: "Under / over and target vs punch on this page explain Flash, call-offs, and no-shows that show up in 5 Star and Labor."
                ),
            ]
        case .pickerScorecard:
            return [
                CoachStep(
                    icon: "person.2.fill",
                    heading: "Callouts",
                    body: "All shoppers, opportunity (15+ orders, underperforming), strong shoppers, and refunds. Tap a tile to focus the lists."
                ),
                CoachStep(
                    icon: "list.bullet",
                    heading: "No market table here",
                    body: "This page is shoppers, not stores. Top opportunity vs strong lists sit above the full table."
                ),
            ]
        case .pph:
            return [
                CoachStep(
                    icon: "speedometer",
                    heading: "Callouts",
                    body: "Avg pure PPH, goal 80, stores at goal, and stores below 74 (at risk). Tap to filter."
                ),
                CoachStep(
                    icon: "person.2.fill",
                    heading: "Stores and shoppers",
                    body: "Markets, then stores. Expand a store for that shopper’s Pure PPH."
                ),
            ]
        case .labor:
            return [
                CoachStep(
                    icon: "dollarsign.circle.fill",
                    heading: "Callouts",
                    body: "Target vs Actual (0% healthy, 0.01–3% watch, over 3% at risk), plus CostTrgt%, ActCost%, Sch Effi%, UPLH, Wage, and AIV. Tap to filter."
                ),
                CoachStep(
                    icon: "tablecells",
                    heading: "Stores",
                    body: "Markets then stores. Pair this with Schedule Quality when punch vs target is off."
                ),
            ]
        case .checklist:
            return [
                CoachStep(
                    icon: "checklist",
                    heading: "What to fix",
                    body: "Every at-risk KPI lists the stores, why it costs sales and customer experience, and the action to course-correct."
                ),
                CoachStep(
                    icon: "person.2.fill",
                    heading: "Shoppers are KPI-specific",
                    body: "Expand a store for the shoppers that KPI cares about — 5 Star metrics on 5 Star, pick path on Pick Path, and so on."
                ),
            ]
        }
    }
}

final class CoachGuide: ObservableObject {
    @Published var active: CoachTour?
    @Published var stepIndex = 0

    private let defaults = UserDefaults.standard
    private let welcomeKey = "hb.coach.welcome.v1"

    var welcomeDone: Bool { defaults.bool(forKey: welcomeKey) }

    func pageKey(_ dest: HubDestination) -> String {
        "hb.coach.page.v1.\(dest.rawValue)"
    }

    func seen(_ dest: HubDestination) -> Bool {
        defaults.bool(forKey: pageKey(dest))
    }

    func presentIfNeeded(for dest: HubDestination) {
        guard active == nil else { return }
        if !welcomeDone {
            active = .welcome
            stepIndex = 0
            return
        }
        if !seen(dest) {
            active = .page(dest)
            stepIndex = 0
        }
    }

    func next() {
        guard let active else { return }
        if stepIndex + 1 < active.steps.count {
            stepIndex += 1
        } else {
            finish()
        }
    }

    func finish() {
        switch active {
        case .welcome:
            defaults.set(true, forKey: welcomeKey)
            active = .page(.upload)
            stepIndex = 0
        case .page(let dest):
            defaults.set(true, forKey: pageKey(dest))
            active = nil
            stepIndex = 0
        case nil:
            break
        }
    }

    func skipAll() {
        defaults.set(true, forKey: welcomeKey)
        for dest in HubDestination.allCases {
            defaults.set(true, forKey: pageKey(dest))
        }
        active = nil
        stepIndex = 0
    }
}

struct CoachOverlay: View {
    @ObservedObject var guide: CoachGuide

    var body: some View {
        if let tour = guide.active {
            let steps = tour.steps
            let step = steps[min(guide.stepIndex, max(steps.count - 1, 0))]
            let last = guide.stepIndex >= steps.count - 1
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            Image(systemName: step.icon)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Walkthrough")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(tour.eyebrow)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppTheme.text)
                            }
                            Spacer()
                            Text("\(guide.stepIndex + 1) / \(steps.count)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        Text(step.heading)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text(step.body)
                            .font(.body)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            ForEach(steps.indices, id: \.self) { index in
                                Capsule()
                                    .fill(index == guide.stepIndex ? AppTheme.blue : AppTheme.blue.opacity(0.22))
                                    .frame(width: index == guide.stepIndex ? 22 : 8, height: 8)
                            }
                        }
                        .padding(.top, 4)
                        HStack {
                            Button("Skip all") { guide.skipAll() }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Button(last ? "Got it" : "Next") { guide.next() }
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(AppTheme.blue, in: Capsule())
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: 560)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 24, y: 10)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}
