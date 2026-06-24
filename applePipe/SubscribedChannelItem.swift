import Foundation
import SwiftData

@Model
public final class SubscribedChannelItem {
    @Attribute(.unique) public var channelID: String
    public var name: String
    public var avatarURLString: String?
    public var notificationsEnabled: Bool
    public var subscribedAt: Date

    public init(
        channelID: String,
        name: String,
        avatarURLString: String? = nil,
        notificationsEnabled: Bool = false,
        subscribedAt: Date = .now
    ) {
        self.channelID = channelID
        self.name = name
        self.avatarURLString = avatarURLString
        self.notificationsEnabled = notificationsEnabled
        self.subscribedAt = subscribedAt
    }
}

extension SubscribedChannelItem {
    public var avatarURL: URL? {
        guard let avatarURLString else { return nil }
        return URL(string: avatarURLString)
    }
}
