# AppleVibeNotebook - Development Documentation

> **Project**: AppleVibeNotebook (formerly React2SwiftUI Canvas)
> **Purpose**: Convert React/JSX projects to native SwiftUI code with AI assistance
> **Platform**: macOS 26+ / iOS 26+
> **Last Updated**: March 8, 2026 (07:48 UTC)

---

## 📁 Project Structure

```
AppleVibeNotebook/
├── Package.swift                    # Swift Package Manager config (Swift 6.0)
├── DEVELOPMENT.md                   # This file
├── TECHNICAL_SPEC.md               # Technical specifications
├── Sources/
│   ├── AppleVibeNotebook/          # Core library
│   │   ├── Parsing/
│   │   │   ├── ReactParser.swift       # Parse JSX/TSX files
│   │   │   ├── CSSParser.swift         # Parse CSS/SCSS files
│   │   │   ├── FigmaFileParser.swift   # Native .fig file parsing
│   │   │   ├── SVGParser.swift         # SVG to SwiftUI shapes
│   │   │   ├── ImageAssetImporter.swift
│   │   │   ├── ProjectParser.swift     # Full project parsing
│   │   │   ├── JavaScriptRuntime.swift # JS execution
│   │   │   ├── BabelParserBundle.swift # Babel integration
│   │   │   └── PostCSSParserBundle.swift
│   │   ├── Mappings/
│   │   │   ├── LayoutMapping.swift     # Flexbox → SwiftUI stacks
│   │   │   ├── StylingMapping.swift    # CSS → SwiftUI modifiers
│   │   │   ├── StateMapping.swift      # React hooks → @State
│   │   │   └── ComponentMapping.swift  # Component mappings
│   │   ├── CodeGen/
│   │   │   └── SwiftSyntaxCodeGenerator.swift
│   │   ├── IR/
│   │   │   └── IntermediateRepresentation.swift
│   │   ├── ConversionReport/
│   │   │   └── ConversionReport.swift
│   │   └── Models/
│   │       ├── CSSTypes.swift
│   │       ├── ReactTypes.swift
│   │       └── SwiftUITypes.swift
│   │
│   └── AppleVibeNotebookApp/       # macOS/iOS App
│       ├── AppleVibeNotebookApp.swift  # @main entry point
│       ├── Services/
│       │   ├── AICodeSuggestionService.swift  # Multi-provider AI
│       │   ├── AIProviders.swift       # Provider enum + Keychain storage
│       │   ├── ImageToUIService.swift  # Vision model image→UI
│       │   ├── ScreenCaptureService.swift
│       │   └── VoiceInputService.swift
│       └── Views/
│           ├── ContentView.swift       # Main navigation (macOS + iPad)
│           ├── WelcomeView.swift       # Landing page with neon glass
│           ├── WorkspaceView.swift     # Code/Preview/Report panels
│           ├── SidebarView.swift       # File browser + AI toggle
│           ├── AISuggestionPanelView.swift  # AI code generation
│           ├── APISettingsView.swift   # API key management
│           ├── SettingsView.swift      # General settings
│           ├── FigmaAssetBrowserView.swift  # Browse .fig files
│           ├── NeonLiquidGlass.swift   # Liquid glass UI component
│           └── ProcessingOverlay.swift
│
├── Tests/AppleVibeNotebookTests/
│   ├── ParserTests.swift
│   ├── MappingTests.swift
│   ├── CodeGeneratorTests.swift
│   └── FigmaParserTests.swift
│
└── Examples/
    └── AppleDesignKit/
        ├── README.md
        ├── src/components/
        │   ├── AppleDesignKit.jsx
        │   └── AppleDesignKit.css
        └── output/
            └── AppleDesignKitView.swift
```

---

## 🤖 AI Providers

### Default: Apple Intelligence (On-Device)

**No API key required** - Uses Apple's built-in Foundation Models.

```swift
import FoundationModels

let model = SystemLanguageModel()
let session = LanguageModelSession(model: model)
let response = try await session.respond(to: prompt)
```

### Available On-Device Apple Models

| Model | Description | Availability |
|-------|-------------|--------------|
| `SystemLanguageModel` | Apple's on-device LLM | macOS 26+, iOS 26+ |
| Native vision support | Image understanding | Built into Foundation Models |
| Conversational memory | Multi-turn context | Automatic with `LanguageModelSession` |

### External Providers (API Key Required)

| Provider | Models | Vision Support |
|----------|--------|----------------|
| **OpenAI** | GPT-4o, GPT-4 Turbo, o1, o1-mini | ✅ GPT-4o |
| **Anthropic** | Claude Sonnet 4, Claude Opus 4, Claude 3.5 Haiku | ✅ All models |
| **Google** | Gemini 2.0 Flash, Gemini 2.0 Pro, Gemini 1.5 Pro | ✅ All models |
| **xAI** | Grok-2, Grok-2 Mini, Grok-2 Vision | ✅ Grok-2 Vision |
| **GitHub** | Copilot | ❌ |

---

## 🔑 API Key Storage

API keys are stored securely in **macOS Keychain**:

```swift
// AIProviders.swift
public final class APIKeyStorage: Sendable {
    private let servicePrefix = "com.applevibenotebook.apikey."

    public func setAPIKey(_ key: String, for provider: AIProvider) throws {
        // Uses SecItemAdd with kSecClassGenericPassword
    }

    public func getAPIKey(for provider: AIProvider) -> String? {
        // Uses SecItemCopyMatching
    }
}
```

---

## ✨ Features Built

### 1. React to SwiftUI Conversion
- JSX parsing with component detection
- CSS to SwiftUI modifier mapping
- React hooks → SwiftUI property wrappers
- Flexbox → SwiftUI stacks

### 2. Figma File Import
- Native `.fig` file parsing (Kiwi schema)
- ZSTD decompression support
- Layer extraction and hierarchy browsing

### 3. SVG Import
- Parse SVG files to SwiftUI Path
- Support for path, rect, circle, ellipse elements
- Generate parameterized SwiftUI shapes

### 4. AI Code Suggestions
- Apple Intelligence (default, no API key)
- Multi-provider support (OpenAI, Anthropic, Google, xAI, GitHub)
- Code conversion, completion, optimization, explanation, fix

### 5. Image to UI (Vision Models)
- Upload screenshot/design image
- Generate SwiftUI code
- Generate React/JSX code
- Or both simultaneously

### 6. Liquid Glass UI
- Native iOS 26/macOS 26 glass effects
- Neon glow animations
- Dark theme optimized

---

## 🚀 How to Run

```bash
cd /Users/aniketbhatt/Desktop/AppleVibeNotebook
swift build
swift run AppleVibeNotebookApp
```

---

## 📝 Session History

### Session 1 (Previous)
- Created initial project structure
- Built JSX/CSS parsers
- Created SwiftUI code generator
- Added liquid glass UI effects

### Session 2 (March 7, 2026)

1. **Fixed build errors**
   - Added `import AppleVibeNotebook` to FigmaAssetBrowserView
   - Fixed glassEffect API usage
   - Fixed recursive view type with AnyView wrapper

2. **Tested Figma import**
   - Discovered ZSTD compression in .fig files
   - Added ZSTD decompression via system tool
   - Successfully extracted 3,122 layers from test file

3. **Added SVG and Image import**
   - Created SVGParser.swift
   - Created ImageAssetImporter.swift
   - Fixed recursive enum Sendable issues

4. **Integrated AI code suggestions**
   - Initially tried MLX Swift (required downloads)
   - Switched to Apple Foundation Models (no downloads)
   - Added multi-provider support with API keys

5. **Added Image-to-UI service**
   - Vision model support for OpenAI, Anthropic, Google, xAI
   - Upload image → get SwiftUI + React code

### Session 3 (March 7, 2026 - Build Fix)

Fixed **860+ build errors** to get the app compiling. Major changes:

1. **API Migrations**
   - `CanvasFrame(x:y:width:height:)` → `CanvasFrame(origin:size:)`
   - `CanvasLayer.fillColor` → `CanvasLayer.backgroundFill: FillConfig?`
   - `CanvasLayer.strokeColor/strokeWidth/cornerRadius` → `CanvasLayer.borderConfig: BorderConfig?`
   - `ConfigurableProperty(id:, category:)` → `ConfigurableProperty(key:, group:)`
   - `PropertyValue.text()` → `.string()`, `.boolean()` → `.bool()`

2. **Swift 6 Concurrency Compliance**
   Added `@MainActor` to: `SimulationEngine`, `CanvasAIBridge`, `InteractionSimulator`, `CloudSyncService`, `CanvasSyncEngine`, `SketchToUIEngine`

3. **Platform Compatibility**
   - Wrapped `AVAudioSession` in `#if os(iOS)` (unavailable on macOS)
   - Fixed `isEligibleForPrediction` for macOS
   - Added audio input validation in VoiceInputService

4. **Naming Conflicts**
   - Renamed `CommandGroup` → `CanvasCommandGroup` (conflict with SwiftUI)

5. **Files Updated**
   - Core: CanvasDocument.swift, StarterTemplateLibrary.swift, GlobalComponentLibrary.swift
   - Views: CanvasWorkspaceView.swift, PropertyInspectorView.swift, iPadCanvasView.swift
   - Services: VoiceInputService.swift, CloudSyncService.swift, ImageToUIService.swift
   - Engines: SimulationEngine.swift, CanvasSyncEngine.swift, InteractionSimulator.swift
   - AI: CanvasAIBridge.swift, AICodeSuggestionService.swift

**Result**: App now builds successfully with 0 errors

---

## 🔧 Key Decisions

| Decision | Reason |
|----------|--------|
| Apple Foundation Models as default | No downloads, instant availability, privacy |
| Keychain for API keys | Secure storage, system-managed |
| macOS 26+ requirement | Needed for FoundationModels framework |
| Multi-provider architecture | Flexibility, user choice |
| Liquid Glass UI | Modern iOS 26 design language |

---

## 🏗️ Current Architecture

### Core Models (CanvasDocument.swift)

```swift
// Frame structure
struct CanvasFrame {
    var origin: CGPoint   // Position (x, y)
    var size: CGSize      // Dimensions (width, height)
}

// Layer styling
struct FillConfig {
    var fillType: FillType   // .solid, .gradient, .none
    var color: CanvasColor?
    var gradient: GradientConfig?
}

struct BorderConfig {
    var width: CGFloat = 1
    var color: CanvasColor?
    var cornerRadius: CGFloat = 0
    var style: BorderStyle = .solid
}

struct ShadowConfig {
    var color: CanvasColor
    var radius: CGFloat
    var offsetX: CGFloat
    var offsetY: CGFloat
}

// Layer definition
struct CanvasLayer {
    var id: UUID
    var name: String
    var frame: CanvasFrame
    var layerType: LayerType
    var borderConfig: BorderConfig?
    var shadowConfig: ShadowConfig?
    var backgroundFill: FillConfig?
    // ... additional properties
}
```

### Configurable Components

```swift
ConfigurableProperty(
    key: "opacity",          // Unique identifier
    name: "Opacity",         // Display name
    type: .slider(min: 0, max: 1),
    defaultValue: .number(1.0),
    group: "Appearance"      // Property group
)
```

### Platform-Specific Code

```swift
// iOS-only features
#if os(iOS)
import PencilKit
// AVAudioSession, pencil interactions, etc.
#endif

// macOS-specific
#if os(macOS)
// AppKit integrations
#endif
```

---

## 📋 TODO

- [x] ~~Fix 860+ build errors~~ (Completed Session 3)
- [x] ~~Update iPadCanvasView to new APIs~~ (Completed Session 3)
- [x] ~~Fix Swift 6 actor isolation crash in VoiceInputService~~ (Completed Session 6)
- [ ] Test voice input on iOS Simulator after actor isolation fix
- [ ] Complete Image-to-UI panel view
- [ ] Add drag-and-drop image upload
- [ ] Integrate image-to-UI into main navigation
- [ ] Add code diff view for conversions
- [ ] Export to Xcode project
- [ ] Add animation mapping (React → SwiftUI)
- [ ] visionOS spatial canvas support
- [ ] Add unit tests for new API changes

---

## 🔐 Session 6 - Actor Isolation Fix (March 8, 2026)

### Problem
VoiceInputService crashed with `EXC_BREAKPOINT` when using voice input. The crash happened because:
- The class was marked `@MainActor`
- Audio callbacks from `AVAudioEngine.inputNode.installTap()` run on `RealtimeMessenger.mServiceQueue`
- Swift 6 strict concurrency detected accessing `@MainActor`-isolated `self` from background thread

### Stack Trace Pattern
```
Thread 2 Crashed::  Dispatch queue: RealtimeMessenger.mServiceQueue
0   libdispatch.dylib    _dispatch_assert_queue_fail
3   libswift_Concurrency swift_task_isCurrentExecutorWithFlagsImpl
5   CanvasCode.debug.dylib closure #1 in VoiceInputService.startListening()
```

### Solution
1. Removed `@MainActor` from class declaration
2. Added `@MainActor` to individual public methods that need it
3. Used `weak var weakSelf = self` pattern instead of `[weak self]` in closures
4. Used `DispatchQueue.main.async` instead of `Task { @MainActor in }` for UI updates

### Key Insight
Even `[weak self]` capture of a `@MainActor`-isolated class triggers actor isolation checks when:
- The closure is created on the main thread
- The closure is called from a background thread

Using `DispatchQueue.main.async` avoids this because GCD doesn't have the same compile-time actor checking.
