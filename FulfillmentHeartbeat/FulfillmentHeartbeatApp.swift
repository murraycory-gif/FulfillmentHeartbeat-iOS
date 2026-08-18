import SwiftUI
import UIKit

@main
struct FulfillmentHeartbeatApp: App {
    @StateObject private var store = HeartbeatStore()

    private let launchUI = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
    private let launch = Color(red: 0.96, green: 0.97, blue: 0.99)

    init() {
        UIWindow.appearance().backgroundColor = launchUI
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1),
            .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
        ]
        nav.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1),
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(red: 0.15, green: 0.42, blue: 0.95, alpha: 1)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                launch.ignoresSafeArea()
                RootView()
                    .environmentObject(store)
            }
            .background(launch.ignoresSafeArea())
            .preferredColorScheme(.light)
            .onAppear {
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                    .forEach { $0.backgroundColor = launchUI }
            }
        }
    }
}
