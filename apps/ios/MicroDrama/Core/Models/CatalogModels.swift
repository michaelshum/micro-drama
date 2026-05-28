import Combine
import Foundation
import UserNotifications

struct Show: Identifiable, Decodable, Hashable {
    let id: String
    let title: String
    let description: String
    let genre: String
    let posterUrl: URL
    let coverUrl: URL
    let episodeCount: Int
}

struct ShowDetail: Identifiable, Decodable {
    let id: String
    let title: String
    let description: String
    let genre: String
    let posterUrl: URL
    let coverUrl: URL
    let episodeCount: Int
    let episodes: [Episode]
}

struct Episode: Identifiable, Decodable, Hashable {
    let id: String
    let showId: String
    let showTitle: String
    let episodeNumber: Int
    let title: String
    let description: String
    let durationSeconds: Int
    let thumbnailUrl: URL
    let playbackUrl: URL
    let isLocked: Bool
    let isFreePreview: Bool
    let publishedAt: Date
}

struct AppConfig: Decodable {
    let name: String
    let minimumSupportedVersion: String
    let defaultFeed: String
    let initialExperience: InitialExperienceConfig?
}

struct InitialExperienceConfig: Decodable {
    let enabled: Bool
    let showId: String
    let episodeId: String?
}

struct FollowedShow: Identifiable, Codable, Hashable {
    var id: String { showID }

    let showID: String
    let showTitle: String
    let showGenre: String?
    let posterUrl: URL
    let latestEpisodeID: String
    let latestEpisodeNumber: Int
    let followedAt: Date

    init(show: ShowDetail, episode: Episode, followedAt: Date = Date()) {
        showID = show.id
        showTitle = show.title
        showGenre = show.genre
        posterUrl = show.posterUrl
        latestEpisodeID = episode.id
        latestEpisodeNumber = episode.episodeNumber
        self.followedAt = followedAt
    }
}

@MainActor
final class FollowedShowStore: ObservableObject {
    static let shared = FollowedShowStore()

    @Published private(set) var followedShows: [FollowedShow]

    private let defaults: UserDefaults
    private let storageKey = "followedShows"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        followedShows = Self.loadFollowedShows(from: defaults, key: storageKey)
    }

    func isFollowing(_ show: ShowDetail) -> Bool {
        followedShows.contains { $0.showID == show.id }
    }

    @discardableResult
    func toggle(show: ShowDetail, episode: Episode) -> Bool {
        if isFollowing(show) {
            remove(showID: show.id)
            return false
        } else {
            follow(show: show, episode: episode)
            return true
        }
    }

    func follow(show: ShowDetail, episode: Episode) {
        let followedShow = FollowedShow(show: show, episode: episode)
        followedShows.removeAll { $0.showID == show.id }
        followedShows.insert(followedShow, at: 0)
        persist()
    }

    func remove(showID: String) {
        followedShows.removeAll { $0.showID == showID }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(followedShows) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadFollowedShows(from defaults: UserDefaults, key: String) -> [FollowedShow] {
        guard let data = defaults.data(forKey: key),
              let shows = try? JSONDecoder().decode([FollowedShow].self, from: data) else {
            return []
        }

        return shows.sorted { $0.followedAt > $1.followedAt }
    }
}

@MainActor
final class NotificationPermissionStore: ObservableObject {
    static let shared = NotificationPermissionStore()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isRequesting = false

    private let defaults: UserDefaults
    private let softAskShownKey = "notificationSoftAskShown"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var canShowSoftAsk: Bool {
        authorizationStatus == .notDetermined && !hasShownSoftAsk
    }

    var shouldShowCTA: Bool {
        authorizationStatus != .authorized && authorizationStatus != .provisional && authorizationStatus != .ephemeral
    }

    private var hasShownSoftAsk: Bool {
        defaults.bool(forKey: softAskShownKey)
    }

    func markSoftAskShown() {
        defaults.set(true, forKey: softAskShownKey)
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async {
        markSoftAskShown()
        isRequesting = true
        defer { isRequesting = false }

        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthorizationStatus()
    }
}
