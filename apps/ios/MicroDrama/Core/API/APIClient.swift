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

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func fetchShows() async throws -> [Show] {
        try await fetch("/shows")
    }

    func fetchShow(id: String) async throws -> ShowDetail {
        try await fetch("/shows/\(id)")
    }

    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appending(path: path)
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(T.self, from: data)
    }
}

