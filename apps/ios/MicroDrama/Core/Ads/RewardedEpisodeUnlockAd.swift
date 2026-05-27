import Foundation
import GoogleMobileAds

@MainActor
final class RewardedEpisodeUnlockAd: NSObject, ObservableObject {
    static let shared = RewardedEpisodeUnlockAd()

    #if DEBUG
    private static let adUnitID = "ca-app-pub-3940256099942544/1712485313"
    #else
    private static let adUnitID = "ca-app-pub-5924087528126044/5815113239"
    #endif

    @Published private(set) var isReady = false
    @Published private(set) var isLoading = false
    @Published private(set) var lastErrorMessage: String?

    private var rewardedAd: RewardedAd?
    private var didRequestReloadAfterPresentation = false

    private override init() {
        super.init()
    }

    func loadIfNeeded() async {
        guard rewardedAd == nil, !isLoading else { return }

        isLoading = true
        lastErrorMessage = nil

        do {
            let ad = try await RewardedAd.load(
                with: Self.adUnitID,
                request: Request()
            )
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
            isReady = true
        } catch {
            lastErrorMessage = error.localizedDescription
            isReady = false
        }

        isLoading = false
    }

    func show(onRewardEarned: @escaping () -> Void) {
        guard let rewardedAd else {
            lastErrorMessage = "The rewarded ad is still loading. Please try again in a moment."
            Task {
                await loadIfNeeded()
            }
            return
        }

        self.rewardedAd = nil
        isReady = false
        didRequestReloadAfterPresentation = false

        rewardedAd.present(from: nil) {
            onRewardEarned()
        }
    }

    private func reloadAfterPresentation() {
        guard !didRequestReloadAfterPresentation else { return }

        didRequestReloadAfterPresentation = true
        Task {
            await loadIfNeeded()
        }
    }
}

extension RewardedEpisodeUnlockAd: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        reloadAfterPresentation()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        lastErrorMessage = error.localizedDescription
        reloadAfterPresentation()
    }
}
