import SwiftUI

@MainActor
final class RootTabViewModel: ObservableObject {
    @Published var initialShowDetail: ShowDetail?
    @Published var isPreparingInitialExperience = true
    var initialEpisodeID: String?

    private let apiClient: APIClient
    private let progressStore: ShowEpisodeProgressStore
    private var didAttemptInitialExperience = false
    private let recentResumeInterval: TimeInterval = 60 * 60

    init(
        apiClient: APIClient = .shared,
        progressStore: ShowEpisodeProgressStore = .shared
    ) {
        self.apiClient = apiClient
        self.progressStore = progressStore
    }

    func openInitialExperienceIfNeeded() async {
        guard !didAttemptInitialExperience else {
            isPreparingInitialExperience = false
            return
        }
        didAttemptInitialExperience = true
        defer { isPreparingInitialExperience = false }

        do {
            if let recentlyWatchedEpisode = progressStore.recentlyWatchedEpisode(maxAge: recentResumeInterval) {
                try await openRecentResumeIfPlayable(recentlyWatchedEpisode)
                return
            }

            guard !progressStore.hasSeenInitialExperience,
                  !progressStore.hasWatchHistory else {
                return
            }

            let config = try await apiClient.fetchConfig()
            guard let initialExperience = config.initialExperience,
                  initialExperience.enabled else {
                return
            }

            try await openStartupPlayer(
                showID: initialExperience.showId,
                preferredEpisodeID: initialExperience.episodeId,
                allowsLockedPreferredEpisode: false
            )
            if initialShowDetail != nil {
                progressStore.markInitialExperienceSeen()
            }
        } catch {
            return
        }
    }

    func recordLastWatchedEpisode(_ episode: Episode, for show: ShowDetail) {
        progressStore.setLastWatchedEpisode(episode, for: show.id)
    }

    private func firstPlayableEpisodeID(in showDetail: ShowDetail) -> String? {
        showDetail.episodes.first { !$0.isLocked }?.id
    }

    private func openRecentResumeIfPlayable(_ recentlyWatchedEpisode: LastWatchedEpisode) async throws {
        let showDetail = try await apiClient.fetchShow(id: recentlyWatchedEpisode.showID)
        guard showDetail.episodes.contains(where: { episode in
            episode.id == recentlyWatchedEpisode.episodeID && !episode.isLocked
        }) else {
            return
        }

        initialEpisodeID = recentlyWatchedEpisode.episodeID
        initialShowDetail = showDetail
    }

    private func openStartupPlayer(
        showID: String,
        preferredEpisodeID: String?,
        allowsLockedPreferredEpisode: Bool
    ) async throws {
        let showDetail = try await apiClient.fetchShow(id: showID)
        initialEpisodeID = preferredEpisodeID.flatMap { episodeID in
            showDetail.episodes.contains { episode in
                episode.id == episodeID && (allowsLockedPreferredEpisode || !episode.isLocked)
            } ? episodeID : nil
        } ?? firstPlayableEpisodeID(in: showDetail)

        guard initialEpisodeID != nil else { return }
        initialShowDetail = showDetail
    }
}

struct RootTabView: View {
    @StateObject private var viewModel = RootTabViewModel()

    var body: some View {
        Group {
            if viewModel.shouldShowStartupSplash {
                StartupSplashView()
            } else {
                TabView {
                    HomeView()
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }

                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle")
                        }
                }
            }
        }
        .task {
            await viewModel.openInitialExperienceIfNeeded()
        }
        .fullScreenCover(item: $viewModel.initialShowDetail) { showDetail in
            EpisodePlayerView(
                show: showDetail,
                initialEpisodeID: viewModel.initialEpisodeID,
                onEpisodeChanged: { episode in
                    viewModel.recordLastWatchedEpisode(episode, for: showDetail)
                }
            )
        }
    }
}

private extension RootTabViewModel {
    var shouldShowStartupSplash: Bool {
        isPreparingInitialExperience || initialShowDetail != nil
    }
}

private struct StartupSplashView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .accessibilityLabel("MicroDrama")

                ProgressView()
                    .tint(.white)
            }
        }
    }
}
