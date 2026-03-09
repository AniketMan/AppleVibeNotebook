# CanvasCode Architecture & Alignment Report
*Generated on March 8, 2026*

This document provides a comprehensive analysis of the CanvasCode (AppleVibeNotebook) codebase, identifying critical architectural divergence from the `TECHNICAL_SPEC.md`, `UI_INSTRUCTIONS.md`, and Apple's WWDC 2025 iPadOS 26 design guidelines.

## 1. Codebase State & Recent Improvements

The repository currently consists of approximately 36,900 lines of Swift code across two targets. The core library (`AppleVibeNotebook`) handles parsers, intermediate representation, mappings, and code generation. The application target (`AppleVibeNotebookApp`) manages the UI, services, and canvas simulation.

Recent sessions have successfully established the foundational iPad architecture. The application now correctly routes iPad users to the `CanvasWorkspaceView`, overlaid with the `LiquidGlassCompanion`. The core canvas state management (`CanvasState`), infinite canvas rendering, and the Apple Pencil sketch-to-UI pipeline are functional. Furthermore, a critical Swift 6 strict concurrency crash in the `VoiceInputService` was resolved by implementing `@Sendable` closures and method-level `@MainActor` isolation.

## 2. Critical Architectural Divergence

Despite the progress on the iPad canvas, the application suffers from severe architectural debt and direct violations of the project specifications.

### 2.1. Identity Crisis: Dual State Management
The application maintains two entirely separate state objects that do not communicate, reflecting a split personality between the legacy "notebook" concept and the modern "visual canvas" architecture. 

The `AppState` object remains bloated with legacy properties from the old converter paradigm, including `notebooks`, `activeNotebook`, and `showImportPanel`. Conversely, `CanvasState` serves as the correct, modern state object driving the visual canvas. This dual-state system creates a fractured data flow and must be unified by deprecating the legacy properties in `AppState` and transitioning fully to `CanvasState`.

### 2.2. macOS Disconnected from Modern Architecture
The `UI_INSTRUCTIONS.md` explicitly mandates that the iPad implementation serves as the reference, and the macOS version must inherit this layout. Currently, this is entirely ignored. 

The `ContentView.macOSContentView()` continues to route users to outdated, legacy views such as `NotebookEditorView` and `WorkspaceView`. The macOS application is completely disconnected from the new canvas architecture and requires an immediate rewrite to achieve feature parity with the iPad.

### 2.3. Legacy Code and Dead Weight
Section 7 of the `UI_INSTRUCTIONS.md` explicitly marks several files for deletion, yet they remain active in the macOS build path. The split-view notebook paradigm is dead, but its artifacts persist.

The following files must be purged from the repository:
- `WorkspaceView.swift`
- `SidebarView.swift`
- `WelcomeView.swift`
- `NeonLiquidGlass.swift` (Generic components unrelated to the AI orb)
- The inline `ConvertToolView` and `NotebookEditorView` within `ContentView.swift`

### 2.4. Complete Absence of Liquid Glass Implementation
The most egregious violation of the UI specifications is the complete lack of Apple's Liquid Glass design language. The `UI_INSTRUCTIONS.md` dictates that every floating panel, toolbar, and button must utilize Liquid Glass APIs. 

Currently, **zero** `.glassEffect()` or `GlassEffectContainer` modifiers exist in the codebase. Every UI element relies on legacy materials (`.ultraThinMaterial`, `.regularMaterial`) or hardcoded opaque colors. Crucially, the `LiquidGlassCompanion` (the AI orb) is rendered as an opaque painted circle, entirely lacking the required translucency, refraction, and dispersion effects that define its character.

## 3. WWDC 2025 iPadOS 26 Alignment

An analysis of the WWDC 2025 session "Elevate your iPad app" reveals significant gaps between CanvasCode's current implementation and Apple's modern iPadOS 26 design patterns.

### 3.1. Fluid Navigation and Morphing
Apple emphasizes starting with a Tab Bar that can fluidly morph into a Sidebar as screen real estate expands or contracts. CanvasCode currently lacks any cohesive navigation structure for project management. The Homescreen gallery defined in the UI instructions must implement this morphing navigation pattern to manage Cloud Documents, Local Storage, and Shared files effectively.

### 3.2. Additive Windowing Behavior
iPadOS 26 deprecates "Open in Place" behavior for multitasking applications. The system now expects each document to open in its own distinct window, persisting until explicitly closed. CanvasCode has no multi-window support. The application must be updated to use `WindowGroup` scenes, generating a new, descriptively named window for each canvas project.

### 3.3. Toolbar and Window Controls Integration
The new window controls in iPadOS 26 appear on the leading edge of the app toolbar. If the toolbar does not wrap around these controls, the system forces a permanent, suboptimal safe area above the toolbar. Currently, `CanvasToolbar` is absolutely positioned (`x: width/2, y: 60`) and does not participate in the system layout. It must be refactored to wrap around the window controls, reclaiming vertical space for the canvas.

### 3.4. Liquid Glass Pointer Hover Effects
The iPad pointer in iPadOS 26 no longer morphs into buttons. Instead, a liquid glass platter materializes directly on top of the hovered control, bending and refracting the underlying elements. CanvasCode's buttons do not support this interaction because they lack the required `.glassEffect(.regular.interactive())` modifier. This material system migration is required to support the new pointer behavior.

## 4. Action Plan

To realign the codebase with the technical specifications and Apple's design guidelines, the following actions must be prioritized:

1. **Execute a Material System Migration:** Replace all legacy materials and hardcoded backgrounds with Liquid Glass APIs (`.glassEffect()`, `GlassEffectContainer`) across the entire application, starting with the AI Companion orb.
2. **Purge Legacy Architecture:** Delete all files associated with the old notebook and converter paradigms.
3. **Unify the State:** Consolidate `AppState` and `CanvasState` into a single source of truth.
4. **Align macOS:** Update the macOS routing to inherit the iPad's `CanvasWorkspaceView`.
5. **Implement iPadOS 26 Features:** Introduce additive windowing, morphing navigation for the Homescreen, and refactor the toolbar to wrap around system window controls.
