import Foundation
import SwiftData

/// Persisted record of a watched video, including resume position.
/// One row per video — re-watching updates `watchedAt` and progress
/// rather than inserting a duplicate.
@Model
public final class WatchHistoryItem {
    @Attribute(.unique) public var videoID: String
    public var title: String
    public var thumbnailURLString: String?
    public var channelID: String
    public var channelName: String
    public var duration: TimeInterval
    public var lastPlaybackPosition: TimeInterval
    public var watchedAt: Date

    public init(
        videoID: String,
        title: String,
        thumbnailURLString: String? = nil,
        channelID: String,
        channelName: String,
        duration: TimeInterval,
        lastPlaybackPosition: TimeInterval = 0,
        watchedAt: Date = .now
    ) {
        self.videoID = videoID
        self.title = title
        self.thumbnailURLString = thumbnailURLString
        self.channelID = channelID
        self.channelName = channelName
        self.duration = duration
        self.lastPlaybackPosition = lastPlaybackPosition
        self.watchedAt = watchedAt
    }
}

extension WatchHistoryItem {
    public var thumbnailURL: URL? {
        guard let thumbnailURLString else { return nil }
        return URL(string: thumbnailURLString)
    }

    /// 0...1 watched fraction, used to draw the red progress bar under
    /// thumbnails in history/library rows.
    public var progressFraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(lastPlaybackPosition / duration, 0), 1)
    }

    /// Treat anything within 15s of the end as "finished" so it doesn't
    /// show a lingering resume bar.
    public var isEffectivelyFinished: Bool {
        duration > 0 && (duration - lastPlaybackPosition) <= 15
    }
}
