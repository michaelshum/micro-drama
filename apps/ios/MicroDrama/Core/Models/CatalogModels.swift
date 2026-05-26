import Combine
import Foundation

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

struct SavedEpisode: Identifiable, Codable, Hashable {
    var id: String { episodeID }

    let episodeID: String
    let showID: String
    let showTitle: String
    let episodeNumber: Int
    let episodeTitle: String
    let episodeDescription: String
    let durationSeconds: Int
    let thumbnailUrl: URL
    let posterUrl: URL
    let savedAt: Date

    init(show: ShowDetail, episode: Episode, savedAt: Date = Date()) {
        episodeID = episode.id
        showID = show.id
        showTitle = show.title
        episodeNumber = episode.episodeNumber
        episodeTitle = episode.title
        episodeDescription = episode.description
        durationSeconds = episode.durationSeconds
        thumbnailUrl = episode.thumbnailUrl
        posterUrl = show.posterUrl
        self.savedAt = savedAt
    }
}

@MainActor
final class MyListEpisodeStore: ObservableObject {
    static let shared = MyListEpisodeStore()

    @Published private(set) var savedEpisodes: [SavedEpisode]

    private let defaults: UserDefaults
    private let storageKey = "savedEpisodes"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        savedEpisodes = Self.loadSavedEpisodes(from: defaults, key: storageKey)
    }

    func isSaved(_ episode: Episode) -> Bool {
        savedEpisodes.contains { $0.episodeID == episode.id }
    }

    func toggle(show: ShowDetail, episode: Episode) {
        if isSaved(episode) {
            remove(episodeID: episode.id)
        } else {
            save(show: show, episode: episode)
        }
    }

    func save(show: ShowDetail, episode: Episode) {
        let savedEpisode = SavedEpisode(show: show, episode: episode)
        savedEpisodes.removeAll { $0.episodeID == episode.id }
        savedEpisodes.insert(savedEpisode, at: 0)
        persist()
    }

    func remove(episodeID: String) {
        savedEpisodes.removeAll { $0.episodeID == episodeID }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(savedEpisodes) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadSavedEpisodes(from defaults: UserDefaults, key: String) -> [SavedEpisode] {
        guard let data = defaults.data(forKey: key),
              let episodes = try? JSONDecoder().decode([SavedEpisode].self, from: data) else {
            return []
        }

        return episodes.sorted { $0.savedAt > $1.savedAt }
    }
}
