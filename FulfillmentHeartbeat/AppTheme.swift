import SwiftUI
import UIKit

/// EnviroMap light paper: HUB canvas #F5F7FC, brand blue, quiet type.
enum AppTheme {
    /// Darker Albertsons blue — Fulfillment title, UI chrome, and all blue text.
    static let blue = Color(hex: "003DA5")
    static let blueSoft = Color(hex: "DCE6F4")
    static let blueDeep = Color(hex: "003DA5")
    /// Darker Albertsons blue — heart fill.
    static let heart = Color(hex: "003DA5")
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
            layer.shadowRadius = 8
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

            let glow = CABasicAnimation(keyPath: "shadowOpacity")
            glow.fromValue = 0.10
            glow.toValue = 0.28
            glow.duration = 1.05
            glow.autoreverses = true
            glow.repeatCount = .infinity
            glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(glow, forKey: "riskGlow")
        }
    }
}

struct TableRowChrome: ViewModifier {
    let health: Health

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.healthWash(health).opacity(0.42))
                    }
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(health == .none ? AppTheme.blue.opacity(0.35) : AppTheme.healthInk(health))
                    .frame(width: 4)
                    .padding(.vertical, 10)
            }
            .overlay {
                Group {
                    if health == .risk {
                        RiskPulseRing(cornerRadius: 14, lineWidth: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    }
                }
                .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
            .shadow(color: Color.black.opacity(0.03), radius: 1, y: 1)
    }
}

extension View {
    func tableRowCard(health: Health) -> some View {
        modifier(TableRowChrome(health: health))
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
