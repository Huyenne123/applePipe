import Foundation
import SwiftData

@Model
public final class SearchHistoryItem {
    @Attribute(.unique) public var query: String
    public var searchedAt: Date

    public init(query: String, searchedAt: Date = .now) {
        self.query = query
        self.searchedAt = searchedAt
    }
}
