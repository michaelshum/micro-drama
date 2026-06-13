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

struct APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://micro-drama.onrender.com")!
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        encoder = JSONEncoder()
    }

    func fetchConfig() async throws -> AppConfig {
        try await fetch("/config")
    }

    func fetchShows() async throws -> [Show] {
        try await fetch("/shows")
    }

    func fetchHome(request: HomeRequest) async throws -> HomeResponse {
        try await post("/home", body: request)
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
