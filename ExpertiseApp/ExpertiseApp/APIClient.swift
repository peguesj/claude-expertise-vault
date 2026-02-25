import Foundation

actor APIClient {
    static let shared = APIClient()
    private let baseURL = URL(string: "http://localhost:8645")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func search(query: String, topK: Int = 10, minScore: Double = 0.2) async throws -> [SearchResult] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "top_k", value: String(topK)),
            URLQueryItem(name: "min_score", value: String(minScore))
        ]

        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return searchResponse.results
    }

    func healthCheck() async -> Bool {
        guard let url = URL(string: "http://localhost:8645/api/health") else { return false }
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

enum APIError: LocalizedError {
    case serverError
    case invalidURL
    case noConnection

    var errorDescription: String? {
        switch self {
        case .serverError: return "Server returned an error"
        case .invalidURL: return "Invalid URL"
        case .noConnection: return "Cannot connect to Expertise API"
        }
    }
}
