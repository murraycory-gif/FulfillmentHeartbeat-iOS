import SwiftUI
import UIKit

@main
struct FulfillmentHeartbeatApp: App {
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
        UINavigationBar.appearance().tintColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
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

private extension UIFont {
    var rounded: UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
