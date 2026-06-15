import Foundation
import SwiftUI

struct RemoteImage: View {
    let url: URL

    @State private var image: Image?
    @State private var imageURL: URL?
    @State private var loadingURL: URL?
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

            if let image, imageURL == url {
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
        let requestedURL = url
        loadingURL = requestedURL
        didFail = false

        let cacheKey = requestedURL.imageCacheKey
        if let cachedImage = ImageMemoryCache.shared.image(for: cacheKey) {
            guard loadingURL == requestedURL else { return }
            image = cachedImage
            imageURL = requestedURL
            return
        }

        var request = URLRequest(url: requestedURL)
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

            guard loadingURL == requestedURL else { return }
            image = Image(uiImage: uiImage)
            imageURL = requestedURL
        } catch where error.isCancellation {
            return
        } catch {
            guard loadingURL == requestedURL else { return }
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
    @Published private var continueWatchingThumbnailURLs: [String: URL] = [:]
    var initialEpisodeID: String?

    private let apiClient: APIClient
    private let progressStore: ShowEpisodeProgressStore
    private let tasteOnboardingStore: TasteOnboardingStore

    init(
        apiClient: APIClient = .shared,
        progressStore: ShowEpisodeProgressStore = .shared,
        tasteOnboardingStore: TasteOnboardingStore = .shared
    ) {
        self.apiClient = apiClient
        self.progressStore = progressStore
        self.tasteOnboardingStore = tasteOnboardingStore
    }

    func loadShows(forceRefresh: Bool = false) async {
        guard forceRefresh || shows.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedShows = try await apiClient.fetchShows()
            shows = fetchedShows
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
            initialEpisodeID = progressStore.activeLastWatchedEpisodeID(for: show.id)
            selectedShowDetail = try await apiClient.fetchShow(id: show.id)
            if let episode = selectedShowDetail?.episodes.first(where: { $0.id == initialEpisodeID }) {
                setLastWatchedThumbnailURL(episode.thumbnailUrl, for: show.id)
            }
        } catch where error.isCancellation {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func continueWatchingShows() -> [Show] {
        continueWatchingShows(in: shows)
    }

    private func continueWatchingShows(in shows: [Show]) -> [Show] {
        shows
            .filter { progressStore.activeLastWatchedEpisodeID(for: $0.id) != nil }
            .sorted { first, second in
                let firstDate = progressStore.activeLastWatchedAt(for: first.id) ?? .distantPast
                let secondDate = progressStore.activeLastWatchedAt(for: second.id) ?? .distantPast
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

    func heroShow() -> Show? {
        if let heroShow = homeResponse?.heroShow, canUseAsHero(heroShow) {
            return heroShow
        }

        for section in visibleHomeSections() {
            if let show = section.shows.first(where: canUseAsHero) {
                return show
            }
        }

        return shows.first(where: canUseAsHero)
    }

    func lastWatchedEpisodeNumber(for showID: String) -> Int? {
        progressStore.activeLastWatchedEpisodeNumber(for: showID)
    }

    func lastWatchedThumbnailURL(for showID: String) -> URL? {
        continueWatchingThumbnailURLs[showID]
    }

    func recordLastWatchedEpisode(_ episode: Episode, for show: ShowDetail) {
        progressStore.setLastWatchedEpisode(episode, for: show.id)
        setLastWatchedThumbnailURL(episode.thumbnailUrl, for: show.id)
    }

    private func setLastWatchedThumbnailURL(_ thumbnailURL: URL, for showID: String) {
        continueWatchingThumbnailURLs[showID] = thumbnailURL
    }

    private func loadHome() async {
        do {
            homeResponse = try await apiClient.fetchHome(request: homeRequest())
            applyContinueWatchingThumbnails(homeResponse?.continueWatchingThumbnails ?? [])
        } catch where error.isCancellation {
            return
        } catch {
            homeResponse = nil
        }
    }

    private func applyContinueWatchingThumbnails(_ thumbnails: [ContinueWatchingThumbnail]) {
        for thumbnail in thumbnails {
            guard progressStore.activeLastWatchedEpisodeID(for: thumbnail.showId) == thumbnail.episodeId else {
                continue
            }

            continueWatchingThumbnailURLs[thumbnail.showId] = thumbnail.thumbnailUrl
        }
    }

    private func homeRequest() -> HomeRequest {
        let continueWatchingShows = continueWatchingShows()
        let activeShowIDs = continueWatchingShows.map(\.id)
        let heroExcludedShowIDs = Array(Set(activeShowIDs + progressStore.completedShowIDs()))

        return HomeRequest(
            onboarding: tasteOnboardingStore.profile.map { profile in
                HomeOnboardingProfile(
                    selectedAnchorIds: profile.selectedAnchorIDs,
                    selectedDealbreakerIds: profile.selectedDealbreakerIDs,
                    matchedShowId: profile.matchedShowID,
                    alternateShowIds: profile.alternateShowIDs
                )
            },
            excludedShowIds: activeShowIDs,
            heroExcludedShowIds: heroExcludedShowIDs,
            continueWatchingEpisodes: continueWatchingShows.compactMap { show in
                guard let episodeId = progressStore.activeLastWatchedEpisodeID(for: show.id) else {
                    return nil
                }

                return HomeContinueWatchingEpisode(showId: show.id, episodeId: episodeId)
            }
        )
    }

    private func canUseAsHero(_ show: Show) -> Bool {
        progressStore.activeLastWatchedEpisodeID(for: show.id) == nil && !progressStore.hasCompletedShow(show.id)
    }

    func markShowCompleted(_ show: ShowDetail) {
        progressStore.markShowCompleted(showID: show.id)
        continueWatchingThumbnailURLs.removeValue(forKey: show.id)
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
    private let completedShowsStorageKey = "completedShowTimestamps"
    private let lastWatchedStorageKey = "lastWatchedEpisode"
    private let legacyStorageKey = "showLastWatchedEpisodeIDs"
    private let initialExperienceSeenKey = "initialExperienceSeen"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func lastWatchedEpisodeID(for showID: String) -> String? {
        allProgress()[showID]?.episodeID ?? legacyProgress()[showID]
    }

    func activeLastWatchedEpisodeID(for showID: String) -> String? {
        if let progress = allProgress()[showID], isActiveProgress(progress, for: showID) {
            return progress.episodeID
        }

        guard !hasCompletedShow(showID) else { return nil }
        return legacyProgress()[showID]
    }

    func lastWatchedEpisodeNumber(for showID: String) -> Int? {
        allProgress()[showID]?.episodeNumber
    }

    func activeLastWatchedEpisodeNumber(for showID: String) -> Int? {
        guard let progress = allProgress()[showID], isActiveProgress(progress, for: showID) else {
            return nil
        }

        return progress.episodeNumber
    }

    func lastWatchedAt(for showID: String) -> Date? {
        allProgress()[showID]?.watchedAt
    }

    func activeLastWatchedAt(for showID: String) -> Date? {
        guard let progress = allProgress()[showID], isActiveProgress(progress, for: showID) else {
            return nil
        }

        return progress.watchedAt
    }

    func recentlyWatchedEpisode(maxAge: TimeInterval, now: Date = Date()) -> LastWatchedEpisode? {
        guard let lastWatchedEpisode,
              now.timeIntervalSince(lastWatchedEpisode.watchedAt) <= maxAge,
              isActiveProgress(lastWatchedEpisode.watchedAt, for: lastWatchedEpisode.showID) else {
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

    func hasCompletedShow(_ showID: String) -> Bool {
        completedShowTimestamps()[showID] != nil
    }

    func completedShowIDs() -> [String] {
        Array(completedShowTimestamps().keys)
    }

    func activeShowIDs() -> [String] {
        allProgress()
            .filter { showID, progress in
                isActiveProgress(progress, for: showID)
            }
            .map(\.key)
    }

    func markInitialExperienceSeen() {
        defaults.set(true, forKey: initialExperienceSeenKey)
    }

    func markShowCompleted(showID: String, completedAt: Date = Date()) {
        var completedShows = completedShowTimestamps()
        completedShows[showID] = completedAt
        persistCompletedShowTimestamps(completedShows)
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

    private func completedShowTimestamps() -> [String: Date] {
        guard let data = defaults.data(forKey: completedShowsStorageKey),
              let completedShows = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }

        return completedShows
    }

    private func persistCompletedShowTimestamps(_ completedShows: [String: Date]) {
        guard let data = try? JSONEncoder().encode(completedShows) else { return }
        defaults.set(data, forKey: completedShowsStorageKey)
    }

    private func isActiveProgress(_ progress: ShowEpisodeProgress, for showID: String) -> Bool {
        isActiveProgress(progress.watchedAt, for: showID)
    }

    private func isActiveProgress(_ watchedAt: Date, for showID: String) -> Bool {
        guard let completedAt = completedShowTimestamps()[showID] else {
            return true
        }

        return watchedAt > completedAt
    }

    private func legacyProgress() -> [String: String] {
        defaults.dictionary(forKey: legacyStorageKey) as? [String: String] ?? [:]
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
                            let heroShow = viewModel.heroShow()

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
                    onEpisodeChanged: { episode, show in
                        viewModel.recordLastWatchedEpisode(episode, for: show)
                    },
                    onShowCompleted: { show in
                        viewModel.markShowCompleted(show)
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

    private let posterAspectRatio: CGFloat = 0.78

    var body: some View {
        VStack(spacing: 0) {
            posterImage
            heroActions
        }
        .background(Color(white: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.34), lineWidth: 1)
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private var posterImage: some View {
        Color.clear
            .aspectRatio(posterAspectRatio, contentMode: .fit)
            .overlay {
                RemoteImage(url: show.thumbnailUrl ?? show.coverUrl)
                    .clipped()
            }
            .overlay(alignment: .bottom) {
                heroTraits
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
            .clipped()
    }

    private var heroActions: some View {
        Button(action: onOpen) {
            Label("Play", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(.white, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    private var heroTraits: some View {
        Text(heroTraitText)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .lineSpacing(2)
            .minimumScaleFactor(0.86)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 44)
        .background(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.22), location: 0.48),
                    .init(color: .black.opacity(0.74), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .padding(.horizontal, -14)
            .padding(.bottom, -10)
        }
    }

    private var heroTraitText: String {
        let traits = show.heroTraits.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !traits.isEmpty else { return show.genre }
        return traits.prefix(4).joined(separator: " • ")
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
