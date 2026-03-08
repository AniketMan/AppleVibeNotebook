import Foundation

public struct ExportOptions: Codable, Sendable {
    public var target: ExportTarget
    public var includeAssets: Bool
    public var generatePackageManifest: Bool
    public var organizationName: String
    public var bundleIdentifier: String
    public var minimumDeploymentTarget: String
    public var includeTests: Bool
    public var includePreview: Bool
    public var codeStyle: CodeStyle

    public init(
        target: ExportTarget = .pureSwift,
        includeAssets: Bool = true,
        generatePackageManifest: Bool = true,
        organizationName: String = "MyOrg",
        bundleIdentifier: String = "com.myorg.app",
        minimumDeploymentTarget: String = "17.0",
        includeTests: Bool = true,
        includePreview: Bool = true,
        codeStyle: CodeStyle = .modern
    ) {
        self.target = target
        self.includeAssets = includeAssets
        self.generatePackageManifest = generatePackageManifest
        self.organizationName = organizationName
        self.bundleIdentifier = bundleIdentifier
        self.minimumDeploymentTarget = minimumDeploymentTarget
        self.includeTests = includeTests
        self.includePreview = includePreview
        self.codeStyle = codeStyle
    }
}

public enum ExportTarget: String, Codable, Sendable, CaseIterable {
    case pureSwift = "Pure Swift"
    case pureReact = "Pure React"
    case hybrid = "Hybrid (Swift + React)"
    case xcodeProject = "Xcode Project"
    case reactNative = "React Native"

    public var description: String {
        switch self {
        case .pureSwift: return "SwiftUI app with native components"
        case .pureReact: return "React app with JSX/TSX components"
        case .hybrid: return "SwiftUI app with WKWebView React components"
        case .xcodeProject: return "Full Xcode project with build settings"
        case .reactNative: return "React Native cross-platform app"
        }
    }
}

public enum CodeStyle: String, Codable, Sendable {
    case modern
    case classic
    case minimal
}

public struct ExportedProject: Sendable {
    public let name: String
    public let files: [ExportedFile]
    public let target: ExportTarget
    public let createdAt: Date

    public init(name: String, files: [ExportedFile], target: ExportTarget) {
        self.name = name
        self.files = files
        self.target = target
        self.createdAt = Date()
    }

    public var totalSize: Int {
        files.reduce(0) { $0 + $1.content.utf8.count }
    }
}

public struct ExportedFile: Sendable {
    public let path: String
    public let content: String
    public let fileType: FileType

    public enum FileType: String, Sendable {
        case swift
        case typescript
        case javascript
        case json
        case markdown
        case yaml
        case html
        case css
        case asset
    }

    public init(path: String, content: String, fileType: FileType) {
        self.path = path
        self.content = content
        self.fileType = fileType
    }
}

public actor ProjectExporter {
    private let options: ExportOptions

    public init(options: ExportOptions = ExportOptions()) {
        self.options = options
    }

    public func export(
        document: CanvasDocument,
        projectName: String
    ) async throws -> ExportedProject {

        switch options.target {
        case .pureSwift:
            return try await exportPureSwift(document: document, projectName: projectName)
        case .pureReact:
            return try await exportPureReact(document: document, projectName: projectName)
        case .hybrid:
            return try await exportHybrid(document: document, projectName: projectName)
        case .xcodeProject:
            return try await exportXcodeProject(document: document, projectName: projectName)
        case .reactNative:
            return try await exportReactNative(document: document, projectName: projectName)
        }
    }

    private func exportPureSwift(document: CanvasDocument, projectName: String) async throws -> ExportedProject {
        var files: [ExportedFile] = []

        let appFile = generateSwiftApp(projectName: projectName)
        files.append(ExportedFile(path: "\(projectName)/\(projectName)App.swift", content: appFile, fileType: .swift))

        let contentView = generateSwiftContentView(document: document)
        files.append(ExportedFile(path: "\(projectName)/ContentView.swift", content: contentView, fileType: .swift))

        for layer in document.layers where layer.layerType == .component {
            let componentCode = generateSwiftComponent(layer: layer)
            files.append(ExportedFile(
                path: "\(projectName)/Components/\(layer.name.sanitizedFileName).swift",
                content: componentCode,
                fileType: .swift
            ))
        }

        if options.generatePackageManifest {
            let packageManifest = generatePackageManifest(projectName: projectName)
            files.append(ExportedFile(path: "\(projectName)/Package.swift", content: packageManifest, fileType: .swift))
        }

        let readme = generateReadme(projectName: projectName, target: .pureSwift)
        files.append(ExportedFile(path: "\(projectName)/README.md", content: readme, fileType: .markdown))

        if options.includeTests {
            let tests = generateSwiftTests(projectName: projectName)
            files.append(ExportedFile(path: "\(projectName)/Tests/\(projectName)Tests.swift", content: tests, fileType: .swift))
        }

        return ExportedProject(name: projectName, files: files, target: .pureSwift)
    }

    private func exportPureReact(document: CanvasDocument, projectName: String) async throws -> ExportedProject {
        var files: [ExportedFile] = []

        let packageJson = generatePackageJson(projectName: projectName)
        files.append(ExportedFile(path: "\(projectName)/package.json", content: packageJson, fileType: .json))

        let appTsx = generateReactApp(document: document)
        files.append(ExportedFile(path: "\(projectName)/src/App.tsx", content: appTsx, fileType: .typescript))

        let indexTsx = generateReactIndex()
        files.append(ExportedFile(path: "\(projectName)/src/index.tsx", content: indexTsx, fileType: .typescript))

        for layer in document.layers where layer.layerType == .component {
            let componentCode = generateReactComponent(layer: layer)
            files.append(ExportedFile(
                path: "\(projectName)/src/components/\(layer.name.sanitizedFileName).tsx",
                content: componentCode,
                fileType: .typescript
            ))
        }

        let styles = generateTailwindStyles(document: document)
        files.append(ExportedFile(path: "\(projectName)/src/styles/globals.css", content: styles, fileType: .css))

        let tsconfig = generateTsConfig()
        files.append(ExportedFile(path: "\(projectName)/tsconfig.json", content: tsconfig, fileType: .json))

        let readme = generateReadme(projectName: projectName, target: .pureReact)
        files.append(ExportedFile(path: "\(projectName)/README.md", content: readme, fileType: .markdown))

        return ExportedProject(name: projectName, files: files, target: .pureReact)
    }

    private func exportHybrid(document: CanvasDocument, projectName: String) async throws -> ExportedProject {
        var files: [ExportedFile] = []

        let appFile = generateSwiftApp(projectName: projectName)
        files.append(ExportedFile(path: "\(projectName)/\(projectName)App.swift", content: appFile, fileType: .swift))

        let webViewWrapper = generateWebViewWrapper()
        files.append(ExportedFile(path: "\(projectName)/WebView/ReactWebView.swift", content: webViewWrapper, fileType: .swift))

        let bridgeCode = generateBridgeCode()
        files.append(ExportedFile(path: "\(projectName)/Bridge/NativeBridge.swift", content: bridgeCode, fileType: .swift))

        let reactBundle = generateReactBundle(document: document)
        files.append(ExportedFile(path: "\(projectName)/Resources/react-app.html", content: reactBundle, fileType: .html))

        let readme = generateReadme(projectName: projectName, target: .hybrid)
        files.append(ExportedFile(path: "\(projectName)/README.md", content: readme, fileType: .markdown))

        return ExportedProject(name: projectName, files: files, target: .hybrid)
    }

    private func exportXcodeProject(document: CanvasDocument, projectName: String) async throws -> ExportedProject {
        var files: [ExportedFile] = []

        let swiftProject = try await exportPureSwift(document: document, projectName: projectName)
        files.append(contentsOf: swiftProject.files)

        let pbxproj = generatePbxproj(projectName: projectName, files: swiftProject.files)
        files.append(ExportedFile(path: "\(projectName).xcodeproj/project.pbxproj", content: pbxproj, fileType: .swift))

        let infoPlist = generateInfoPlist(projectName: projectName)
        files.append(ExportedFile(path: "\(projectName)/Info.plist", content: infoPlist, fileType: .swift))

        let assetsContents = generateAssetCatalog()
        files.append(ExportedFile(path: "\(projectName)/Assets.xcassets/Contents.json", content: assetsContents, fileType: .json))

        return ExportedProject(name: projectName, files: files, target: .xcodeProject)
    }

    private func exportReactNative(document: CanvasDocument, projectName: String) async throws -> ExportedProject {
        var files: [ExportedFile] = []

        let packageJson = generateReactNativePackageJson(projectName: projectName)
        files.append(ExportedFile(path: "\(projectName)/package.json", content: packageJson, fileType: .json))

        let appTsx = generateReactNativeApp(document: document)
        files.append(ExportedFile(path: "\(projectName)/App.tsx", content: appTsx, fileType: .typescript))

        for layer in document.layers where layer.layerType == .component {
            let componentCode = generateReactNativeComponent(layer: layer)
            files.append(ExportedFile(
                path: "\(projectName)/src/components/\(layer.name.sanitizedFileName).tsx",
                content: componentCode,
                fileType: .typescript
            ))
        }

        let readme = generateReadme(projectName: projectName, target: .reactNative)
        files.append(ExportedFile(path: "\(projectName)/README.md", content: readme, fileType: .markdown))

        return ExportedProject(name: projectName, files: files, target: .reactNative)
    }

    private func generateSwiftApp(projectName: String) -> String {
        """
        import SwiftUI

        @main
        struct \(projectName.sanitizedIdentifier)App: App {
            var body: some Scene {
                WindowGroup {
                    ContentView()
                }
            }
        }
        """
    }

    private func generateSwiftContentView(document: CanvasDocument) -> String {
        var code = """
        import SwiftUI

        struct ContentView: View {
            var body: some View {

        """

        code += generateSwiftViewHierarchy(layers: document.layers, indent: 8)

        code += """
            }
        }

        #Preview {
            ContentView()
        }
        """

        return code
    }

    private func generateSwiftViewHierarchy(layers: [CanvasLayer], indent: Int) -> String {
        let indentStr = String(repeating: " ", count: indent)
        var code = ""

        let visibleLayers = layers.filter { $0.isVisible }

        if visibleLayers.count == 1, let layer = visibleLayers.first {
            code += indentStr + generateSwiftView(for: layer) + "\n"
        } else {
            code += indentStr + "ZStack {\n"
            for layer in visibleLayers.sorted(by: { $0.zIndex < $1.zIndex }) {
                code += String(repeating: " ", count: indent + 4) + generateSwiftView(for: layer) + "\n"
            }
            code += indentStr + "}\n"
        }

        return code
    }

    private func generateSwiftView(for layer: CanvasLayer) -> String {
        switch layer.layerType {
        case .text:
            return "Text(\"\(layer.name)\")"
        case .image:
            return "Image(systemName: \"photo\")"
        case .shape:
            if let cornerRadius = layer.borderConfig?.cornerRadius, cornerRadius > 0 {
                return "RoundedRectangle(cornerRadius: \(cornerRadius))"
            } else {
                return "Rectangle()"
            }
        case .container:
            return "VStack { /* \(layer.name) content */ }"
        default:
            return "EmptyView() // \(layer.name)"
        }
    }

    private func generateSwiftComponent(layer: CanvasLayer) -> String {
        """
        import SwiftUI

        struct \(layer.name.sanitizedIdentifier): View {
            var body: some View {
                \(generateSwiftView(for: layer))
                    .frame(width: \(layer.frame.size.width), height: \(layer.frame.size.height))
            }
        }

        #Preview {
            \(layer.name.sanitizedIdentifier)()
        }
        """
    }

    private func generatePackageManifest(projectName: String) -> String {
        """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "\(projectName)",
            platforms: [
                .iOS(.v\(options.minimumDeploymentTarget.replacingOccurrences(of: ".", with: "_"))),
                .macOS(.v14)
            ],
            products: [
                .library(name: "\(projectName)", targets: ["\(projectName)"])
            ],
            targets: [
                .target(name: "\(projectName)"),
                .testTarget(name: "\(projectName)Tests", dependencies: ["\(projectName)"])
            ]
        )
        """
    }

    private func generateSwiftTests(projectName: String) -> String {
        """
        import XCTest
        @testable import \(projectName.sanitizedIdentifier)

        final class \(projectName.sanitizedIdentifier)Tests: XCTestCase {
            func testContentViewExists() {
                let contentView = ContentView()
                XCTAssertNotNil(contentView)
            }
        }
        """
    }

    private func generatePackageJson(projectName: String) -> String {
        """
        {
          "name": "\(projectName.lowercased())",
          "version": "1.0.0",
          "private": true,
          "scripts": {
            "dev": "next dev",
            "build": "next build",
            "start": "next start",
            "lint": "next lint"
          },
          "dependencies": {
            "react": "^18",
            "react-dom": "^18",
            "next": "14"
          },
          "devDependencies": {
            "typescript": "^5",
            "@types/node": "^20",
            "@types/react": "^18",
            "@types/react-dom": "^18",
            "tailwindcss": "^3",
            "autoprefixer": "^10",
            "postcss": "^8"
          }
        }
        """
    }

    private func generateReactApp(document: CanvasDocument) -> String {
        var code = """
        import React from 'react';

        export default function App() {
          return (
            <div className="min-h-screen bg-white">

        """

        for layer in document.layers.filter({ $0.isVisible }).sorted(by: { $0.zIndex < $1.zIndex }) {
            code += "      " + generateReactElement(for: layer) + "\n"
        }

        code += """
            </div>
          );
        }
        """

        return code
    }

    private func generateReactElement(for layer: CanvasLayer) -> String {
        let style = generateInlineStyle(for: layer)

        switch layer.layerType {
        case .text:
            return "<p style={{\(style)}}>\(layer.name)</p>"
        case .image:
            return "<img src=\"/placeholder.png\" alt=\"\(layer.name)\" style={{\(style)}} />"
        case .shape:
            return "<div style={{\(style)}} />"
        case .container:
            return "<div style={{\(style)}}>{/* \(layer.name) content */}</div>"
        default:
            return "{/* \(layer.name) */}"
        }
    }

    private func generateInlineStyle(for layer: CanvasLayer) -> String {
        var styles: [String] = []
        styles.append("position: 'absolute'")
        styles.append("left: \(Int(layer.frame.origin.x))")
        styles.append("top: \(Int(layer.frame.origin.y))")
        styles.append("width: \(Int(layer.frame.size.width))")
        styles.append("height: \(Int(layer.frame.size.height))")

        if let cornerRadius = layer.borderConfig?.cornerRadius, cornerRadius > 0 {
            styles.append("borderRadius: \(Int(cornerRadius))")
        }

        if let fill = layer.backgroundFill?.color {
            styles.append("backgroundColor: '\(fill.cssColor)'")
        }

        return styles.joined(separator: ", ")
    }

    private func generateReactIndex() -> String {
        """
        import React from 'react';
        import ReactDOM from 'react-dom/client';
        import App from './App';
        import './styles/globals.css';

        const root = ReactDOM.createRoot(
          document.getElementById('root') as HTMLElement
        );
        root.render(
          <React.StrictMode>
            <App />
          </React.StrictMode>
        );
        """
    }

    private func generateReactComponent(layer: CanvasLayer) -> String {
        """
        import React from 'react';

        interface \(layer.name.sanitizedIdentifier)Props {
          className?: string;
        }

        export default function \(layer.name.sanitizedIdentifier)({ className }: \(layer.name.sanitizedIdentifier)Props) {
          return (
            <div className={className}>
              {/* \(layer.name) component */}
            </div>
          );
        }
        """
    }

    private func generateTailwindStyles(document: CanvasDocument) -> String {
        """
        @tailwind base;
        @tailwind components;
        @tailwind utilities;

        :root {
          --foreground-rgb: 0, 0, 0;
          --background-rgb: 255, 255, 255;
        }

        body {
          color: rgb(var(--foreground-rgb));
          background: rgb(var(--background-rgb));
        }
        """
    }

    private func generateTsConfig() -> String {
        """
        {
          "compilerOptions": {
            "target": "es5",
            "lib": ["dom", "dom.iterable", "esnext"],
            "allowJs": true,
            "skipLibCheck": true,
            "strict": true,
            "noEmit": true,
            "esModuleInterop": true,
            "module": "esnext",
            "moduleResolution": "bundler",
            "resolveJsonModule": true,
            "isolatedModules": true,
            "jsx": "preserve",
            "incremental": true
          },
          "include": ["**/*.ts", "**/*.tsx"],
          "exclude": ["node_modules"]
        }
        """
    }

    private func generateWebViewWrapper() -> String {
        """
        import SwiftUI
        import WebKit

        struct ReactWebView: UIViewRepresentable {
            let htmlContent: String

            func makeUIView(context: Context) -> WKWebView {
                let config = WKWebViewConfiguration()
                config.userContentController.add(context.coordinator, name: "nativeBridge")

                let webView = WKWebView(frame: .zero, configuration: config)
                webView.loadHTMLString(htmlContent, baseURL: nil)
                return webView
            }

            func updateUIView(_ webView: WKWebView, context: Context) {}

            func makeCoordinator() -> Coordinator {
                Coordinator()
            }

            class Coordinator: NSObject, WKScriptMessageHandler {
                func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
                    if let body = message.body as? [String: Any] {
                        handleMessage(body)
                    }
                }

                private func handleMessage(_ message: [String: Any]) {
                    guard let action = message["action"] as? String else { return }
                    print("Received action: \\(action)")
                }
            }
        }
        """
    }

    private func generateBridgeCode() -> String {
        """
        import Foundation

        struct NativeBridge {
            static func sendToReact(_ message: [String: Any]) -> String {
                guard let data = try? JSONSerialization.data(withJSONObject: message),
                      let json = String(data: data, encoding: .utf8) else {
                    return "{}"
                }
                return "window.receiveFromNative(\\(json));"
            }
        }
        """
    }

    private func generateReactBundle(document: CanvasDocument) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
            <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
            <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
            </style>
        </head>
        <body>
            <div id="root"></div>
            <script type="text/babel">
                function App() {
                    return (
                        <div style={{ minHeight: '100vh', backgroundColor: 'white' }}>
                            {/* Generated content */}
                        </div>
                    );
                }

                ReactDOM.createRoot(document.getElementById('root')).render(<App />);
            </script>
        </body>
        </html>
        """
    }

    private func generateReactNativePackageJson(projectName: String) -> String {
        """
        {
          "name": "\(projectName.lowercased())",
          "version": "1.0.0",
          "main": "index.js",
          "scripts": {
            "android": "react-native run-android",
            "ios": "react-native run-ios",
            "start": "react-native start"
          },
          "dependencies": {
            "react": "18.2.0",
            "react-native": "0.73.0"
          },
          "devDependencies": {
            "@types/react": "^18",
            "typescript": "5.0.4"
          }
        }
        """
    }

    private func generateReactNativeApp(document: CanvasDocument) -> String {
        """
        import React from 'react';
        import { View, StyleSheet } from 'react-native';

        export default function App() {
          return (
            <View style={styles.container}>
              {/* Generated content */}
            </View>
          );
        }

        const styles = StyleSheet.create({
          container: {
            flex: 1,
            backgroundColor: '#fff',
          },
        });
        """
    }

    private func generateReactNativeComponent(layer: CanvasLayer) -> String {
        """
        import React from 'react';
        import { View, StyleSheet } from 'react-native';

        interface \(layer.name.sanitizedIdentifier)Props {}

        export default function \(layer.name.sanitizedIdentifier)({}: \(layer.name.sanitizedIdentifier)Props) {
          return (
            <View style={styles.container}>
              {/* \(layer.name) content */}
            </View>
          );
        }

        const styles = StyleSheet.create({
          container: {},
        });
        """
    }

    private func generatePbxproj(projectName: String, files: [ExportedFile]) -> String {
        "// Xcode project placeholder - full pbxproj generation requires complex UUID management"
    }

    private func generateInfoPlist(projectName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDevelopmentRegion</key>
            <string>$(DEVELOPMENT_LANGUAGE)</string>
            <key>CFBundleExecutable</key>
            <string>$(EXECUTABLE_NAME)</string>
            <key>CFBundleIdentifier</key>
            <string>\(options.bundleIdentifier)</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>CFBundleName</key>
            <string>\(projectName)</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>LSRequiresIPhoneOS</key>
            <true/>
            <key>UILaunchStoryboardName</key>
            <string>LaunchScreen</string>
            <key>UIRequiredDeviceCapabilities</key>
            <array>
                <string>armv7</string>
            </array>
            <key>UISupportedInterfaceOrientations</key>
            <array>
                <string>UIInterfaceOrientationPortrait</string>
            </array>
        </dict>
        </plist>
        """
    }

    private func generateAssetCatalog() -> String {
        """
        {
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }

    private func generateReadme(projectName: String, target: ExportTarget) -> String {
        """
        # \(projectName)

        Generated by CanvasCode

        ## Target: \(target.rawValue)

        \(target.description)

        ## Getting Started

        \(getStartedInstructions(for: target))

        ## Structure

        \(structureDescription(for: target))

        ---
        Generated on \(Date().formatted())
        """
    }

    private func getStartedInstructions(for target: ExportTarget) -> String {
        switch target {
        case .pureSwift:
            return "Open the project in Xcode and run on your target device or simulator."
        case .pureReact:
            return """
            ```bash
            npm install
            npm run dev
            ```
            """
        case .hybrid:
            return "Open the project in Xcode. The React components are bundled in Resources."
        case .xcodeProject:
            return "Open `\(options.bundleIdentifier).xcodeproj` in Xcode."
        case .reactNative:
            return """
            ```bash
            npm install
            npx react-native run-ios  # or run-android
            ```
            """
        }
    }

    private func structureDescription(for target: ExportTarget) -> String {
        switch target {
        case .pureSwift:
            return "SwiftUI views organized by feature with shared components."
        case .pureReact:
            return "React components in `src/components/` with Tailwind CSS styling."
        case .hybrid:
            return "SwiftUI wrapper with WKWebView hosting React components."
        case .xcodeProject:
            return "Standard Xcode project structure with targets for iOS and macOS."
        case .reactNative:
            return "Cross-platform React Native project for iOS and Android."
        }
    }
}

extension String {
    var sanitizedFileName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
    }

    var sanitizedIdentifier: String {
        let cleaned = sanitizedFileName
        if cleaned.isEmpty { return "Component" }
        let first = cleaned.prefix(1).uppercased()
        let rest = cleaned.dropFirst()
        return first + rest
    }
}

extension CanvasColor {
    var cssColor: String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        if alpha < 1 {
            return "rgba(\(r), \(g), \(b), \(alpha))"
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
