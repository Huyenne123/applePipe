import Foundation
import CryptoKit

/// Talks to the public SponsorBlock API (https://sponsor.ajay.app) to
/// fetch crowd-sourced skip segments for a video.
public actor SponsorBlockClient: SponsorSegmentProviding {
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder

    public init(
        baseURL: URL = URL(string: "https://sponsor.ajay.app")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
    }

    /// Fetches skip segments for `videoID`.
    ///
    /// Uses SponsorBlock's privacy-preserving hash-prefix lookup: only the
    /// first 4 hex characters of the SHA-256 hash of the video ID are sent
    /// to the server, never the plaintext ID. The response can contain
    /// segments for other videos that happen to share the same prefix —
    /// those are filtered out locally before returning.
    public func segments(
        videoID: String,
        categories: [SponsorBlockCategory] = SponsorBlockCategory.allCases
    ) async throws -> [SponsorSegment] {
        let hashPrefix = Self.sha256HashPrefix(of: videoID)

        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/skipSegments/\(hashPrefix)"),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL
        }

        let categoriesData = try JSONEncoder().encode(categories.map(\.rawValue))
        guard let categoriesJSON = String(data: categoriesData, encoding: .utf8) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "categories", value: categoriesJSON)]

        guard let url = components.url else { throw NetworkError.invalidURL }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw NetworkError.transport(underlying: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.transport(underlying: "No HTTP response received")
        }

        // A 404 means no segments exist for this hash prefix at all —
        // that's a normal "nothing submitted yet" outcome, not an error.
        if httpResponse.statusCode == 404 {
            return []
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let matches: [SponsorBlockVideoMatch]
        do {
            matches = try decoder.decode([SponsorBlockVideoMatch].self, from: data)
        } catch {
            throw NetworkError.decodingFailed(underlying: String(describing: error))
        }

        return matches
            .first { $0.videoID == videoID }?
            .segments
            .compactMap(SponsorSegment.init(sponsorBlockSegment:)) ?? []
    }

    public static func sha256HashPrefix(of videoID: String, length: Int = 4) -> String {
        let digest = SHA256.hash(data: Data(videoID.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(length))
    }
}
