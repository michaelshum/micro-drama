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

