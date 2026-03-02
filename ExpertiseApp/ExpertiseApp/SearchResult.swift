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
