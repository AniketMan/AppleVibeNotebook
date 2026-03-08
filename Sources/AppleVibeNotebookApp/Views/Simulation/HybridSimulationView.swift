import SwiftUI
import WebKit
import AppleVibeNotebook

// MARK: - Hybrid Simulation View

/// WKWebView wrapper for React simulation.
/// Enables previewing React code in a web context alongside SwiftUI.
struct HybridSimulationView: View {
    let reactCode: String
    let device: DevicePreset
    let colorScheme: ColorScheme

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var consoleMessages: [ConsoleMessage] = []
    @State private var showConsole = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Main content
            ZStack {
                if let error = errorMessage {
                    errorView(error)
                } else {
                    webViewContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Console
            if showConsole {
                consolePanel
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Label("React Preview", systemImage: "atom")
                .font(.headline)

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Button {
                reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)

            Button {
                showConsole.toggle()
            } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.borderless)
            .foregroundColor(showConsole ? .accentColor : .secondary)
        }
        .padding()
    }

    // MARK: - Web View Content

    private var webViewContent: some View {
        GeometryReader { geometry in
            #if os(macOS)
            WebViewRepresentable(
                htmlContent: generateHTML(),
                onLoad: { isLoading = false },
                onError: { errorMessage = $0 },
                onConsoleMessage: { consoleMessages.append($0) }
            )
            .frame(width: device.size.width, height: device.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 10)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            #else
            Text("React preview available on macOS")
                .foregroundColor(.secondary)
            #endif
        }
        .background(Color(white: 0.15))
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.yellow)

            Text("Error Loading Preview")
                .font(.headline)

            Text(error)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(white: 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button("Retry") {
                errorMessage = nil
                reload()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Console Panel

    private var consolePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Console")
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Button {
                    consoleMessages.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(Color(white: 0.12))

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(consoleMessages) { message in
                        ConsoleMessageRow(message: message)
                    }
                }
                .padding(8)
            }
            .frame(height: 150)
        }
        .background(Color(white: 0.1))
    }

    // MARK: - HTML Generation

    private func generateHTML() -> String {
        let darkModeCSS = colorScheme == .dark ? darkModeStyles : ""

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <script src="https://unpkg.com/react@18/umd/react.development.js"></script>
            <script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>
            <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    background: \(colorScheme == .dark ? "#1c1c1e" : "#ffffff");
                    color: \(colorScheme == .dark ? "#ffffff" : "#000000");
                    min-height: 100vh;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                }
                #root {
                    width: 100%;
                    min-height: 100vh;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    padding: 20px;
                }
                \(tailwindResetCSS)
                \(darkModeCSS)
            </style>
        </head>
        <body>
            <div id="root"></div>
            <script type="text/babel">
                \(reactCode.isEmpty ? defaultReactCode : reactCode)

                const root = ReactDOM.createRoot(document.getElementById('root'));
                root.render(<App />);
            </script>
        </body>
        </html>
        """
    }

    private var tailwindResetCSS: String {
        """
        .flex { display: flex; }
        .flex-col { flex-direction: column; }
        .items-center { align-items: center; }
        .justify-center { justify-content: center; }
        .gap-4 { gap: 1rem; }
        .p-4 { padding: 1rem; }
        .rounded-lg { border-radius: 0.5rem; }
        .bg-blue-500 { background-color: #3b82f6; }
        .text-white { color: white; }
        .font-bold { font-weight: 700; }
        .text-xl { font-size: 1.25rem; }
        .shadow-lg { box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1); }
        """
    }

    private var darkModeStyles: String {
        """
        .bg-white { background-color: #2c2c2e; }
        .text-gray-900 { color: #ffffff; }
        """
    }

    private var defaultReactCode: String {
        """
        const App = () => {
            const [count, setCount] = React.useState(0);

            return (
                <div className="flex flex-col items-center gap-4 p-4">
                    <h1 className="text-xl font-bold">React Preview</h1>
                    <p>Count: {count}</p>
                    <button
                        className="bg-blue-500 text-white p-4 rounded-lg shadow-lg"
                        onClick={() => setCount(c => c + 1)}
                    >
                        Increment
                    </button>
                </div>
            );
        };
        """
    }

    // MARK: - Actions

    private func reload() {
        isLoading = true
        errorMessage = nil
        consoleMessages.removeAll()
    }
}

// MARK: - Console Message

struct ConsoleMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: ConsoleLevel
    let message: String
}

enum ConsoleLevel: String {
    case log, info, warn, error

    var color: Color {
        switch self {
        case .log: return .primary
        case .info: return .blue
        case .warn: return .yellow
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .log: return "text.bubble"
        case .info: return "info.circle"
        case .warn: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
}

struct ConsoleMessageRow: View {
    let message: ConsoleMessage

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: message.level.icon)
                .foregroundColor(message.level.color)
                .font(.system(size: 10))

            Text(message.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(message.level.color)

            Spacer()

            Text(message.timestamp.formatted(.dateTime.hour().minute().second()))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - WebView Representable (macOS)

#if os(macOS)
struct WebViewRepresentable: NSViewRepresentable {
    let htmlContent: String
    let onLoad: () -> Void
    let onError: (String) -> Void
    let onConsoleMessage: (ConsoleMessage) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Enable JavaScript
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // Set up console logging
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "consoleLog")

        let consoleScript = WKUserScript(
            source: """
                const originalLog = console.log;
                const originalWarn = console.warn;
                const originalError = console.error;
                const originalInfo = console.info;

                console.log = (...args) => {
                    window.webkit.messageHandlers.consoleLog.postMessage({level: 'log', message: args.map(String).join(' ')});
                    originalLog.apply(console, args);
                };
                console.warn = (...args) => {
                    window.webkit.messageHandlers.consoleLog.postMessage({level: 'warn', message: args.map(String).join(' ')});
                    originalWarn.apply(console, args);
                };
                console.error = (...args) => {
                    window.webkit.messageHandlers.consoleLog.postMessage({level: 'error', message: args.map(String).join(' ')});
                    originalError.apply(console, args);
                };
                console.info = (...args) => {
                    window.webkit.messageHandlers.consoleLog.postMessage({level: 'info', message: args.map(String).join(' ')});
                    originalInfo.apply(console, args);
                };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(consoleScript)
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoad: onLoad, onError: onError, onConsoleMessage: onConsoleMessage)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onLoad: () -> Void
        let onError: (String) -> Void
        let onConsoleMessage: (ConsoleMessage) -> Void

        init(onLoad: @escaping () -> Void, onError: @escaping (String) -> Void, onConsoleMessage: @escaping (ConsoleMessage) -> Void) {
            self.onLoad = onLoad
            self.onError = onError
            self.onConsoleMessage = onConsoleMessage
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoad()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onError(error.localizedDescription)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: String],
                  let level = body["level"],
                  let messageText = body["message"] else { return }

            let consoleLevel = ConsoleLevel(rawValue: level) ?? .log
            let consoleMessage = ConsoleMessage(
                timestamp: Date(),
                level: consoleLevel,
                message: messageText
            )
            onConsoleMessage(consoleMessage)
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    HybridSimulationView(
        reactCode: "",
        device: .iPhone15,
        colorScheme: .light
    )
    .frame(width: 600, height: 800)
}
