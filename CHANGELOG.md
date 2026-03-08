# Changelog

All notable changes to AppleVibeNotebook will be documented in this file.

## [Unreleased] - 2026-03-08

### Swift 6 Actor Isolation Fix (Session 6)

Fixed critical crash in VoiceInputService caused by Swift 6 strict concurrency checking on audio callbacks.

#### Problem
The app was crashing with `EXC_BREAKPOINT (SIGTRAP)` and `_dispatch_assert_queue_fail` when using voice input. The crash occurred because:
1. `VoiceInputService` was marked as `@MainActor`-isolated
2. Audio tap callbacks from `AVAudioEngine` run on `RealtimeMessenger.mServiceQueue` (audio thread)
3. Swift 6's strict concurrency checking detected accessing `@MainActor`-isolated `self` from a non-main thread

#### Solution
Removed `@MainActor` from the class declaration and used method-level `@MainActor` annotations instead:
- `requestAuthorization()` - `@MainActor` (updates UI state)
- `startListening()` - `@MainActor` (must be called from main thread)
- `stopListening()` - `@MainActor` (updates UI state)
- `toggleListening()` - `@MainActor` (calls startListening/stopListening)
- `clearHistory()` - `@MainActor` (updates Published properties)

The audio tap callback now:
1. Captures `recognitionRequest` locally before installing the tap
2. Uses `weak var weakSelf = self` instead of `[weak self]` in closure capture
3. Uses `DispatchQueue.main.async` to update `@Published` properties on the main thread

#### Files Changed
- `Sources/AppleVibeNotebookApp/Services/VoiceInputService.swift` - Complete rewrite of thread safety approach

#### Technical Details
Swift 6 with strict concurrency checking validates actor isolation at runtime. Even `[weak self]` capture of a `@MainActor`-isolated class in a closure triggers actor isolation checks when:
- The closure is created on the main thread
- The closure is called from a background thread
- Any property of `self` is accessed

The fix avoids this by:
- Not using class-level `@MainActor` isolation
- Using method-level `@MainActor` for public API
- Using `DispatchQueue.main.async` for UI updates from callbacks (not `Task { @MainActor in }`)

---

## [Unreleased] - 2026-03-07

### iPadOS UI Redesign (Session 5)

Completely rewrote iPad interface to match TECHNICAL_SPEC.md requirements.

#### Major Change: Canvas-First Interface

**BEFORE**: Basic notebook-style interface with sidebar navigation (wrong)
**AFTER**: Visual canvas workspace with Liquid Glass voice companion (per spec)

#### New Components

1. **LiquidGlassCompanion.swift** - The voice input orb (per spec section 4.1)
   - Living, breathing orb with neon glow animation
   - Draggable to any position on screen
   - Audio reactive waveform when listening
   - Three states: idle (breathing), listening (waveform), processing (spinner)
   - AI response bubble appears near orb when AI responds
   - Uses `VoiceInputService` for speech recognition
   - Uses `AICodeSuggestionService` for AI code generation

2. **ContentView iPad Rewrite**
   - Now shows `CanvasWorkspaceView` (the visual canvas) as main interface
   - `LiquidGlassCompanion` floats over canvas
   - Uses existing infrastructure: `InfiniteCanvasView`, `ObjectLibraryView`, `PropertyInspectorView`

#### Architecture Alignment

The iPad interface now correctly uses the existing canvas infrastructure:
- `CanvasState` - Observable state for canvas document, selection, tools
- `CanvasWorkspaceView` - Main workspace with canvas + panels
- `iPadCanvasView` / `InfiniteCanvasView` - The actual visual canvas
- `ObjectLibraryView` - Searchable component library
- `PropertyInspectorView` - Property sliders and controls
- `CanvasToolbar` - Floating tool selection

#### Per TECHNICAL_SPEC.md Section 4.1

> "The voice interface is embodied as a Liquid Glass orb — a living, breathing,
> translucent blob that floats on the screen. It is not a static microphone button.
> It has personality. It has a life of its own."

The LiquidGlassCompanion implements:
- ✅ Gentle breathing animation when idle
- ✅ Audio-reactive morphing when user speaks
- ✅ Processing animation when AI is thinking
- ✅ Draggable positioning (remembers position)
- ✅ Neon glow with rotating gradient
- ✅ Response bubble near orb (not full-screen modal)

---

### iOS Build Support (Session 4)

Successfully made the project compile for iOS. Fixed numerous platform-specific APIs.

#### Platform Conditionals Added

1. **Process/NSTask** (macOS-only)
   - `FigmaFileParser.swift` - ZIP extraction wrapped in `#if os(macOS)`
   - `ProjectParser.swift` - ZIP extraction wrapped in `#if os(macOS)`

2. **ScreenCaptureKit** (macOS-only)
   - `ScreenCaptureService.swift` - Full stub implementation for iOS

3. **HSplitView** (macOS-only)
   - `WorkspaceView.swift` - Uses HStack on iOS
   - `AISuggestionPanelView.swift` - Uses HStack on iOS

4. **NSImage** (macOS-only)
   - `FigmaAssetBrowserView.swift` - Uses UIImage on iOS

5. **SCWindow** (macOS-only)
   - `AISuggestionPanelView.swift` - Screen capture sheet shows placeholder on iOS

#### Swift 6 Concurrency Fixes

Added `@MainActor` to:
- `SketchToUIEngine` (iPadCanvasView.swift)
- `VoiceCaptureEngine` (iPhoneCanvasView.swift)

#### API Corrections

- Fixed `BorderConfig` parameter order: `color:`, `width:`, `cornerRadius:`
- Fixed `ShadowConfig` using `offset: CGPoint` instead of `offsetX:`/`offsetY:`
- Fixed `CanvasLayer` parameter order: `zIndex:` before `layerType:`

---

### Major Build Fix Session (Session 3)
Fixed 860+ build errors to get the application compiling successfully.

### API Changes

#### CanvasFrame
- **Breaking**: Changed from `CanvasFrame(x:y:width:height:)` to `CanvasFrame(origin:size:)`
- Access frame dimensions via `frame.origin.x`, `frame.origin.y`, `frame.size.width`, `frame.size.height`

#### CanvasLayer
- **Breaking**: Removed direct properties `fillColor`, `strokeColor`, `strokeWidth`, `cornerRadius`
- **New**: Use `backgroundFill: FillConfig?` for fill colors
- **New**: Use `borderConfig: BorderConfig?` for stroke/border settings and corner radius
- **New**: Use `shadowConfig: ShadowConfig?` for shadow settings

#### ConfigurableProperty
- **Breaking**: Changed `id:` parameter to `key:`
- **Breaking**: Changed `category:` parameter to `group:`
- **Breaking**: Slider type no longer accepts `step:` parameter

#### PropertyValue
- **Breaking**: Changed `.text()` to `.string()`
- **Breaking**: Changed `.boolean()` to `.bool()`

### Swift 6 Concurrency Compliance

Added `@MainActor` to the following classes for data race safety:
- `SimulationEngine`
- `CanvasAIBridge`
- `InteractionSimulator`
- `CloudSyncService`
- `CanvasSyncEngine`
- `SketchToUIEngine`

### Platform Compatibility Fixes

#### macOS
- Wrapped `AVAudioSession` usage in `#if os(iOS)` conditionals (unavailable on macOS)
- Wrapped `isEligibleForPrediction` in `#if os(iOS)` conditionals
- Fixed `CloudSyncService` deinit that was calling MainActor-isolated methods

#### VoiceInputService
- Added new error cases: `noAudioInput`, `invalidAudioFormat`
- Added validation for audio input node availability before recording
- Added validation for recording format (sample rate > 0, channel count > 0)

### Naming Conflicts Resolved

#### CanvasUndoManager
- Renamed internal `CommandGroup` class to `CanvasCommandGroup` to avoid conflict with SwiftUI's `CommandGroup`

### Files Updated

#### Core Models
- `Sources/AppleVibeNotebook/Models/CanvasDocument.swift` - Updated CanvasFrame, CanvasLayer APIs

#### Views
- `Sources/AppleVibeNotebookApp/Views/Canvas/CanvasWorkspaceView.swift` - Changed from AppState properties to local @State
- `Sources/AppleVibeNotebookApp/Views/Inspector/PropertyInspectorView.swift` - Fixed BlendMode ambiguity, CGFloat→Double conversions
- `Sources/AppleVibeNotebookApp/Views/Platform/iPadCanvasView.swift` - Updated to new CanvasFrame/CanvasLayer APIs

#### Services
- `Sources/AppleVibeNotebookApp/Services/VoiceInputService.swift` - Added platform conditionals, input validation
- `Sources/AppleVibeNotebookApp/Services/CloudSyncService.swift` - Added @MainActor, platform conditionals
- `Sources/AppleVibeNotebookApp/Services/ImageToUIService.swift` - Added missing .geminiNotebook case
- `Sources/AppleVibeNotebookApp/Services/AICodeSuggestionService.swift` - Added missing .geminiNotebook case

#### Engines
- `Sources/AppleVibeNotebookApp/Engines/SimulationEngine.swift` - Added @MainActor, fixed closure captures
- `Sources/AppleVibeNotebookApp/Engines/CanvasSyncEngine.swift` - Added @MainActor
- `Sources/AppleVibeNotebookApp/Engines/InteractionSimulator.swift` - Added @MainActor

#### Libraries
- `Sources/AppleVibeNotebook/Templates/StarterTemplateLibrary.swift` - Migrated to new APIs
- `Sources/AppleVibeNotebook/Components/GlobalComponentLibrary.swift` - Migrated to new APIs

#### AI Integration
- `Sources/AppleVibeNotebookApp/AI/CanvasAIBridge.swift` - Added @MainActor, created local SuggestedLayoutType enum

#### Utilities
- `Sources/AppleVibeNotebookApp/Services/SpatialIndex.swift` - Removed duplicate CGRect extension
- `Sources/AppleVibeNotebook/History/CanvasUndoManager.swift` - Renamed CommandGroup to CanvasCommandGroup

### Known Issues
- Voice input on macOS may still have issues with audio node configuration on some systems

---

## Migration Guide

### Updating CanvasFrame Usage

**Before:**
```swift
let frame = CanvasFrame(x: 10, y: 20, width: 100, height: 50)
let x = frame.x
let width = frame.width
```

**After:**
```swift
let frame = CanvasFrame(origin: CGPoint(x: 10, y: 20), size: CGSize(width: 100, height: 50))
let x = frame.origin.x
let width = frame.size.width
```

### Updating CanvasLayer Usage

**Before:**
```swift
var layer = CanvasLayer(...)
layer.fillColor = CanvasColor(red: 1, green: 0, blue: 0, alpha: 1)
layer.cornerRadius = 12
layer.strokeWidth = 2
layer.strokeColor = CanvasColor(...)
```

**After:**
```swift
let layer = CanvasLayer(
    ...,
    borderConfig: BorderConfig(width: 2, color: strokeColor, cornerRadius: 12),
    backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 1, green: 0, blue: 0, alpha: 1))
)
```

### Updating ConfigurableProperty Usage

**Before:**
```swift
ConfigurableProperty(
    id: "opacity",
    name: "Opacity",
    type: .slider(min: 0, max: 1, step: 0.1),
    defaultValue: .number(1.0),
    category: "Appearance"
)
```

**After:**
```swift
ConfigurableProperty(
    key: "opacity",
    name: "Opacity",
    type: .slider(min: 0, max: 1),
    defaultValue: .number(1.0),
    group: "Appearance"
)
```
