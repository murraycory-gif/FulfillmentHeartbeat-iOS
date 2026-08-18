import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @State private var showSplash = true

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            if showSplash {
                LaunchSplashView()
                    .zIndex(2)
            } else {
                MainHubView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.light)
        .tint(AppTheme.blue)
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }
}

struct LaunchSplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 18) {
                Image("HeartbeatMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 148, height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .shadow(color: AppTheme.blue.opacity(0.22), radius: 18, y: 8)
                    .scaleEffect(appear ? 1 : 0.92)
                    .opacity(appear ? 1 : 0.85)

                VStack(spacing: 4) {
                    Text("Fulfillment")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Text("Heartbeat")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                appear = true
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(HeartbeatStore())
}
