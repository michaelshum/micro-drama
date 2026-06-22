import Foundation

enum APIError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        }
    }
}

enum OndaWebLinks {
    static let baseURL = URL(string: "https://onda-micro-drama.vercel.app")!
    static let privacyPolicyURL = baseURL.appending(path: "privacy")
    static let termsOfServiceURL = baseURL.appending(path: "terms")
}

struct APIClient {
    static let shared = APIClient()

    private static let productionBaseURL = URL(string: "https://micro-drama.onrender.com")!

    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL ?? Self.bundleBaseURL() ?? Self.productionBaseURL
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        encoder = JSONEncoder()
    }

    func fetchConfig() async throws -> AppConfig {
        try await fetch("/config")
    }

    func fetchTasteAnchors() async throws -> [TasteAnchor] {
        try await fetch("/taste-anchors")
    }

    func fetchShows() async throws -> [Show] {
        try await fetch("/shows")
    }

    func fetchHome(request: HomeRequest) async throws -> HomeResponse {
        try await post("/home", body: request)
    }

    func fetchEndOfShowRecommendation(request: EndOfShowRecommendationRequest) async throws -> EndOfShowRecommendationResponse {
        try await post("/recommendations/end-of-show", body: request)
    }

    func fetchMoreLikeThis(showId: String, request: MoreLikeThisRequest) async throws -> [MoreLikeThisShow] {
        try await post("/shows/\(showId)/more-like-this", body: request)
    }

    func fetchShow(id: String) async throws -> ShowDetail {
        try await fetch("/shows/\(id)")
    }

    func fetchPlaybackTicket(for episode: Episode) async throws -> PlaybackTicket {
        try await fetch(episode.playbackPath)
    }

    func url(for path: String) -> URL {
        baseURL.appending(path: path)
    }

    private static func bundleBaseURL() -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MicroDramaAPIBaseURL") as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        return URL(string: trimmedValue)
    }

    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        let url = url(for: path)
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(T.self, from: data)
    }
}
