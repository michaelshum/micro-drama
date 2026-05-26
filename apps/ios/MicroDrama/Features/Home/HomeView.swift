import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var shows: [Show] = []
    @Published var selectedShowDetail: ShowDetail?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let apiClient: APIClient
    private let progressStore: ShowEpisodeProgressStore

    init(apiClient: APIClient = .shared, progressStore: ShowEpisodeProgressStore = .shared) {
        self.apiClient = apiClient
        self.progressStore = progressStore
    }

    func loadShows(forceRefresh: Bool = false) async {
        guard forceRefresh || shows.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            shows = try await apiClient.fetchShows()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func open(_ show: Show) async {
        isLoading = true
        defer { isLoading = false }

        do {
            selectedShowDetail = try await apiClient.fetchShow(id: show.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func lastWatchedEpisodeID(for showID: String) -> String? {
        progressStore.lastWatchedEpisodeID(for: showID)
    }

    func recordLastWatchedEpisode(_ episode: Episode, for show: ShowDetail) {
        progressStore.setLastWatchedEpisodeID(episode.id, for: show.id)
    }
}

final class ShowEpisodeProgressStore {
    static let shared = ShowEpisodeProgressStore()

    private let defaults: UserDefaults
    private let storageKey = "showLastWatchedEpisodeIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func lastWatchedEpisodeID(for showID: String) -> String? {
        allProgress()[showID]
    }

    func setLastWatchedEpisodeID(_ episodeID: String, for showID: String) {
        var progress = allProgress()
        progress[showID] = episodeID
        defaults.set(progress, forKey: storageKey)
    }

    private func allProgress() -> [String: String] {
        defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    private let showGridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
        count: 3
    )

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.shows.isEmpty {
                    ProgressView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: showGridColumns, alignment: .leading, spacing: 16) {
                            ForEach(viewModel.shows) { show in
                                Button {
                                    Task {
                                        await viewModel.open(show)
                                    }
                                } label: {
                                    ShowPosterCard(show: show)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        await viewModel.loadShows(forceRefresh: true)
                    }
                }
            }
            .navigationTitle("Shows")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ShowSearchView()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search")
                }
            }
            .task {
                await viewModel.loadShows()
            }
            .alert("Unable to load", isPresented: errorAlertBinding) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .fullScreenCover(item: $viewModel.selectedShowDetail) { showDetail in
                EpisodePlayerView(
                    show: showDetail,
                    initialEpisodeID: viewModel.lastWatchedEpisodeID(for: showDetail.id),
                    onEpisodeChanged: { episode in
                        viewModel.recordLastWatchedEpisode(episode, for: showDetail)
                    }
                )
            }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.errorMessage = nil
            }
        }
    }
}

private struct ShowPosterCard: View {
    let show: Show

    private let posterAspectRatio: CGFloat = 108 / 150

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            posterImage

            Text(show.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var posterImage: some View {
        GeometryReader { proxy in
            let posterWidth = proxy.size.width
            let posterHeight = posterWidth / posterAspectRatio

            AsyncImage(url: show.posterUrl) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Rectangle().fill(.quaternary)
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        Rectangle().fill(.quaternary)
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: posterWidth, height: posterHeight)
            .clipped()
        }
        .aspectRatio(posterAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
