import Foundation
import SwiftUI

struct RemoteImage: View {
    let url: URL

    @State private var image: Image?
    @State private var didFail = false

    static func prefetch(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    await prefetch(url: url)
                }
            }
        }
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)

            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else if didFail {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        let cacheKey = url.imageCacheKey
        if let cachedImage = ImageMemoryCache.shared.image(for: cacheKey) {
            image = cachedImage
            didFail = false
            return
        }

        didFail = false

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let uiImage = UIImage(data: data) else {
                didFail = true
                return
            }

            ImageMemoryCache.shared.insert(uiImage, for: cacheKey)
            if let responseUrl = httpResponse.url {
                ImageMemoryCache.shared.insert(uiImage, for: responseUrl.imageCacheKey)
            }
            image = Image(uiImage: uiImage)
        } catch where error.isCancellation {
            return
        } catch {
            didFail = true
        }
    }

    private static func prefetch(url: URL) async {
        let cacheKey = url.imageCacheKey
        if ImageMemoryCache.shared.hasImage(for: cacheKey) {
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let uiImage = UIImage(data: data) else {
                return
            }

            ImageMemoryCache.shared.insert(uiImage, for: cacheKey)
            if let responseUrl = httpResponse.url {
                ImageMemoryCache.shared.insert(uiImage, for: responseUrl.imageCacheKey)
            }
        } catch {
            return
        }
    }
}

@MainActor
private final class ImageMemoryCache {
    static let shared = ImageMemoryCache()

    private var cache: [String: UIImage] = [:]

    func image(for key: String) -> Image? {
        cache[key].map(Image.init(uiImage:))
    }

    func hasImage(for key: String) -> Bool {
        cache[key] != nil
    }

    func insert(_ image: UIImage, for key: String) {
        cache[key] = image
    }
}

extension URL {
    var imageCacheKey: String {
        if let streamThumbnailKey {
            return streamThumbnailKey
        }

        return absoluteString
    }

    private var streamThumbnailKey: String? {
        guard let host,
              host == "videodelivery.net" || host.hasSuffix(".cloudflarestream.com") else {
            return nil
        }

        let components = pathComponents
        guard components.count >= 4,
              components[components.count - 2] == "thumbnails",
              components[components.count - 1] == "thumbnail.jpg" else {
            return nil
        }

        let tokenOrUid = components[1]
        let videoUid = Self.videoUid(fromStreamToken: tokenOrUid) ?? tokenOrUid
        return "cloudflare-stream-thumbnail:\(videoUid)"
    }

    private static func videoUid(fromStreamToken token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = payload.count % 4
        if padding > 0 {
            payload += String(repeating: "=", count: 4 - padding)
        }

        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subject = object["sub"] as? String,
              !subject.isEmpty else {
            return nil
        }

        return subject
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var shows: [Show] = []
    @Published var homeResponse: HomeResponse?
    @Published var selectedShowDetail: ShowDetail?
    @Published var errorMessage: String?
    @Published var isLoading = false
    var initialEpisodeID: String?

    private let apiClient: APIClient
    private let progressStore: ShowEpisodeProgressStore
    private let episodeThumbnailStore: LastWatchedEpisodeThumbnailStore
    private let tasteOnboardingStore: TasteOnboardingStore

    init(
        apiClient: APIClient = .shared,
        progressStore: ShowEpisodeProgressStore = .shared,
        episodeThumbnailStore: LastWatchedEpisodeThumbnailStore = .shared,
        tasteOnboardingStore: TasteOnboardingStore = .shared
    ) {
        self.apiClient = apiClient
        self.progressStore = progressStore
        self.episodeThumbnailStore = episodeThumbnailStore
        self.tasteOnboardingStore = tasteOnboardingStore
    }

    func loadShows(forceRefresh: Bool = false) async {
        guard forceRefresh || shows.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            shows = try await apiClient.fetchShows()
            await loadHome()
        } catch where error.isCancellation {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func open(_ show: Show) async {
        isLoading = true
        defer { isLoading = false }

        do {
            initialEpisodeID = progressStore.lastWatchedEpisodeID(for: show.id)
            selectedShowDetail = try await apiClient.fetchShow(id: show.id)
            if let episode = selectedShowDetail?.episodes.first(where: { $0.id == initialEpisodeID }) {
                episodeThumbnailStore.setThumbnailURL(episode.thumbnailUrl, for: show.id)
            }
        } catch where error.isCancellation {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func continueWatchingShows() -> [Show] {
        shows
            .filter { progressStore.lastWatchedEpisodeID(for: $0.id) != nil }
            .sorted { first, second in
                let firstDate = progressStore.lastWatchedAt(for: first.id) ?? .distantPast
                let secondDate = progressStore.lastWatchedAt(for: second.id) ?? .distantPast
                return firstDate > secondDate
            }
    }

    func fallbackHomeSections() -> [HomeSection] {
        [HomeSection(id: "all-shows", title: "All Shows", shows: shows)]
    }

    func visibleHomeSections() -> [HomeSection] {
        let continueWatchingShowIDs = Set(continueWatchingShows().map(\.id))
        let sections = homeResponse?.sections ?? fallbackHomeSections()

        return sections.compactMap { section in
            let visibleShows = section.shows.filter { !continueWatchingShowIDs.contains($0.id) }
            guard !visibleShows.isEmpty else { return nil }

            return HomeSection(id: section.id, title: section.title, shows: visibleShows)
        }
    }

    func lastWatchedEpisodeNumber(for showID: String) -> Int? {
        progressStore.lastWatchedEpisodeNumber(for: showID)
    }

    func lastWatchedThumbnailURL(for showID: String) -> URL? {
        episodeThumbnailStore.thumbnailURL(for: showID)
    }

    func recordLastWatchedEpisode(_ episode: Episode, for show: ShowDetail) {
        progressStore.setLastWatchedEpisode(episode, for: show.id)
        episodeThumbnailStore.setThumbnailURL(episode.thumbnailUrl, for: show.id)
    }

    private func loadHome() async {
        do {
            homeResponse = try await apiClient.fetchHome(request: homeRequest())
        } catch where error.isCancellation {
            return
        } catch {
            homeResponse = nil
        }
    }

    private func homeRequest() -> HomeRequest {
        HomeRequest(
            onboarding: tasteOnboardingStore.profile.map { profile in
                HomeOnboardingProfile(
                    selectedAnchorIds: profile.selectedAnchorIDs,
                    selectedDealbreakerIds: profile.selectedDealbreakerIDs,
                    matchedShowId: profile.matchedShowID,
                    alternateShowIds: profile.alternateShowIDs
                )
            },
            excludedShowIds: continueWatchingShows().map(\.id)
        )
    }
}

private extension Error {
    var isCancellation: Bool {
        if self is CancellationError {
            return true
        }

        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

struct ShowEpisodeProgress: Codable {
    let episodeID: String
    let episodeNumber: Int
    let watchedAt: Date

    init(episodeID: String, episodeNumber: Int, watchedAt: Date = Date()) {
        self.episodeID = episodeID
        self.episodeNumber = episodeNumber
        self.watchedAt = watchedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episodeID = try container.decode(String.self, forKey: .episodeID)
        episodeNumber = try container.decode(Int.self, forKey: .episodeNumber)
        watchedAt = try container.decodeIfPresent(Date.self, forKey: .watchedAt) ?? .distantPast
    }
}

struct LastWatchedEpisode: Codable {
    let showID: String
    let episodeID: String
    let episodeNumber: Int
    let watchedAt: Date
}

final class ShowEpisodeProgressStore {
    static let shared = ShowEpisodeProgressStore()

    private let defaults: UserDefaults
    private let storageKey = "showLastWatchedEpisodeProgress"
    private let lastWatchedStorageKey = "lastWatchedEpisode"
    private let legacyStorageKey = "showLastWatchedEpisodeIDs"
    private let initialExperienceSeenKey = "initialExperienceSeen"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func lastWatchedEpisodeID(for showID: String) -> String? {
        allProgress()[showID]?.episodeID ?? legacyProgress()[showID]
    }

    func lastWatchedEpisodeNumber(for showID: String) -> Int? {
        allProgress()[showID]?.episodeNumber
    }

    func lastWatchedAt(for showID: String) -> Date? {
        allProgress()[showID]?.watchedAt
    }

    func recentlyWatchedEpisode(maxAge: TimeInterval, now: Date = Date()) -> LastWatchedEpisode? {
        guard let lastWatchedEpisode,
              now.timeIntervalSince(lastWatchedEpisode.watchedAt) <= maxAge else {
            return nil
        }

        return lastWatchedEpisode
    }

    var hasSeenInitialExperience: Bool {
        defaults.bool(forKey: initialExperienceSeenKey)
    }

    var hasWatchHistory: Bool {
        !allProgress().isEmpty || !legacyProgress().isEmpty || lastWatchedEpisode != nil
    }

    func markInitialExperienceSeen() {
        defaults.set(true, forKey: initialExperienceSeenKey)
    }

    func setLastWatchedEpisode(_ episode: Episode, for showID: String) {
        var progress = allProgress()
        progress[showID] = ShowEpisodeProgress(
            episodeID: episode.id,
            episodeNumber: episode.episodeNumber
        )

        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: storageKey)
        setLastWatchedEpisode(
            LastWatchedEpisode(
                showID: showID,
                episodeID: episode.id,
                episodeNumber: episode.episodeNumber,
                watchedAt: Date()
            )
        )
    }

    private var lastWatchedEpisode: LastWatchedEpisode? {
        guard let data = defaults.data(forKey: lastWatchedStorageKey) else { return nil }
        return try? JSONDecoder().decode(LastWatchedEpisode.self, from: data)
    }

    private func setLastWatchedEpisode(_ episode: LastWatchedEpisode) {
        guard let data = try? JSONEncoder().encode(episode) else { return }
        defaults.set(data, forKey: lastWatchedStorageKey)
    }

    private func allProgress() -> [String: ShowEpisodeProgress] {
        guard let data = defaults.data(forKey: storageKey),
              let progress = try? JSONDecoder().decode([String: ShowEpisodeProgress].self, from: data) else {
            return [:]
        }

        return progress
    }

    private func legacyProgress() -> [String: String] {
        defaults.dictionary(forKey: legacyStorageKey) as? [String: String] ?? [:]
    }
}

final class LastWatchedEpisodeThumbnailStore {
    static let shared = LastWatchedEpisodeThumbnailStore()

    private let defaults: UserDefaults
    private let storageKey = "showLastWatchedEpisodeThumbnailURLs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func thumbnailURL(for showID: String) -> URL? {
        allThumbnailURLs()[showID].flatMap(URL.init(string:))
    }

    func setThumbnailURL(_ thumbnailURL: URL, for showID: String) {
        var thumbnailURLs = allThumbnailURLs()
        thumbnailURLs[showID] = thumbnailURL.absoluteString
        defaults.set(thumbnailURLs, forKey: storageKey)
    }

    private func allThumbnailURLs() -> [String: String] {
        defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.shows.isEmpty {
                    ZStack {
                        Color.black.ignoresSafeArea()

                        ProgressView()
                            .tint(.white)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            let continueWatchingShows = viewModel.continueWatchingShows()
                            let homeSections = viewModel.visibleHomeSections()
                            let heroShow = viewModel.homeResponse?.heroShow ?? continueWatchingShows.first ?? viewModel.shows.first

                            if let heroShow {
                                HomeHeroSection(show: heroShow) {
                                    Task {
                                        await viewModel.open(heroShow)
                                    }
                                }
                            }

                            if !continueWatchingShows.isEmpty {
                                HomeRailSection(title: "Continue Watching") {
                                    ForEach(continueWatchingShows.prefix(8)) { show in
                                        Button {
                                            Task {
                                                await viewModel.open(show)
                                            }
                                        } label: {
                                            ContinueWatchingCard(
                                                show: show,
                                                episodeNumber: viewModel.lastWatchedEpisodeNumber(for: show.id),
                                                thumbnailURL: viewModel.lastWatchedThumbnailURL(for: show.id)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            ForEach(homeSections) { section in
                                HomeRailSection(title: section.title) {
                                    ForEach(section.shows) { show in
                                        Button {
                                            Task {
                                                await viewModel.open(show)
                                            }
                                        } label: {
                                            HomePosterRailCard(show: show)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .background(Color.black)
                    .scrollBounceBehavior(.always, axes: .vertical)
                    .refreshable {
                        await viewModel.loadShows(forceRefresh: true)
                    }
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                    initialEpisodeID: viewModel.initialEpisodeID,
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

private struct HomeHeroSection: View {
    let show: Show
    let onOpen: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: show.coverUrl)
                .frame(maxWidth: .infinity)
                .frame(height: 430)
                .clipped()
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.1), location: 0),
                            .init(color: .black.opacity(0.25), location: 0.42),
                            .init(color: .black.opacity(0.95), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(show.title)
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(show.genre) • \(show.episodeCount) episodes")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }

                Button(action: onOpen) {
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.black)
    }
}

private struct HomeRailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    content()
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct HomePosterRailCard: View {
    let show: Show

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            posterImage

            Text(show.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .lineSpacing(1)
                .multilineTextAlignment(.leading)
                .frame(width: 118, alignment: .leading)
        }
        .frame(width: 118, alignment: .leading)
    }

    private var posterImage: some View {
        RemoteImage(url: show.thumbnailUrl ?? show.posterUrl)
            .frame(width: 118, height: 164)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct ContinueWatchingCard: View {
    let show: Show
    let episodeNumber: Int?
    let thumbnailURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            posterImage

            VStack(alignment: .leading, spacing: 3) {
                Text(show.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(episodeNumber.map { "Episode \($0)" } ?? "Keep watching")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }
        }
        .frame(width: 150, alignment: .leading)
    }

    private var posterImage: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: thumbnailURL ?? show.thumbnailUrl ?? show.posterUrl)
                .frame(width: 150, height: 208)
                .clipped()

            GeometryReader { proxy in
                Rectangle()
                    .fill(.red)
                    .frame(width: progressWidth(in: proxy.size.width), height: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func progressWidth(in posterWidth: CGFloat) -> CGFloat {
        guard let episodeNumber, show.episodeCount > 0 else {
            return posterWidth * 0.12
        }

        return posterWidth * min(CGFloat(episodeNumber) / CGFloat(show.episodeCount), 1)
    }
}

private struct ShowPosterCard: View {
    let show: Show

    private let posterAspectRatio: CGFloat = 108 / 150

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            posterImage

            Text(show.title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .lineSpacing(1)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var posterImage: some View {
        GeometryReader { proxy in
            let posterWidth = proxy.size.width
            let posterHeight = posterWidth / posterAspectRatio

            RemoteImage(url: show.posterUrl)
            .frame(width: posterWidth, height: posterHeight)
            .clipped()
        }
        .aspectRatio(posterAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
