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

    enum CodingKeys: String, CodingKey {
        case score
        case chunkId = "chunk_id"
        case postId = "post_id"
        case author, platform, likes, comments, reposts
        case chunkIndex = "chunk_index"
        case totalChunks = "total_chunks"
        case text
        case timeRelative = "time_relative"
    }
}
