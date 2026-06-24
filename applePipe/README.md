# applePipe — Modules 1–4: Foundation + Networking + Search + Player

A NewPipe-inspired YouTube client, built one module at a time. Modules 1–3
laid the foundation, networking layer, and search feature. Module 4 adds
the player: real AVPlayer-backed video playback with background audio,
Picture in Picture, and watch-progress persistence.

## Xcode setup

1. Xcode 17 → File → New → Project → iOS → App. Name it **applePipe**.
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (we wire SwiftData manually below — don't check
     Xcode's "Use SwiftData" box, it generates a conflicting App file).
2. Delete the generated `ContentView.swift` and `applePipeApp.swift`.
3. Drag the `App/`, `Core/`, `Persistence/`, `Networking/`, and `Features/`
   folders from this delivery into the project navigator ("Copy items if
   needed" checked, target membership checked).

4. **Add Background Modes capability** — in Xcode, select your target →
   "Signing & Capabilities" → "+" → "Background Modes" → tick **"Audio,
   AirPlay, and Picture in Picture"**. Without this, the AVAudioSession
   can't activate in the background and the PiP button won't appear.
5. Project settings → target → General → Minimum Deployments → **iOS 17.0**
   (required by `@Model`/`@Query`/`ContentUnavailableView`).
6. Build Settings → Swift Language Version → **Swift 6**.
   (Optional but recommended: Strict Concurrency Checking → Complete.)
7. Build & run. Tap the search icon → search for something → tap any
   result → the player pushes, resolves the stream via Piped, and starts
   playback. Lock the screen or go home — audio continues. Tap the PiP
   icon to float the player in a corner. Videos you watch populate the
   "Continue Watching" list on the home screen with a red progress bar.

## What's in Module 1 (Foundation)

**`Core/Models/`** — plain `Codable`/`Sendable` value types shared by the
networking layer (Module 2) and the UI. Not persisted directly.
- `Video`, `ChannelSummary`, `Channel`
- `StreamInfo` — a resolved playable stream (DASH video/audio split, muxed,
  or HLS), with quality/codec/bitrate metadata.
- `SponsorSegment` / `SponsorBlockCategory` — mirrors the real SponsorBlock
  category list and default skip behavior.
- `Caption` — subtitle track reference.

**`Persistence/SwiftDataModels/`** — `@Model` classes, the actual on-disk
schema:
- `WatchHistoryItem` — resume position + watch history, one row per video.
- `DownloadedVideoItem` — offline download bookkeeping (status, bytes,
  local file name) for Module 6.
- `SubscribedChannelItem` — subscriptions feed.
- `SearchHistoryItem` — recent search queries.

**`App/`**
- `applePipeApp.swift` — `@main` entry point, builds the `ModelContainer`
  from the schema above and attaches it to the window.
- `ContentView.swift` — a working `@Query`-driven "Continue Watching" list
  with thumbnails, resume progress bars, and an empty state. Real,
  functioning code — just deliberately minimal until Search/Player land.

## What's in Module 2 (Networking)

**`Networking/Support/`**
- `NetworkError.swift` — shared error type for both clients below.
- `VideoServiceProtocols.swift` — `VideoSearchService`, `VideoStreamResolving`,
  `SponsorSegmentProviding`. ViewModels (Module 3+) depend on these
  protocols, not the concrete clients, so they stay unit-testable with
  fakes.

**`Networking/Piped/`** — talks to [Piped](https://docs.piped.video), the
same kind of open YouTube front-end API NewPipe-style clients build on.
- `PipedInstance.swift` — a small federated-instance list (`kavin.rocks`,
  `adminforge.de`, `lunar.icu`), user-configurable later in Settings
  (Module 8).
- `PipedDTOs.swift` — `Decodable` wire types matching Piped's actual JSON
  shapes (verified against Piped's published OpenAPI spec).
- `PipedMapping.swift` — converts those DTOs into the `Core/Models` types
  from Module 1.
- `PipedAPIClient.swift` — `public actor` implementing `VideoSearchService`
  + `VideoStreamResolving`. Tries each configured instance in order,
  failing over on network/HTTP errors (but not on decode errors, which
  mean a real schema mismatch, not a flaky instance).

**`Networking/SponsorBlock/`** — talks to the public
[SponsorBlock](https://sponsor.ajay.app) API.
- `SponsorBlockDTOs.swift` / `SponsorBlockMapping.swift` — wire types and
  mapping, verified against a real captured API response.
- `SponsorBlockClient.swift` — `public actor` implementing
  `SponsorSegmentProviding`. Uses the privacy-preserving hash-prefix
  lookup (SHA-256 of the video ID, only the first 4 hex chars sent) so the
  server never sees the plaintext video ID being queried.

This module is networking-only — there's no UI hooked up to it yet, so
nothing new will appear on screen until Module 3 (Search) wires a
`SearchViewModel` up to `PipedAPIClient`. If you want to sanity-check it
yourself in the meantime, a quick way is to drop this into a SwiftUI
`.task {}` somewhere temporary:

```swift
let client = PipedAPIClient()
let page = try await client.search(query: "swift concurrency")
print(page.videos.map(\.title))
```

## What's in Module 3 (Search)

**`Features/Search/`** — first feature module, MVVM on top of Module 2's
networking layer.
- `SearchViewModel.swift` — `@Observable` `@MainActor` view model. Takes a
  query, calls `VideoSearchService` (defaults to `PipedAPIClient`), handles
  pagination via Piped's `nextPageToken` (with a guard against a slow,
  now-stale page request clobbering results from whatever the user's
  since searched for), and persists/reads recent searches through
  `SearchHistoryItem` (SwiftData, from Module 1).
- `SearchView.swift` — `.searchable`-backed search screen: recent searches
  (swipe to delete, tap to re-run), infinite scroll, a "did you mean"
  banner driven by Piped's query-correction signal, loading and error
  states, and `ContentUnavailableView.search` for empty results.

`ContentView` now has a search toolbar button that presents `SearchView`
as a sheet — a temporary entry point so this is actually reachable and
testable in the running app. Module 7 will replace it with Search as a
proper tab. Tapping a search result doesn't do anything yet on purpose:
there's no detail/player destination to navigate to until Module 4, and a
fake destination would be exactly the kind of stub this project is
avoiding.

## What's in Module 4 (Player)

**`Features/Player/`**
- `PlayerViewModel.swift` — `@MainActor @Observable` view model. Calls
  `VideoStreamResolving` (`PipedAPIClient`) to resolve the full
  `VideoDetail`, selects a playable URL (HLS first → best muxed stream
  up to 720p), configures `AVAudioSession` for background playback, builds
  an `AVPlayer`, seeks to the last persisted position, and writes progress
  to `WatchHistoryItem` every 5 seconds via a periodic time observer.
  Tears everything down cleanly on dismiss.
- `PlayerView.swift` — `AVPlayerViewController` wrapped in a
  `UIViewControllerRepresentable` (PiP and transport controls come for
  free from the system UI). Below the player: title, view count,
  like count, upload date, channel row, collapsible description, and a
  related-videos list that pushes another `PlayerView` for each tap.

**`Features/Search/SearchView.swift`** updated — result rows are now
`NavigationLink(value: video)` with a `.navigationDestination(for:
Video.self)` that pushes `PlayerView`. Related videos in `PlayerView`
use the same destination, so you can follow a rabbit hole without
the navigation stack caring how deep it gets.

**Stream selection note** — Piped provides muxed (audio+video combined)
streams up to 720p, and separate video-only + audio-only tracks for
1080p+. The player currently picks muxed for simplicity; real adaptive
quality (combining the two separate tracks) is a future enhancement.
Most content plays fine at 720p.

## Next module

**Module 5: SponsorBlock runtime** — wires `SponsorBlockClient` from
Module 2 into the player, auto-skipping segments with an undo toast, and
adding a per-video category toggle sheet.
