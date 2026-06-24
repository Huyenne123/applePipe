import Foundation

/// Mirrors the category list used by the SponsorBlock API
/// (https://wiki.sponsor.ajay.app/w/Types#Category).
public enum SponsorBlockCategory: String, Codable, CaseIterable, Sendable {
    case sponsor
    case selfpromo
    case interaction
    case intro
    case outro
    case preview
    case musicOfftopic = "music_offtopic"
    case filler
    case exclusiveAccess = "exclusive_access"

    public var displayName: String {
        switch self {
        case .sponsor: return "Sponsor"
        case .selfpromo: return "Unpaid/Self Promotion"
        case .interaction: return "Interaction Reminder"
        case .intro: return "Intro/Intermission"
        case .outro: return "Endcards/Credits"
        case .preview: return "Preview/Recap"
        case .musicOfftopic: return "Non-Music Section"
        case .filler: return "Filler Tangent"
        case .exclusiveAccess: return "Exclusive Access"
        }
    }

    /// Whether this category is skipped automatically by default. Users can
    /// override this per-category in Settings (added in a later module).
    public var isSkippedByDefault: Bool {
        switch self {
        case .sponsor, .selfpromo, .interaction, .preview, .exclusiveAccess:
            return true
        case .intro, .outro, .musicOfftopic, .filler:
            return false
        }
    }
}

/// A single timestamped segment returned by SponsorBlock for a video.
public struct SponsorSegment: Identifiable, Codable, Hashable, Sendable {
    public let uuid: String
    public let category: SponsorBlockCategory
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let votes: Int
    public let locked: Bool

    public var id: String { uuid }

    public init(
        uuid: String,
        category: SponsorBlockCategory,
        startTime: TimeInterval,
        endTime: TimeInterval,
        votes: Int = 0,
        locked: Bool = false
    ) {
        self.uuid = uuid
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.votes = votes
        self.locked = locked
    }

    public func contains(_ time: TimeInterval) -> Bool {
        time >= startTime && time < endTime
    }
}
