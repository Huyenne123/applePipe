import Foundation

/// Core domain representation of a video. This is a plain, `Sendable` value
/// type used across networking, view models and views. It is intentionally
/// decoupled from the SwiftData persistence models in `Persistence/`.
public struct Video: Identifiable, Codable, Hashable, Sendable {
    /// YouTube video ID (e.g. "dQw4w9WgXcQ").
    public let id: String
    public let title: String
    public let thumbnailURL: URL?
    public let channel: ChannelSummary
    public let duration: TimeInterval
    public let viewCount: Int
    public let uploadDate: Date?
    public let description: String
    public let isShort: Bool

    public init(
        id: String,
        title: String,
        thumbnailURL: URL? = nil,
        channel: ChannelSummary,
        duration: TimeInterval = 0,
        viewCount: Int = 0,
        uploadDate: Date? = nil,
        description: String = "",
        isShort: Bool = false
    ) {
        self.id = id
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.channel = channel
        self.duration = duration
        self.viewCount = viewCount
        self.uploadDate = uploadDate
        self.description = description
        self.isShort = isShort
    }
}

extension Video {
    /// "1:23:45" or "3:21" style formatting for thumbnails/rows.
    public var formattedDuration: String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// "2.3M views" style formatting.
    public var formattedViewCount: String {
        switch viewCount {
        case 1_000_000_000...:
            return String(format: "%.1fB views", Double(viewCount) / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM views", Double(viewCount) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK views", Double(viewCount) / 1_000)
        default:
            return viewCount == 1 ? "1 view" : "\(viewCount) views"
        }
    }

    /// "3 days ago" style formatting, falling back gracefully when unknown.
    public var formattedUploadDate: String {
        guard let uploadDate else { return "" }
        return uploadDate.formatted(.relative(presentation: .named))
    }
}
