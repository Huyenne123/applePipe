import Foundation

/// Full channel profile, as shown on a channel page. Distinct from
/// `ChannelSummary`, which is the cheap reference embedded in `Video`.
public struct Channel: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let avatarURL: URL?
    public let bannerURL: URL?
    public let description: String
    public let subscriberCount: Int
    public let isVerified: Bool

    public init(
        id: String,
        name: String,
        avatarURL: URL? = nil,
        bannerURL: URL? = nil,
        description: String = "",
        subscriberCount: Int = 0,
        isVerified: Bool = false
    ) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.bannerURL = bannerURL
        self.description = description
        self.subscriberCount = subscriberCount
        self.isVerified = isVerified
    }

    public var formattedSubscriberCount: String {
        switch subscriberCount {
        case 1_000_000...:
            return String(format: "%.1fM subscribers", Double(subscriberCount) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK subscribers", Double(subscriberCount) / 1_000)
        default:
            return "\(subscriberCount) subscribers"
        }
    }
}
