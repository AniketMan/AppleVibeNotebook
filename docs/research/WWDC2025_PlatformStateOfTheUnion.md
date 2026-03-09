# WWDC 2025-102: Platform State of the Union

**Author:** Manus AI
**Date:** March 09, 2026
**Source:** WWDC 2025, Session 102

## 1.0 Overview

This document summarizes the key announcements from the WWDC 2025 Platform State of the Union, focusing on the major new technologies and design paradigms introduced for Apple platforms.

## 2.0 Key Announcements

### 2.1 Liquid Glass Design System

Apple introduced its broadest design update ever, centered around a new foundational element called **Liquid Glass**. This new design language emphasizes dynamism, expressiveness, and a focus on content.

-   **Optical Properties:** Liquid Glass combines the optical qualities of glass (refraction, reflection) with responsive fluidity.
-   **Interaction:** It provides a distinct functional layer that floats above the content, with controls that can fluidly morph and recede to minimize visual density.
-   **Hierarchy & Harmony:** The design establishes clear visual hierarchy, and its forms are influenced by the hardware and the geometry of human touch for better ergonomics and harmony.
-   **Consistency:** The design is universal across all platforms (macOS, iOS, iPadOS, watchOS), making it easier to create consistent cross-platform experiences.
-   **Adoption:** Developers can start by simply recompiling their apps, as many standard SwiftUI, UIKit, and AppKit components will automatically adopt the new design. Further refinement is possible through new APIs.

### 2.2 Apple Intelligence & Foundation Models

Apple is bringing powerful on-device generative models to its platforms through **Apple Intelligence**. The **Foundation Models framework** provides developers with direct access to these models via a Swift API.

-   **On-Device & Private:** All processing is done on-device, ensuring user privacy.
-   **Guided Generation:** A key feature that guarantees structurally correct, type-safe output from the model, eliminating the need for parsing unstructured text.
-   **Tool Calling:** Allows the model to autonomously call Swift code, enabling it to access real-time data and interact with system services.

### 2.3 End of Intel Mac Support

**macOS Tahoe** will be the final release to support Intel-based Macs. This marks the completion of the transition to Apple Silicon and allows developers to fully depend on Apple Silicon-specific features.

### 2.4 Metal 4 & Gaming

Metal 4 introduces new features to further enhance gaming on Apple platforms:

-   **Ray Tracing:** Significant performance improvements.
-   **Shader Compilation:** Faster shader compilation times.
-   **Game Porting Toolkit 3:** Simplifies the process of bringing advanced PC games to Mac.

### 2.5 Framework & API Updates

-   **WebKit for SwiftUI:** A new, simplified API for integrating web content into SwiftUI apps.
-   **AVFoundation for Multiview:** New APIs to simplify synchronized playback of multiple video streams.
-   **MLX:** Apple's open-source array framework for machine learning on Apple Silicon, with full support in Swift.
-   **Background Tasks API:** A new API on iOS and iPadOS for long-running background tasks.
-   **PermissionKit:** New tools for building safe communication features for children with parental supervision.
