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
    /// Hardware class. Layout, launch, and paging never mix these.
    enum Kind { case phone, pad, mac }

    static var kind: Kind {
        #if targetEnvironment(macCatalyst)
        return .mac
        #else
        return UIDevice.current.userInterfaceIdiom == .phone ? .phone : .pad
        #endif
    }

    static var isPhoneDevice: Bool { kind == .phone }
    static var isPadDevice: Bool { kind == .pad }
    static var isMac: Bool { kind == .mac }

    /// 4GB class (iPhone 13 / SE 3 / old iPads).
    static var lowMemory: Bool {
        ProcessInfo.processInfo.physicalMemory < 5_500_000_000
    }

    /// iPhone always. 4GB iPad too. Skip labor/picker and Excel on launch.
    static var lightLaunch: Bool { isPhoneDevice || lowMemory }

    /// Back-compat for store/pager. Means lightLaunch, not "small screen".
    static var constrained: Bool { lightLaunch }

    /// Phone chrome stays phone even in landscape. iPad/Mac stay regular
    /// even in split view. Never drive this off width alone.
    static func isPhone(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        _ = sizeClass
        return isPhoneDevice
    }

    static func phoneBannerTitleFont() -> Font { AppTheme.rounded(.footnote, weight: .bold) }
    static func phoneBannerIconFont() -> Font { AppTheme.rounded(.footnote, weight: .semibold) }
    static var phoneControlHeight: CGFloat { 30 }
    static var phoneInset: CGFloat { 12 }

    static func flagColumns(count: Int, width: CGFloat) -> Int {
        guard count > 0 else { return 1 }
        if isPhoneDevice { return 1 }
        if width < 500 { return 1 }
        let chip: CGFloat
        if width < 700 { chip = 164 }
        else if width >= 1100 { chip = 196 }
        else { chip = 176 }
        return max(1, min(count, Int(max(width, chip) / chip)))
    }

    static func kpiColumns(width: CGFloat, sizeClass: UserInterfaceSizeClass? = .regular) -> Int {
        if isPhone(sizeClass) {
            return width >= 640 ? 3 : 2
        }
        if width >= 1100 { return 5 }
        if width >= 860 { return 4 }
        return 4
    }

    static func uploadColumns(width: CGFloat, sizeClass: UserInterfaceSizeClass? = .regular) -> Int {
        if isPhone(sizeClass) { return 1 }
        return width >= 720 ? 2 : 2
    }

    static func grid(_ count: Int, spacing: CGFloat = 12, minWidth: CGFloat = 140) -> [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: minWidth), spacing: spacing), count: max(1, count))
    }

    static var grainCap: Int { lightLaunch ? 12 : 24 }
    static var storeGrainCap: Int { lightLaunch ? 16 : 50 }
    static var pickerCap: Int { 50 }
    /// Next page hydrates on swipe. Taps never pre-build neighbors.
    static var hydrateNeighbors: Bool { false }
    /// Rasterizing huge SwiftUI lists stalls Mac. iPad only.
    static var rasterizeSwipe: Bool { isPadDevice && !lowMemory }
}

private struct HubWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
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
