import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Image to UI Service

/// Service for generating React and SwiftUI code from design images/screenshots.
/// Uses vision models to analyze UI designs and generate corresponding code.
@Observable
@MainActor
public final class ImageToUIService {

    // MARK: - Types

    public enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
        case swiftUI = "SwiftUI"
        case react = "React/JSX"
        case both = "Both"

        public var id: String { rawValue }
    }

    public struct GeneratedUI: Identifiable, Sendable {
        public let id = UUID()
        public let imageData: Data
        public let swiftUICode: String?
        public let reactCode: String?
        public let description: String
        public let provider: AIProvider
        public let timestamp: Date
    }

    public enum ServiceState: Sendable {
        case idle
        case analyzing
        case generating
        case complete
        case error(String)
    }

    // MARK: - Properties

    public private(set) var state: ServiceState = .idle
    public private(set) var currentImage: Data?
    public private(set) var generatedResults: [GeneratedUI] = []
    public private(set) var progress: String = ""

    public var selectedProvider: AIProvider = .openai
    public var outputFormat: OutputFormat = .both

    private let keyStorage = APIKeyStorage.shared

    // MARK: - System Prompts

    private let swiftUIVisionPrompt = """
    You are an expert UI developer. Analyze this UI design image and generate clean, production-ready SwiftUI code.

    Requirements:
    - Use proper SwiftUI components (VStack, HStack, ZStack, List, etc.)
    - Apply appropriate modifiers for styling (padding, font, foregroundColor, etc.)
    - Use SF Symbols for icons when appropriate
    - Make the UI responsive and adaptive
    - Use @State for any interactive elements
    - Follow Apple Human Interface Guidelines
    - Use modern SwiftUI APIs (iOS 17+/macOS 14+)

    Output ONLY the Swift code in a code block. No explanations before the code.
    After the code block, briefly describe the key UI components identified.
    """

    private let reactVisionPrompt = """
    You are an expert UI developer. Analyze this UI design image and generate clean, production-ready React/JSX code.

    Requirements:
    - Use functional components with hooks
    - Use modern CSS-in-JS or CSS modules for styling
    - Make the UI responsive with flexbox/grid
    - Use semantic HTML elements
    - Include appropriate ARIA attributes for accessibility
    - Use React best practices (props, state management)

    Output ONLY the JSX code in a code block, followed by the CSS in a separate code block.
    After the code blocks, briefly describe the key UI components identified.
    """

    private let bothVisionPrompt = """
    You are an expert cross-platform UI developer. Analyze this UI design image and generate code for BOTH SwiftUI and React.

    First, output the SwiftUI code:
    - Use proper SwiftUI components and modifiers
    - Follow Apple Human Interface Guidelines
    - Use modern SwiftUI APIs (iOS 17+/macOS 14+)

    Then, output the React/JSX code:
    - Use functional components with hooks
    - Include CSS styling (inline or separate)
    - Make it responsive

    Format your response as:

    ## SwiftUI
    ```swift
    [SwiftUI code here]
    ```

    ## React
    ```jsx
    [React code here]
    ```

    ```css
    [CSS code here]
    ```

    ## Description
    [Brief description of the UI components]
    """

    // MARK: - Public API

    public init() {}

    /// Generate UI code from an image
    public func generateFromImage(
        _ imageData: Data,
        format: OutputFormat? = nil
    ) async throws -> GeneratedUI {
        let outputFormat = format ?? self.outputFormat

        guard selectedProvider.supportsVision else {
            throw ImageToUIError.providerDoesNotSupportVision
        }

        guard selectedProvider == .apple || keyStorage.hasAPIKey(for: selectedProvider) else {
            throw ImageToUIError.apiKeyRequired(selectedProvider)
        }

        currentImage = imageData
        state = .analyzing
        progress = "Analyzing image..."

        let response: String

        switch selectedProvider {
        case .openai:
            response = try await generateWithOpenAI(imageData: imageData, format: outputFormat)
        case .anthropic:
            response = try await generateWithAnthropic(imageData: imageData, format: outputFormat)
        case .google, .geminiNotebook:
            response = try await generateWithGoogle(imageData: imageData, format: outputFormat)
        case .xai:
            response = try await generateWithXAI(imageData: imageData, format: outputFormat)
        case .apple:
            response = try await generateWithApple(imageData: imageData, format: outputFormat)
        case .github:
            throw ImageToUIError.providerDoesNotSupportVision
        }

        state = .generating
        progress = "Extracting code..."

        let swiftUICode = extractSwiftUICode(from: response)
        let reactCode = extractReactCode(from: response)
        let description = extractDescription(from: response)

        let result = GeneratedUI(
            imageData: imageData,
            swiftUICode: swiftUICode,
            reactCode: reactCode,
            description: description,
            provider: selectedProvider,
            timestamp: Date()
        )

        generatedResults.insert(result, at: 0)
        if generatedResults.count > 10 {
            generatedResults = Array(generatedResults.prefix(10))
        }

        state = .complete
        progress = "Complete!"

        return result
    }

    /// Generate from a file URL
    public func generateFromFile(_ url: URL) async throws -> GeneratedUI {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImageToUIError.cannotAccessFile
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let imageData = try Data(contentsOf: url)
        return try await generateFromImage(imageData)
    }

    #if canImport(AppKit)
    /// Generate from NSImage
    public func generateFromNSImage(_ image: NSImage) async throws -> GeneratedUI {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ImageToUIError.invalidImage
        }
        return try await generateFromImage(pngData)
    }
    #endif

    /// Clear results
    public func clearResults() {
        generatedResults.removeAll()
        currentImage = nil
        state = .idle
        progress = ""
    }

    // MARK: - OpenAI Vision

    private func generateWithOpenAI(imageData: Data, format: OutputFormat) async throws -> String {
        guard let apiKey = keyStorage.getAPIKey(for: .openai) else {
            throw ImageToUIError.apiKeyRequired(.openai)
        }

        let base64Image = imageData.base64EncodedString()
        let prompt = promptForFormat(format)

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64Image)",
                                "detail": "high"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 4096
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImageToUIError.apiError(error)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String

        return content ?? ""
    }

    // MARK: - Anthropic Vision

    private func generateWithAnthropic(imageData: Data, format: OutputFormat) async throws -> String {
        guard let apiKey = keyStorage.getAPIKey(for: .anthropic) else {
            throw ImageToUIError.apiKeyRequired(.anthropic)
        }

        let base64Image = imageData.base64EncodedString()
        let mediaType = detectMediaType(imageData)
        let prompt = promptForFormat(format)

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4096,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": mediaType,
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImageToUIError.apiError(error)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = json?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String

        return text ?? ""
    }

    // MARK: - Google Vision

    private func generateWithGoogle(imageData: Data, format: OutputFormat) async throws -> String {
        guard let apiKey = keyStorage.getAPIKey(for: .google) else {
            throw ImageToUIError.apiKeyRequired(.google)
        }

        let base64Image = imageData.base64EncodedString()
        let prompt = promptForFormat(format)

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/png",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 4096
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImageToUIError.apiError(error)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let text = parts?.first?["text"] as? String

        return text ?? ""
    }

    // MARK: - xAI Vision

    private func generateWithXAI(imageData: Data, format: OutputFormat) async throws -> String {
        guard let apiKey = keyStorage.getAPIKey(for: .xai) else {
            throw ImageToUIError.apiKeyRequired(.xai)
        }

        let base64Image = imageData.base64EncodedString()
        let prompt = promptForFormat(format)

        let url = URL(string: "https://api.x.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "grok-2-vision",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 4096
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImageToUIError.apiError(error)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String

        return content ?? ""
    }

    // MARK: - Apple Vision

    private func generateWithApple(imageData: Data, format: OutputFormat) async throws -> String {
        // Apple Foundation Models support images natively
        // For now, return a placeholder - full implementation would use the vision APIs
        throw ImageToUIError.providerDoesNotSupportVision
    }

    // MARK: - Helpers

    private func promptForFormat(_ format: OutputFormat) -> String {
        switch format {
        case .swiftUI:
            return swiftUIVisionPrompt
        case .react:
            return reactVisionPrompt
        case .both:
            return bothVisionPrompt
        }
    }

    private func detectMediaType(_ data: Data) -> String {
        guard data.count >= 8 else { return "image/png" }

        let bytes = [UInt8](data.prefix(8))

        // PNG signature
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }
        // JPEG signature
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "image/jpeg"
        }
        // GIF signature
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return "image/gif"
        }
        // WebP signature
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
            return "image/webp"
        }

        return "image/png"
    }

    private func extractSwiftUICode(from response: String) -> String? {
        // Look for Swift code blocks
        let pattern = "```swift\\s*([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let range = Range(match.range(at: 1), in: response) {
            return String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func extractReactCode(from response: String) -> String? {
        // Look for JSX code blocks
        let patterns = ["```jsx\\s*([\\s\\S]*?)```", "```javascript\\s*([\\s\\S]*?)```", "```tsx\\s*([\\s\\S]*?)```"]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
               let range = Range(match.range(at: 1), in: response) {
                var code = String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)

                // Also try to find CSS
                let cssPattern = "```css\\s*([\\s\\S]*?)```"
                if let cssRegex = try? NSRegularExpression(pattern: cssPattern, options: .caseInsensitive),
                   let cssMatch = cssRegex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
                   let cssRange = Range(cssMatch.range(at: 1), in: response) {
                    let css = String(response[cssRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    code += "\n\n/* CSS */\n" + css
                }

                return code
            }
        }
        return nil
    }

    private func extractDescription(from response: String) -> String {
        // Remove all code blocks and return remaining text
        var text = response

        let patterns = ["```[\\s\\S]*?```"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                text = regex.stringByReplacingMatches(
                    in: text,
                    range: NSRange(text.startIndex..., in: text),
                    withTemplate: ""
                )
            }
        }

        // Remove markdown headers
        text = text.replacingOccurrences(of: "## SwiftUI", with: "")
        text = text.replacingOccurrences(of: "## React", with: "")
        text = text.replacingOccurrences(of: "## Description", with: "")

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Errors

    public enum ImageToUIError: Error, LocalizedError {
        case providerDoesNotSupportVision
        case apiKeyRequired(AIProvider)
        case invalidImage
        case cannotAccessFile
        case apiError(String)

        public var errorDescription: String? {
            switch self {
            case .providerDoesNotSupportVision:
                return "This provider does not support vision/image analysis"
            case .apiKeyRequired(let provider):
                return "API key required for \(provider.rawValue)"
            case .invalidImage:
                return "Invalid or unsupported image format"
            case .cannotAccessFile:
                return "Cannot access the selected file"
            case .apiError(let msg):
                return "API error: \(msg)"
            }
        }
    }
}
