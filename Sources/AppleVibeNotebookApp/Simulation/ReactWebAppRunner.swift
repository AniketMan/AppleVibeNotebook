import Foundation
import WebKit
import SwiftUI
import Combine
import AppleVibeNotebook

@Observable
public final class ReactWebAppRunner {
    public var isRunning: Bool = false
    public var currentApp: ReactWebApp?
    public var consoleLogs: [ConsoleLogEntry] = []
    public var error: ReactRunnerError?

    private let bundler = ReactBundler()
    private let storage = ReactAppStorage()

    public init() {}

    public func build(from document: CanvasDocument, name: String) async throws -> ReactWebApp {
        let compiler = CanvasToIRCompiler()
        let ir = compiler.compile(document)

        let generator = ReactCodeGenerator(options: ReactCodeGenerator.Options(
            format: .tsx,
            useTypeScript: true,
            useTailwind: true,
            componentStyle: .functional
        ))
        let generatedCode = generator.generate(from: ir)

        let bundle = try await bundler.bundle(
            components: generatedCode,
            appName: name
        )

        let app = ReactWebApp(
            id: UUID(),
            name: name,
            bundle: bundle,
            sourceDocumentId: document.id,
            createdAt: Date(),
            modifiedAt: Date()
        )

        try storage.save(app)

        return app
    }

    public func run(_ app: ReactWebApp) {
        currentApp = app
        isRunning = true
        consoleLogs.removeAll()
    }

    public func stop() {
        isRunning = false
        currentApp = nil
    }

    public func listSavedApps() -> [ReactWebApp] {
        storage.loadAll()
    }

    public func delete(_ app: ReactWebApp) throws {
        try storage.delete(app.id)
    }

    public func appendLog(_ entry: ConsoleLogEntry) {
        consoleLogs.append(entry)
        if consoleLogs.count > 500 {
            consoleLogs.removeFirst(100)
        }
    }
}

public struct ReactWebApp: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var bundle: ReactBundle
    public let sourceDocumentId: UUID
    public let createdAt: Date
    public var modifiedAt: Date

    public var displayIcon: String {
        "app.badge"
    }
}

public struct ReactBundle: Codable, Sendable {
    public let html: String
    public let css: String
    public let javascript: String
    public let assets: [BundledAsset]

    public var fullHTML: String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>React App</title>
            <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
            <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
            <script src="https://cdn.tailwindcss.com"></script>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                    -webkit-font-smoothing: antialiased;
                    overscroll-behavior: none;
                }
                \(css)
            </style>
        </head>
        <body>
            <div id="root"></div>
            <script>
                // Console bridge to native
                (function() {
                    const originalLog = console.log;
                    const originalWarn = console.warn;
                    const originalError = console.error;

                    function sendToNative(level, args) {
                        try {
                            window.webkit.messageHandlers.consoleBridge.postMessage({
                                level: level,
                                message: Array.from(args).map(a => String(a)).join(' '),
                                timestamp: Date.now()
                            });
                        } catch(e) {}
                    }

                    console.log = function() { sendToNative('log', arguments); originalLog.apply(console, arguments); };
                    console.warn = function() { sendToNative('warn', arguments); originalWarn.apply(console, arguments); };
                    console.error = function() { sendToNative('error', arguments); originalError.apply(console, arguments); };

                    window.onerror = function(msg, url, line, col, error) {
                        sendToNative('error', [msg + ' at line ' + line]);
                        return false;
                    };
                })();
            </script>
            <script>
                \(javascript)
            </script>
        </body>
        </html>
        """
    }
}

public struct BundledAsset: Codable, Sendable {
    public let name: String
    public let mimeType: String
    public let data: Data
}

public struct ConsoleLogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let level: LogLevel
    public let message: String
    public let timestamp: Date

    public enum LogLevel: String, Sendable {
        case log, warn, error, info

        public var color: Color {
            switch self {
            case .log: return .primary
            case .warn: return .orange
            case .error: return .red
            case .info: return .blue
            }
        }

        public var icon: String {
            switch self {
            case .log: return "text.alignleft"
            case .warn: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            case .info: return "info.circle"
            }
        }
    }
}

public enum ReactRunnerError: Error, LocalizedError {
    case bundleFailed(String)
    case storageFailed(String)
    case appNotFound

    public var errorDescription: String? {
        switch self {
        case .bundleFailed(let msg): return "Bundle failed: \(msg)"
        case .storageFailed(let msg): return "Storage error: \(msg)"
        case .appNotFound: return "App not found"
        }
    }
}

final class ReactBundler {
    func bundle(components: [GeneratedReactFile], appName: String) async throws -> ReactBundle {
        var allCSS = ""
        var allJS = """
        const { useState, useEffect, useCallback, useMemo, useRef } = React;

        """

        for file in components {
            if file.path.hasSuffix(".css") {
                allCSS += file.content + "\n"
            } else if file.path.hasSuffix(".tsx") || file.path.hasSuffix(".jsx") || file.path.hasSuffix(".js") {
                let cleanedJS = cleanTypeScriptForBrowser(file.content)
                allJS += cleanedJS + "\n\n"
            }
        }

        allJS += """

        // Mount the App
        const root = ReactDOM.createRoot(document.getElementById('root'));
        root.render(React.createElement(App));
        """

        return ReactBundle(
            html: "",
            css: allCSS,
            javascript: allJS,
            assets: []
        )
    }

    private func cleanTypeScriptForBrowser(_ code: String) -> String {
        var cleaned = code

        let typePatterns = [
            #": React\.FC<[^>]*>"#,
            #": React\.ReactNode"#,
            #": string"#,
            #": number"#,
            #": boolean"#,
            #": any"#,
            #": void"#,
            #"<[A-Z][A-Za-z]*Props>"#,
            #"interface \w+ \{[^}]*\}"#,
            #"type \w+ = [^;]+;"#
        ]

        for pattern in typePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }

        cleaned = cleaned.replacingOccurrences(of: "export default ", with: "const ")
        cleaned = cleaned.replacingOccurrences(of: "export ", with: "")
        cleaned = cleaned.replacingOccurrences(of: "import React from 'react';", with: "")
        cleaned = cleaned.replacingOccurrences(of: "import React from \"react\";", with: "")

        return cleaned
    }
}

final class ReactAppStorage {
    private let fileManager = FileManager.default

    private var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("CanvasCode/ReactApps", isDirectory: true)
    }

    init() {
        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }

    func save(_ app: ReactWebApp) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(app)

        let fileURL = storageURL.appendingPathComponent("\(app.id.uuidString).json")
        try data.write(to: fileURL)
    }

    func load(_ id: UUID) -> ReactWebApp? {
        let fileURL = storageURL.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(ReactWebApp.self, from: data)
    }

    func loadAll() -> [ReactWebApp] {
        guard let files = try? fileManager.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil) else {
            return []
        }

        return files.compactMap { url -> ReactWebApp? in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(ReactWebApp.self, from: data)
        }.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func delete(_ id: UUID) throws {
        let fileURL = storageURL.appendingPathComponent("\(id.uuidString).json")
        try fileManager.removeItem(at: fileURL)
    }
}

public struct ReactAppRunnerView: View {
    @Bindable var runner: ReactWebAppRunner
    @State private var showConsole = false

    public init(runner: ReactWebAppRunner) {
        self.runner = runner
    }

    public var body: some View {
        ZStack {
            if let app = runner.currentApp, runner.isRunning {
                ReactWebViewContainer(
                    app: app,
                    onConsoleLog: { entry in
                        runner.appendLog(entry)
                    }
                )

                VStack {
                    HStack {
                        Button {
                            runner.stop()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white, .red)
                        }

                        Spacer()

                        Text(app.name)
                            .font(.headline)
                            .foregroundColor(.white)

                        Spacer()

                        Button {
                            showConsole.toggle()
                        } label: {
                            Image(systemName: "terminal.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial.opacity(0.8))

                    Spacer()

                    if showConsole {
                        consoleView
                    }
                }
            } else {
                appLibraryView
            }
        }
    }

    private var appLibraryView: some View {
        NavigationStack {
            List {
                let apps = runner.listSavedApps()

                if apps.isEmpty {
                    ContentUnavailableView(
                        "No Apps",
                        systemImage: "app.badge",
                        description: Text("Build a React app from your canvas design")
                    )
                } else {
                    ForEach(apps) { app in
                        Button {
                            runner.run(app)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: app.displayIcon)
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 44, height: 44)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(app.name)
                                        .font(.headline)

                                    Text(app.modifiedAt, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "play.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                try? runner.delete(app)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Apps")
        }
    }

    private var consoleView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Console")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    runner.consoleLogs.removeAll()
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(runner.consoleLogs) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: entry.level.icon)
                                .foregroundColor(entry.level.color)
                                .font(.caption)

                            Text(entry.message)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(entry.level.color)

                            Spacer()

                            Text(entry.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(height: 200)
        }
        .background(.ultraThinMaterial)
    }
}

#if os(iOS)
struct ReactWebViewContainer: UIViewRepresentable {
    let app: ReactWebApp
    let onConsoleLog: (ConsoleLogEntry) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "consoleBridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.bounces = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        webView.loadHTMLString(app.bundle.fullHTML, baseURL: nil)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onConsoleLog: onConsoleLog)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        let onConsoleLog: (ConsoleLogEntry) -> Void

        init(onConsoleLog: @escaping (ConsoleLogEntry) -> Void) {
            self.onConsoleLog = onConsoleLog
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let levelStr = body["level"] as? String,
                  let msg = body["message"] as? String else { return }

            let level = ConsoleLogEntry.LogLevel(rawValue: levelStr) ?? .log
            let entry = ConsoleLogEntry(level: level, message: msg, timestamp: Date())

            DispatchQueue.main.async {
                self.onConsoleLog(entry)
            }
        }
    }
}
#else
struct ReactWebViewContainer: NSViewRepresentable {
    let app: ReactWebApp
    let onConsoleLog: (ConsoleLogEntry) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "consoleBridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.loadHTMLString(app.bundle.fullHTML, baseURL: nil)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onConsoleLog: onConsoleLog)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        let onConsoleLog: (ConsoleLogEntry) -> Void

        init(onConsoleLog: @escaping (ConsoleLogEntry) -> Void) {
            self.onConsoleLog = onConsoleLog
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let levelStr = body["level"] as? String,
                  let msg = body["message"] as? String else { return }

            let level = ConsoleLogEntry.LogLevel(rawValue: levelStr) ?? .log
            let entry = ConsoleLogEntry(level: level, message: msg, timestamp: Date())

            DispatchQueue.main.async {
                self.onConsoleLog(entry)
            }
        }
    }
}
#endif
