import Foundation
import SwiftData

/// Lifecycle state of a download. Stored on the model as a raw `String`
/// (`statusRawValue`) rather than the enum directly, so the persisted
/// schema stays stable even if SwiftData's native enum support changes
/// across OS versions — the typed `status` accessor below is what the
/// rest of the app actually uses.
public enum DownloadStatus: String, Codable, Sendable {
    case queued
    case downloading
    case paused
    case completed
    case failed
}

@Model
public final class DownloadedVideoItem {
    @Attribute(.unique) public var videoID: String
    public var title: String
    public var channelName: String
    public var thumbnailURLString: String?
    /// File name (not full path) inside the app's Downloads directory.
    /// Resolved against a base URL at read time so the record stays valid
    /// even if the app's container path changes between launches.
    public var localFileName: String?
    public var qualityLabel: String
    public var fileSizeBytes: Int64
    public var bytesDownloaded: Int64
    public var duration: TimeInterval
    public var statusRawValue: String
    public var createdAt: Date
    public var completedAt: Date?

    public init(
        videoID: String,
        title: String,
        channelName: String,
        thumbnailURLString: String? = nil,
        localFileName: String? = nil,
        qualityLabel: String,
        fileSizeBytes: Int64 = 0,
        bytesDownloaded: Int64 = 0,
        duration: TimeInterval,
        status: DownloadStatus = .queued,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.videoID = videoID
        self.title = title
        self.channelName = channelName
        self.thumbnailURLString = thumbnailURLString
        self.localFileName = localFileName
        self.qualityLabel = qualityLabel
        self.fileSizeBytes = fileSizeBytes
        self.bytesDownloaded = bytesDownloaded
        self.duration = duration
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

extension DownloadedVideoItem {
    public var status: DownloadStatus {
        get { DownloadStatus(rawValue: statusRawValue) ?? .queued }
        set { statusRawValue = newValue.rawValue }
    }

    public var thumbnailURL: URL? {
        guard let thumbnailURLString else { return nil }
        return URL(string: thumbnailURLString)
    }

    public var progressFraction: Double {
        guard fileSizeBytes > 0 else { return 0 }
        return min(max(Double(bytesDownloaded) / Double(fileSizeBytes), 0), 1)
    }

    public func localFileURL(in directory: URL) -> URL? {
        guard let localFileName else { return nil }
        return directory.appendingPathComponent(localFileName)
    }
}
