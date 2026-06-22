import Foundation
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class AdConsentManager: ObservableObject {
    static let shared = AdConsentManager()

    @Published private(set) var isPrivacyOptionsRequired = false
    @Published private(set) var lastErrorMessage: String?

    private var didStartAds = false

    private init() {}

    func configureAndStartAds() async {
        await updateConsentInformation()
        await presentRequiredConsentForm()
        refreshPrivacyOptionsRequirement()
        startAdsIfAllowed()
    }

    func presentPrivacyOptions() async {
        do {
            try await presentPrivacyOptionsForm()
            refreshPrivacyOptionsRequirement()
            startAdsIfAllowed()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func updateConsentInformation() async {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        do {
            try await requestConsentInfoUpdate(with: parameters)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func presentRequiredConsentForm() async {
        do {
            try await loadAndPresentRequiredForm()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func refreshPrivacyOptionsRequirement() {
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func startAdsIfAllowed() {
        guard !didStartAds, ConsentInformation.shared.canRequestAds else { return }

        didStartAds = true
        MobileAds.shared.start()
        Task {
            await RewardedEpisodeUnlockAd.shared.loadIfNeeded()
        }
    }

    private func requestConsentInfoUpdate(with parameters: RequestParameters) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func loadAndPresentRequiredForm() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentForm.loadAndPresentIfRequired(from: nil) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func presentPrivacyOptionsForm() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentForm.presentPrivacyOptionsForm(from: nil) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
