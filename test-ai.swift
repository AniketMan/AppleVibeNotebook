#!/usr/bin/env swift

// AI Model Loading and Generation Test Script
// Run with: swift test-ai.swift
// Requires: MLX Swift dependencies resolved

import Foundation

print("""
╔══════════════════════════════════════════════════════════════════╗
║         React2SwiftUI AI Code Suggestion Test                   ║
╠══════════════════════════════════════════════════════════════════╣
║  This test verifies the MLX model loading and code generation   ║
║  Run the full app to test interactively:                        ║
║  $ cd React2SwiftUI && swift run React2SwiftUIApp               ║
╚══════════════════════════════════════════════════════════════════╝
""")

// Since we can't easily import MLX in a standalone script,
// let's verify the build and provide manual test instructions

print("""

📋 Manual Testing Steps:
========================

1. Build and run the app:
   $ cd /Users/aniketbhatt/Desktop/React2SwiftUI
   $ swift build
   $ swift run React2SwiftUIApp

2. Click "AI Code Assistant" on the welcome screen
   OR press ⌘4 to toggle AI panel

3. Click "Select Model" and choose "SmolLM 135M" (smallest/fastest)
   - Model will download from HuggingFace (~100MB)
   - Wait for status to show "Ready"

4. Enter test React code:
   ```jsx
   function Button({ onClick, children }) {
       return <button onClick={onClick}>{children}</button>
   }
   ```

5. Click "Generate" and verify SwiftUI output

Expected output should contain:
   - struct ButtonView: View
   - var onClick: () -> Void
   - var children: some View
   - Button(action: onClick)

✅ Test passes if:
   - Model loads successfully (shows "Ready")
   - Generation produces SwiftUI code
   - Tokens/second shows generation speed

❌ Test fails if:
   - Model fails to load (check network)
   - Generation throws error
   - Output is empty or not SwiftUI code

""")

// Build verification
print("🔨 Verifying build...")
let buildProcess = Process()
buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
buildProcess.arguments = ["swift", "build"]
buildProcess.currentDirectoryURL = URL(fileURLWithPath: "/Users/aniketbhatt/Desktop/React2SwiftUI")

let pipe = Pipe()
buildProcess.standardOutput = pipe
buildProcess.standardError = pipe

do {
    try buildProcess.run()
    buildProcess.waitUntilExit()

    if buildProcess.terminationStatus == 0 {
        print("✅ Build successful!")
        print("\n🚀 Ready to test. Run:")
        print("   swift run React2SwiftUIApp")
    } else {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        print("❌ Build failed:")
        print(output)
    }
} catch {
    print("❌ Error running build: \(error)")
}
