# CanvasCode UI Instructions & Architecture Guide

## 1. Interface Philosophy

The CanvasCode user interface is built on the core principle that the document (the canvas) is the center of the experience. The chrome must be minimal, floating, and contextual, deferring maximum screen real estate to the user's design. This philosophy draws heavily from the design patterns of Linearity Curve, Linearity Move, and Essayist, adapted for a voice-first AI design tool.

The application abandons traditional heavy sidebars and fixed toolbars in favor of a fluid, adaptive interface that feels native to both iPadOS and macOS. Every control should be exactly where it is needed, when it is needed, and invisible otherwise.

## 2. Global Layout Architecture

The application interface is divided into four primary zones. These zones remain conceptually consistent across iPad and Mac, though their specific implementations adapt to the platform's input methods.

### 2.1. The Canvas (Center)
The canvas is an infinite, scrollable, zoomable workspace. It is the primary view of the application. All UI designs are represented as artboards on this canvas. The canvas background should support both light and dark modes, with a preference for a deep, neutral dark gray in dark mode to allow the designed UI elements to stand out. 

### 2.2. The Floating Toolbar (Left Edge)
Instead of a fixed sidebar, the primary tools are housed in a floating, pill-shaped toolbar anchored to the middle-left edge of the screen. This pattern, inspired by Essayist, ensures tools are always accessible without permanently consuming horizontal space.

**Contents:**
- Selection Tool
- Text Tool
- Component Library (Opens Object Library popover)
- Export Menu

### 2.3. The Contextual Inspector (Right Edge)
When an element or artboard is selected, a contextual Inspector panel appears on the right edge. If nothing is selected, this panel should collapse or hide completely to maximize canvas space.

**Structure:**
- **Style Tab:** Controls for Position (X, Y), Dimensions (W, H), Opacity, Fill, Stroke, Effects (including the Liquid Glass effect controls: Frostness, Refraction, Depth, Dispersion).
- **Layout Tab:** Z-index ordering (Bring Forward, Send Backward), Grouping, Masking, and Alignment controls.
- **Code View Tab:** A split-view or toggleable panel that reveals the generated SwiftUI or React code for the selected component.

### 2.4. The Action Bar (Top Center)
A minimal, floating pill at the top center of the screen handles document-level actions.

**Contents:**
- Undo / Redo
- Zoom Percentage Dropdown
- Document Name
- Play Mode Toggle (Full-screen simulation)

## 3. The Liquid Glass Companion (Voice UI)

As defined in the technical specification, the Liquid Glass Companion is the most critical UI element in CanvasCode. It serves as the primary voice interaction surface and the embodiment of the AI.

### 3.1. Visual Design
The Companion is a translucent, floating orb that utilizes the Liquid Glass design language. It must feature real-time refraction, depth, and dispersion effects, reacting dynamically to the content beneath it on the canvas.

### 3.2. Interaction States
- **Idle:** The orb exhibits a slow, organic "breathing" animation, drifting slightly to feel alive.
- **Listening:** When the user speaks, the orb deforms and stretches in real-time, syncing with the audio waveform's amplitude and frequency.
- **Processing:** The orb transitions to a smooth, internal swirling animation, indicating the AI is generating code or analyzing the request.
- **Responding:** The orb pulses gently in sync with the AI's audio or text output.

### 3.3. Positioning
The Companion is a floating element that the user can drag and place anywhere on the screen. Its position must be persisted across sessions. It must never be obscured by other UI panels.

## 4. Interaction Patterns

### 4.1. Popovers Over Modals
CanvasCode strictly favors contextual popovers over full-screen modals. When a user needs to select a font, pick a color, or adjust citation styles (as seen in Essayist), the UI should present a clean, card-based popover attached to the relevant control. Modals should be reserved exclusively for destructive actions or critical document-level settings.

### 4.2. Direct Manipulation
Properties in the Inspector must use direct manipulation controls. Numeric values (corner radius, padding, opacity) should be adjustable via sliders or by dragging horizontally on the value field itself. Color selection should use inline swatches that expand into a full picker.

### 4.3. Empty Artboard Selection
Following modern vector tool patterns, empty artboards can be selected by clicking anywhere inside their bounds. Once an artboard contains elements, clicking the background space will deselect current items, and the artboard itself must be selected by clicking its title label above the frame.

## 5. Platform-Specific Adaptations

While the core architecture is shared, specific adaptations are required for the best experience on each platform.

### 5.1. iPadOS
- The Floating Toolbar and Action Bar must have touch-friendly hit targets (minimum 44x44pt).
- The Inspector panel should support swipe-to-dismiss gestures.
- Support for Apple Pencil hover states to preview selection bounds before tapping.

### 5.2. macOS
- The Action Bar functionality can be partially mirrored in the standard macOS Menu Bar.
- The Floating Toolbar can optionally be docked to the left edge as a standard sidebar if the user prefers a more traditional window layout.
- Full keyboard shortcut support for all tools and Inspector actions.

## 6. Implementation Directives

1. **Delete Existing UI:** The current `WorkspaceView`, `ConvertToolView`, and `NotebookEditorView` implementations are deprecated. They must be entirely removed and replaced with this new architecture. Do not attempt to salvage the split-view notebook paradigm.
2. **Shared Codebase:** The UI components (Floating Toolbar, Inspector, Action Bar) must be built as shared SwiftUI views applicable to both iOS and macOS targets. Platform-specific modifiers (`#if os(macOS)`) should be used sparingly, primarily for window management and menu bar integration.
3. **No Horizontal Scrolling in UI Panels:** The Inspector and Toolbar must be designed to fit their contents without requiring horizontal scrolling. Text should wrap, and controls should stack vertically if space is constrained.

This document serves as the absolute source of truth for the CanvasCode UI layer moving forward. All visual development must adhere to these structural and philosophical guidelines.
