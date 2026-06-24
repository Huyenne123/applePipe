import SwiftUI
import AVKit
import SwiftData

/// The player screen: a 16:9 `AVPlayerViewController` on top, scrollable
/// metadata + description panel below, and a related-videos list that
/// pushes a new `PlayerView` for each tap (handled by the parent
/// `NavigationStack`'s `.navigationDestination`).
///
/// **Xcode setup required** — before running, open your target's
/// "Signing & Capabilities" and add "Background Modes", then tick
/// "Audio, AirPlay, and Picture in Picture". Without this the audio
/// session can't activate in the background and PiP won't appear.
public struct PlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PlayerViewModel
    @State private var isDescriptionExpanded = false
    @State private var isShowingCategorySheet = false

    public init(video: Video, streamResolver: VideoStreamResolving = PipedAPIClient()) {
        _viewModel = State(wrappedValue: PlayerViewModel(video: video, streamResolver: streamResolver))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                playerArea
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .background(Color.black)

                Group {
                    if let detail = viewModel.detail {
                        infoPanel(detail)
                    } else if viewModel.isLoading {
                        loadingPlaceholder
                    } else if let msg = viewModel.errorMessage {
                        errorPanel(msg)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCategorySheet = true
                } label: {
                    Image(systemName: "theatermasks")
                }
                .opacity(viewModel.sponsorSegments.isEmpty ? 0.4 : 1)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.skipToast {
                skipToastView(toast)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.skipToast != nil)
        .sheet(isPresented: $isShowingCategorySheet) {
            SponsorBlockCategorySheet(enabledCategories: $viewModel.enabledCategories)
                .presentationDetents([.medium, .large])
        }
        .task {
            viewModel.configure(modelContext: modelContext)
            await viewModel.load()
        }
        .onDisappear {
            viewModel.handleDismiss()
        }
    }

    // MARK: - Skip toast

    private func skipToastView(_ toast: PlayerViewModel.SkipToast) -> some View {
        HStack(spacing: 12) {
            Text("Skipped: \(toast.categoryName)")
                .font(.caption)
                .foregroundStyle(.white)
            Button("Undo") {
                viewModel.undoSkip()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.82), in: Capsule())
    }

    // MARK: - Player area

    @ViewBuilder
    private var playerArea: some View {
        if let player = viewModel.player {
            VideoPlayerRepresentable(player: player)
        } else {
            ZStack {
                Color.black
                AsyncImage(url: viewModel.video.thumbnailURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .opacity(0.4)
                    }
                }
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else if viewModel.errorMessage != nil {
                    Image(systemName: "exclamationmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Info panel

    @ViewBuilder
    private func infoPanel(_ detail: VideoDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(detail.video.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Text(detail.video.formattedViewCount)
                if !detail.video.formattedUploadDate.isEmpty {
                    Text("·")
                    Text(detail.video.formattedUploadDate)
                }
                Spacer()
                if let likes = detail.likeCount {
                    Label(formatCount(likes), systemImage: "hand.thumbsup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            channelRow(detail.video.channel)

            if !detail.video.description.isEmpty {
                Divider()
                descriptionBlock(detail.video.description)
            }

            if !detail.relatedVideos.isEmpty {
                Divider()
                Text("Related")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(detail.relatedVideos) { related in
                    NavigationLink(value: related) {
                        RelatedVideoRow(video: related)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }

    private func channelRow(_ channel: ChannelSummary) -> some View {
        HStack(spacing: 10) {
            AsyncImage(url: channel.avatarURL) { phase in
                if case .success(let image) = phase {
                    image.resizable()
                } else {
                    Circle().fill(Color.secondary.opacity(0.25))
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            HStack(spacing: 4) {
                Text(channel.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if channel.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func descriptionBlock(_ text: String) -> some View {
        let truncated = String(text.prefix(160))
        let needsToggle = text.count > 160
        VStack(alignment: .leading, spacing: 4) {
            Text(isDescriptionExpanded ? text : truncated)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if needsToggle {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDescriptionExpanded.toggle()
                    }
                } label: {
                    Text(isDescriptionExpanded ? "Show less" : "Show more")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - State panels

    private var loadingPlaceholder: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .frame(height: 16)
            }
        }
        .padding()
        .redacted(reason: .placeholder)
    }

    private func errorPanel(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    // MARK: - Helpers

    private func formatCount(_ n: Int) -> String {
        switch n {
        case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000)
        case 1_000...:     return String(format: "%.1fK", Double(n) / 1_000)
        default:           return "\(n)"
        }
    }
}

// MARK: - AVPlayerViewController bridge

private struct VideoPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.allowsPictureInPicturePlayback = true
        vc.canStartPictureInPictureAutomaticallyFromInline = true
        vc.showsPlaybackControls = true
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Only update if the player instance actually changed — AVPlayerViewController
        // manages its own playback controls state, so mutating it unnecessarily
        // causes a flicker.
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: ()) {
        uiViewController.player?.pause()
        uiViewController.player = nil
    }
}

// MARK: - Related video row

private struct RelatedVideoRow: View {
    let video: Video

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: video.thumbnailURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(16.0 / 9.0, contentMode: .fill)
                } else {
                    Rectangle().fill(Color.secondary.opacity(0.2))
                }
            }
            .frame(width: 110, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .bottomTrailing) {
                Text(video.formattedDuration)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3))
                    .padding(3)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text(video.channel.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PlayerView(video: Video(
            id: "dQw4w9WgXcQ",
            title: "Rick Astley — Never Gonna Give You Up (Official Music Video)",
            channel: ChannelSummary(id: "UCuAXFkgsw1L7xaCfnd5JJOw", name: "Rick Astley", isVerified: true),
            duration: 213,
            viewCount: 1_400_000_000,
            description: "The official video for Never Gonna Give You Up by Rick Astley."
        ))
    }
}
