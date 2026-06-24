import Foundation

/// A lightweight reference to a channel, embedded inside `Video`.
/// Kept separate from the full `Channel` model so list/search results
/// stay cheap to decode and diff.
public struct ChannelSummary: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let avatarURL: URL?
    public let isVerified: Bool

    public init(
        id: String,
        name: String,
        avatarURL: URL? = nil,
        isVerified: Bool = false
    ) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.isVerified = isVerified
    }
}
