import Foundation
 
public actor PipedAPIClient: VideoSearchService, VideoStreamResolving {
    private let session: URLSession
    private let instances: [PipedInstance]
    private let decoder: JSONDecoder
 
    public init(
        instances: [PipedInstance] = PipedInstances.defaults,
        session: URLSession? = nil
    ) {
        self.instances = instances
        self.decoder = JSONDecoder()
        
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            // 1. Timeout faster so you don't wait 30 seconds on dead instances
            config.timeoutIntervalForRequest = 8
            
            // 2. Spoof a real iPhone Safari browser to bypass Cloudflare bot detection
            config.httpAdditionalHeaders = [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
                "Accept": "application/json, text/plain, */*"
            ]
            self.session = URLSession(configuration: config)
        }
    }
 
    public func search(query: String, nextPage: String? = nil) async throws -> SearchResultsPage {
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "filter", value: "videos")
        ]
        if let nextPage {
            queryItems.append(URLQueryItem(name: "nextpage", value: nextPage))
        }
 
        let response: PipedSearchResponse = try await get(path: "/search", queryItems: queryItems)
        let videos = response.items.compactMap(Video.init(pipedSearchItem:))
        return SearchResultsPage(
            videos: videos,
            nextPageToken: response.nextpage,
            didCorrectQuery: response.corrected ?? false,
            suggestion: response.suggestion
        )
    }
 
    public func videoDetail(videoID: String) async throws -> VideoDetail {
        let response: PipedStreamsResponse = try await get(path: "/streams/\(videoID)", queryItems: [])
        return VideoDetail(videoID: videoID, response: response)
    }
 
    private func get<T: Decodable & Sendable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        var lastError: NetworkError = .noInstancesReachable
 
        for instance in instances {
            guard let url = Self.makeURL(base: instance.baseURL, path: path, queryItems: queryItems) else {
                continue
            }
            
            print("BASE =", instance.baseURL.absoluteString)
            print("URL  =", url.absoluteString)
 
            let data: Data
            do {
                let (responseData, response) = try await session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse else {
                    lastError = .transport(underlying: "No HTTP response received")
                    continue
                }
                guard (200..<300).contains(httpResponse.statusCode) else {
                    lastError = .requestFailed(statusCode: httpResponse.statusCode)
                    continue
                }
                
                // 3. Silently skip Cloudflare HTML pages
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   !contentType.lowercased().contains("json") {
                    lastError = .transport(underlying: "Received non-JSON response (likely Cloudflare challenge)")
                    continue
                }
                
                data = responseData
            } catch {
                lastError = .transport(underlying: error.localizedDescription)
                continue
            }
 
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingFailed(underlying: String(describing: error))
            }
        }
 
        throw lastError
    }
 
    // MARK: - URL Construction
 
    private static func makeURL(base: URL, path: String, queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        // 4. The bulletproof way to append paths without Swift mangling the TLD
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = cleanPath
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        return components.url
    }
}
