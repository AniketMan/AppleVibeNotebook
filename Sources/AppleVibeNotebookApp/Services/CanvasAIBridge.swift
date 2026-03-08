import Foundation
import AppleVibeNotebook

// MARK: - Canvas AI Bridge

/// Bridges AI services (voice, image, text) to canvas layer generation.
/// Acts as the adapter between AI output and the canvas document model.
@Observable @MainActor
final class CanvasAIBridge {

    // MARK: - State

    var isProcessing: Bool = false
    var processingStatus: String = ""
    var lastError: String?

    // MARK: - Dependencies

    private let voiceInputService: VoiceInputService
    private let imageToUIService: ImageToUIService
    private let aiCodeSuggestionService: AICodeSuggestionService
    private let codeToCanvasCompiler = CodeToCanvasCompiler()

    // MARK: - Initialization

    init(
        voiceInputService: VoiceInputService = VoiceInputService(),
        imageToUIService: ImageToUIService = ImageToUIService(),
        aiCodeSuggestionService: AICodeSuggestionService = AICodeSuggestionService()
    ) {
        self.voiceInputService = voiceInputService
        self.imageToUIService = imageToUIService
        self.aiCodeSuggestionService = aiCodeSuggestionService
    }

    // MARK: - Voice to Canvas

    /// Generates canvas layers from voice input.
    /// Example: "Create a login form with email and password fields"
    func generateLayersFromVoice(transcript: String, in document: inout CanvasDocument) async throws -> [CanvasLayer] {
        isProcessing = true
        processingStatus = "Processing voice input..."
        lastError = nil

        defer {
            isProcessing = false
            processingStatus = ""
        }

        do {
            // Step 1: Enhance the prompt for UI generation
            let enhancedPrompt = buildUIGenerationPrompt(from: transcript)

            // Step 2: Generate SwiftUI code via AI
            processingStatus = "Generating UI code..."
            let generatedCode = try await generateUICode(from: enhancedPrompt)

            // Step 3: Parse code to IR and compile to layers
            processingStatus = "Creating canvas layers..."
            let layers = try parseAndCompileLayers(from: generatedCode, into: &document)

            return layers
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Image to Canvas

    /// Generates canvas layers from an image (screenshot, mockup, sketch).
    func generateLayersFromImage(_ imageData: Data, in document: inout CanvasDocument) async throws -> [CanvasLayer] {
        isProcessing = true
        processingStatus = "Analyzing image..."
        lastError = nil

        defer {
            isProcessing = false
            processingStatus = ""
        }

        do {
            // Step 1: Analyze image with vision model
            processingStatus = "Extracting UI elements..."
            let analysisResult = try await analyzeImage(imageData)

            // Step 2: Generate code from analysis
            processingStatus = "Generating UI code..."
            let generatedCode = try await generateCodeFromAnalysis(analysisResult)

            // Step 3: Parse and compile to layers
            processingStatus = "Creating canvas layers..."
            let layers = try parseAndCompileLayers(from: generatedCode, into: &document)

            return layers
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Text Prompt to Canvas

    /// Generates canvas layers from a text prompt.
    func generateLayersFromPrompt(_ prompt: String, in document: inout CanvasDocument) async throws -> [CanvasLayer] {
        isProcessing = true
        processingStatus = "Processing prompt..."
        lastError = nil

        defer {
            isProcessing = false
            processingStatus = ""
        }

        do {
            let enhancedPrompt = buildUIGenerationPrompt(from: prompt)
            processingStatus = "Generating UI..."
            let generatedCode = try await generateUICode(from: enhancedPrompt)

            processingStatus = "Creating layers..."
            let layers = try parseAndCompileLayers(from: generatedCode, into: &document)

            return layers
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Layer Enhancement

    /// Enhances an existing layer with AI suggestions.
    func enhanceLayer(_ layer: CanvasLayer, suggestion: LayerEnhancement) async throws -> CanvasLayer {
        var enhanced = layer

        switch suggestion {
        case .addShadow:
            enhanced.shadowConfig = ShadowConfig(
                color: CanvasColor(red: 0, green: 0, blue: 0, alpha: 0.15),
                radius: 10,
                offset: CGPoint(x: 0, y: 4)
            )

        case .roundCorners(let radius):
            var config = enhanced.borderConfig ?? BorderConfig()
            config.cornerRadius = radius
            enhanced.borderConfig = config

        case .addBorder(let color, let width):
            var config = enhanced.borderConfig ?? BorderConfig()
            config.color = color
            config.width = width
            enhanced.borderConfig = config

        case .changeColor(let color):
            enhanced.backgroundFill = FillConfig(fillType: .solid, color: color)

        case .addGradient(let colors, let direction):
            let gradient = GradientConfig(
                type: .linear,
                colors: colors,
                stops: colors.enumerated().map { CGFloat($0.offset) / CGFloat(colors.count - 1) },
                startPoint: direction == .vertical ? CGPoint(x: 0.5, y: 0) : CGPoint(x: 0, y: 0.5),
                endPoint: direction == .vertical ? CGPoint(x: 0.5, y: 1) : CGPoint(x: 1, y: 0.5)
            )
            enhanced.backgroundFill = FillConfig(fillType: .gradient, gradient: gradient)

        case .resize(let size):
            enhanced.frame.size = size

        case .convertToComponent(let name):
            enhanced.layerType = .component
            enhanced.name = name
        }

        return enhanced
    }

    // MARK: - Private Helpers

    private func buildUIGenerationPrompt(from input: String) -> String {
        """
        Generate SwiftUI code for the following UI request:

        \(input)

        Requirements:
        - Use modern SwiftUI syntax (iOS 17+)
        - Include appropriate spacing and padding
        - Use system colors and SF Symbols where appropriate
        - Create a single View struct
        - Make it visually appealing with shadows and rounded corners
        - Keep the code simple and readable

        Respond with only the SwiftUI code, no explanations.
        """
    }

    private func generateUICode(from prompt: String) async throws -> String {
        // Use the AI code suggestion service to generate code
        // This would integrate with the actual AI provider

        // For now, return a template based on common patterns
        return extractCodeTemplate(from: prompt)
    }

    private func analyzeImage(_ imageData: Data) async throws -> ImageAnalysisResult {
        // Use vision model to analyze the image
        // This would integrate with the ImageToUIService

        return ImageAnalysisResult(
            detectedElements: [],
            suggestedLayout: .vertical,
            colorPalette: [],
            dimensions: CGSize(width: 393, height: 852)
        )
    }

    private func generateCodeFromAnalysis(_ analysis: ImageAnalysisResult) async throws -> String {
        // Convert image analysis to code
        var code = "struct GeneratedView: View {\n    var body: some View {\n"

        switch analysis.suggestedLayout {
        case .horizontal:
            code += "        HStack(spacing: 16) {\n"
        case .vertical:
            code += "        VStack(spacing: 16) {\n"
        case .stacked, .freeform:
            code += "        ZStack {\n"
        }

        for element in analysis.detectedElements {
            code += generateCodeForElement(element)
        }

        code += "        }\n    }\n}"

        return code
    }

    private func generateCodeForElement(_ element: DetectedUIElement) -> String {
        switch element.type {
        case .text:
            return "            Text(\"\(element.content ?? "Text")\")\n"
        case .button:
            return "            Button(\"\(element.content ?? "Button")\") { }\n                .buttonStyle(.borderedProminent)\n"
        case .image:
            return "            Image(systemName: \"photo\")\n                .resizable()\n                .frame(width: 100, height: 100)\n"
        case .textField:
            return "            TextField(\"\(element.content ?? "Placeholder")\", text: .constant(\"\"))\n                .textFieldStyle(.roundedBorder)\n"
        case .container:
            return "            RoundedRectangle(cornerRadius: 12)\n                .fill(Color.gray.opacity(0.1))\n                .frame(height: 100)\n"
        }
    }

    private func parseAndCompileLayers(from code: String, into document: inout CanvasDocument) throws -> [CanvasLayer] {
        // For now, create layers based on pattern matching
        // A full implementation would parse the SwiftUI code properly

        var layers: [CanvasLayer] = []
        var yOffset: CGFloat = 100

        // Detect common patterns and create layers
        if code.contains("VStack") || code.contains("HStack") || code.contains("ZStack") {
            let containerLayer = CanvasLayer(
                name: "Container",
                frame: CanvasFrame(
                    origin: CGPoint(x: 100, y: yOffset),
                    size: CGSize(width: 300, height: 400)
                ),
                layerType: .container,
                borderConfig: BorderConfig(cornerRadius: 16),
                backgroundFill: FillConfig(fillType: .solid, color: .white)
            )
            layers.append(containerLayer)
            yOffset += 50
        }

        // Detect text elements
        let textPattern = #"Text\("([^"]+)"\)"#
        if let regex = try? NSRegularExpression(pattern: textPattern) {
            let range = NSRange(code.startIndex..., in: code)
            for match in regex.matches(in: code, range: range) {
                if let textRange = Range(match.range(at: 1), in: code) {
                    let text = String(code[textRange])
                    let textLayer = CanvasLayer(
                        name: text,
                        frame: CanvasFrame(
                            origin: CGPoint(x: 120, y: yOffset),
                            size: CGSize(width: 260, height: 30)
                        ),
                        layerType: .text
                    )
                    layers.append(textLayer)
                    yOffset += 40
                }
            }
        }

        // Detect buttons
        let buttonPattern = #"Button\("([^"]+)"\)"#
        if let regex = try? NSRegularExpression(pattern: buttonPattern) {
            let range = NSRange(code.startIndex..., in: code)
            for match in regex.matches(in: code, range: range) {
                if let textRange = Range(match.range(at: 1), in: code) {
                    let buttonText = String(code[textRange])
                    let buttonLayer = CanvasLayer(
                        name: buttonText,
                        frame: CanvasFrame(
                            origin: CGPoint(x: 120, y: yOffset),
                            size: CGSize(width: 260, height: 44)
                        ),
                        layerType: .element,
                        borderConfig: BorderConfig(cornerRadius: 10),
                        backgroundFill: FillConfig(fillType: .solid, color: .accent)
                    )
                    layers.append(buttonLayer)
                    yOffset += 60
                }
            }
        }

        // Add layers to document
        for layer in layers {
            document.addLayer(layer)
        }

        return layers
    }

    private func extractCodeTemplate(from prompt: String) -> String {
        let lowercased = prompt.lowercased()

        if lowercased.contains("login") || lowercased.contains("sign in") {
            return loginFormTemplate
        }
        if lowercased.contains("profile") {
            return profileTemplate
        }
        if lowercased.contains("card") {
            return cardTemplate
        }
        if lowercased.contains("list") {
            return listTemplate
        }
        if lowercased.contains("settings") {
            return settingsTemplate
        }

        return defaultTemplate
    }

    // MARK: - Templates

    private var loginFormTemplate: String {
        """
        struct LoginView: View {
            @State private var email = ""
            @State private var password = ""

            var body: some View {
                VStack(spacing: 24) {
                    Text("Welcome Back")
                        .font(.largeTitle.bold())

                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button("Sign In") { }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
                .padding(32)
            }
        }
        """
    }

    private var profileTemplate: String {
        """
        struct ProfileView: View {
            var body: some View {
                VStack(spacing: 20) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)

                    Text("John Doe")
                        .font(.title.bold())

                    Text("iOS Developer")
                        .foregroundColor(.secondary)

                    Button("Edit Profile") { }
                        .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        """
    }

    private var cardTemplate: String {
        """
        struct CardView: View {
            var body: some View {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("Card Title")
                        .font(.headline)

                    Text("Card description goes here")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 10)
            }
        }
        """
    }

    private var listTemplate: String {
        """
        struct ListView: View {
            var body: some View {
                List {
                    ForEach(0..<5) { index in
                        HStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 40, height: 40)

                            VStack(alignment: .leading) {
                                Text("Item \\(index + 1)")
                                    .font(.headline)
                                Text("Description")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        """
    }

    private var settingsTemplate: String {
        """
        struct SettingsView: View {
            @State private var notifications = true
            @State private var darkMode = false

            var body: some View {
                List {
                    Section("Preferences") {
                        Toggle("Notifications", isOn: $notifications)
                        Toggle("Dark Mode", isOn: $darkMode)
                    }

                    Section("Account") {
                        Button("Sign Out") { }
                            .foregroundColor(.red)
                    }
                }
            }
        }
        """
    }

    private var defaultTemplate: String {
        """
        struct ContentView: View {
            var body: some View {
                VStack(spacing: 20) {
                    Text("Hello, World!")
                        .font(.largeTitle.bold())

                    Button("Get Started") { }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        """
    }
}

// MARK: - Supporting Types

enum LayerEnhancement {
    case addShadow
    case roundCorners(CGFloat)
    case addBorder(CanvasColor, CGFloat)
    case changeColor(CanvasColor)
    case addGradient([CanvasColor], GradientDirection)
    case resize(CGSize)
    case convertToComponent(String)
}

enum GradientDirection {
    case vertical
    case horizontal
}

enum SuggestedLayoutType {
    case horizontal
    case vertical
    case stacked
    case freeform
}

struct ImageAnalysisResult {
    let detectedElements: [DetectedUIElement]
    let suggestedLayout: SuggestedLayoutType
    let colorPalette: [CanvasColor]
    let dimensions: CGSize
}

struct DetectedUIElement {
    let type: UIElementType
    let bounds: CGRect
    let confidence: Double
    let content: String?
}

enum UIElementType {
    case text
    case button
    case image
    case textField
    case container
}
