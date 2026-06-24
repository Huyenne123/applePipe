import Foundation

/// Everything needed to render a video's detail screen and play it back:
/// metadata plus resolved, directly-playable stream candidates.
public struct VideoDetail: Identifiable, Sendable {
    public let video: Video
    public let likeCount: Int?
    public let dislikeCount: Int?
    public let isLive: Bool
    public let audioStreams: [StreamInfo]
    public let videoStreams: [StreamInfo]
    /// Master HLS playlist URL, when the backend exposes one. Some videos
    /// (notably livestreams) are only playable through this.
    public let hlsURL: URL?
    public let captions: [Caption]
    public let relatedVideos: [Video]

    public var id: String { video.id }

    public init(
        video: Video,
        likeCount: Int? = nil,
        dislikeCount: Int? = nil,
        isLive: Bool = false,
        audioStreams: [StreamInfo] = [],
        videoStreams: [StreamInfo] = [],
        hlsURL: URL? = nil,
        captions: [Caption] = [],
        relatedVideos: [Video] = []
    ) {
        self.video = video
        self.likeCount = likeCount
        self.dislikeCount = dislikeCount
        self.isLive = isLive
        self.audioStreams = audioStreams
        self.videoStreams = videoStreams
        self.hlsURL = hlsURL
        self.captions = captions
        self.relatedVideos = relatedVideos
    }
}

extension VideoDetail {
    /// Best progressive (muxed audio+video) stream, when one is available —
    /// the simplest path for the player since no separate-track muxing is
    /// needed.
    public var bestMuxedStream: StreamInfo? {
        videoStreams
            .filter { $0.kind == .muxed }
            .max { $0.sortRank < $1.sortRank }
    }

    /// Highest quality video-only stream, to be paired with
    /// `bestAudioStream` by the player when no muxed stream covers the
    /// desired quality.
    public var bestVideoOnlyStream: StreamInfo? {
        videoStreams
            .filter { $0.kind == .video }
            .max { $0.sortRank < $1.sortRank }
    }

    public var bestAudioStream: StreamInfo? {
        audioStreams.max { $0.sortRank < $1.sortRank }
    }
}
