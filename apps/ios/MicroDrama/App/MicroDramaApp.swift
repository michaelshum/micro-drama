import AVFoundation
import GoogleMobileAds
import SwiftUI

@main
struct MicroDramaApp: App {
    init() {
        configurePlaybackAudioSession()
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

    private func configurePlaybackAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            assertionFailure("Unable to configure playback audio session: \(error.localizedDescription)")
        }
    }
}
