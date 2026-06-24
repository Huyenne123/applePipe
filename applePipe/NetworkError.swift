import Foundation

/// Error type shared by `PipedAPIClient` and `SponsorBlockClient`. Wraps
/// the underlying error as a `String` description rather than holding the
/// original `Error` so this type can be `Sendable` without requiring every
/// possible underlying error to be `Sendable` itself.
public enum NetworkError: Error, LocalizedError, Sendable {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed(underlying: String)
    case noInstancesReachable
    case transport(underlying: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL was malformed."
        case .requestFailed(let statusCode):
            return "The server returned an unexpected status code (\(statusCode))."
        case .decodingFailed(let underlying):
            return "Failed to parse the server's response: \(underlying)"
        case .noInstancesReachable:
            return "Couldn't reach any Piped instance. Check your connection or pick a different instance in Settings."
        case .transport(let underlying):
            return "Network request failed: \(underlying)"
        }
    }
}
