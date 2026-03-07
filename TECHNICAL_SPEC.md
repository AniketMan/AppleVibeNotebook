# APPLEVIBENOTEBOOK_TECHNICAL_SPEC

## METADATA
```yaml
project_name: AppleVibeNotebook
project_path: /Users/aniketbhatt/Desktop/AppleVibeNotebook
swift_tools_version: "6.0"
platforms:
  - macOS: "26.0"
  - iOS: "26.0"
dependencies:
  - swift-syntax: "600.0.0"
build_command: "cd /Users/aniketbhatt/Desktop/AppleVibeNotebook && swift build"
run_command: "cd /Users/aniketbhatt/Desktop/AppleVibeNotebook && swift run AppleVibeNotebookApp"
test_command: "cd /Users/aniketbhatt/Desktop/AppleVibeNotebook && swift test"
```

---

## FILE_INDEX

### PACKAGE_MANIFEST
```
path: /Users/aniketbhatt/Desktop/AppleVibeNotebook/Package.swift
targets:
  - name: AppleVibeNotebook
    type: library
    path: Sources/AppleVibeNotebook
    dependencies: [SwiftSyntax, SwiftSyntaxBuilder]
  - name: AppleVibeNotebookApp
    type: executable
    path: Sources/AppleVibeNotebookApp
    dependencies: [AppleVibeNotebook]
  - name: AppleVibeNotebookTests
    type: test
    path: Tests/AppleVibeNotebookTests
    dependencies: [AppleVibeNotebook]
```

### CORE_LIBRARY_FILES
```
/Users/aniketbhatt/Desktop/AppleVibeNotebook/Sources/AppleVibeNotebook/
├── Parsing/
│   ├── ReactParser.swift
│   ├── CSSParser.swift
│   ├── FigmaFileParser.swift
│   ├── SVGParser.swift
│   ├── ImageAssetImporter.swift
│   ├── ProjectParser.swift
│   ├── JavaScriptRuntime.swift
│   ├── BabelParserBundle.swift
│   └── PostCSSParserBundle.swift
├── Mappings/
│   ├── LayoutMapping.swift
│   ├── StylingMapping.swift
│   ├── StateMapping.swift
│   └── ComponentMapping.swift
├── CodeGen/
│   └── SwiftSyntaxCodeGenerator.swift
├── IR/
│   └── IntermediateRepresentation.swift
├── ConversionReport/
│   └── ConversionReport.swift
└── Models/
    ├── CSSTypes.swift
    ├── ReactTypes.swift
    └── SwiftUITypes.swift
```

### APP_FILES
```
/Users/aniketbhatt/Desktop/AppleVibeNotebook/Sources/AppleVibeNotebookApp/
├── AppleVibeNotebookApp.swift          # @main, Scene, Commands
├── Services/
│   ├── AICodeSuggestionService.swift
│   ├── AIProviders.swift
│   ├── ImageToUIService.swift
│   ├── ScreenCaptureService.swift
│   └── VoiceInputService.swift
└── Views/
    ├── ContentView.swift
    ├── WelcomeView.swift
    ├── WorkspaceView.swift
    ├── SidebarView.swift
    ├── AISuggestionPanelView.swift
    ├── APISettingsView.swift
    ├── FigmaAssetBrowserView.swift
    ├── NeonLiquidGlass.swift
    ├── ProcessingOverlay.swift
    └── SettingsView.swift
```

---

## TYPE_DEFINITIONS

### AIProvider
```swift
// File: /Users/aniketbhatt/Desktop/AppleVibeNotebook/Sources/AppleVibeNotebookApp/Services/AIProviders.swift

public enum AIProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case apple = "Apple Intelligence"
    case openai = "OpenAI (ChatGPT)"
    case anthropic = "Anthropic (Claude)"
    case xai = "xAI (Grok)"
    case google = "Google (Gemini)"
    case github = "GitHub MCP"

    var iconName: String
    var requiresAPIKey: Bool
    var apiKeyPlaceholder: String
    var helpURL: URL?
    var baseURL: String
    var defaultModel: String
    var visionModel: String?
    var supportsVision: Bool
    var availableModels: [String]
}
```

### APIKeyStorage
```swift
// File: /Users/aniketbhatt/Desktop/AppleVibeNotebook/Sources/AppleVibeNotebookApp/Services/AIProviders.swift

public final class APIKeyStorage: Sendable {
    public static let shared = APIKeyStorage()
    private let servicePrefix = "com.applevibenotebook.apikey."

    public func setAPIKey(_ key: String, for provider: AIProvider) throws
    public func getAPIKey(for provider: AIProvider) -> String?
    public func deleteAPIKey(for provider: AIProvider)
    public func hasAPIKey(for provider: AIProvider) -> Bool
}
// Storage: macOS Keychain via Security.framework
// Key format: "com.applevibenotebook.apikey.{provider.rawValue}"
```

### AIProviderSettings
```swift
// File: /Users/aniketbhatt/Desktop/AppleVibeNotebook/Sources/AppleVibeNotebookApp/Services/AIProviders.swift

@Observable
@MainActor
public final class AIProviderSettings {
    public static let shared = AIProviderSettings()

    public var selectedProvider: AIProvider  // UserDefaults: "selectedAIProvider"
    public var selectedModels: [AIProvider: String]  // UserDefaults: "selectedAIModels"

    public func selectedModel(for provider: AIProvider) -> String
    public func setSelectedModel(_ model: String, for provider: AIProvider)
}
```

### AICodeSuggestionService
```swift
// File: /Users/aniketbhatt/Desktop/AppleVibeNotebook/Sources/AppleVibeNotebookApp/Services/AICodeSuggestionService.swift

@Observable
@MainActor
public final class AICodeSuggestionService {

    public enum SuggestionType: String, Sendable {
        case completion, conversion, optimization, explanation, fix
    }

    public struct CodeSuggestion: Identifiable, Sendable {
        public let id: UUID
        public let type: SuggestionType
        public let originalCode: String
        public let suggestedCode: String
        public let explanation: String
        public let confidence: Double
        public let timestamp: Date
        public let provider: AIProvider
    }

    public enum ModelState: Sendable {
        case notLoaded, checking, ready, generating
        case unavailable(String), error(String)
    }

    // Properties
    public private(set) var modelState: ModelState
    public private(set) var suggestions: [CodeSuggestion]
    public private(set) var tokensPerSecond: Double
    public var currentProvider: AIProvider
    public var currentModel: String

    // Apple Foundation Models session
    private var appleSession: LanguageModelSession?

    // Methods
    public func checkAvailability() async
    public func suggest(code: String, type: SuggestionType, context: String?) async throws -> CodeSuggestion
    public func convertReactToSwiftUI(reactCode: String, cssCode: String?) async throws -> CodeSuggestion
    public func complete(partialCode: String) async throws -> CodeSuggestion
    public func explain(swiftUICode: String) async throws -> CodeSuggestion
    public func optimize(swiftUICode: String) async throws -> CodeSuggestion
    public func cancelGeneration()
    public func clearHistory()

    // Provider implementations
    private func generateWithApple(code: String, type: SuggestionType, context: String?) async throws -> String
    private func generateWithOpenAI(code: String, type: SuggestionType, context: String?) async throws -> String
    private func generateWithAnthropic(code: String, type: SuggestionType, context: String?) async throws -> String
    private func generateWithXAI(code: String, type: SuggestionType, context: String?) async throws -> String
    private func generateWithGoogle(code: String, type: SuggestionType, context: String?) async throws -> String
    private func generateWithGitHub(code: String, type: SuggestionType, context: String?) async throws -> String
}
```

### ImageToUIService
```swift
// File: /Users/aniketbhatt/Desktop/AppleVibeNotebook/Sources/AppleVibeNotebookApp/Services/ImageToUIService.swift

@Observable
@MainActor
public final class ImageToUIService {

    public enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
        case swiftUI, react, both
    }

    public struct GeneratedUI: Identifiable, Sendable {
        public let id: UUID
        public let imageData: Data
        public let swiftUICode: String?
        public let reactCode: String?
        public let description: String
        public let provider: AIProvider
        public let timestamp: Date
    }

    public enum ServiceState: Sendable {
        case idle, analyzing, generating, complete, error(String)
    }

    // Properties
    public private(set) var state: ServiceState
    public private(set) var currentImage: Data?
    public private(set) var generatedResults: [GeneratedUI]
    public private(set) var progress: String
    public var selectedProvider: AIProvider
    public var outputFormat: OutputFormat

    // Methods
    public func generateFromImage(_ imageData: Data, format: OutputFormat?) async throws -> GeneratedUI
    public func generateFromFile(_ url: URL) async throws -> GeneratedUI
    public func generateFromNSImage(_ image: NSImage) async throws -> GeneratedUI
    public func clearResults()

    // Vision API implementations
    private func generateWithOpenAI(imageData: Data, format: OutputFormat) async throws -> String
    private func generateWithAnthropic(imageData: Data, format: OutputFormat) async throws -> String
    private func generateWithGoogle(imageData: Data, format: OutputFormat) async throws -> String
    private func generateWithXAI(imageData: Data, format: OutputFormat) async throws -> String
}
```

### AppState
```swift
// File: /Users/aniketbhatt/Desktop/AppleVibeNotebook/Sources/AppleVibeNotebookApp/AppleVibeNotebookApp.swift

@Observable
final class AppState {
    var projectURL: URL?
    var projectName: String
    var isProcessing: Bool
    var processingProgress: Double
    var processingStatus: String
    var sourceFiles: [SourceFileInfo]
    var selectedFile: SourceFileInfo?
    var generatedCode: [GeneratedFileInfo]
    var selectedGeneratedFile: GeneratedFileInfo?
    var conversionReport: ConversionReportInfo?
    var showImportPanel: Bool
    var showZipImportPanel: Bool
    var showExportPanel: Bool
    var showCodePanel: Bool
    var showPreviewPanel: Bool
    var showReportPanel: Bool
    var showAIPanel: Bool
    var errorMessage: String?
    var showError: Bool
}
```

---

## API_CONTRACTS

### APPLE_FOUNDATION_MODELS
```swift
import FoundationModels

// Initialization
let model = SystemLanguageModel()
let session = LanguageModelSession(model: model)

// Generation
let response: LanguageModelSession.Response<String> = try await session.respond(to: prompt)
let text = response.content
```

### OPENAI_API
```
POST https://api.openai.com/v1/chat/completions
Headers:
  Authorization: Bearer {api_key}
  Content-Type: application/json
Body:
  model: "gpt-4o"
  messages: [{role, content}]
  max_tokens: 4096

Vision body content:
  [
    {type: "text", text: prompt},
    {type: "image_url", image_url: {url: "data:image/png;base64,{base64}", detail: "high"}}
  ]
```

### ANTHROPIC_API
```
POST https://api.anthropic.com/v1/messages
Headers:
  x-api-key: {api_key}
  anthropic-version: 2023-06-01
  Content-Type: application/json
Body:
  model: "claude-sonnet-4-20250514"
  max_tokens: 4096
  system: {system_prompt}
  messages: [{role, content}]

Vision body content:
  [
    {type: "image", source: {type: "base64", media_type: "image/png", data: base64}},
    {type: "text", text: prompt}
  ]
```

### GOOGLE_GEMINI_API
```
POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}
Headers:
  Content-Type: application/json
Body:
  contents: [{parts: [{text: prompt}]}]
  generationConfig: {temperature: 0.3}

Vision body:
  contents: [{parts: [{text: prompt}, {inline_data: {mime_type: "image/png", data: base64}}]}]
```

### XAI_GROK_API
```
POST https://api.x.ai/v1/chat/completions
Headers:
  Authorization: Bearer {api_key}
  Content-Type: application/json
Body:
  model: "grok-2" or "grok-2-vision"
  messages: [{role, content}]
  max_tokens: 4096
```

---

## NAVIGATION_STRUCTURE

```
App Launch
├── No project loaded
│   ├── WelcomeView (default)
│   │   ├── Import React Project → FileImporter
│   │   ├── Import from ZIP → FileImporter
│   │   └── AI Code Assistant → AISuggestionPanelView
│   └── AISuggestionPanelView (when showAIPanel && projectURL == nil)
│
└── Project loaded
    └── WorkspaceView
        ├── CodePanelView (showCodePanel)
        ├── PreviewPanelView (showPreviewPanel)
        ├── ReportPanelView (showReportPanel)
        └── AISuggestionPanelView (showAIPanel)

Sidebar (always visible)
├── AI Assistant section
│   └── Code Assistant toggle → showAIPanel
├── Source Files section (when sourceFiles not empty)
└── Generated SwiftUI section (when generatedCode not empty)

Menu Commands:
├── ⌘O: Import React Project
├── ⇧⌘O: Import from ZIP
├── ⌘E: Export SwiftUI Code
├── ⌘1: Toggle Code Panel
├── ⌘2: Toggle Preview Panel
├── ⌘3: Toggle Report Panel
└── ⌘4: Toggle AI Assistant
```

---

## KEYCHAIN_STORAGE

```
Service prefix: "com.applevibenotebook.apikey."
Key names:
  - "com.applevibenotebook.apikey.Apple Intelligence"
  - "com.applevibenotebook.apikey.OpenAI (ChatGPT)"
  - "com.applevibenotebook.apikey.Anthropic (Claude)"
  - "com.applevibenotebook.apikey.xAI (Grok)"
  - "com.applevibenotebook.apikey.Google (Gemini)"
  - "com.applevibenotebook.apikey.GitHub MCP"

Security attributes:
  kSecClass: kSecClassGenericPassword
  kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked
```

---

## USERDEFAULTS_KEYS

```
"selectedAIProvider": String (AIProvider.rawValue)
"selectedAIModels": [String: String] (AIProvider.rawValue -> model name)
```

---

## KNOWN_ISSUES

```yaml
- id: FOUNDATION_MODELS_CATCH
  file: AICodeSuggestionService.swift
  line: 118
  warning: "'catch' block is unreachable because no errors are thrown in 'do' block"
  reason: SystemLanguageModel() does not throw in current beta
  status: ACCEPTED
```

---

## PENDING_IMPLEMENTATION

```yaml
- feature: ImageToUIPanelView
  description: UI for drag-drop image upload and display generated code
  dependencies: [ImageToUIService]
  integrate_into: [ContentView, SidebarView, WorkspaceView]

- feature: Apple Vision in ImageToUIService
  description: Use Apple Foundation Models vision capabilities
  blocker: Need to research correct API for image input
  current_status: throws providerDoesNotSupportVision
```

---

## SESSION_LOG

### 2026-03-07_SESSION_2

```yaml
actions:
  - action: FIX_BUILD_ERROR
    file: FigmaAssetBrowserView.swift
    change: "added import AppleVibeNotebook"

  - action: FIX_BUILD_ERROR
    file: FigmaAssetBrowserView.swift
    change: "changed .glassEffect(.regular.cornerRadius()) to .containerShape().glassEffect()"

  - action: FIX_BUILD_ERROR
    file: FigmaAssetBrowserView.swift
    change: "wrapped recursive nodeRow call in AnyView()"

  - action: ADD_FEATURE
    file: FigmaFileParser.swift
    change: "added ZSTD decompression for canvas.fig files"
    method: "shell out to system zstd tool"

  - action: CREATE_FILE
    file: SVGParser.swift
    description: "parse SVG files to SwiftUI Path code"

  - action: CREATE_FILE
    file: ImageAssetImporter.swift
    description: "import images and generate Asset Catalog + SwiftUI code"

  - action: REFACTOR
    file: AICodeSuggestionService.swift
    change: "switched from MLX to Apple Foundation Models"
    reason: "MLX required downloading models from HuggingFace"

  - action: CREATE_FILE
    file: AIProviders.swift
    description: "AIProvider enum, APIKeyStorage (Keychain), AIProviderSettings"

  - action: REFACTOR
    file: AICodeSuggestionService.swift
    change: "added multi-provider support"
    providers: [apple, openai, anthropic, xai, google, github]

  - action: CREATE_FILE
    file: APISettingsView.swift
    description: "UI for managing API keys with test connection"

  - action: UPDATE
    file: AISuggestionPanelView.swift
    change: "added provider picker and settings sheet"

  - action: UPDATE
    file: Package.swift
    change: "removed MLX dependencies, changed platform to macOS 26.0"

  - action: CREATE_FILE
    file: ImageToUIService.swift
    description: "vision model service for image→UI code generation"
```

### 2026-03-07_SESSION_3

```yaml
actions:
  - action: REBRAND
    description: "Renamed project from React2SwiftUI to AppleVibeNotebook"
    files_updated:
      - DEVELOPMENT.md
      - TECHNICAL_SPEC.md
      - IntermediateRepresentation.swift
      - SwiftSyntaxCodeGenerator.swift
      - ConversionReport.swift
      - NeonLiquidGlass.swift
      - FigmaAssetBrowserView.swift
      - SettingsView.swift
      - ImageAssetImporter.swift

  - action: GIT_INIT
    description: "Initialized git repository and pushed to GitHub"
    remote: "https://github.com/AniketMan/AppleVibeNotebook"
```

---

## COMMAND_REFERENCE

```bash
# Build
cd /Users/aniketbhatt/Desktop/AppleVibeNotebook && swift build

# Run
cd /Users/aniketbhatt/Desktop/AppleVibeNotebook && swift run AppleVibeNotebookApp

# Test
cd /Users/aniketbhatt/Desktop/AppleVibeNotebook && swift test

# Clean
cd /Users/aniketbhatt/Desktop/AppleVibeNotebook && swift package clean

# Update dependencies
cd /Users/aniketbhatt/Desktop/AppleVibeNotebook && swift package update
```
