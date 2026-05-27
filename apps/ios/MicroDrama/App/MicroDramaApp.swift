import GoogleMobileAds
import SwiftUI

@main
struct MicroDramaApp: App {
    init() {
        MobileAds.shared.start()
        Task {
            await RewardedEpisodeUnlockAd.shared.loadIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
