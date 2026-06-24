import Foundation
import Observation
import SwiftData

/// Drives the search screen: takes a query, talks to `VideoSearchService`
/// (`PipedAPIClient` by default, from Module 2), and tracks recent
/// searches via SwiftData's `SearchHistoryItem` (from Module 1).
@MainActor
@Observable
public final class SearchViewModel {
    public var query: String = ""
    public private(set) var results: [Video] = []
    public private(set) var recentSearches: [String] = []
    public private(set) var isLoading = false
    public private(set) var isLoadingMore = false
    public private(set) var errorMessage: String?
    public private(set) var suggestion: String?
    public private(set) var didCorrectQuery = false
    public private(set) var hasSearched = false

    private var nextPageToken: String?
    private var activeQuery = ""
    private let searchService: VideoSearchService
    private var modelContext: ModelContext?

    public init(searchService: VideoSearchService = PipedAPIClient()) {
        self.searchService = searchService
    }

    /// Must be called once the view has access to the environment's
    /// `ModelContext` — `@Environment` values aren't available at
    /// `View.init` time, so this can't happen inside `init` above.
    /// Safe to call more than once (e.g. each time the view appears).
    public func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadRecentSearches()
    }

    public func submitSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await performSearch(query: trimmed)
    }

    /// Re-runs a search for an explicit term — used by recent-search rows
    /// and the "did you mean" suggestion.
    public func search(for term: String) async {
        query = term
        await performSearch(query: term)
    }

    public func clear() {
        query = ""
        results = []
        nextPageToken = nil
        errorMessage = nil
        suggestion = nil
        didCorrectQuery = false
        hasSearched = false
    }

    public func dismissError() {
        errorMessage = nil
    }

    private func performSearch(query: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        suggestion = nil
        didCorrectQuery = false
        hasSearched = true
        activeQuery = query
        results = []
        nextPageToken = nil
        defer { isLoading = false }

        do {
            let page = try await searchService.search(query: query, nextPage: nil)
            results = page.videos
            nextPageToken = page.nextPageToken
            suggestion = page.suggestion
            didCorrectQuery = page.didCorrectQuery
            recordSearch(query)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Call from each row's `.task` — triggers the next page once the
    /// user scrolls within the last few results. Cheap to call
    /// frequently: it no-ops unless `video` is actually near the end.
    public func loadMoreIfNeeded(currentItem video: Video) async {
        guard let nextPageToken, !isLoadingMore, !isLoading else { return }
        guard let index = results.firstIndex(of: video), index >= results.count - 5 else { return }

        // Captured so a slow response from a now-abandoned query can't
        // clobber results for whatever the user has since searched for.
        let queryAtRequestTime = activeQuery
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await searchService.search(query: queryAtRequestTime, nextPage: nextPageToken)
            guard queryAtRequestTime == activeQuery else { return }
            results.append(contentsOf: page.videos)
            self.nextPageToken = page.nextPageToken
        } catch {
            guard queryAtRequestTime == activeQuery else { return }
            // There are already results on screen; stop paginating
            // quietly rather than surfacing a noisy error banner.
            self.nextPageToken = nil
        }
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Something went wrong while searching."
    }

    // MARK: - Recent searches (SwiftData)

    private func loadRecentSearches() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<SearchHistoryItem>(
            sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
        )
        let items = (try? modelContext.fetch(descriptor)) ?? []
        recentSearches = items.prefix(10).map(\.query)
    }

    private func recordSearch(_ term: String) {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<SearchHistoryItem>(predicate: #Predicate { $0.query == term })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.searchedAt = .now
        } else {
            modelContext.insert(SearchHistoryItem(query: term))
        }
        try? modelContext.save()
        loadRecentSearches()
    }

    public func deleteRecentSearch(_ term: String) {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<SearchHistoryItem>(predicate: #Predicate { $0.query == term })
        if let item = try? modelContext.fetch(descriptor).first {
            modelContext.delete(item)
            try? modelContext.save()
        }
        loadRecentSearches()
    }
}
