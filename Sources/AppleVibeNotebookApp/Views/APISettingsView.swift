import SwiftUI

// MARK: - API Settings View

/// Settings view for managing AI provider API keys
struct APISettingsView: View {
    @State private var apiKeys: [AIProvider: String] = [:]
    @State private var showingKeys: Set<AIProvider> = []
    @State private var saveStatus: [AIProvider: SaveStatus] = [:]
    @State private var testResults: [AIProvider: TestResult] = [:]

    private let keyStorage = APIKeyStorage.shared

    enum SaveStatus {
        case idle, saving, saved, error(String)
    }

    enum TestResult {
        case idle, testing, success, error(String)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView

                ForEach(AIProvider.allCases) { provider in
                    providerCard(provider)
                }

                footerView
            }
            .padding(24)
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .onAppear {
            loadExistingKeys()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "key.horizontal")
                    .font(.system(size: 24))
                    .foregroundStyle(.cyan)

                Text("AI Provider Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Connect your preferred AI providers. Apple Intelligence is always available as the default.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Provider Card

    private func providerCard(_ provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Provider header
            HStack(spacing: 12) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(providerColor(provider))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(providerDescription(provider))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                connectionBadge(for: provider)
            }

            // API Key input (not for Apple)
            if provider.requiresAPIKey {
                Divider()
                    .background(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 8) {
                    Text("API KEY")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))

                    HStack(spacing: 8) {
                        if showingKeys.contains(provider) {
                            TextField(provider.apiKeyPlaceholder, text: binding(for: provider))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.white)
                        } else {
                            SecureField(provider.apiKeyPlaceholder, text: binding(for: provider))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.white)
                        }

                        Button {
                            if showingKeys.contains(provider) {
                                showingKeys.remove(provider)
                            } else {
                                showingKeys.insert(provider)
                            }
                        } label: {
                            Image(systemName: showingKeys.contains(provider) ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))

                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            saveAPIKey(for: provider)
                        } label: {
                            HStack(spacing: 4) {
                                if case .saving = saveStatus[provider] {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark")
                                }
                                Text("Save")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.cyan.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .disabled((apiKeys[provider] ?? "").isEmpty)

                        Button {
                            testConnection(for: provider)
                        } label: {
                            HStack(spacing: 4) {
                                if case .testing = testResults[provider] {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "bolt")
                                }
                                Text("Test")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .disabled(!keyStorage.hasAPIKey(for: provider))

                        if keyStorage.hasAPIKey(for: provider) {
                            Button {
                                deleteAPIKey(for: provider)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.red.opacity(0.7))
                                    .padding(6)
                                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        if let url = provider.helpURL {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Text("Get API Key")
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.system(size: 10))
                                .foregroundStyle(.cyan)
                            }
                        }
                    }

                    // Status messages
                    statusMessage(for: provider)
                }
            } else {
                // Apple Intelligence - show availability
                Divider()
                    .background(Color.white.opacity(0.1))

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Built-in, no API key required")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func connectionBadge(for provider: AIProvider) -> some View {
        let isConnected = provider == .apple || keyStorage.hasAPIKey(for: provider)

        return HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Color.green : Color.white.opacity(0.3))
                .frame(width: 6, height: 6)
            Text(isConnected ? "Connected" : "Not connected")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isConnected ? .green : .white.opacity(0.4))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (isConnected ? Color.green : Color.white).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 4)
        )
    }

    @ViewBuilder
    private func statusMessage(for provider: AIProvider) -> some View {
        if case .saved = saveStatus[provider] {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("API key saved securely")
                    .foregroundStyle(.green)
            }
            .font(.system(size: 11))
        } else if case .error(let msg) = saveStatus[provider] {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .foregroundStyle(.red)
            }
            .font(.system(size: 11))
        }

        if case .success = testResults[provider] {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.green)
                Text("Connection successful!")
                    .foregroundStyle(.green)
            }
            .font(.system(size: 11))
        } else if case .error(let msg) = testResults[provider] {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(msg)
                    .foregroundStyle(.orange)
            }
            .font(.system(size: 11))
            .lineLimit(2)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.cyan)
                Text("API keys are stored securely in your system Keychain")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .font(.system(size: 11))

            HStack(spacing: 6) {
                Image(systemName: "network")
                    .foregroundStyle(.cyan)
                Text("Keys are only sent to their respective provider APIs")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func providerColor(_ provider: AIProvider) -> Color {
        switch provider {
        case .apple: return .white
        case .openai: return .green
        case .anthropic: return .orange
        case .xai: return .white
        case .google: return .blue
        case .github: return .purple
        }
    }

    private func providerDescription(_ provider: AIProvider) -> String {
        switch provider {
        case .apple: return "On-device AI, private and fast"
        case .openai: return "GPT-4o, GPT-4 Turbo, o1"
        case .anthropic: return "Claude Sonnet 4, Claude Opus 4"
        case .xai: return "Grok-2, Grok-2 Mini"
        case .google: return "Gemini 2.0 Flash, Pro"
        case .github: return "GitHub Copilot integration"
        }
    }

    private func binding(for provider: AIProvider) -> Binding<String> {
        Binding(
            get: { apiKeys[provider] ?? "" },
            set: { apiKeys[provider] = $0 }
        )
    }

    private func loadExistingKeys() {
        for provider in AIProvider.allCases where provider.requiresAPIKey {
            if let key = keyStorage.getAPIKey(for: provider) {
                // Show masked version for display
                apiKeys[provider] = key
            }
        }
    }

    private func saveAPIKey(for provider: AIProvider) {
        guard let key = apiKeys[provider], !key.isEmpty else { return }

        saveStatus[provider] = .saving

        do {
            try keyStorage.setAPIKey(key, for: provider)
            saveStatus[provider] = .saved

            // Clear saved status after delay
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    if case .saved = saveStatus[provider] {
                        saveStatus[provider] = .idle
                    }
                }
            }
        } catch {
            saveStatus[provider] = .error(error.localizedDescription)
        }
    }

    private func deleteAPIKey(for provider: AIProvider) {
        keyStorage.deleteAPIKey(for: provider)
        apiKeys[provider] = ""
        testResults[provider] = .idle
        saveStatus[provider] = .idle
    }

    private func testConnection(for provider: AIProvider) {
        testResults[provider] = .testing

        Task {
            do {
                let success = try await performConnectionTest(for: provider)
                await MainActor.run {
                    testResults[provider] = success ? .success : .error("Test failed")
                }
            } catch {
                await MainActor.run {
                    testResults[provider] = .error(error.localizedDescription)
                }
            }
        }
    }

    private func performConnectionTest(for provider: AIProvider) async throws -> Bool {
        guard let apiKey = keyStorage.getAPIKey(for: provider) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No API key found"])
        }

        switch provider {
        case .openai:
            return try await testOpenAI(apiKey: apiKey)
        case .anthropic:
            return try await testAnthropic(apiKey: apiKey)
        case .xai:
            return try await testXAI(apiKey: apiKey)
        case .google:
            return try await testGoogle(apiKey: apiKey)
        case .github:
            return try await testGitHub(apiKey: apiKey)
        case .apple:
            return true
        }
    }

    private func testOpenAI(apiKey: String) async throws -> Bool {
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    private func testAnthropic(apiKey: String) async throws -> Bool {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "Hi"]]
        ])
        let (_, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return statusCode == 200 || statusCode == 201
    }

    private func testXAI(apiKey: String) async throws -> Bool {
        let url = URL(string: "https://api.x.ai/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    private func testGoogle(apiKey: String) async throws -> Bool {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
        let (_, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    private func testGitHub(apiKey: String) async throws -> Bool {
        let url = URL(string: "https://api.github.com/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
}

#Preview {
    APISettingsView()
        .frame(width: 600, height: 800)
}
