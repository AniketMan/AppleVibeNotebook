import Foundation
import FoundationModels

// MARK: - AI Code Suggestion Service (Multi-Provider)

/// Service for generating AI-powered code suggestions.
/// Defaults to Apple Foundation Models, with optional external providers via API keys.
@Observable
@MainActor
public final class AICodeSuggestionService {

    // MARK: - Types

    public enum SuggestionType: String, Sendable {
        case completion = "Code Completion"
        case conversion = "React to SwiftUI"
        case optimization = "Code Optimization"
        case explanation = "Code Explanation"
        case fix = "Bug Fix"
    }

    public struct CodeSuggestion: Identifiable, Sendable {
        public let id = UUID()
        public let type: SuggestionType
        public let originalCode: String
        public let suggestedCode: String
        public let explanation: String
        public let confidence: Double
        public let timestamp: Date
        public let provider: AIProvider
    }

    public enum ModelState: Sendable {
        case notLoaded
        case checking
        case ready
        case generating
        case unavailable(String)
        case error(String)
    }

    // MARK: - Properties

    public private(set) var modelState: ModelState = .notLoaded
    public private(set) var suggestions: [CodeSuggestion] = []
    public private(set) var tokensPerSecond: Double = 0

    public var currentProvider: AIProvider {
        didSet {
            AIProviderSettings.shared.selectedProvider = currentProvider
            appleSession = nil
            modelState = .notLoaded
        }
    }

    public var currentModel: String {
        get { AIProviderSettings.shared.selectedModel(for: currentProvider) }
        set { AIProviderSettings.shared.setSelectedModel(newValue, for: currentProvider) }
    }

    private var appleSession: LanguageModelSession?
    private var currentTask: Task<Void, Never>?
    private let keyStorage = APIKeyStorage.shared

    // MARK: - System Prompts

    private let swiftUISystemPrompt = """
    You are an expert Swift and SwiftUI developer. Convert React/JSX code to native SwiftUI.

    Key mappings:
    - React useState → SwiftUI @State
    - React useEffect → SwiftUI .onAppear/.onChange
    - React props → SwiftUI parameters or @Binding
    - div → VStack/HStack/ZStack
    - className → SwiftUI modifiers
    - onClick → .onTapGesture or Button
    - CSS flexbox → SwiftUI stacks with alignment

    Output clean, idiomatic SwiftUI code. Use modern APIs (iOS 17+/macOS 14+).
    Only output the Swift code in a code block, then a brief explanation.
    """

    private let codeCompletionPrompt = """
    Complete the SwiftUI code naturally. Follow Swift naming conventions.
    Only output the completion, not the full code.
    """

    // MARK: - Initialization

    public init() {
        self.currentProvider = AIProviderSettings.shared.selectedProvider
    }

    // MARK: - Provider Management

    /// Check if the current provider is available
    public func checkAvailability() async {
        modelState = .checking

        switch currentProvider {
        case .apple:
            await checkAppleAvailability()
        default:
            if keyStorage.hasAPIKey(for: currentProvider) {
                modelState = .ready
            } else {
                modelState = .unavailable("API key required for \(currentProvider.rawValue)")
            }
        }
    }

    private func checkAppleAvailability() async {
        // Initialize Foundation Models session
        do {
            let model = SystemLanguageModel()
            appleSession = LanguageModelSession(model: model)
            modelState = .ready
        } catch {
            modelState = .unavailable("Apple Intelligence unavailable: \(error.localizedDescription)")
        }
    }

    /// Get available providers (Apple always available, others need API keys)
    public var availableProviders: [AIProvider] {
        var providers: [AIProvider] = [.apple]
        for provider in AIProvider.allCases where provider != .apple {
            if keyStorage.hasAPIKey(for: provider) {
                providers.append(provider)
            }
        }
        return providers
    }

    /// Get all providers with their connection status
    public var allProvidersStatus: [(provider: AIProvider, connected: Bool)] {
        AIProvider.allCases.map { provider in
            let connected = provider == .apple || keyStorage.hasAPIKey(for: provider)
            return (provider, connected)
        }
    }

    // MARK: - Code Suggestion

    /// Generate a code suggestion using the current provider
    public func suggest(
        code: String,
        type: SuggestionType,
        context: String? = nil
    ) async throws -> CodeSuggestion {
        // Ensure provider is ready
        if case .notLoaded = modelState {
            await checkAvailability()
        }

        guard case .ready = modelState else {
            if case .unavailable(let msg) = modelState {
                throw SuggestionError.providerUnavailable(msg)
            }
            throw SuggestionError.providerUnavailable("Provider not ready")
        }

        modelState = .generating
        let startTime = Date()

        let generatedText: String

        switch currentProvider {
        case .apple:
            generatedText = try await generateWithApple(code: code, type: type, context: context)
        case .openai:
            generatedText = try await generateWithOpenAI(code: code, type: type, context: context)
        case .anthropic:
            generatedText = try await generateWithAnthropic(code: code, type: type, context: context)
        case .xai:
            generatedText = try await generateWithXAI(code: code, type: type, context: context)
        case .google, .geminiNotebook:
            generatedText = try await generateWithGoogle(code: code, type: type, context: context)
        case .github:
            generatedText = try await generateWithGitHub(code: code, type: type, context: context)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let estimatedTokens = Double(generatedText.count) / 4.0
        tokensPerSecond = estimatedTokens / max(elapsed, 0.1)

        modelState = .ready

        let suggestion = CodeSuggestion(
            type: type,
            originalCode: code,
            suggestedCode: extractCode(from: generatedText),
            explanation: extractExplanation(from: generatedText),
            confidence: calculateConfidence(generatedText),
            timestamp: Date(),
            provider: currentProvider
        )

        suggestions.insert(suggestion, at: 0)
        if suggestions.count > 20 {
            suggestions = Array(suggestions.prefix(20))
        }

        return suggestion
    }

    // MARK: - Apple Foundation Models

    private func generateWithApple(code: String, type: SuggestionType, context: String?) async throws -> String {
        if appleSession == nil {
            let model = SystemLanguageModel()
            appleSession = LanguageModelSession(model: model)
        }

        guard let session = appleSession else {
            throw SuggestionError.providerUnavailable("Apple session not available")
        }

        let prompt = buildPrompt(code: code, type: type, context: context)

        // Use respond method and extract the string content
        let response: LanguageModelSession.Response<String> = try await session.respond(to: prompt)
        return response.content
    }

    // MARK: - OpenAI (ChatGPT)

    private func generateWithOpenAI(code: String, type: SuggestionType, context: String?) async throws -> String {
        guard let apiKey = keyStorage.getAPIKey(for: .openai) else {
            throw SuggestionError.apiKeyMissing(.openai)
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": currentModel,
            "messages": [
                ["role": "system", "content": systemPrompt(for: type)],
                ["role": "user", "content": buildUserPrompt(code: code, type: type, context: context)]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SuggestionError.apiError(error)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String

        return content ?? ""
    }

    // MARK: - Anthropic (Claude)

    private func generateWithAnthropic(code: String, type: SuggestionType, context: String?) async throws -> String {
        guard let apiKey = keyStorage.getAPIKey(for: .anthropic) else {
            throw SuggestionError.apiKeyMissing(.anthropic)
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": currentModel,
            "max_tokens": 4096,
            "system": systemPrompt(for: type),
            "messages": [
                ["role": "user", "content": buildUserPrompt(code: code, type: type, context: context)]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SuggestionError.apiError(error)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = json?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String

        return text ?? ""
    }

    // MARK: - xAI (Grok)

    private func generateWithXAI(code: String, type: SuggestionType, context: String?) async throws -> String {
        guard let apiKey = keyStorage.getAPIKey(for: .xai) else {
            throw SuggestionError.apiKeyMissing(.xai)
        }

        let url = URL(string: "https://api.x.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": currentModel,
            "messages": [
                ["role": "system", "content": systemPrompt(for: type)],
                ["role": "user", "content": buildUserPrompt(code: code, type: type, context: context)]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SuggestionError.apiError(error)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String

        return content ?? ""
    }

    // MARK: - Google (Gemini)

    private func generateWithGoogle(code: String, type: SuggestionType, context: String?) async throws -> String {
        guard let apiKey = keyStorage.getAPIKey(for: .google) else {
            throw SuggestionError.apiKeyMissing(.google)
        }

        let model = currentModel
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let fullPrompt = systemPrompt(for: type) + "\n\n" + buildUserPrompt(code: code, type: type, context: context)

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": fullPrompt]]]
            ],
            "generationConfig": [
                "temperature": 0.3
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SuggestionError.apiError(error)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let text = parts?.first?["text"] as? String

        return text ?? ""
    }

    // MARK: - GitHub MCP

    private func generateWithGitHub(code: String, type: SuggestionType, context: String?) async throws -> String {
        guard let apiKey = keyStorage.getAPIKey(for: .github) else {
            throw SuggestionError.apiKeyMissing(.github)
        }

        // GitHub Copilot uses a different endpoint for completions
        // For now, we'll use the models API which supports chat
        let url = URL(string: "https://api.githubcopilot.com/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt(for: type)],
                ["role": "user", "content": buildUserPrompt(code: code, type: type, context: context)]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SuggestionError.apiError(error)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String

        return content ?? ""
    }

    // MARK: - Convenience Methods

    public func convertReactToSwiftUI(reactCode: String, cssCode: String? = nil) async throws -> CodeSuggestion {
        var fullCode = reactCode
        if let css = cssCode {
            fullCode += "\n\n/* CSS */\n\(css)"
        }
        return try await suggest(code: fullCode, type: .conversion)
    }

    public func complete(partialCode: String) async throws -> CodeSuggestion {
        return try await suggest(code: partialCode, type: .completion)
    }

    public func explain(swiftUICode: String) async throws -> CodeSuggestion {
        return try await suggest(code: swiftUICode, type: .explanation)
    }

    public func optimize(swiftUICode: String) async throws -> CodeSuggestion {
        return try await suggest(code: swiftUICode, type: .optimization)
    }

    public func cancelGeneration() {
        currentTask?.cancel()
        currentTask = nil
        if case .generating = modelState {
            modelState = .ready
        }
    }

    public func clearHistory() {
        suggestions.removeAll()
    }

    // MARK: - Private Helpers

    private func systemPrompt(for type: SuggestionType) -> String {
        switch type {
        case .completion:
            return codeCompletionPrompt
        case .conversion, .optimization, .explanation, .fix:
            return swiftUISystemPrompt
        }
    }

    private func buildPrompt(code: String, type: SuggestionType, context: String?) -> String {
        systemPrompt(for: type) + "\n\n" + buildUserPrompt(code: code, type: type, context: context)
    }

    private func buildUserPrompt(code: String, type: SuggestionType, context: String?) -> String {
        var prompt = ""

        switch type {
        case .conversion:
            prompt = "Convert this React/JSX code to SwiftUI:\n\n```jsx\n\(code)\n```"
        case .completion:
            prompt = "Complete this SwiftUI code:\n\n```swift\n\(code)\n```"
        case .optimization:
            prompt = "Optimize this SwiftUI code:\n\n```swift\n\(code)\n```"
        case .explanation:
            prompt = "Explain this SwiftUI code:\n\n```swift\n\(code)\n```"
        case .fix:
            prompt = "Fix issues in this SwiftUI code:\n\n```swift\n\(code)\n```"
        }

        if let context = context {
            prompt += "\n\nContext: \(context)"
        }

        return prompt
    }

    private func extractCode(from response: String) -> String {
        let pattern = "```(?:swift)?\\s*([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let range = Range(match.range(at: 1), in: response) {
            return String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractExplanation(from response: String) -> String {
        let pattern = "```[\\s\\S]*?```"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let result = regex.stringByReplacingMatches(
                in: response,
                range: NSRange(response.startIndex..., in: response),
                withTemplate: ""
            )
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private func calculateConfidence(_ response: String) -> Double {
        var score = 0.5
        if response.contains("struct") || response.contains("View") { score += 0.2 }
        if response.contains("var body") { score += 0.1 }
        if response.count > 50 { score += 0.1 }
        if !response.lowercased().contains("error") { score += 0.1 }
        return min(score, 1.0)
    }

    // MARK: - Errors

    public enum SuggestionError: Error, LocalizedError {
        case providerUnavailable(String)
        case apiKeyMissing(AIProvider)
        case apiError(String)
        case generationFailed(String)
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .providerUnavailable(let msg):
                return msg
            case .apiKeyMissing(let provider):
                return "API key required for \(provider.rawValue). Add it in Settings."
            case .apiError(let msg):
                return "API error: \(msg)"
            case .generationFailed(let reason):
                return "Generation failed: \(reason)"
            case .cancelled:
                return "Generation was cancelled"
            }
        }
    }
}
