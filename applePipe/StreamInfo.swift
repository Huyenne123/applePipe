import Foundation

/// What kind of elementary stream a `StreamInfo` represents. Adaptive
/// (DASH-style) sources are split into separate `video` (video-only) and
/// `audio` tracks that the player muxes together; `muxed` carries both in
/// one container; `hls` is a master playlist URL handed directly to
/// AVPlayer.
public enum StreamKind: String, Codable, Sendable {
    case muxed
    case video
    case audio
    case hls
}

/// A single resolved, directly-playable stream candidate for a video.
public struct StreamInfo: Identifiable, Codable, Hashable, Sendable {
    public let url: URL
    public let kind: StreamKind
    public let mimeType: String
    public let codec: String
    /// Human readable label such as "1080p60", "720p", or "128kbps".
    public let qualityLabel: String
    public let bitrate: Int
    public let width: Int?
    public let height: Int?
    public let fps: Int?
    public let contentLength: Int64?

    public var id: String { url.absoluteString }

    public init(
        url: URL,
        kind: StreamKind,
        mimeType: String,
        codec: String,
        qualityLabel: String,
        bitrate: Int,
        width: Int? = nil,
        height: Int? = nil,
        fps: Int? = nil,
        contentLength: Int64? = nil
    ) {
        self.url = url
        self.kind = kind
        self.mimeType = mimeType
        self.codec = codec
        self.qualityLabel = qualityLabel
        self.bitrate = bitrate
        self.width = width
        self.height = height
        self.fps = fps
        self.contentLength = contentLength
    }

    /// Resolution sort key, falling back to bitrate for audio-only streams.
    public var sortRank: Int {
        if let height { return height }
        return bitrate / 1000
    }
}
