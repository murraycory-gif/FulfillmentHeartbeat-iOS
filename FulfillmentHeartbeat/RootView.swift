import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @State private var minTimeElapsed = false

    private var showSplash: Bool {
        !minTimeElapsed || !store.isReady
    }

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            if showSplash {
                LaunchSplashView(isLoading: !store.isReady)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                minTimeElapsed = true
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showSplash)
    }
}

struct LaunchSplashView: View {
    var isLoading: Bool
    @State private var appear = false

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 22) {
                Image("HeartbeatMark")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 280)
                    .shadow(color: AppTheme.blue.opacity(0.18), radius: 16, y: 6)
                    .scaleEffect(appear ? 1 : 0.94)
                    .opacity(appear ? 1 : 0)

                HeartbeatTrace()
                    .frame(width: 240, height: 40)

                VStack(spacing: 4) {
                    Text("Fulfillment")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Text("Heartbeat")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                }

                if isLoading {
                    ProgressView()
                        .tint(AppTheme.blue)
                        .padding(.top, 6)
                    Text("Loading market pulse…")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                appear = true
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(HeartbeatStore())
}