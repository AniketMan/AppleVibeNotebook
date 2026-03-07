import Testing
import Foundation
@testable import React2SwiftUI

@Suite("Figma Parser Tests")
struct FigmaParserTests {

    @Test("Parse Untitled.fig file")
    func testParseUntitledFigFile() async throws {
        let figPath = "/Users/aniketbhatt/Downloads/Untitled.fig"
        let url = URL(fileURLWithPath: figPath)

        guard FileManager.default.fileExists(atPath: figPath) else {
            print("⚠️ Test file not found at: \(figPath)")
            return
        }

        let parser = FigmaFileParser()
        let document = try await parser.parse(fileURL: url)

        print("📄 Document: \(document.fileName)")
        print("📊 Pages: \(document.pages.count)")
        print("🖼️ Has thumbnail: \(document.thumbnail != nil)")

        if let bg = document.metadata.backgroundColor {
            print("🎨 Background: r=\(bg.r), g=\(bg.g), b=\(bg.b)")
        }

        for page in document.pages {
            print("\n📃 Page: \(page.name)")
            print("   Layers: \(page.children.count)")

            for (index, node) in page.children.prefix(20).enumerated() {
                print("   [\(index)] \(node.type.rawValue): \(node.name)")
            }

            if page.children.count > 20 {
                print("   ... and \(page.children.count - 20) more")
            }
        }

        #expect(document.pages.count > 0, "Should have at least one page")
        #expect(!document.fileName.isEmpty, "Should have a file name")
    }
}
