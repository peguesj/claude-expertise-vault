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

    func fetchStats() async throws -> StatsResponse {
        let url = baseURL.appendingPathComponent("/api/stats")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(StatsResponse.self, from: data)
    }

    func triggerScan(author: String = "mitko-vasilev") async throws -> String {
        let url = baseURL.appendingPathComponent("/api/scan")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["author": author])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        let result = try JSONDecoder().decode(PipelineResponse.self, from: data)
        return result.result ?? "Scan complete"
    }

    func triggerImport(author: String = "mitko-vasilev") async throws -> String {
        let url = baseURL.appendingPathComponent("/api/import")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["author": author])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        let result = try JSONDecoder().decode(PipelineResponse.self, from: data)
        return result.result ?? "Import complete"
    }

    func triggerImageScrape(author: String = "mitko-vasilev") async throws -> String {
        let url = baseURL.appendingPathComponent("/api/scrape-images")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["author": author])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        let result = try JSONDecoder().decode(PipelineResponse.self, from: data)
        return result.result ?? "Image scrape complete"
    }

    func ask(query: String, topK: Int = 8) async throws -> AskResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/ask"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "top_k", value: String(topK))
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 90 // Anthropic API calls can take time
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(AskResponse.self, from: data)
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
