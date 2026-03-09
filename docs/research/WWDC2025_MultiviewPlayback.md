# WWDC 2025-302: Build engaging multiview playback experiences

**Author:** Manus AI
**Date:** March 09, 2026
**Source:** WWDC 2025, Session 302

## 1.0 Overview

This document summarizes the new AVFoundation and AVRouting APIs designed to simplify the creation of rich, multiview playback experiences, where multiple audio and video streams are played simultaneously.

## 2.0 Core Use Cases

1.  **Synchronized Playback:** Multiple streams of the same event (e.g., different camera angles of a sports game, a main content stream with a sign language stream) that must be perfectly synchronized.
2.  **Unsynchronized Playback:** Multiple streams of different events (e.g., various Olympic events playing simultaneously) that do not require synchronization.

## 3.0 Key APIs

### 3.1 `AVPlaybackCoordinationMedium` (for Synchronized Playback)

This AVFoundation class dramatically simplifies the synchronization of playback across multiple `AVPlayer` instances. It handles the complex coordination of:

-   Playback rate changes (play, pause)
-   Time jumps (seeks)
-   Stalling and interruptions
-   Startup synchronization

**Implementation:**

1.  Create an instance of `AVPlaybackCoordinationMedium`.
2.  Connect each `AVPlayer` to the medium using the `coordinate(with:)` method on the player's `playbackCoordinator`.

Once connected, any action (e.g., `play()`) called on one player will be automatically propagated to all other connected players, ensuring they remain in perfect sync.

### 3.2 `AVRoutingPlaybackArbiter` (for AirPlay & External Routing)

This AVRouting singleton manages the complexities of routing multiview content to external devices like Apple TV or HomePod, which often only support a single stream.

-   **`preferredParticipantForExternalPlayback`:** A property on the arbiter to specify which `AVPlayer`'s video stream should be sent to an external display (e.g., AirPlay to Apple TV). Other players will continue to play locally.
-   **`preferredParticipantForNonMixableAudioRoutes`:** A property to specify which `AVPlayer`'s audio should be sent to a non-mixable audio route (e.g., a HomePod).

### 3.3 `networkResourcePriority` (for Quality Management)

This property on `AVPlayer` allows developers to indicate the relative importance of different streams in a multiview scenario, helping the system allocate network bandwidth more effectively.

-   **`.high`:** For critical streams that require high-quality resolution (e.g., the main camera angle).
-   **`.low`:** For less important streams where lower quality is acceptable (e.g., a crowd camera).

The system uses this priority as a hint, balancing it with other factors like player size and hardware constraints to optimize the overall viewing experience.
