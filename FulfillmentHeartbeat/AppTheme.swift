import SwiftUI
import UIKit

/// EnviroMap light paper: HUB canvas #F5F7FC, brand blue, quiet type.
enum AppTheme {
    /// Overview callout navy — banners, chrome, and blue text through the app.
    static let blue = Color(hex: "00285C")
    static let blueSoft = Color(hex: "D6DEEA")
    static let blueDeep = Color(hex: "00285C")
    static let overviewBar = blue
    /// Darker Albertsons blue — heart fill.
    static let heart = Color(hex: "00285C")
    /// Lighter Albertsons blue — ECG pulse and "ment" in the wordmark.
    static let pulse = Color(hex: "00A9E0")

    /// Same canvas as the HUB app.
    static let bg = Color(hex: "F5F7FC")
    static let uiBg = UIColor(red: 245 / 255, green: 247 / 255, blue: 252 / 255, alpha: 1)
    static let card = Color.white
    /// HUB table interior — light blue wash inside the outlined boxes.
    static let tableFill = Color(hex: "EEF2FB")
    static let cardBorder = Color.black.opacity(0.06)

    static let text = Color(red: 0.08, green: 0.10, blue: 0.16)
    static let textSecondary = Color(red: 0.38, green: 0.42, blue: 0.50)
    static let textTertiary = Color(red: 0.55, green: 0.58, blue: 0.65)

    static let ok = Color(hex: "059669")
    static let okSoft = Color(hex: "D1FAE5")
    static let warn = Color(hex: "D97706")
    static let warnSoft = Color(hex: "FEF3C7")
    static let bad = Color(hex: "DC2626")
    static let badSoft = Color(hex: "FEE2E2")

    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        Font.system(style, design: .rounded).weight(weight)
    }

    static func rounded(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        Font.system(size: size, weight: weight, design: .rounded)
    }

    static var bodyFont: Font { Font.system(.body, design: .rounded) }

    static let radiusL: CGFloat = 20
    static let radiusM: CGFloat = 14
    static let radiusS: CGFloat = 10

    static func healthInk(_ health: Health) -> Color {
        switch health {
        case .good: return ok
        case .watch: return warn
        case .risk: return bad
        case .none: return text
        }
    }

    static func healthWash(_ health: Health) -> Color {
        switch health {
        case .good: return okSoft
        case .watch: return warnSoft
        case .risk: return badSoft
        case .none: return tableFill
        }
    }
}

/// Isolated AT RISK pulse — Core Animation, so SwiftUI does not re-render the page.
struct RiskPulseRing: View {
    var cornerRadius: CGFloat = 16
    var lineWidth: CGFloat = 2.5

    var body: some View {
        RiskPulseLayer(cornerRadius: cornerRadius, lineWidth: lineWidth)
            .allowsHitTesting(false)
    }
}

private struct RiskPulseLayer: UIViewRepresentable {
    var cornerRadius: CGFloat
    var lineWidth: CGFloat

    func makeUIView(context: Context) -> PulseView {
        PulseView()
    }

    func updateUIView(_ view: PulseView, context: Context) {
        view.isUserInteractionEnabled = false
        view.apply(cornerRadius: cornerRadius, lineWidth: lineWidth)
    }

    final class PulseView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isOpaque = false
            backgroundColor = .clear
            layer.borderColor = UIColor(red: 220 / 255, green: 38 / 255, blue: 38 / 255, alpha: 1).cgColor
            layer.cornerCurve = .continuous
            layer.shadowColor = UIColor(red: 220 / 255, green: 38 / 255, blue: 38 / 255, alpha: 1).cgColor
            layer.shadowOffset = CGSize(width: 0, height: 3)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func apply(cornerRadius: CGFloat, lineWidth: CGFloat) {
            layer.cornerRadius = cornerRadius
            layer.borderWidth = lineWidth
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            startIfNeeded()
        }

        private func startIfNeeded() {
            guard layer.animation(forKey: "riskPulse") == nil else { return }
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0.28
            opacity.toValue = 0.95
            opacity.duration = 1.05
            opacity.autoreverses = true
            opacity.repeatCount = .infinity
            opacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(opacity, forKey: "riskPulse")
        }
    }
}

struct TableRowChrome: ViewModifier {
    let health: Health

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Rectangle()
                    .fill(health == .risk ? AppTheme.badSoft.opacity(0.45)
                          : health == .watch ? AppTheme.warnSoft.opacity(0.28)
                          : Color.clear)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(health == .none ? Color.clear : AppTheme.healthInk(health))
                    .frame(width: 3)
            }
    }
}

extension View {
    func tableRowCard(health: Health) -> some View {
        modifier(TableRowChrome(health: health))
    }

    func hubScorecardChrome() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .fill(AppTheme.tableFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .strokeBorder(AppTheme.blue, lineWidth: 2.5)
            )
            .padding(3)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (38, 107, 242)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                    .fill(AppTheme.blue)
                    .opacity(configuration.isPressed ? 0.88 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.blueSoft)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct BrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.blue)
                    .opacity(configuration.isPressed ? 0.88 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

enum HubLayout {
    /// Hardware family. Layout, launch, and paging never mix these.
    enum Kind { case phone, pad, mac }

    /// One profile per device. Call sites use capabilities, not RAM guesses.
    struct Profile: Equatable {
        var kind: Kind
        var machine: String
        var name: String
        var ramGB: Int
        /// iPhone 13, 17, … nil on iPad/Mac.
        var phoneGeneration: Int?
        /// Skip the xlsx parser (phones + 4GB iPads). Pack-only.
        var skipExcel: Bool
        /// Skip labor/picker on first sqlite read (iPhone 13 / 4GB).
        var lightLaunch: Bool
        var phoneChrome: Bool
        var hydrateNeighbors: Bool
        var rasterizeSwipe: Bool
        var grainCap: Int
        var storeGrainCap: Int
    }

    static let profile: Profile = makeProfile()

    static var kind: Kind { profile.kind }
    static var isPhoneDevice: Bool { profile.kind == .phone }
    static var isPadDevice: Bool { profile.kind == .pad }
    static var isMac: Bool { profile.kind == .mac }
    static var lowMemory: Bool { profile.ramGB < 6 }
    static var lightLaunch: Bool { profile.lightLaunch }
    /// Skip Excel. Name kept for HeartbeatStore call sites.
    static var constrained: Bool { profile.skipExcel }
    /// Only the Mac builds the sqlite pack from Excel. Phones and iPads never unzip xlsx.
    static var ingestsWorkbook: Bool { isMac }

    static func isPhone(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        _ = sizeClass
        return profile.phoneChrome
    }

    static var grainCap: Int { profile.grainCap }
    static var storeGrainCap: Int { profile.storeGrainCap }

    /// Floor width so currency and percents stay whole; narrower screens scroll.
    static func readableTableFloor(
        phone: Bool,
        columns: Int,
        showCount: Bool,
        district: Bool = false,
        valueMin: CGFloat? = nil
    ) -> CGFloat {
        let label = scopeLabelWidth(district: district, phone: phone)
        let stores: CGFloat = showCount ? readableStoreWidth(phone: phone) : 0
        let value = valueMin ?? readableValueMin(phone: phone)
        let status = readableStatusWidth(phone: phone)
        let pad: CGFloat = 28 + CGFloat(columns + (showCount ? 2 : 1)) * tableGutter
        return label + stores + CGFloat(max(columns, 1)) * value + status + pad
    }

    /// Use the window when it is wider than the readable floor (iPad, iPhone, Mac).
    static func tableSpan(available: CGFloat, floor: CGFloat) -> CGFloat {
        max(available, floor)
    }

    /// Many-column dashboard grains use a tighter min so the table fits/scrolls instead of exploding.
    static func dashboardValueMin(phone: Bool, columns: Int) -> CGFloat {
        if columns >= 8 { return phone ? 72 : 88 }
        if columns >= 6 { return phone ? 84 : 96 }
        return readableValueMin(phone: phone)
    }

    /// Extra width is split evenly across value columns. Never thinner than the readable min.
    static func evenValueWidth(
        available: CGFloat,
        phone: Bool,
        columns: Int,
        showCount: Bool,
        district: Bool = false,
        valueMin: CGFloat? = nil
    ) -> CGFloat {
        let label = district
            ? scopeLabelWidth(district: true, phone: phone)
            : readableLabelWidth(phone: phone, available: available)
        let minVal = valueMin ?? readableValueMin(phone: phone)
        let floor = readableTableFloor(
            phone: phone,
            columns: columns,
            showCount: showCount,
            district: district,
            valueMin: minVal
        )
        let span = tableSpan(available: available, floor: floor)
        let gutters = tableGutter * CGFloat(max(columns, 1) + (showCount ? 2 : 1))
        let reserved = label
            + (showCount ? readableStoreWidth(phone: phone) : 0)
            + readableStatusWidth(phone: phone)
            + gutters
            + 16
        let leftover = max(span - reserved, 0)
        return max(minVal, leftover / CGFloat(max(columns, 1)))
    }

    /// Wide enough for "California Region" and "24500 | A2 | Mid-Atlantic".
    static func readableLabelWidth(phone: Bool, available: CGFloat = 0) -> CGFloat {
        let minW: CGFloat = phone ? 156 : 228
        let maxW: CGFloat = phone ? 188 : 268
        guard available > 0 else { return minW }
        return min(maxW, max(minW, available * (phone ? 0.30 : 0.18)))
    }

    static var pageLabelWidth: CGFloat { readableLabelWidth(phone: isPhoneDevice) }

    /// District codes are short (J3, 03). Do not reserve the store-label column.
    static func scopeLabelWidth(district: Bool, phone: Bool = isPhoneDevice) -> CGFloat {
        if district { return phone ? 72 : 88 }
        return readableLabelWidth(phone: phone)
    }
    static func readableStoreWidth(phone: Bool) -> CGFloat { phone ? 58 : 68 }
    static func readableValueMin(phone: Bool) -> CGFloat { phone ? 118 : 128 }
    static func readableStatusWidth(phone: Bool) -> CGFloat { 88 }
    static var tableGutter: CGFloat { 6 }
    static var pickerCap: Int { 50 }
    static var hydrateNeighbors: Bool { profile.hydrateNeighbors }
    static var rasterizeSwipe: Bool { profile.rasterizeSwipe }

    /// Sales-style callouts: readable, but tighter than the oversized 324 tiles.
    static func calloutMinHeight(phone: Bool) -> CGFloat { phone ? 88 : 98 }
    static func calloutValueSize(phone: Bool) -> CGFloat { phone ? 20 : 22 }
    static func calloutMinWidth(phone: Bool) -> CGFloat { phone ? 136 : 152 }
    static var calloutGridSpacing: CGFloat { 8 }

    static func phoneBannerTitleFont() -> Font { AppTheme.rounded(.footnote, weight: .bold) }
    static func phoneBannerIconFont() -> Font { AppTheme.rounded(.footnote, weight: .semibold) }
    static var phoneControlHeight: CGFloat { 30 }
    static var phoneInset: CGFloat { 12 }

    static func flagColumns(count: Int, width: CGFloat) -> Int {
        calloutColumns(count: count, width: width)
    }

    /// Even KPI tiles: 2 on phone portrait, 3–4 on iPad / landscape / Mac.
    static func calloutColumns(count: Int, width: CGFloat, sizeClass: UserInterfaceSizeClass? = .regular) -> Int {
        guard count > 0 else { return 1 }
        let maxCols: Int
        if isPhone(sizeClass) {
            if width >= 700 { maxCols = 4 }
            else if width >= 520 { maxCols = 3 }
            else { maxCols = 2 }
        } else if width >= 1100 {
            maxCols = 4
        } else if width >= 760 {
            maxCols = 4
        } else {
            maxCols = 3
        }
        if count == 5 { return min(3, maxCols) }
        if count == 7 { return min(4, maxCols) }
        return max(1, min(count, maxCols))
    }

    static func kpiColumns(width: CGFloat, sizeClass: UserInterfaceSizeClass? = .regular) -> Int {
        calloutColumns(count: 8, width: width, sizeClass: sizeClass)
    }

    static func uploadColumns(width: CGFloat, sizeClass: UserInterfaceSizeClass? = .regular) -> Int {
        if isPhone(sizeClass) { return 1 }
        return 2
    }

    static func grid(_ count: Int, spacing: CGFloat = 12, minWidth: CGFloat = 140) -> [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: minWidth), spacing: spacing), count: max(1, count))
    }

    private static func makeProfile() -> Profile {
        let kind = detectKind()
        let machine = machineIdentifier()
        let ramGB = max(1, Int(ProcessInfo.processInfo.physicalMemory / 1_000_000_000))
        let phoneGen = phoneGeneration(machine)
        let name = marketingName(machine: machine, kind: kind, phoneGen: phoneGen)
        let fourGig = ramGB < 6
        let thirteenClass = (phoneGen ?? 99) <= 13
        /// Skip labor+picker on first sqlite read. Mac loads the pack whole.
        let lightLaunch = kind != .mac
        /// 555 iPad path: never parse the 11MB xlsx. Mac is the publisher.
        let skipExcel = kind != .mac
        return Profile(
            kind: kind,
            machine: machine,
            name: name,
            ramGB: ramGB,
            phoneGeneration: phoneGen,
            skipExcel: skipExcel,
            lightLaunch: lightLaunch,
            phoneChrome: kind == .phone,
            hydrateNeighbors: false,
            rasterizeSwipe: false,
            grainCap: lightLaunch ? 12 : 24,
            storeGrainCap: lightLaunch ? 16 : 50
        )
    }

    private static func detectKind() -> Kind {
        #if targetEnvironment(macCatalyst)
        return .mac
        #else
        return UIDevice.current.userInterfaceIdiom == .phone ? .phone : .pad
        #endif
    }

    private static func machineIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return Mirror(reflecting: info.machine).children.reduce(into: "") { result, child in
            guard let value = child.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
    }

    /// Apple product name → iPhone generation. iPhone14,5 = 13, iPhone18,1 = 17.
    private static func phoneGeneration(_ machine: String) -> Int? {
        guard machine.hasPrefix("iPhone") else { return nil }
        let code = String(machine.dropFirst("iPhone".count))
        let major = Int(code.split(separator: ",").first ?? "") ?? 0
        switch machine {
        case "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5", "iPhone14,6":
            return 13
        case "iPhone14,7", "iPhone14,8", "iPhone15,2", "iPhone15,3":
            return 14
        case "iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2":
            return 15
        case "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4", "iPhone17,5":
            return 16
        default:
            if machine.hasPrefix("iPhone18") { return 17 }
            if machine.hasPrefix("iPhone19") { return 18 }
            if major >= 18 { return 17 }
            if major >= 17 { return 16 }
            if major >= 16 { return 15 }
            if major >= 15 { return 14 }
            if major >= 14 { return 13 }
            if major >= 13 { return 12 }
            return major > 0 ? major : nil
        }
    }

    private static func marketingName(machine: String, kind: Kind, phoneGen: Int?) -> String {
        if kind == .mac { return "Mac" }
        if let gen = phoneGen {
            if machine.contains("iPhone14,2") || machine.contains("iPhone14,3") { return "iPhone 13 Pro" }
            if machine.contains("iPhone14,4") { return "iPhone 13 mini" }
            if machine.contains("iPhone14,6") { return "iPhone SE (3rd)" }
            return "iPhone \(gen)"
        }
        if machine.hasPrefix("iPad") { return "iPad" }
        return UIDevice.current.model
    }
}

struct HubWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

/// Table scrollers must not share HubWidthKey with dashboard card readWidth —
/// that preference war relayouts every grain table after ready and heats the iPad.
struct HubScrollWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

private struct HubTableWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var hubTableWidth: CGFloat {
        get { self[HubTableWidthKey.self] }
        set { self[HubTableWidthKey.self] = newValue }
    }
}

extension View {
    func readWidth(_ width: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: HubWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(HubWidthKey.self) { value in
            if value > 0, abs(value - width.wrappedValue) > 12 {
                width.wrappedValue = value
            }
        }
    }
}
