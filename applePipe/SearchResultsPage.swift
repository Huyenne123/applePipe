import Foundation

/// One page of video search results, plus pagination and typo-correction
/// metadata surfaced by the backend. `nextPageToken` is an opaque cursor —
/// pass it straight back into the next `search` call, don't parse it.
public struct SearchResultsPage: Sendable {
    public let videos: [Video]
    public let nextPageToken: String?
    public let didCorrectQuery: Bool
    public let suggestion: String?

    public init(
        videos: [Video],
        nextPageToken: String? = nil,
        didCorrectQuery: Bool = false,
        suggestion: String? = nil
    ) {
        self.videos = videos
        self.nextPageToken = nextPageToken
        self.didCorrectQuery = didCorrectQuery
        self.suggestion = suggestion
    }
}
