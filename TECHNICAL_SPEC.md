# CanvasCode: Technical Specification & Requirements

**Project Codename:** CanvasCode
**Tier:** 0 (Flagship Product)
**Status:** Blueprint
**Owner:** Master Control

## 1. Vision

CanvasCode is a next-generation, AI-native design and development environment for creating beautiful, production-ready applications for both the Apple and web ecosystems. It abandons traditional, rigid coding workflows in favor of a fluid, intuitive, and "vibe-driven" creative process. Users can design visually, speak naturally, or even show the AI a picture, and CanvasCode will translate that intent into clean, exportable Swift and React code in real-time.

It is designed from the ground up to be a showcase for Apple's on-device intelligence, leveraging the full power of the Apple Silicon ecosystem to provide a private, efficient, and deeply integrated experience. It is not just a tool; it is a creative partner.

## 2. Core Principles

-   **Visual-First, Code-Aware:** The primary interface is a visual canvas, reminiscent of professional creative tools like Procreate. However, every visual element is backed by real code, which is always accessible and editable.
-   **AI-Native & On-Device First:** The application's intelligence is powered by Apple's Foundation Models, running directly on the user's device. This ensures privacy, speed, and offline capability. Cloud-based models (like ChatGPT) are available as an optional, explicitly-disclosed alternative.
-   **Ethical AI Positioning:** The app will transparently communicate the benefits of on-device processing (privacy, efficiency, lower carbon footprint) versus cloud-based models, empowering users to make an informed choice.
-   **Seamless Cross-Platform Experience:** Projects are synced via iCloud and the experience is tailored to the strengths of each device (iPhone, iPad, Mac), with deep integration of Apple's Continuity features.
-   **Self-Extensible System (JARVIS Core):** The CanvasCode engine will be a core competency of the JARVIS system, allowing JARVIS to programmatically design and generate UIs for its own modules and tools.

## 3. Platform-Specific Strategy

CanvasCode will be delivered as a unified experience across three tiers of Apple hardware, each with a specific focus:

| Platform | Primary Role | Key Features |
| :--- | :--- | :--- |
| **iPhone** | **Capture & Ideation** | A lightweight, voice-first interface for capturing UI ideas on the go. Users can describe a UI, and the app generates the initial Swift code and syncs it to iCloud. |
| **iPad** | **Visual Design & Refinement** | The primary creative canvas. A touch-and-Pencil-first experience for visually designing, arranging, and styling components. Full access to AI features. |
| **Mac** | **Full Development Studio** | Includes the complete visual canvas of the iPad app, plus a powerful, integrated code editor and deep developer-focused features. The ultimate environment for finalizing and exporting projects. |

## 4. Key Features & Technical Implementation

### 4.1. Core Functionality

-   **Visual Canvas:** A freeform, infinite canvas where users can draw, arrange, and style UI components. The UI will be intuitive and gesture-based, avoiding the rigidity of traditional design tools.
-   **Real-time Code Generation:** All visual manipulations on the canvas will be instantly translated into both SwiftUI and React code, visible in a side-by-side or tabbed view.
-   **Dual-Platform Export:** Users can export their project in three distinct formats:
    -   **Pure Swift:** A clean, production-ready, and buildable Xcode project.
    -   **Pure React:** A set of organized React components (`.tsx` files) for web projects.
    -   **Hybrid Component:** A self-contained SwiftUI View that wraps a `WKWebView` pointing to the generated React code. This component can be dropped into any existing native iOS project, allowing the React portion to handle its own backend service connections independently.
-   **Live Simulation Environment:** A "Run" mode that presents the designed UI as a fully interactive, high-fidelity simulation. This allows for testing the user flow and visual fidelity of the front-end directly within the app. The simulation targets will be platform-specific and will include a new **Hybrid App** target. This will launch a simulation of the native SwiftUI host app running the React code inside a `WKWebView`, allowing for end-to-end testing of the complete hybrid experience.

### 4.2. AI-Powered Inputs & Generation

-   **Voice-to-UI:** Leveraging the `FoundationModels` framework, users can describe UI layouts and components in natural language (e.g., "Create a login screen with a logo, two text fields, and a button").
-   **Image-to-UI:** Using `VisionKit` and the multimodal capabilities of the on-device model, users can take a picture of a hand-drawn sketch or a whiteboard wireframe, and the app will generate the corresponding UI code.

### 4.3. Deep Apple Ecosystem Integration

-   **Foundation Models Framework:** This is the heart of the app's intelligence. We will use `SystemLanguageModel` for all language tasks, `@Generable` for structured data output, and the `Tool` protocol to allow the model to interact with app features.
-   **Visual Intelligence:** With user permission, the app will leverage the system's ability to understand on-screen content, allowing users to reference elements from other apps in their designs.
-   **Native Continuity Suite:**
    -   **Handoff:** Start a design on an iPhone and seamlessly continue on an iPad or Mac.
    -   **Sidecar:** Use an iPad as a live, interactive preview canvas for the Mac app.
    -   **Universal Control:** Use a single keyboard and mouse to control the app running on both a Mac and an iPad simultaneously.
    -   **Continuity Camera:** Instantly pull photos of sketches from an iPhone into a project on a Mac or iPad.
-   **iCloud Sync:** All projects, components, and assets will be stored in iCloud Drive, ensuring they are always available and up-to-date across all of the user's devices.

### 4.4. Developer-Focused Features (Mac App)

-   **One-Click Xcode Project:** A button to generate and open a complete, buildable Xcode project from the current canvas design.
-   **Remote Build & Preview:** The ability to trigger a build process on a remote machine (e.g., the user's primary development Mac) directly from the iPad or iPhone app.

## 5. JARVIS Core Integration

CanvasCode will not be just a standalone app; its engine will be a fundamental, extensible component of the JARVIS system.

-   **Programmatic UI Generation:** JARVIS will have an internal API to access the CanvasCode engine. This will allow JARVIS to dynamically generate user interfaces for its own modules, create new ad-hoc tools, or even modify its own settings UI.
-   **Self-Modification:** This creates a powerful feedback loop where JARVIS can design, build, and deploy new versions of its own tools and interfaces in response to user needs or system changes.

## 6. Architectural Clarifications

-   **Export Limitation:** The React export will be limited to the UI component structure and styling. It will **not** and **cannot** transpile the deep native Swift logic that powers the `FoundationModels` integration, Continuity features, or other system-level APIs. This distinction will be made clear to the user during the export process.
-   **Repo Rename:** The GitHub repository `AniketMan/AppleVibeNotebook` should be renamed to `AniketMan/CanvasCode` to reflect the new project vision.
