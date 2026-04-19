import Foundation

struct SearchResponse: Codable {
    let query: String
    let results: [SearchResult]
    let count: Int
}

struct SearchResult: Codable, Identifiable {
    var id: String { chunkId }

    let score: Double
    let chunkId: String
    let postId: String
    let author: String
    let platform: String
    let likes: Int
    let comments: Int
    let reposts: Int
    let chunkIndex: Int
    let totalChunks: Int
    let text: String
    let timeRelative: String?
    let url: String?
    let images: [String]?

    enum CodingKeys: String, CodingKey {
        case score
        case chunkId = "chunk_id"
        case postId = "post_id"
        case author, platform, likes, comments, reposts
        case chunkIndex = "chunk_index"
        case totalChunks = "total_chunks"
        case text
        case timeRelative = "time_relative"
        case url
        case images
    }
}

struct StatsResponse: Codable {
    let rawPosts: Int
    let processedChunks: Int
    let images: Int
    let indexExists: Bool
    let authors: [String]

    enum CodingKeys: String, CodingKey {
        case rawPosts = "raw_posts"
        case processedChunks = "processed_chunks"
        case images
        case indexExists = "index_exists"
        case authors
    }
}

struct PipelineResponse: Codable {
    let status: String
    let action: String
    let result: String?

    enum CodingKeys: String, CodingKey {
        case status, action, result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        action = try container.decode(String.self, forKey: .action)
        // result can be String or nested object - just stringify it
        if let str = try? container.decode(String.self, forKey: .result) {
            result = str
        } else if let dict = try? container.decode([String: String].self, forKey: .result) {
            result = dict.values.joined(separator: "\n")
        } else {
            result = nil
        }
    }
}

// MARK: - AI Ask / Insights models

struct AskResponse: Codable {
    let answer: String
    let citations: [Citation]
    let relatedResources: [RelatedResource]
    let taxonomyTags: [String]
    let confidence: String

    enum CodingKeys: String, CodingKey {
        case answer, citations, confidence
        case relatedResources = "related_resources"
        case taxonomyTags = "taxonomy_tags"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        answer = try c.decode(String.self, forKey: .answer)
        citations = (try? c.decode([Citation].self, forKey: .citations)) ?? []
        relatedResources = (try? c.decode([RelatedResource].self, forKey: .relatedResources)) ?? []
        taxonomyTags = (try? c.decode([String].self, forKey: .taxonomyTags)) ?? []
        confidence = (try? c.decode(String.self, forKey: .confidence)) ?? "medium"
    }
}

struct Citation: Codable, Identifiable {
    var id: String { postId }
    let postId: String
    let author: String
    let text: String
    let url: String?

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case author, text, url
    }
}

struct RelatedResource: Codable, Identifiable {
    var id: String { url }
    let title: String?
    let url: String
    let type: String?
}

// MARK: - Authority models

struct Authority: Codable, Identifiable {
    var id: String { slug }
    let slug: String
    let name: String
    let platform: String
    let profileUrl: String
    let fetchUrl: String?
    let status: String
    let lastSyncedAt: String?
    let nextSyncAt: String?
    let postCount: Int
    let newSinceLastSync: Int
    let credibilityScore: Double
    let expertiseTags: [String]
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case slug, name, platform, status
        case profileUrl = "profile_url"
        case fetchUrl = "fetch_url"
        case lastSyncedAt = "last_synced_at"
        case nextSyncAt = "next_sync_at"
        case postCount = "post_count"
        case newSinceLastSync = "new_since_last_sync"
        case credibilityScore = "credibility_score"
        case expertiseTags = "expertise_tags"
        case errorMessage = "error_message"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slug = try c.decode(String.self, forKey: .slug)
        name = try c.decode(String.self, forKey: .name)
        platform = try c.decode(String.self, forKey: .platform)
        profileUrl = try c.decode(String.self, forKey: .profileUrl)
        fetchUrl = try? c.decode(String.self, forKey: .fetchUrl)
        status = (try? c.decode(String.self, forKey: .status)) ?? "active"
        lastSyncedAt = try? c.decode(String.self, forKey: .lastSyncedAt)
        nextSyncAt = try? c.decode(String.self, forKey: .nextSyncAt)
        postCount = (try? c.decode(Int.self, forKey: .postCount)) ?? 0
        newSinceLastSync = (try? c.decode(Int.self, forKey: .newSinceLastSync)) ?? 0
        credibilityScore = (try? c.decode(Double.self, forKey: .credibilityScore)) ?? 1.0
        expertiseTags = (try? c.decode([String].self, forKey: .expertiseTags)) ?? []
        errorMessage = try? c.decode(String.self, forKey: .errorMessage)
    }
}

struct AuthoritiesResponse: Codable {
    let authorities: [Authority]
    let count: Int
}

struct AuthoritySyncResult: Codable {
    let slug: String
    let status: String
    let newPosts: Int?
    let message: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case slug, status, message, error
        case newPosts = "new_posts"
    }
}

// MARK: - LinkedIn Auth models

struct LinkedInAuthStatus: Codable {
    let status: String
    let valid: Bool
    let method: String?
    let authenticatedAt: String?
    let lastValidated: String?
    let cookieCount: Int?
    let needsRevalidation: Bool?
    let liAtExpires: String?

    enum CodingKeys: String, CodingKey {
        case status, valid, method
        case authenticatedAt = "authenticated_at"
        case lastValidated = "last_validated"
        case cookieCount = "cookie_count"
        case needsRevalidation = "needs_revalidation"
        case liAtExpires = "li_at_expires"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = (try? c.decode(String.self, forKey: .status)) ?? "unknown"
        valid = (try? c.decode(Bool.self, forKey: .valid)) ?? false
        method = try? c.decode(String.self, forKey: .method)
        authenticatedAt = try? c.decode(String.self, forKey: .authenticatedAt)
        lastValidated = try? c.decode(String.self, forKey: .lastValidated)
        cookieCount = try? c.decode(Int.self, forKey: .cookieCount)
        needsRevalidation = try? c.decode(Bool.self, forKey: .needsRevalidation)
        liAtExpires = try? c.decode(String.self, forKey: .liAtExpires)
    }
}

// MARK: - Analytics models

struct TopQuery: Codable, Identifiable {
    var id: String { query }
    let query: String
    let count: Int
    let avgResults: Double
    let avgLatencyMs: Double

    enum CodingKeys: String, CodingKey {
        case query, count
        case avgResults = "avg_results"
        case avgLatencyMs = "avg_latency_ms"
    }
}

struct TopQueriesResponse: Codable {
    let queries: [TopQuery]
    let count: Int
}

struct UserPreference: Codable, Identifiable {
    var id: String { tag }
    let tag: String
    let weight: Double
    let rawWeight: Double
    let interactions: Int
    let lastUpdated: String?

    enum CodingKeys: String, CodingKey {
        case tag, weight, interactions
        case rawWeight = "raw_weight"
        case lastUpdated = "last_updated"
    }
}

struct PreferencesResponse: Codable {
    let preferences: [UserPreference]
    let count: Int
}

struct RecommendedPost: Codable, Identifiable {
    let id: String
    let author: String
    let platform: String
    let url: String?
    let text: String
    let likes: Int
    let comments: Int
    let reposts: Int
    let recommendationScore: Double?

    enum CodingKeys: String, CodingKey {
        case id, author, platform, url, text, likes, comments, reposts
        case recommendationScore = "recommendation_score"
    }
}

struct RecommendationsResponse: Codable {
    let recommendations: [RecommendedPost]
    let strategy: String
}

// MARK: - Insights Feed models

struct InsightsFeedResponse: Codable {
    let feed: [FeedItem]
    let trendingTopics: [TrendingTopic]
    let highlights: [HighlightItem]
    let resources: ResourcesSummary
    let platforms: [PlatformCount]
    let authors: [AuthorStat]
    let totalPosts: Int

    enum CodingKeys: String, CodingKey {
        case feed, highlights, resources, platforms, authors
        case trendingTopics = "trending_topics"
        case totalPosts = "total_posts"
    }
}

struct FeedItem: Codable, Identifiable {
    var id: String { postId }
    let type: String
    let postId: String
    let author: String
    let platform: String
    let url: String?
    let excerpt: String
    let likes: Int
    let comments: Int
    let reposts: Int
    let tags: [String]
    let date: String?

    enum CodingKeys: String, CodingKey {
        case type, author, platform, url, excerpt, likes, comments, reposts, tags, date
        case postId = "post_id"
    }
}

struct TrendingTopic: Codable, Identifiable {
    var id: String { tag }
    let tag: String
    let taxonomyType: String
    let postCount: Int

    enum CodingKeys: String, CodingKey {
        case tag
        case taxonomyType = "taxonomy_type"
        case postCount = "post_count"
    }
}

struct HighlightItem: Codable, Identifiable {
    var id: String { postId }
    let postId: String
    let author: String
    let platform: String
    let url: String?
    let excerpt: String
    let likes: Int
    let comments: Int
    let reposts: Int
    let engagement: Int
    let date: String?

    enum CodingKeys: String, CodingKey {
        case author, platform, url, excerpt, likes, comments, reposts, engagement, date
        case postId = "post_id"
    }
}

struct ResourcesSummary: Codable {
    let total: Int
    let byType: [ResourceTypeCount]

    enum CodingKeys: String, CodingKey {
        case total
        case byType = "by_type"
    }
}

struct ResourceTypeCount: Codable, Identifiable {
    var id: String { type }
    let type: String
    let count: Int
}

struct PlatformCount: Codable, Identifiable {
    var id: String { platform }
    let platform: String
    let count: Int
}

struct AuthorStat: Codable, Identifiable {
    var id: String { author }
    let author: String
    let posts: Int
    let totalLikes: Int
    let totalComments: Int

    enum CodingKeys: String, CodingKey {
        case author, posts
        case totalLikes = "total_likes"
        case totalComments = "total_comments"
    }
}
