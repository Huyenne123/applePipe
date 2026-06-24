import SwiftUI
import SwiftData

/// The search screen: a `.searchable`-backed video search UI with recent
/// searches, infinite scroll, and "did you mean" handling. Tapping a
/// result pushes `PlayerView` via `NavigationLink(value:)` + a registered
/// `.navigationDestination(for: Video.self)`.
///
/// Reachable from `ContentView`'s toolbar as a sheet for now; Module 7
/// will move it into a proper tab.
public struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SearchViewModel

    public init(searchService: VideoSearchService = PipedAPIClient()) {
        _viewModel = State(wrappedValue: SearchViewModel(searchService: searchService))
    }

    public var body: some View {
        NavigationStack {
            List {
                if let suggestion = viewModel.suggestion {
                    suggestionRow(suggestion)
                }

                if !viewModel.hasSearched {
                    recentSearchesSection
                } else {
                    ForEach(viewModel.results) { video in
                        NavigationLink(value: video) {
                            SearchResultRow(video: video)
                        }
                        .buttonStyle(.plain)
                        .task {
                            await viewModel.loadMoreIfNeeded(currentItem: video)
                        }
                    }

                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .navigationDestination(for: Video.self) { video in
                PlayerView(video: video)
            }
            .searchable(
                text: Binding(get: { viewModel.query }, set: { viewModel.query = $0 }),
                prompt: "Search videos"
            )
            .onSubmit(of: .search) {
                Task { await viewModel.submitSearch() }
            }
            .overlay {
                if viewModel.isLoading && viewModel.results.isEmpty {
                    ProgressView()
                } else if viewModel.hasSearched && viewModel.results.isEmpty && viewModel.suggestion == nil {
                    ContentUnavailableView.search(text: viewModel.query)
                }
            }
            .alert(
                "Search Failed",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { isPresented in if !isPresented { viewModel.dismissError() } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .task {
            viewModel.configure(modelContext: modelContext)
        }
    }

    @ViewBuilder
    private func suggestionRow(_ suggestion: String) -> some View {
        if viewModel.didCorrectQuery {
            Label("Showing results for \"\(suggestion)\"", systemImage: "arrow.triangle.2.circlepath")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)
        } else {
            Button {
                Task { await viewModel.search(for: suggestion) }
            } label: {
                Label("Did you mean \"\(suggestion)\"?", systemImage: "questionmark.circle")
                    .font(.footnote)
            }
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var recentSearchesSection: some View {
        if viewModel.recentSearches.isEmpty {
            ContentUnavailableView(
                "Search for Videos",
                systemImage: "magnifyingglass",
                description: Text("Find anything on YouTube, no account or algorithm required.")
            )
            .listRowSeparator(.hidden)
        } else {
            Section("Recent Searches") {
                ForEach(viewModel.recentSearches, id: \.self) { term in
                    Button {
                        Task { await viewModel.search(for: term) }
                    } label: {
                        Label(term, systemImage: "clock")
                    }
                    .foregroundStyle(.primary)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteRecentSearch(term)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

private struct SearchResultRow: View {
    let video: Video

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    channelAvatar
                    Text(video.channel.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if video.channel.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(video.formattedViewCount) • \(video.formattedUploadDate)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        AsyncImage(url: video.thumbnailURL) { phase in
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
        .overlay(alignment: .bottomTrailing) { durationBadge }
        .overlay(alignment: .topLeading) {
            if video.isShort { shortsBadge }
        }
    }

    private var durationBadge: some View {
        Text(video.formattedDuration)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
            .padding(4)
    }

    private var shortsBadge: some View {
        Text("SHORTS")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.red, in: RoundedRectangle(cornerRadius: 4))
            .padding(4)
    }

    @ViewBuilder
    private var channelAvatar: some View {
        AsyncImage(url: video.channel.avatarURL) { phase in
            if case .success(let image) = phase {
                image.resizable()
            } else {
                Circle().fill(Color.secondary.opacity(0.3))
            }
        }
        .frame(width: 16, height: 16)
        .clipShape(Circle())
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [SearchHistoryItem.self], inMemory: true)
}
