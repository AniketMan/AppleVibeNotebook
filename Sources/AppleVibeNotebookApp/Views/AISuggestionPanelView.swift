import SwiftUI

// MARK: - AI Suggestion Panel View
// Follows Apple Human Interface Guidelines:
// - Clear visual hierarchy
// - Consistent spacing (8pt grid)
// - Native controls and system colors
// - Accessibility support
// - Keyboard navigation

struct AISuggestionPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var aiService = AICodeSuggestionService()
    @State private var voiceService = VoiceInputService()
    @State private var screenService = ScreenCaptureService()
    @State private var imageToUIService = ImageToUIService()

    @State private var inputCode = ""
    @State private var suggestionType: AICodeSuggestionService.SuggestionType = .conversion
    @State private var showProviderPicker = false
    @State private var showSettings = false
    @State private var showScreenCapture = false
    @State private var showImagePicker = false
    @State private var errorMessage: String?
    @State private var selectedTab: InputTab = .code

    enum InputTab: String, CaseIterable, Identifiable {
        case code = "Code"
        case voice = "Voice"
        case screen = "Screen"
        case image = "Image"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .code: return "curlybraces"
            case .voice: return "mic"
            case .screen: return "macwindow"
            case .image: return "photo"
            }
        }
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("AI Assistant")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        providerMenu
                        settingsButton
                    }

                    ToolbarItem(placement: .navigation) {
                        if appState.projectURL == nil {
                            Button("Back", systemImage: "chevron.left") {
                                appState.showAIPanel = false
                            }
                        }
                    }
                }
        }
        .task {
            await aiService.checkAvailability()
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showSettings) {
            APISettingsView()
                .frame(minWidth: 550, minHeight: 600)
        }
        .sheet(isPresented: $showScreenCapture) {
            screenCaptureSheet
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        #if os(macOS)
        HSplitView {
            inputPanel
                .frame(minWidth: 320, idealWidth: 400)

            suggestionsPanel
                .frame(minWidth: 320)
        }
        #else
        HStack(spacing: 0) {
            inputPanel
                .frame(minWidth: 320, idealWidth: 400)

            suggestionsPanel
                .frame(minWidth: 320)
        }
        #endif
    }

    // MARK: - Provider Menu (HIG: Use native menus)

    private var providerMenu: some View {
        Menu {
            Section("On-Device") {
                providerButton(for: .apple)
            }

            Section("Server-Side Models") {
                providerButton(for: .openai)
                providerButton(for: .anthropic)
                providerButton(for: .google)
                providerButton(for: .geminiNotebook)
                providerButton(for: .xai)
                providerButton(for: .github)
            }

            Divider()

            Button("Manage API Keys...", systemImage: "key") {
                showSettings = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: aiService.currentProvider.iconName)
                Text(shortProviderName)
                statusIndicator
            }
            .font(.callout)
        }
    }

    private func providerButton(for provider: AIProvider) -> some View {
        let connected = provider == .apple || APIKeyStorage.shared.hasAPIKey(for: provider)

        return Button {
            if connected {
                aiService.currentProvider = provider
                Task { await aiService.checkAvailability() }
            } else {
                showSettings = true
            }
        } label: {
            Label {
                HStack {
                    Text(provider.rawValue)
                    Spacer()
                    if !connected {
                        Text("Add Key")
                            .foregroundStyle(.secondary)
                    }
                    if provider.supportsVision {
                        Image(systemName: "eye")
                            .foregroundStyle(.purple)
                    }
                }
            } icon: {
                Image(systemName: provider.iconName)
            }
        }
        .disabled(!connected && provider != .apple)
    }

    private var shortProviderName: String {
        switch aiService.currentProvider {
        case .apple: return "Apple"
        case .openai: return "OpenAI"
        case .anthropic: return "Claude"
        case .google: return "Gemini"
        case .geminiNotebook: return "Notebook"
        case .xai: return "Grok"
        case .github: return "GitHub"
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch aiService.modelState {
        case .ready:
            Circle().fill(.green).frame(width: 8, height: 8)
        case .generating:
            ProgressView().scaleEffect(0.5)
        case .error, .unavailable:
            Circle().fill(.red).frame(width: 8, height: 8)
        default:
            Circle().fill(.orange).frame(width: 8, height: 8)
        }
    }

    private var settingsButton: some View {
        Button("Settings", systemImage: "gearshape") {
            showSettings = true
        }
    }

    // MARK: - Input Panel (HIG: Clear sections with proper spacing)

    private var inputPanel: some View {
        VStack(spacing: 0) {
            // Tab picker - HIG: Use segmented control for related options
            Picker("Input Mode", selection: $selectedTab) {
                ForEach(InputTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content area
            ScrollView {
                Group {
                    switch selectedTab {
                    case .code: codeInputView
                    case .voice: voiceInputView
                    case .screen: screenInputView
                    case .image: imageInputView
                    }
                }
                .padding()
            }
        }
        .background(.background)
    }

    // MARK: - Code Input

    private var codeInputView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Suggestion type - HIG: Use picker for mutually exclusive options
            VStack(alignment: .leading, spacing: 8) {
                Text("Action")
                    .font(.headline)

                Picker("Action", selection: $suggestionType) {
                    Text("Convert").tag(AICodeSuggestionService.SuggestionType.conversion)
                    Text("Complete").tag(AICodeSuggestionService.SuggestionType.completion)
                    Text("Optimize").tag(AICodeSuggestionService.SuggestionType.optimization)
                    Text("Explain").tag(AICodeSuggestionService.SuggestionType.explanation)
                    Text("Fix").tag(AICodeSuggestionService.SuggestionType.fix)
                }
                .pickerStyle(.segmented)
            }

            // Code input - HIG: Clear labels, proper text field styling
            VStack(alignment: .leading, spacing: 8) {
                Text(inputLabel)
                    .font(.headline)

                TextEditor(text: $inputCode)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
            }

            // Generate button - HIG: Primary action prominent
            HStack {
                Button(action: { Task { await generateSuggestion() } }) {
                    Label("Generate", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canGenerate)
                .keyboardShortcut(.return, modifiers: .command)

                if case .generating = aiService.modelState {
                    Button("Cancel", role: .cancel) {
                        aiService.cancelGeneration()
                    }
                }

                Spacer()

                // Model info
                Text(aiService.currentModel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Voice Input

    private var voiceInputView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Microphone button - HIG: Large touch target, clear state
            Button {
                Task {
                    if case .idle = voiceService.state {
                        let authorized = await voiceService.requestAuthorization()
                        if authorized {
                            try? voiceService.startListening()
                        }
                    } else {
                        try? voiceService.toggleListening()
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(voiceService.isListening ? .red : .accentColor)
                        .frame(width: 88, height: 88)
                        .shadow(radius: voiceService.isListening ? 8 : 0)

                    Image(systemName: voiceService.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(voiceService.isListening ? "Stop recording" : "Start recording")

            Text(voiceService.isListening ? "Listening..." : "Tap to speak")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Transcription
            if !voiceService.currentTranscription.isEmpty {
                GroupBox("Transcription") {
                    Text(voiceService.currentTranscription)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    Button("Use as Code Input") {
                        inputCode = voiceService.currentTranscription
                        selectedTab = .code
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
            }

            Spacer()
        }
    }

    // MARK: - Screen Input

    private var screenInputView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Capture Screen")
                .font(.title2.bold())

            Text("Capture a window or screen to generate UI code")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Capture options - HIG: Clear action buttons
            HStack(spacing: 16) {
                Button {
                    screenService.captureMode = .window
                    showScreenCapture = true
                } label: {
                    Label("Window", systemImage: "macwindow")
                }
                .buttonStyle(.bordered)

                Button {
                    Task {
                        screenService.captureMode = .fullScreen
                        let _ = await screenService.requestAccess()
                        if let data = try? await screenService.capture() {
                            await processScreenCapture(data)
                        }
                    }
                } label: {
                    Label("Full Screen", systemImage: "rectangle.dashed")
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
    }

    // MARK: - Image Input

    private var imageInputView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.purple)

            Text("Image to UI")
                .font(.title2.bold())

            Text("Upload a design to generate SwiftUI and React code")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Output format - HIG: Clear options
            Picker("Output Format", selection: $imageToUIService.outputFormat) {
                ForEach(ImageToUIService.OutputFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            Button {
                showImagePicker = true
            } label: {
                Label("Choose Image", systemImage: "photo.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .fileImporter(
                isPresented: $showImagePicker,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    if case .success(let urls) = result, let url = urls.first {
                        await processImageFile(url)
                    }
                }
            }

            if case .analyzing = imageToUIService.state {
                ProgressView(imageToUIService.progress)
            }

            Spacer()
        }
    }

    // MARK: - Suggestions Panel

    private var suggestionsPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Results")
                    .font(.headline)

                Spacer()

                if !aiService.suggestions.isEmpty || !imageToUIService.generatedResults.isEmpty {
                    Button("Clear", role: .destructive) {
                        aiService.clearHistory()
                        imageToUIService.clearResults()
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding()

            Divider()

            if aiService.suggestions.isEmpty && imageToUIService.generatedResults.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "sparkles.rectangle.stack")
                } description: {
                    Text("Enter code, speak, or capture screen to generate suggestions")
                }
            } else {
                List {
                    ForEach(imageToUIService.generatedResults) { result in
                        imageResultRow(result)
                    }

                    ForEach(aiService.suggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(.background.secondary)
    }

    private func imageResultRow(_ result: ImageToUIService.GeneratedUI) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                if let swiftUI = result.swiftUICode {
                    GroupBox("SwiftUI") {
                        Text(swiftUI)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let react = result.reactCode {
                    GroupBox("React") {
                        Text(react)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } label: {
            Label("Image to UI", systemImage: "photo")
                .badge(Text(timeAgo(result.timestamp)))
        }
    }

    private func suggestionRow(_ suggestion: AICodeSuggestionService.CodeSuggestion) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text(suggestion.suggestedCode)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 6))

                if !suggestion.explanation.isEmpty {
                    Text(suggestion.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Copy", systemImage: "doc.on.doc") {
                        copyToClipboard(suggestion.suggestedCode)
                    }
                    .buttonStyle(.borderless)

                    Button("Use as Input", systemImage: "arrow.left") {
                        inputCode = suggestion.suggestedCode
                        selectedTab = .code
                    }
                    .buttonStyle(.borderless)
                }
            }
        } label: {
            HStack {
                Label(suggestion.type.rawValue, systemImage: iconForType(suggestion.type))

                Spacer()

                Text(suggestion.provider.rawValue.split(separator: " ").first ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(timeAgo(suggestion.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Screen Capture Sheet

    private var screenCaptureSheet: some View {
        #if os(macOS)
        NavigationStack {
            List(screenService.availableWindows, id: \.windowID) { window in
                Button {
                    Task {
                        screenService.selectedWindow = window
                        if let data = try? await screenService.capture() {
                            showScreenCapture = false
                            await processScreenCapture(data)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "macwindow")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading) {
                            Text(window.title ?? "Untitled")
                                .lineLimit(1)
                            Text(window.owningApplication?.applicationName ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Window")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showScreenCapture = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await screenService.refreshAvailableContent() }
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .task {
            let _ = await screenService.requestAccess()
        }
        #else
        NavigationStack {
            ContentUnavailableView(
                "Screen Capture",
                systemImage: "rectangle.dashed",
                description: Text("Screen capture is not available on iOS. Please import an image instead.")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showScreenCapture = false
                    }
                }
            }
        }
        #endif
    }

    // MARK: - Helpers

    private var inputLabel: String {
        switch suggestionType {
        case .conversion: return "React/JSX Code"
        case .completion: return "Partial SwiftUI Code"
        case .optimization: return "SwiftUI Code to Optimize"
        case .explanation: return "SwiftUI Code to Explain"
        case .fix: return "SwiftUI Code with Issues"
        }
    }

    private var canGenerate: Bool {
        !inputCode.isEmpty && {
            if case .ready = aiService.modelState { return true }
            return false
        }()
    }

    private func iconForType(_ type: AICodeSuggestionService.SuggestionType) -> String {
        switch type {
        case .conversion: return "arrow.triangle.2.circlepath"
        case .completion: return "text.cursor"
        case .optimization: return "gauge.with.dots.needle.67percent"
        case .explanation: return "book"
        case .fix: return "wrench"
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    // MARK: - Actions

    private func generateSuggestion() async {
        do {
            _ = try await aiService.suggest(code: inputCode, type: suggestionType)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func processScreenCapture(_ imageData: Data) async {
        imageToUIService.selectedProvider = aiService.currentProvider
        do {
            _ = try await imageToUIService.generateFromImage(imageData)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func processImageFile(_ url: URL) async {
        imageToUIService.selectedProvider = aiService.currentProvider
        do {
            _ = try await imageToUIService.generateFromFile(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AISuggestionPanelView()
        .environment(AppState())
        .frame(width: 900, height: 600)
}
