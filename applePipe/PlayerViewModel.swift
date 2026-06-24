import Foundation
import AVFoundation
import Observation
import SwiftData

@MainActor
@Observable
public final class PlayerViewModel {

    // MARK: - Public state

    public let video: Video
    public private(set) var player: AVPlayer?
    public private(set) var detail: VideoDetail?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    // SponsorBlock
    public private(set) var sponsorSegments: [SponsorSegment] = []
    public private(set) var skipToast: SkipToast? = nil
    /// Which categories auto-skip. Starts from `isSkippedByDefault`; the
    /// category sheet in `PlayerView` mutates this at runtime.
    public var enabledCategories: Set<SponsorBlockCategory> =
        Set(SponsorBlockCategory.allCases.filter(\.isSkippedByDefault))

    // MARK: - Nested types

    public struct SkipToast: Sendable, Equatable {
        public let categoryName: String
        public let segment: SponsorSegment
    }

    // MARK: - Private

    private let streamResolver: VideoStreamResolving
    private let sponsorClient: SponsorSegmentProviding
    private var timeObserverToken: Any?
    private var sponsorObserverToken: Any?
    private var toastDismissTask: Task<Void, Never>?
    private var skippedIDs: Set<String> = []
    private var modelContext: ModelContext?

    public init(
        video: Video,
        streamResolver: VideoStreamResolving = PipedAPIClient(),
        sponsorClient: SponsorSegmentProviding = SponsorBlockClient()
    ) {
        self.video = video
        self.streamResolver = streamResolver
        self.sponsorClient = sponsorClient
    }

    public func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Load

    public func load() async {
        guard player == nil, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Fetch stream detail and SponsorBlock segments concurrently —
            // SponsorBlock failure is non-fatal so it's wrapped in try?.
            async let streamDetail = streamResolver.videoDetail(videoID: video.id)
            async let sponsorSegs = fetchSegments()

            let resolved = try await streamDetail
            let segments = await sponsorSegs

            self.detail = resolved
            self.sponsorSegments = segments

            guard let playURL = resolvePlayURL(from: resolved) else {
                errorMessage = "No playable stream is available for this video."
                return
            }

            setupAudioSession()

            let item = AVPlayerItem(url: playURL)
            let avPlayer = AVPlayer(playerItem: item)
            avPlayer.allowsExternalPlayback = true

            let resumeAt = lastPlaybackPosition(videoID: video.id)
            if resumeAt > 5 {
                await avPlayer.seek(
                    to: CMTime(seconds: resumeAt, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                )
            }

            player = avPlayer
            addProgressObserver()
            addSponsorObserver()
            avPlayer.play()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Failed to load video."
        }
    }

    public func handleDismiss() {
        if let player {
            if let token = timeObserverToken { player.removeTimeObserver(token) }
            if let token = sponsorObserverToken { player.removeTimeObserver(token) }
            timeObserverToken = nil
            sponsorObserverToken = nil
            let position = player.currentTime().seconds
            if position.isFinite && position > 0 { persistProgress(position: position) }
        }
        toastDismissTask?.cancel()
        player?.pause()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - SponsorBlock actions

    public func undoSkip() {
        guard let toast = skipToast else { return }
        skippedIDs.remove(toast.segment.uuid)
        player?.seek(
            to: CMTime(seconds: toast.segment.startTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        )
        toastDismissTask?.cancel()
        skipToast = nil
    }

    public func dismissToast() {
        toastDismissTask?.cancel()
        skipToast = nil
    }

    // MARK: - Private: SponsorBlock

    private func fetchSegments() async -> [SponsorSegment] {
        (try? await sponsorClient.segments(
            videoID: video.id,
            categories: Array(SponsorBlockCategory.allCases)
        )) ?? []
    }

    private func addSponsorObserver() {
        guard let player else { return }
        // Check every 0.5 s — fine-grained enough to catch segment entry
        // without missing a short segment entirely.
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        sponsorObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, time.isValid, time.seconds.isFinite else { return }
                self.checkSegments(at: time.seconds)
            }
        }
    }

    private func checkSegments(at position: TimeInterval) {
        guard !sponsorSegments.isEmpty else { return }
        for segment in sponsorSegments {
            guard enabledCategories.contains(segment.category) else { continue }
            guard !skippedIDs.contains(segment.uuid) else { continue }
            guard segment.contains(position) else { continue }
            performSkip(segment)
            break
        }
    }

    private func performSkip(_ segment: SponsorSegment) {
        skippedIDs.insert(segment.uuid)
        player?.seek(
            to: CMTime(seconds: segment.endTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        )
        skipToast = SkipToast(categoryName: segment.category.displayName, segment: segment)
        toastDismissTask?.cancel()
        toastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.skipToast = nil
        }
    }

    // MARK: - Private: playback

    private func resolvePlayURL(from detail: VideoDetail) -> URL? {
        if let hls = detail.hlsURL { return hls }
        if let muxed = detail.bestMuxedStream { return muxed.url }
        return nil
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
    }

    private func addProgressObserver() {
        guard let player else { return }
        let interval = CMTime(seconds: 5, preferredTimescale: 1)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, time.isValid, time.seconds.isFinite else { return }
                self.persistProgress(position: time.seconds)
            }
        }
    }

    private func persistProgress(position: TimeInterval) {
        guard let modelContext else { return }
        let videoID = video.id
        let descriptor = FetchDescriptor<WatchHistoryItem>(predicate: #Predicate { $0.videoID == videoID })
        let duration = detail?.video.duration ?? video.duration
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.lastPlaybackPosition = position
            existing.watchedAt = .now
        } else {
            modelContext.insert(WatchHistoryItem(
                videoID: video.id,
                title: video.title,
                thumbnailURLString: video.thumbnailURL?.absoluteString,
                channelID: video.channel.id,
                channelName: video.channel.name,
                duration: duration,
                lastPlaybackPosition: position
            ))
        }
        try? modelContext.save()
    }

    private func lastPlaybackPosition(videoID: String) -> TimeInterval {
        guard let modelContext else { return 0 }
        let descriptor = FetchDescriptor<WatchHistoryItem>(predicate: #Predicate { $0.videoID == videoID })
        return (try? modelContext.fetch(descriptor).first)?.lastPlaybackPosition ?? 0
    }
}
