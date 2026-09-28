import SwiftUI
import UIKit
import UserNotifications

@main
struct FulfillmentHeartbeatApp: App {
    @UIApplicationDelegateAdaptor(HeartbeatPushBridge.self) private var pushBridge
    @StateObject private var store = HeartbeatStore()
    @Environment(\.scenePhase) private var scenePhase

    private let launchUI = AppTheme.uiBg
    private let launch = AppTheme.bg

    init() {
        UIWindow.appearance().backgroundColor = launchUI
        UITableView.appearance().backgroundColor = launchUI
        UITableViewCell.appearance().backgroundColor = launchUI
        UICollectionView.appearance().backgroundColor = launchUI
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = launchUI
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold).rounded,
        ]
        nav.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded,
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(red: 0.00, green: 0.24, blue: 0.65, alpha: 1)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                launch.ignoresSafeArea()
                RootView()
                    .environmentObject(store)
                    .environment(\.font, AppTheme.bodyFont)
            }
            .background(launch.ignoresSafeArea())
            .preferredColorScheme(.light)
            .onChange(of: scenePhase) { _, phase in
                if phase == .inactive || phase == .background {
                    store.flush()
                } else if phase == .active {
                    store.pullLatestWorkbookIfNeeded()
                    if NewDataPreferences.pushAlertsEnabled(in: .standard) {
                        NewDataPush.registerIfAuthorized()
                    }
                }
            }
            .onAppear {
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                    .forEach { $0.backgroundColor = launchUI }
                #if targetEnvironment(macCatalyst)
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .forEach { scene in
                        scene.title = "Fulfillment Heartbeat"
                        guard let size = scene.sizeRestrictions else { return }
                        size.minimumSize = CGSize(width: 1100, height: 720)
                    }
                #endif
            }
        }
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 1280, height: 860)
        #endif
    }
}

/// APNs registration. The iOS permission dialog runs after a pack is on screen.
enum NewDataPush {
    static let tokenKey = "hb.apnsToken"

    static var environment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "prod"
        #endif
    }

    static func requestSystemPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    static func registerIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    static func refreshAuthorizationDenied(_ update: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let denied = settings.authorizationStatus == .denied
            DispatchQueue.main.async {
                update(denied)
            }
        }
    }

    /// ON keeps or registers the token. OFF posts the same token with optedOut so the cook skips it.
    static func applyPreference(_ on: Bool, defaults: UserDefaults = .standard) {
        let token = defaults.string(forKey: tokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !token.isEmpty {
            post(token: token, optedOut: !on)
        }
        if on {
            requestSystemPermission()
        }
    }

    static func storeAndPost(deviceToken: Data, defaults: UserDefaults = .standard) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        defaults.set(hex, forKey: tokenKey)
        let optedOut = !NewDataPreferences.pushAlertsEnabled(in: defaults)
        post(token: hex, optedOut: optedOut)
    }

    static func post(token: String, optedOut: Bool = false, bundle: Bundle = .main) {
        let raw = (bundle.object(forInfoDictionaryKey: "HBPushWorkerURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let base = URL(string: raw), !raw.isEmpty else { return }
        let endpoint = base.appendingPathComponent("token")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "token": token,
            "env": environment,
            "appVersion": BuildStamp.id,
            "optedOut": optedOut,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request).resume()
    }
}

final class HeartbeatPushBridge: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NewDataPush.storeAndPost(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {}
}

private extension UIFont {
    var rounded: UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
