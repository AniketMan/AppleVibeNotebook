# AppleVibeNotebook - Development Documentation

> **Project**: AppleVibeNotebook (formerly React2SwiftUI Canvas)
> **Purpose**: Convert React/JSX projects to native SwiftUI code with AI assistance
> **Platform**: macOS 26+ / iOS 26+
> **Last Updated**: March 7, 2026 (10:43 UTC)

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

### Session 2 (Current - March 7, 2026)

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

## 📋 TODO

- [ ] Complete Image-to-UI panel view
- [ ] Add drag-and-drop image upload
- [ ] Integrate image-to-UI into main navigation
- [ ] Add code diff view for conversions
- [ ] Export to Xcode project
- [ ] Add animation mapping (React → SwiftUI)
