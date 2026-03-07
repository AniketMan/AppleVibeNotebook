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

## 5. Component Hierarchy & Object Library

The component system is the backbone of CanvasCode. It is designed to eliminate the repetitive, copy-paste-driven workflow that plagues tools like Figma, replacing it with a clean, hierarchical, and reusable architecture.

### 5.1. Hierarchy

| Level | Name | Description |
| :--- | :--- | :--- |
| **Component** | Base building block | A reusable UI element (e.g., "Button", "Card", "NavBar"). It has configurable properties exposed as sliders, color pickers, toggles, and other direct-manipulation controls. |
| **Preset** | Saved configuration | A specific, saved set of property values for a Component. For example, a "Primary CTA" Preset of the Button Component with rounded corners, a blue gradient, and bold text. Presets are first-class citizens in the Object Library. |
| **Composition** | Component of Components | A higher-order element assembled from other Components and Presets. A "Login Form" Composition might contain a Logo Component, two TextField Components, and a Button Preset. Each child retains its own configurability. |
| **App** | Full project | A collection of Compositions arranged into screens and views with defined navigation flows between them. |

### 5.2. Object Library

A persistent, searchable panel (analogous to Procreate's brush library) where all of the user's Components, Presets, and Compositions are organized and accessible. Users drag items from the Object Library directly onto the canvas. There is no copy-pasting, no file hunting, and no recreating elements from scratch.

### 5.3. Inheritance & Overrides

If the user updates a base Component (e.g., changes the default font on the "Button" Component), every Preset and every Composition that uses it will inherit the change automatically. However, if a user has explicitly overridden a specific property on a particular instance (e.g., changed the font color on one specific Button Preset), that override will be preserved and will not be affected by upstream changes.

### 5.4. Sliders for Everything

Every configurable property on a Component will be exposed as a direct-manipulation control: sliders for numeric values (corner radius, padding, font size, opacity, animation duration), color pickers for colors, dropdowns for easing curves, toggles for boolean states. The user changes it visually; the code updates in real-time behind the scenes. The code view is always available but never required.

### 5.5. Portable Component Export

Any individual Component, Preset, or Composition can be exported independently, without exporting an entire App. This allows a user to design a single polished UI element with a custom animation and drop it directly into an existing Swift or React project. This is a core daily-use workflow.

### 5.6. "Save as Component" from Any Project

While working inside an App project, a user can long-press (or right-click on Mac) any element or group of elements on the canvas and select "Save as Component" from the context menu. This promotes the selection to the user's global Component Library, extracting it from the project it was created in. From that point forward, the Component is available in the Object Library for use in any other project. The user can then create Presets of it, nest it inside Compositions, or export it independently. The workflow is: build it once, save it, reuse it forever. No element should ever be "trapped" inside a single project.

### 5.7. Platform Starter Templates

When creating a new Component, the user can start from a blank canvas or from a platform-specific starter template. Templates will be provided for common UIKit elements (Button, TableViewCell, NavigationBar), SwiftUI views (NavigationStack, List, TabView), and React components (Card, Modal, Form). The template provides the base structure and standard properties; the user customizes from there using the visual controls.

## 6. Live Simulation Environment

The "Run" mode will present the designed UI as a fully interactive, high-fidelity simulation directly within CanvasCode. The available simulation targets depend on the platform:

| Running On | Can Simulate |
| :--- | :--- |
| **Mac** | iPhone, iPad, Mac window, Hybrid App, Web App |
| **iPad** | iPhone, iPad, Hybrid App, Web App |
| **iPhone** | iPhone, Web App |

The simulation covers the full UI layer: tapping buttons, navigating between screens, triggering animations, and scrolling through content. It will not connect to live backend services or databases. It is for testing user flow and visual fidelity only. The Hybrid App simulation target will launch the native SwiftUI host running the React code inside a `WKWebView`, allowing end-to-end testing of the complete hybrid experience.

### 6.1. React-as-Web-App on Device

If a user builds a React project in CanvasCode, they can run it as a local web application directly on their device via a `WKWebView`. No external server is required. The generated React code is bundled and rendered locally, providing an instant, self-contained preview of the web application. This is available on all platforms (iPhone, iPad, Mac).

## 7. JARVIS Core Integration

CanvasCode will not be just a standalone app; its engine will be a fundamental, extensible component of the JARVIS system.

-   **Programmatic UI Generation:** JARVIS will have an internal API to access the CanvasCode engine. This will allow JARVIS to dynamically generate user interfaces for its own modules, create new ad-hoc tools, or even modify its own settings UI.
-   **Self-Modification:** This creates a powerful feedback loop where JARVIS can design, build, and deploy new versions of its own tools and interfaces in response to user needs or system changes.

## 8. Architectural Clarifications

-   **Export Limitation:** The React export will be limited to the UI component structure and styling. It will **not** and **cannot** transpile the deep native Swift logic that powers the `FoundationModels` integration, Continuity features, or other system-level APIs. This distinction will be made clear to the user during the export process.
-   **Repo Rename:** ~~The GitHub repository `AniketMan/AppleVibeNotebook` should be renamed to `AniketMan/CanvasCode`.~~ **DONE.** The repository is now `AniketMan/CanvasCode`.

## 9. Apple Human Interface Guidelines Compliance

The entire application will be built in strict adherence to Apple's Human Interface Guidelines (HIG). This is a non-negotiable requirement. All navigation patterns, touch targets, typography scales, spacing, safe area insets, Dynamic Type support, and accessibility features will conform to Apple's published specifications. No custom navigation hacks, no non-standard gestures, no deviations. If Apple's guidelines specify a behavior, CanvasCode will implement it exactly.

## 10. Performance Requirements

Performance is a first-class requirement, not an afterthought. The application will be optimized specifically for Apple Silicon hardware.

-   **Canvas Rendering:** The infinite canvas must maintain 60fps (120fps on ProMotion displays) during pan, zoom, and component manipulation, regardless of project complexity.
-   **Code Generation:** Real-time code generation must not introduce perceptible latency. Visual changes on the canvas must be reflected in the code view within one frame.
-   **AI Inference:** On-device Foundation Model inference must not block the main thread. All AI operations will run asynchronously with clear progress indication.
-   **Simulation:** The Live Simulation Environment must run at native frame rates with no dropped frames during animation previews.
-   **Memory:** The app must be aggressive about memory management, especially on iPhone and iPad where resources are more constrained. Large projects must use lazy loading and virtualization for off-screen components.
