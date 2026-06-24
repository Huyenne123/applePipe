import SwiftUI
import SwiftData

/// Module 1's root view: a working "Continue Watching" list driven directly
/// by SwiftData. The player (Module 4) will extend this into a full
/// tab-based shell in Module 7 — nothing here is a stub, it's a real,
/// runnable screen against real persisted data.
///
/// The search toolbar button below is a temporary entry point for
/// Module 3's `SearchView` so it's actually reachable in the running app
/// instead of dangling unused; Module 7 will replace it with Search as a
/// proper tab.
struct ContentView: View {
    @Query(sort: \WatchHistoryItem.watchedAt, order: .reverse)
    private var watchHistory: [WatchHistoryItem]
    @State private var isShowingSearch = false

    var body: some View {
        NavigationStack {
            List {
                if watchHistory.isEmpty {
                    ContentUnavailableView(
                        "No Watch History Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Videos you watch will show up here so you can pick up where you left off.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(watchHistory) { item in
                        WatchHistoryRow(item: item)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("applePipe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSearch = true
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $isShowingSearch) {
                SearchView()
            }
        }
    }
}

private struct WatchHistoryRow: View {
    let item: WatchHistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text(item.channelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.watchedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        AsyncImage(url: item.thumbnailURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(16.0 / 9.0, contentMode: .fill)
            case .failure:
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
            case .empty:
                Rectangle().fill(Color.secondary.opacity(0.2))
            @unknown default:
                Rectangle().fill(Color.secondary.opacity(0.2))
            }
        }
        .frame(width: 140, height: 79)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottom) {
            if !item.isEffectivelyFinished, item.progressFraction > 0 {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: proxy.size.width * item.progressFraction, height: 3)
                }
                .frame(height: 3)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WatchHistoryItem.self], inMemory: true)
}
