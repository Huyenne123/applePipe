import Foundation

/// A single Piped API backend. Piped is federated — anyone can run an
/// instance — so `PipedAPIClient` accepts an ordered list and races them
/// all simultaneously, using whichever responds first.
public struct PipedInstance: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let baseURL: URL

    public init(name: String, baseURL: URL) {
        self.id = baseURL.absoluteString
        self.name = name
        self.baseURL = baseURL
    }
}

public enum PipedInstances {
    /// A curated list of public Piped API instances. The Piped ecosystem
    /// is highly volatile—instances frequently go offline or get blocked.
    /// This list prioritizes the official instances and known-stable backups.
    public static let defaults: [PipedInstance] = [
        // Official Instances (Hosted by the Piped lead developer)
        PipedInstance(name: "kavin.rocks", baseURL: URL(string: "https://pipedapi.kavin.rocks")!),
        PipedInstance(name: "kavin.rocks (libre)", baseURL: URL(string: "https://pipedapi-libre.kavin.rocks")!),
        
        // Reliable Third-Party Instances
        PipedInstance(name: "adminforge.de", baseURL: URL(string: "https://pipedapi.adminforge.de/")!),
        PipedInstance(name: "lunar.icu", baseURL: URL(string: "https://piped-api.lunar.icu")!),
        PipedInstance(name: "privacydev.net", baseURL: URL(string: "https://api.piped.privacydev.net")!),
        PipedInstance(name: "projectsegfau.lt", baseURL: URL(string: "https://api.piped.projectsegfau.lt")!),
    ]
}
