import AVFoundation
import SwiftUI

@main
struct MicroDramaApp: App {
    init() {
        configurePlaybackAudioSession()
        Task {
            await AdConsentManager.shared.configureAndStartAds()
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
