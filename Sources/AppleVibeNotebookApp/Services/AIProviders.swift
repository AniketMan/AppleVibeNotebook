import Foundation
import Security

// MARK: - AI Providers

/// Supported AI providers for code suggestions
public enum AIProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case apple = "Apple Intelligence"
    case openai = "OpenAI (ChatGPT)"
    case anthropic = "Anthropic (Claude)"
    case xai = "xAI (Grok)"
    case google = "Google (Gemini)"
    case geminiNotebook = "Gemini Notebook MCP"
    case github = "GitHub MCP"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .apple: return "apple.logo"
        case .openai: return "brain"
        case .anthropic: return "message.badge.waveform"
        case .xai: return "xmark.circle"
        case .google: return "sparkle"
        case .geminiNotebook: return "book.pages"
        case .github: return "chevron.left.forwardslash.chevron.right"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .apple: return false
        default: return true
        }
    }

    public var apiKeyPlaceholder: String {
        switch self {
        case .apple: return ""
        case .openai: return "sk-..."
        case .anthropic: return "sk-ant-..."
        case .xai: return "xai-..."
        case .google: return "AIza..."
        case .geminiNotebook: return "AIza..."
        case .github: return "ghp_..."
        }
    }

    public var helpURL: URL? {
        switch self {
        case .apple: return URL(string: "https://support.apple.com/apple-intelligence")
        case .openai: return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")
        case .xai: return URL(string: "https://console.x.ai/")
        case .google: return URL(string: "https://aistudio.google.com/apikey")
        case .geminiNotebook: return URL(string: "https://notebooklm.google.com/")
        case .github: return URL(string: "https://github.com/settings/tokens")
        }
    }

    public var baseURL: String {
        switch self {
        case .apple: return ""
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .xai: return "https://api.x.ai/v1"
        case .google: return "https://generativelanguage.googleapis.com/v1beta"
        case .geminiNotebook: return "https://generativelanguage.googleapis.com/v1beta"
        case .github: return "https://api.github.com"
        }
    }

    public var defaultModel: String {
        switch self {
        case .apple: return "apple-intelligence"
        case .openai: return "gpt-4o"
        case .anthropic: return "claude-sonnet-4-20250514"
        case .xai: return "grok-2"
        case .google: return "gemini-2.0-flash"
        case .geminiNotebook: return "gemini-2.0-flash"
        case .github: return "copilot"
        }
    }

    public var visionModel: String? {
        switch self {
        case .apple: return nil
        case .openai: return "gpt-4o"
        case .anthropic: return "claude-sonnet-4-20250514"
        case .xai: return "grok-2-vision"
        case .google: return "gemini-2.0-flash"
        case .geminiNotebook: return "gemini-2.0-flash"
        case .github: return nil
        }
    }

    public var supportsVision: Bool {
        switch self {
        case .apple, .openai, .anthropic, .google, .geminiNotebook, .xai: return true
        case .github: return false
        }
    }

    public var availableModels: [String] {
        switch self {
        case .apple:
            return ["apple-intelligence"]
        case .openai:
            return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o1", "o1-mini"]
        case .anthropic:
            return ["claude-sonnet-4-20250514", "claude-opus-4-20250514", "claude-3-5-haiku-20241022"]
        case .xai:
            return ["grok-2", "grok-2-mini", "grok-2-vision"]
        case .google:
            return ["gemini-2.0-flash", "gemini-2.0-pro", "gemini-1.5-pro"]
        case .geminiNotebook:
            return ["gemini-2.0-flash", "gemini-2.0-pro"]
        case .github:
            return ["copilot"]
        }
    }

    public var isOnDevice: Bool {
        self == .apple
    }
}

// MARK: - API Key Storage (Keychain)

/// Secure storage for API keys using Keychain
public final class APIKeyStorage: Sendable {

    public static let shared = APIKeyStorage()

    private let servicePrefix = "com.applevibenotebook.apikey."

    private init() {}

    /// Store an API key securely
    public func setAPIKey(_ key: String, for provider: AIProvider) throws {
        let service = servicePrefix + provider.rawValue
        let data = key.data(using: .utf8)!

        // Delete existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieve an API key
    public func getAPIKey(for provider: AIProvider) -> String? {
        let service = servicePrefix + provider.rawValue

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    /// Delete an API key
    public func deleteAPIKey(for provider: AIProvider) {
        let service = servicePrefix + provider.rawValue

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Check if an API key exists
    public func hasAPIKey(for provider: AIProvider) -> Bool {
        return getAPIKey(for: provider) != nil
    }

    public enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save API key (error \(status))"
            }
        }
    }
}

// MARK: - Provider Settings

/// User preferences for AI providers
@Observable
@MainActor
public final class AIProviderSettings {

    public static let shared = AIProviderSettings()

    private let defaults = UserDefaults.standard
    private let selectedProviderKey = "selectedAIProvider"
    private let selectedModelsKey = "selectedAIModels"

    public var selectedProvider: AIProvider {
        didSet {
            defaults.set(selectedProvider.rawValue, forKey: selectedProviderKey)
        }
    }

    public var selectedModels: [AIProvider: String] {
        didSet {
            let encoded = selectedModels.mapKeys { $0.rawValue }
            defaults.set(encoded, forKey: selectedModelsKey)
        }
    }

    private init() {
        // Load saved provider
        if let savedProvider = defaults.string(forKey: selectedProviderKey),
           let provider = AIProvider(rawValue: savedProvider) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .apple
        }

        // Load saved models
        if let saved = defaults.dictionary(forKey: selectedModelsKey) as? [String: String] {
            var models: [AIProvider: String] = [:]
            for (key, value) in saved {
                if let provider = AIProvider(rawValue: key) {
                    models[provider] = value
                }
            }
            self.selectedModels = models
        } else {
            self.selectedModels = [:]
        }
    }

    public func selectedModel(for provider: AIProvider) -> String {
        selectedModels[provider] ?? provider.defaultModel
    }

    public func setSelectedModel(_ model: String, for provider: AIProvider) {
        selectedModels[provider] = model
    }

    /// Get providers grouped by type
    public var onDeviceProviders: [AIProvider] {
        AIProvider.allCases.filter { $0.isOnDevice }
    }

    public var cloudProviders: [AIProvider] {
        AIProvider.allCases.filter { !$0.isOnDevice }
    }
}

// Helper extension
extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
