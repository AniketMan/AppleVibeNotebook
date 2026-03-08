import Foundation

public struct XcodeProject: Sendable {
    public let name: String
    public let files: [XcodeFile]
    public let targetPlatforms: [Platform]
    public let deploymentTarget: String
    public let bundleIdentifier: String

    public enum Platform: String, Sendable {
        case iOS, macOS, visionOS, watchOS, tvOS
    }
}

public struct XcodeFile: Sendable {
    public let path: String
    public let content: String
    public let fileType: FileType

    public enum FileType: String, Sendable {
        case swift, plist, xcconfig, pbxproj, xcworkspace, asset, storyboard
    }
}

public actor XcodeProjectGenerator {
    private let organizationName: String
    private let bundleIdentifierPrefix: String

    public init(
        organizationName: String = "MyOrg",
        bundleIdentifierPrefix: String = "com.myorg"
    ) {
        self.organizationName = organizationName
        self.bundleIdentifierPrefix = bundleIdentifierPrefix
    }

    public func generate(
        from document: CanvasDocument,
        projectName: String,
        platforms: [XcodeProject.Platform] = [.iOS]
    ) async throws -> XcodeProject {
        var files: [XcodeFile] = []

        let compiler = CanvasToIRCompiler()
        let ir = compiler.compile(document)

        let codeGenerator = SwiftSyntaxCodeGenerator()
        let generatedFiles = codeGenerator.generate(from: ir)

        for file in generatedFiles {
            files.append(XcodeFile(
                path: "\(projectName)/\(file.path)",
                content: file.content,
                fileType: .swift
            ))
        }

        files.append(XcodeFile(
            path: "\(projectName)/\(projectName)App.swift",
            content: generateAppFile(projectName: projectName),
            fileType: .swift
        ))

        files.append(XcodeFile(
            path: "\(projectName)/Info.plist",
            content: generateInfoPlist(projectName: projectName),
            fileType: .plist
        ))

        files.append(XcodeFile(
            path: "\(projectName)/Assets.xcassets/Contents.json",
            content: generateAssetCatalogContents(),
            fileType: .asset
        ))

        files.append(XcodeFile(
            path: "\(projectName)/Assets.xcassets/AppIcon.appiconset/Contents.json",
            content: generateAppIconContents(),
            fileType: .asset
        ))

        files.append(XcodeFile(
            path: "\(projectName)/Assets.xcassets/AccentColor.colorset/Contents.json",
            content: generateAccentColorContents(),
            fileType: .asset
        ))

        let pbxproj = generatePbxproj(
            projectName: projectName,
            files: files,
            platforms: platforms
        )
        files.append(XcodeFile(
            path: "\(projectName).xcodeproj/project.pbxproj",
            content: pbxproj,
            fileType: .pbxproj
        ))

        files.append(XcodeFile(
            path: "\(projectName).xcodeproj/project.xcworkspace/contents.xcworkspacedata",
            content: generateWorkspaceContents(projectName: projectName),
            fileType: .xcworkspace
        ))

        return XcodeProject(
            name: projectName,
            files: files,
            targetPlatforms: platforms,
            deploymentTarget: "17.0",
            bundleIdentifier: "\(bundleIdentifierPrefix).\(projectName.lowercased())"
        )
    }

    public func writeToDirectory(_ project: XcodeProject, at baseURL: URL) async throws {
        let fileManager = FileManager.default

        for file in project.files {
            let fileURL = baseURL.appendingPathComponent(file.path)
            let directoryURL = fileURL.deletingLastPathComponent()

            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try file.content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    public func openInXcode(_ project: XcodeProject, at baseURL: URL) async throws {
        let projectURL = baseURL.appendingPathComponent("\(project.name).xcodeproj")

        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [projectURL.path]
        try process.run()
        process.waitUntilExit()
        #endif
    }

    private func generateAppFile(projectName: String) -> String {
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

    private func generateInfoPlist(projectName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDevelopmentRegion</key>
            <string>$(DEVELOPMENT_LANGUAGE)</string>
            <key>CFBundleDisplayName</key>
            <string>\(projectName)</string>
            <key>CFBundleExecutable</key>
            <string>$(EXECUTABLE_NAME)</string>
            <key>CFBundleIdentifier</key>
            <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>CFBundleName</key>
            <string>$(PRODUCT_NAME)</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>LSRequiresIPhoneOS</key>
            <true/>
            <key>UIApplicationSceneManifest</key>
            <dict>
                <key>UIApplicationSupportsMultipleScenes</key>
                <true/>
            </dict>
            <key>UILaunchScreen</key>
            <dict/>
            <key>UIRequiredDeviceCapabilities</key>
            <array>
                <string>arm64</string>
            </array>
            <key>UISupportedInterfaceOrientations</key>
            <array>
                <string>UIInterfaceOrientationPortrait</string>
                <string>UIInterfaceOrientationLandscapeLeft</string>
                <string>UIInterfaceOrientationLandscapeRight</string>
            </array>
            <key>UISupportedInterfaceOrientations~ipad</key>
            <array>
                <string>UIInterfaceOrientationPortrait</string>
                <string>UIInterfaceOrientationPortraitUpsideDown</string>
                <string>UIInterfaceOrientationLandscapeLeft</string>
                <string>UIInterfaceOrientationLandscapeRight</string>
            </array>
        </dict>
        </plist>
        """
    }

    private func generateAssetCatalogContents() -> String {
        """
        {
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }

    private func generateAppIconContents() -> String {
        """
        {
          "images" : [
            {
              "idiom" : "universal",
              "platform" : "ios",
              "size" : "1024x1024"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }

    private func generateAccentColorContents() -> String {
        """
        {
          "colors" : [
            {
              "color" : {
                "color-space" : "srgb",
                "components" : {
                  "alpha" : "1.000",
                  "blue" : "1.000",
                  "green" : "0.478",
                  "red" : "0.000"
                }
              },
              "idiom" : "universal"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }

    private func generateWorkspaceContents(projectName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Workspace
           version = "1.0">
           <FileRef
              location = "self:">
           </FileRef>
        </Workspace>
        """
    }

    private func generatePbxproj(
        projectName: String,
        files: [XcodeFile],
        platforms: [XcodeProject.Platform]
    ) -> String {
        let projectUUID = generateUUID()
        let mainGroupUUID = generateUUID()
        let productsGroupUUID = generateUUID()
        let targetUUID = generateUUID()
        let buildConfigListProjectUUID = generateUUID()
        let buildConfigListTargetUUID = generateUUID()
        let debugConfigProjectUUID = generateUUID()
        let releaseConfigProjectUUID = generateUUID()
        let debugConfigTargetUUID = generateUUID()
        let releaseConfigTargetUUID = generateUUID()
        let productRefUUID = generateUUID()
        let sourcesPhaseUUID = generateUUID()
        let resourcesPhaseUUID = generateUUID()
        let frameworksPhaseUUID = generateUUID()

        var fileRefSection = ""
        var buildFileSection = ""
        var sourcesBuildFiles = ""
        var resourcesBuildFiles = ""
        var childrenRefs: [String] = []

        let swiftFiles = files.filter { $0.fileType == .swift }
        for file in swiftFiles {
            let fileRefUUID = generateUUID()
            let buildFileUUID = generateUUID()
            let fileName = URL(fileURLWithPath: file.path).lastPathComponent

            fileRefSection += "\t\t\(fileRefUUID) /* \(fileName) */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"\(fileName)\"; sourceTree = \"<group>\"; };\n"
            buildFileSection += "\t\t\(buildFileUUID) /* \(fileName) in Sources */ = {isa = PBXBuildFile; fileRef = \(fileRefUUID) /* \(fileName) */; };\n"
            sourcesBuildFiles += "\t\t\t\t\(buildFileUUID) /* \(fileName) in Sources */,\n"
            childrenRefs.append("\(fileRefUUID) /* \(fileName) */")
        }

        let assetFiles = files.filter { $0.path.contains("Assets.xcassets") }
        if !assetFiles.isEmpty {
            let assetsRefUUID = generateUUID()
            let assetsBuildUUID = generateUUID()
            fileRefSection += "\t\t\(assetsRefUUID) /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; };\n"
            buildFileSection += "\t\t\(assetsBuildUUID) /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = \(assetsRefUUID) /* Assets.xcassets */; };\n"
            resourcesBuildFiles += "\t\t\t\t\(assetsBuildUUID) /* Assets.xcassets in Resources */,\n"
            childrenRefs.append("\(assetsRefUUID) /* Assets.xcassets */")
        }

        let childrenList = childrenRefs.map { "\t\t\t\t\($0)," }.joined(separator: "\n")

        return """
        // !$*UTF8*$!
        {
            archiveVersion = 1;
            classes = {
            };
            objectVersion = 56;
            objects = {

        /* Begin PBXBuildFile section */
        \(buildFileSection)/* End PBXBuildFile section */

        /* Begin PBXFileReference section */
        \(fileRefSection)\t\t\(productRefUUID) /* \(projectName).app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "\(projectName).app"; sourceTree = BUILT_PRODUCTS_DIR; };
        /* End PBXFileReference section */

        /* Begin PBXFrameworksBuildPhase section */
                \(frameworksPhaseUUID) /* Frameworks */ = {
                    isa = PBXFrameworksBuildPhase;
                    buildActionMask = 2147483647;
                    files = (
                    );
                    runOnlyForDeploymentPostprocessing = 0;
                };
        /* End PBXFrameworksBuildPhase section */

        /* Begin PBXGroup section */
                \(mainGroupUUID) = {
                    isa = PBXGroup;
                    children = (
        \(childrenList)
                        \(productsGroupUUID) /* Products */,
                    );
                    sourceTree = "<group>";
                };
                \(productsGroupUUID) /* Products */ = {
                    isa = PBXGroup;
                    children = (
                        \(productRefUUID) /* \(projectName).app */,
                    );
                    name = Products;
                    sourceTree = "<group>";
                };
        /* End PBXGroup section */

        /* Begin PBXNativeTarget section */
                \(targetUUID) /* \(projectName) */ = {
                    isa = PBXNativeTarget;
                    buildConfigurationList = \(buildConfigListTargetUUID) /* Build configuration list for PBXNativeTarget "\(projectName)" */;
                    buildPhases = (
                        \(sourcesPhaseUUID) /* Sources */,
                        \(frameworksPhaseUUID) /* Frameworks */,
                        \(resourcesPhaseUUID) /* Resources */,
                    );
                    buildRules = (
                    );
                    dependencies = (
                    );
                    name = "\(projectName)";
                    productName = "\(projectName)";
                    productReference = \(productRefUUID) /* \(projectName).app */;
                    productType = "com.apple.product-type.application";
                };
        /* End PBXNativeTarget section */

        /* Begin PBXProject section */
                \(projectUUID) /* Project object */ = {
                    isa = PBXProject;
                    buildConfigurationList = \(buildConfigListProjectUUID) /* Build configuration list for PBXProject "\(projectName)" */;
                    compatibilityVersion = "Xcode 14.0";
                    developmentRegion = en;
                    hasScannedForEncodings = 0;
                    knownRegions = (
                        en,
                        Base,
                    );
                    mainGroup = \(mainGroupUUID);
                    productRefGroup = \(productsGroupUUID) /* Products */;
                    projectDirPath = "";
                    projectRoot = "";
                    targets = (
                        \(targetUUID) /* \(projectName) */,
                    );
                };
        /* End PBXProject section */

        /* Begin PBXResourcesBuildPhase section */
                \(resourcesPhaseUUID) /* Resources */ = {
                    isa = PBXResourcesBuildPhase;
                    buildActionMask = 2147483647;
                    files = (
        \(resourcesBuildFiles)            );
                    runOnlyForDeploymentPostprocessing = 0;
                };
        /* End PBXResourcesBuildPhase section */

        /* Begin PBXSourcesBuildPhase section */
                \(sourcesPhaseUUID) /* Sources */ = {
                    isa = PBXSourcesBuildPhase;
                    buildActionMask = 2147483647;
                    files = (
        \(sourcesBuildFiles)            );
                    runOnlyForDeploymentPostprocessing = 0;
                };
        /* End PBXSourcesBuildPhase section */

        /* Begin XCBuildConfiguration section */
                \(debugConfigProjectUUID) /* Debug */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        ALWAYS_SEARCH_USER_PATHS = NO;
                        CLANG_ANALYZER_NONNULL = YES;
                        CLANG_ENABLE_MODULES = YES;
                        CLANG_ENABLE_OBJC_ARC = YES;
                        COPY_PHASE_STRIP = NO;
                        DEBUG_INFORMATION_FORMAT = dwarf;
                        ENABLE_STRICT_OBJC_MSGSEND = YES;
                        ENABLE_TESTABILITY = YES;
                        GCC_DYNAMIC_NO_PIC = NO;
                        GCC_OPTIMIZATION_LEVEL = 0;
                        GCC_PREPROCESSOR_DEFINITIONS = (
                            "DEBUG=1",
                            "$(inherited)",
                        );
                        IPHONEOS_DEPLOYMENT_TARGET = 17.0;
                        MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
                        ONLY_ACTIVE_ARCH = YES;
                        SDKROOT = iphoneos;
                        SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
                        SWIFT_OPTIMIZATION_LEVEL = "-Onone";
                        SWIFT_VERSION = 5.0;
                    };
                    name = Debug;
                };
                \(releaseConfigProjectUUID) /* Release */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        ALWAYS_SEARCH_USER_PATHS = NO;
                        CLANG_ANALYZER_NONNULL = YES;
                        CLANG_ENABLE_MODULES = YES;
                        CLANG_ENABLE_OBJC_ARC = YES;
                        COPY_PHASE_STRIP = NO;
                        DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
                        ENABLE_NS_ASSERTIONS = NO;
                        ENABLE_STRICT_OBJC_MSGSEND = YES;
                        GCC_OPTIMIZATION_LEVEL = s;
                        IPHONEOS_DEPLOYMENT_TARGET = 17.0;
                        MTL_ENABLE_DEBUG_INFO = NO;
                        SDKROOT = iphoneos;
                        SWIFT_COMPILATION_MODE = wholemodule;
                        SWIFT_OPTIMIZATION_LEVEL = "-O";
                        SWIFT_VERSION = 5.0;
                        VALIDATE_PRODUCT = YES;
                    };
                    name = Release;
                };
                \(debugConfigTargetUUID) /* Debug */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
                        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
                        CODE_SIGN_STYLE = Automatic;
                        CURRENT_PROJECT_VERSION = 1;
                        DEVELOPMENT_TEAM = "";
                        ENABLE_PREVIEWS = YES;
                        GENERATE_INFOPLIST_FILE = YES;
                        INFOPLIST_FILE = "\(projectName)/Info.plist";
                        INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
                        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
                        INFOPLIST_KEY_UILaunchScreen_Generation = YES;
                        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
                        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
                        LD_RUNPATH_SEARCH_PATHS = (
                            "$(inherited)",
                            "@executable_path/Frameworks",
                        );
                        MARKETING_VERSION = 1.0;
                        PRODUCT_BUNDLE_IDENTIFIER = "\(bundleIdentifierPrefix).\(projectName.lowercased())";
                        PRODUCT_NAME = "$(TARGET_NAME)";
                        SWIFT_EMIT_LOC_STRINGS = YES;
                        SWIFT_VERSION = 5.0;
                        TARGETED_DEVICE_FAMILY = "1,2";
                    };
                    name = Debug;
                };
                \(releaseConfigTargetUUID) /* Release */ = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
                        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
                        CODE_SIGN_STYLE = Automatic;
                        CURRENT_PROJECT_VERSION = 1;
                        DEVELOPMENT_TEAM = "";
                        ENABLE_PREVIEWS = YES;
                        GENERATE_INFOPLIST_FILE = YES;
                        INFOPLIST_FILE = "\(projectName)/Info.plist";
                        INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
                        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
                        INFOPLIST_KEY_UILaunchScreen_Generation = YES;
                        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
                        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
                        LD_RUNPATH_SEARCH_PATHS = (
                            "$(inherited)",
                            "@executable_path/Frameworks",
                        );
                        MARKETING_VERSION = 1.0;
                        PRODUCT_BUNDLE_IDENTIFIER = "\(bundleIdentifierPrefix).\(projectName.lowercased())";
                        PRODUCT_NAME = "$(TARGET_NAME)";
                        SWIFT_EMIT_LOC_STRINGS = YES;
                        SWIFT_VERSION = 5.0;
                        TARGETED_DEVICE_FAMILY = "1,2";
                    };
                    name = Release;
                };
        /* End XCBuildConfiguration section */

        /* Begin XCConfigurationList section */
                \(buildConfigListProjectUUID) /* Build configuration list for PBXProject "\(projectName)" */ = {
                    isa = XCConfigurationList;
                    buildConfigurations = (
                        \(debugConfigProjectUUID) /* Debug */,
                        \(releaseConfigProjectUUID) /* Release */,
                    );
                    defaultConfigurationIsVisible = 0;
                    defaultConfigurationName = Release;
                };
                \(buildConfigListTargetUUID) /* Build configuration list for PBXNativeTarget "\(projectName)" */ = {
                    isa = XCConfigurationList;
                    buildConfigurations = (
                        \(debugConfigTargetUUID) /* Debug */,
                        \(releaseConfigTargetUUID) /* Release */,
                    );
                    defaultConfigurationIsVisible = 0;
                    defaultConfigurationName = Release;
                };
        /* End XCConfigurationList section */
            };
            rootObject = \(projectUUID) /* Project object */;
        }
        """
    }

    private func generateUUID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24).uppercased()
    }
}

import SwiftUI

public struct XcodeExportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let document: CanvasDocument

    @State private var projectName: String = "MyApp"
    @State private var organizationName: String = "MyOrg"
    @State private var bundleIdPrefix: String = "com.myorg"
    @State private var selectedPlatforms: Set<XcodeProject.Platform> = [.iOS]
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportSuccess = false

    public init(document: CanvasDocument) {
        self.document = document
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Project Info") {
                    TextField("Project Name", text: $projectName)
                    TextField("Organization", text: $organizationName)
                    TextField("Bundle ID Prefix", text: $bundleIdPrefix)
                }

                Section("Platforms") {
                    ForEach([XcodeProject.Platform.iOS, .macOS], id: \.self) { platform in
                        Toggle(platform.rawValue, isOn: Binding(
                            get: { selectedPlatforms.contains(platform) },
                            set: { isOn in
                                if isOn {
                                    selectedPlatforms.insert(platform)
                                } else {
                                    selectedPlatforms.remove(platform)
                                }
                            }
                        ))
                    }
                }

                if let error = exportError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        Task { await exportProject() }
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isExporting ? "Exporting..." : "Export & Open in Xcode")
                            Spacer()
                        }
                    }
                    .disabled(projectName.isEmpty || selectedPlatforms.isEmpty || isExporting)
                }
            }
            .navigationTitle("Export to Xcode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Export Successful", isPresented: $exportSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your Xcode project has been created and opened.")
            }
        }
        .presentationDetents([.medium])
    }

    private func exportProject() async {
        isExporting = true
        exportError = nil

        do {
            let generator = XcodeProjectGenerator(
                organizationName: organizationName,
                bundleIdentifierPrefix: bundleIdPrefix
            )

            let project = try await generator.generate(
                from: document,
                projectName: projectName,
                platforms: Array(selectedPlatforms)
            )

            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let projectURL = desktopURL.appendingPathComponent(projectName)

            try await generator.writeToDirectory(project, at: projectURL)
            try await generator.openInXcode(project, at: projectURL)

            exportSuccess = true
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }
}
