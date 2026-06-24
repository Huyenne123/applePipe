import Foundation

/// Abstraction over "search for videos", implemented by `PipedAPIClient`.
/// ViewModels depend on this protocol rather than the concrete client so
/// they stay unit-testable with a fake/mock implementation.
public protocol VideoSearchService: Sendable {
    func search(query: String, nextPage: String?) async throws -> SearchResultsPage
}

/// Abstraction over "resolve a video ID into playable streams + metadata",
/// implemented by `PipedAPIClient`.
public protocol VideoStreamResolving: Sendable {
    func videoDetail(videoID: String) async throws -> VideoDetail
}

/// Abstraction over "fetch SponsorBlock segments for a video", implemented
/// by `SponsorBlockClient`.
public protocol SponsorSegmentProviding: Sendable {
    func segments(videoID: String, categories: [SponsorBlockCategory]) async throws -> [SponsorSegment]
}
