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

    // MARK: - Analytics

    func logSearch(query: String, mode: String, resultCount: Int, latencyMs: Int) async {
        let url = baseURL.appendingPathComponent("/api/analytics/search")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "query": query, "mode": mode,
            "result_count": resultCount, "latency_ms": latencyMs
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await session.data(for: request)
    }

    func logInteraction(query: String, postId: String, action: String = "click", dwellMs: Int = 0) async {
        let url = baseURL.appendingPathComponent("/api/analytics/interaction")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "query": query, "post_id": postId,
            "action": action, "dwell_ms": dwellMs
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await session.data(for: request)
    }

    func fetchTopQueries(limit: Int = 20) async throws -> TopQueriesResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/analytics/top-queries"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components.url else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(TopQueriesResponse.self, from: data)
    }

    func fetchRecommendations() async throws -> RecommendationsResponse {
        let url = baseURL.appendingPathComponent("/api/analytics/recommendations")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(RecommendationsResponse.self, from: data)
    }

    // MARK: - VIKI Sync

    func syncToViki(baseURL: String = "http://localhost:8000") async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/v1/hooks/metrics") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let payload: [String: Any] = [
            "source": "claude-expertise-vault",
            "metric_type": "expertise_sync",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "data": [
                "action": "sync_posts",
                "api_base": "http://localhost:8645"
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func fetchInsightsFeed(limit: Int = 20) async throws -> InsightsFeedResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/analytics/insights-feed"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components.url else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(InsightsFeedResponse.self, from: data)
    }

    func fetchPreferences() async throws -> PreferencesResponse {
        let url = baseURL.appendingPathComponent("/api/analytics/preferences")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(PreferencesResponse.self, from: data)
    }

    // MARK: - Authorities

    func fetchAuthorities(status: String? = nil) async throws -> AuthoritiesResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/authorities"), resolvingAgainstBaseURL: false)!
        if let status {
            components.queryItems = [URLQueryItem(name: "status", value: status)]
        }
        guard let url = components.url else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(AuthoritiesResponse.self, from: data)
    }

    func syncAuthority(slug: String) async throws -> AuthoritySyncResult {
        let url = baseURL.appendingPathComponent("/api/authorities/\(slug)/sync")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(AuthoritySyncResult.self, from: data)
    }

    func addAuthority(slug: String, name: String, platform: String, profileUrl: String, fetchUrl: String? = nil, adapter: String? = nil) async throws -> AuthoritySyncResult {
        let url = baseURL.appendingPathComponent("/api/authorities")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["slug": slug, "name": name, "platform": platform, "profile_url": profileUrl]
        if let fetchUrl { body["fetch_url"] = fetchUrl }
        if let adapter { body["adapter"] = adapter }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(AuthoritySyncResult.self, from: data)
    }

    func fetchSyncerStatus() async throws -> [String: Any] {
        let url = baseURL.appendingPathComponent("/api/authorities/syncer/status")
        let (data, _) = try await session.data(from: url)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
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
