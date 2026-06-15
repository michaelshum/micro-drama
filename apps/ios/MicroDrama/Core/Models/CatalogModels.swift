import Combine
import Foundation
import UserNotifications

struct Show: Identifiable, Decodable, Hashable {
    let id: String
    let title: String
    let description: String
    let genre: String
    let thumbnailUrl: URL?
    let posterUrl: URL
    let coverUrl: URL
    let heroTraits: [String]
    let episodeCount: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case genre
        case thumbnailUrl
        case posterUrl
        case coverUrl
        case heroTraits
        case episodeCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        genre = try container.decode(String.self, forKey: .genre)
        thumbnailUrl = try container.decodeIfPresent(URL.self, forKey: .thumbnailUrl)
        posterUrl = try container.decode(URL.self, forKey: .posterUrl)
        coverUrl = try container.decode(URL.self, forKey: .coverUrl)
        heroTraits = try container.decodeIfPresent([String].self, forKey: .heroTraits) ?? []
        episodeCount = try container.decode(Int.self, forKey: .episodeCount)
    }
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

struct HomeResponse: Decodable {
    let heroShow: Show?
    let sections: [HomeSection]
}

struct HomeSection: Identifiable, Decodable {
    let id: String
    let title: String
    let shows: [Show]
}

struct HomeRequest: Encodable {
    let onboarding: HomeOnboardingProfile?
    let excludedShowIds: [String]
}

struct HomeOnboardingProfile: Encodable {
    let selectedAnchorIds: [String]
    let selectedDealbreakerIds: [String]
    let matchedShowId: String
    let alternateShowIds: [String]
}

struct EndOfShowRecommendationRequest: Encodable {
    let sourceShowId: String
    let completedShowIds: [String]
    let activeShowIds: [String]
    let onboarding: HomeOnboardingProfile?
}

struct EndOfShowRecommendationResponse: Decodable {
    let show: Show
    let episodeId: String
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
    let playbackPath: String
    let isLocked: Bool
    let isFreePreview: Bool
    let publishedAt: Date
}

struct PlaybackTicket: Decodable {
    let playbackUrl: URL
    let expiresAt: Date?
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
        posterUrl = Self.stablePosterUrl(for: show.id)
        latestEpisodeID = episode.id
        latestEpisodeNumber = episode.episodeNumber
        self.followedAt = followedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showID = try container.decode(String.self, forKey: .showID)
        showTitle = try container.decode(String.self, forKey: .showTitle)
        showGenre = try container.decodeIfPresent(String.self, forKey: .showGenre)
        latestEpisodeID = try container.decode(String.self, forKey: .latestEpisodeID)
        latestEpisodeNumber = try container.decode(Int.self, forKey: .latestEpisodeNumber)
        followedAt = try container.decode(Date.self, forKey: .followedAt)
        posterUrl = Self.stablePosterUrl(for: showID)
    }

    private static func stablePosterUrl(for showID: String) -> URL {
        APIClient.shared.url(for: "/shows/\(showID)/poster")
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
