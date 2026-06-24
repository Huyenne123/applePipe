import Foundation

/// One entry in the response from `GET /api/skipSegments/{hashPrefix}` —
/// since the hash-prefix lookup is a k-anonymity match, the response can
/// contain segments for *several* video IDs that share the same prefix;
/// the client filters down to the exact `videoID` it asked about.
struct SponsorBlockVideoMatch: Decodable, Sendable {
    let videoID: String
    let segments: [SponsorBlockSegmentDTO]
}

struct SponsorBlockSegmentDTO: Decodable, Sendable {
    let category: String
    let actionType: String?
    /// `[startSeconds, endSeconds]`.
    let segment: [Double]
    let uuid: String
    let votes: Int?
    /// `0`/`1` rather than a JSON bool on this endpoint.
    let locked: Int?

    enum CodingKeys: String, CodingKey {
        case category, actionType, segment, votes, locked
        case uuid = "UUID"
    }
}
