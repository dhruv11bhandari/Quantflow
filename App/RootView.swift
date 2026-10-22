import SwiftUI

enum AppStage { case splash, scan, main }

struct RootView: View {
    @StateObject private var model = AppModel()
    @StateObject private var train = TrainSession()
    @State private var stage: AppStage = .splash
    @State private var confirmDemo = false

    var body: some View {
        ZStack {
            ScreenBackground()
            stageView
            bannerLayer
        }
        .environmentObject(model)
        .environmentObject(train)
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .alert("Replace your progress with demo data?", isPresented: $confirmDemo, actions: {
            Button("Load demo", role: .destructive) { loadDemoNow() }
            Button("Cancel", role: .cancel) {}
        }, message: { Text("The demo profile is sample data. Your current progress on this device will be replaced.") })
        .onChange(of: model.hasProfile) {
            // Progress was reset or a scan retake was requested: return to the start.
            if !model.hasProfile && stage == .main {
                train.reset()
                go(.splash)
            }
        }
    }

    @ViewBuilder
    private var stageView: some View {
        switch stage {
        case .splash:
            SplashView(hasProfile: model.hasProfile, onStart: start, onDemo: demo)
                .transition(.opacity)
        case .scan:
            QuantScanFlow(onFinish: { go(.main) }, onClose: { go(.splash) })
                .transition(.opacity)
        case .main:
            MainView(initialTab: .train)
                .transition(.opacity)
        }
    }

    private var bannerLayer: some View {
        VStack {
            if let b = model.banner {
                BannerView(banner: b)
                    .padding(.top, 6)
                    .transition(AnyTransition.move(edge: .top).combined(with: AnyTransition.opacity))
            }
            Spacer()
        }
        .animation(Motion.spring, value: model.banner?.id)
        .allowsHitTesting(false)
    }

    private func go(_ next: AppStage) {
        withAnimation(Motion.smooth) { stage = next }
    }

    private func start() {
        go(model.hasProfile ? .main : .scan)
    }

    private func demo() {
        if model.hasProfile && !model.save.isDemo {
            confirmDemo = true
        } else {
            loadDemoNow()
        }
    }

    private func loadDemoNow() {
        model.loadDemo()
        train.reset()
        go(.main)
    }
}
