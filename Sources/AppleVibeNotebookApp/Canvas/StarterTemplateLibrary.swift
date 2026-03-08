import Foundation
import AppleVibeNotebook

public enum TemplatePlatform: String, CaseIterable, Codable, Sendable {
    case swiftUI = "SwiftUI"
    case uiKit = "UIKit"
    case react = "React"

    public var iconName: String {
        switch self {
        case .swiftUI: return "swift"
        case .uiKit: return "iphone"
        case .react: return "atom"
        }
    }
}

public struct StarterTemplate: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let platform: TemplatePlatform
    public let category: String
    public let description: String
    public let layers: [CanvasLayer]
    public let properties: [ConfigurableProperty]
    public let swiftCode: String
    public let reactCode: String

    public init(
        id: UUID = UUID(),
        name: String,
        platform: TemplatePlatform,
        category: String,
        description: String,
        layers: [CanvasLayer],
        properties: [ConfigurableProperty],
        swiftCode: String,
        reactCode: String
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.category = category
        self.description = description
        self.layers = layers
        self.properties = properties
        self.swiftCode = swiftCode
        self.reactCode = reactCode
    }
}

public final class StarterTemplateLibrary: @unchecked Sendable {
    public static let shared = StarterTemplateLibrary()

    public let templates: [StarterTemplate]

    private init() {
        self.templates = Self.buildTemplates()
    }

    public func templates(for platform: TemplatePlatform) -> [StarterTemplate] {
        templates.filter { $0.platform == platform }
    }

    public func templates(in category: String) -> [StarterTemplate] {
        templates.filter { $0.category == category }
    }

    public var categories: [String] {
        Array(Set(templates.map(\.category))).sorted()
    }

private static func buildTemplates() -> [StarterTemplate] {
        var templates: [StarterTemplate] = []

        // Helper to create CanvasFrame with convenience parameters
        func makeFrame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CanvasFrame {
            CanvasFrame(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
        }

        // Helper to create a simple layer
        func makeLayer(
            name: String,
            x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
            layerType: LayerType = .element,
            fillColor: CanvasColor? = nil,
            cornerRadius: CGFloat? = nil,
            shadow: ShadowConfig? = nil
        ) -> CanvasLayer {
            CanvasLayer(
                name: name,
                frame: makeFrame(x: x, y: y, width: width, height: height),
                layerType: layerType,
                borderConfig: cornerRadius.map { BorderConfig(cornerRadius: $0) },
                backgroundFill: fillColor.map { FillConfig(fillType: .solid, color: $0) }
            )
        }

        // MARK: - SwiftUI Templates

        templates.append(StarterTemplate(
            name: "Button",
            platform: .swiftUI,
            category: "Controls",
            description: "A standard button with customizable style",
            layers: [
                makeLayer(
                    name: "Button",
                    x: 0, y: 0, width: 120, height: 44,
                    layerType: .element,
                    fillColor: CanvasColor(red: 0, green: 0.48, blue: 1, alpha: 1),
                    cornerRadius: 10
                )
            ],
            properties: buttonProperties(),
            swiftCode: """
            Button(action: { }) {
                Text("Button")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            """,
            reactCode: """
            <button className="px-6 py-3 bg-blue-500 text-white font-semibold rounded-lg hover:bg-blue-600 transition-colors">
              Button
            </button>
            """
        ))

        templates.append(StarterTemplate(
            name: "NavigationStack",
            platform: .swiftUI,
            category: "Navigation",
            description: "A navigation container with title and content",
            layers: [
                makeLayer(
                    name: "NavigationBar",
                    x: 0, y: 0, width: 390, height: 96,
                    layerType: .container,
                    fillColor: CanvasColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)
                ),
                makeLayer(
                    name: "Content",
                    x: 0, y: 96, width: 390, height: 748,
                    layerType: .container
                )
            ],
            properties: navigationProperties(),
            swiftCode: """
            NavigationStack {
                List {
                    // Content
                }
                .navigationTitle("Title")
            }
            """,
            reactCode: """
            <div className="min-h-screen bg-white">
              <header className="bg-gray-100 px-4 py-6">
                <h1 className="text-2xl font-bold">Title</h1>
              </header>
              <main className="p-4">
                {/* Content */}
              </main>
            </div>
            """
        ))

        templates.append(StarterTemplate(
            name: "List",
            platform: .swiftUI,
            category: "Data Display",
            description: "A scrollable list of items",
            layers: listLayers(),
            properties: listProperties(),
            swiftCode: """
            List {
                ForEach(items) { item in
                    Text(item.title)
                }
            }
            .listStyle(.insetGrouped)
            """,
            reactCode: """
            <ul className="divide-y divide-gray-200">
              {items.map(item => (
                <li key={item.id} className="px-4 py-3 hover:bg-gray-50">
                  {item.title}
                </li>
              ))}
            </ul>
            """
        ))

        templates.append(StarterTemplate(
            name: "TabView",
            platform: .swiftUI,
            category: "Navigation",
            description: "A tab-based navigation container",
            layers: tabViewLayers(),
            properties: tabViewProperties(),
            swiftCode: """
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            """,
            reactCode: """
            <div className="min-h-screen flex flex-col">
              <main className="flex-1">
                {/* Tab Content */}
              </main>
              <nav className="border-t bg-white px-4 py-2">
                <div className="flex justify-around">
                  <button className="flex flex-col items-center text-blue-500">
                    <HomeIcon />
                    <span className="text-xs">Home</span>
                  </button>
                  <button className="flex flex-col items-center text-gray-500">
                    <SettingsIcon />
                    <span className="text-xs">Settings</span>
                  </button>
                </div>
              </nav>
            </div>
            """
        ))

        templates.append(StarterTemplate(
            name: "Card",
            platform: .swiftUI,
            category: "Layout",
            description: "A rounded card container with shadow",
            layers: [
                makeLayer(
                    name: "Card",
                    x: 0, y: 0, width: 350, height: 200,
                    layerType: .container,
                    fillColor: CanvasColor(red: 1, green: 1, blue: 1, alpha: 1),
                    cornerRadius: 16
                )
            ],
            properties: cardProperties(),
            swiftCode: """
            VStack(alignment: .leading) {
                // Card content
            }
            .padding()
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
            """,
            reactCode: """
            <div className="bg-white rounded-2xl shadow-lg p-4">
              {/* Card content */}
            </div>
            """
        ))

        // MARK: - UIKit Templates

        templates.append(StarterTemplate(
            name: "UIButton",
            platform: .uiKit,
            category: "Controls",
            description: "A UIKit button with system styling",
            layers: [
                makeLayer(
                    name: "UIButton",
                    x: 0, y: 0, width: 120, height: 44,
                    layerType: .element,
                    fillColor: CanvasColor(red: 0, green: 0.48, blue: 1, alpha: 1),
                    cornerRadius: 10
                )
            ],
            properties: buttonProperties(),
            swiftCode: """
            let button = UIButton(configuration: .filled())
            button.setTitle("Button", for: .normal)
            button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
            """,
            reactCode: """
            <button className="px-6 py-3 bg-blue-500 text-white font-semibold rounded-lg">
              Button
            </button>
            """
        ))

        templates.append(StarterTemplate(
            name: "UITableViewCell",
            platform: .uiKit,
            category: "Data Display",
            description: "A standard table view cell",
            layers: tableViewCellLayers(),
            properties: tableViewCellProperties(),
            swiftCode: """
            class CustomCell: UITableViewCell {
                override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
                    super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
                    accessoryType = .disclosureIndicator
                }
            }
            """,
            reactCode: """
            <div className="flex items-center px-4 py-3 border-b">
              <div className="flex-1">
                <p className="font-medium">Title</p>
                <p className="text-sm text-gray-500">Subtitle</p>
              </div>
              <ChevronRightIcon className="w-5 h-5 text-gray-400" />
            </div>
            """
        ))

        templates.append(StarterTemplate(
            name: "UINavigationBar",
            platform: .uiKit,
            category: "Navigation",
            description: "A navigation bar with title",
            layers: [
                makeLayer(
                    name: "NavigationBar",
                    x: 0, y: 0, width: 390, height: 96,
                    layerType: .container,
                    fillColor: CanvasColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)
                )
            ],
            properties: navigationProperties(),
            swiftCode: """
            navigationItem.title = "Title"
            navigationController?.navigationBar.prefersLargeTitles = true
            """,
            reactCode: """
            <header className="bg-gray-100 px-4 pt-12 pb-4">
              <h1 className="text-3xl font-bold">Title</h1>
            </header>
            """
        ))

        // MARK: - React Templates

        templates.append(StarterTemplate(
            name: "Card",
            platform: .react,
            category: "Layout",
            description: "A React card component with Tailwind",
            layers: [
                makeLayer(
                    name: "Card",
                    x: 0, y: 0, width: 350, height: 200,
                    layerType: .container,
                    fillColor: CanvasColor(red: 1, green: 1, blue: 1, alpha: 1),
                    cornerRadius: 16
                )
            ],
            properties: cardProperties(),
            swiftCode: """
            VStack {
                // Card content
            }
            .padding()
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 10)
            """,
            reactCode: """
            interface CardProps {
              children: React.ReactNode;
              className?: string;
            }

            export function Card({ children, className }: CardProps) {
              return (
                <div className={`bg-white rounded-2xl shadow-lg p-4 ${className}`}>
                  {children}
                </div>
              );
            }
            """
        ))

        templates.append(StarterTemplate(
            name: "Modal",
            platform: .react,
            category: "Overlays",
            description: "A modal dialog component",
            layers: modalLayers(),
            properties: modalProperties(),
            swiftCode: """
            .sheet(isPresented: $showModal) {
                VStack {
                    Text("Modal Content")
                }
                .presentationDetents([.medium])
            }
            """,
            reactCode: """
            interface ModalProps {
              isOpen: boolean;
              onClose: () => void;
              children: React.ReactNode;
            }

            export function Modal({ isOpen, onClose, children }: ModalProps) {
              if (!isOpen) return null;

              return (
                <div className="fixed inset-0 z-50 flex items-center justify-center">
                  <div className="absolute inset-0 bg-black/50" onClick={onClose} />
                  <div className="relative bg-white rounded-2xl p-6 max-w-md w-full mx-4 shadow-xl">
                    {children}
                  </div>
                </div>
              );
            }
            """
        ))

        templates.append(StarterTemplate(
            name: "Form",
            platform: .react,
            category: "Forms",
            description: "A form with inputs and submit button",
            layers: formLayers(),
            properties: formProperties(),
            swiftCode: """
            Form {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                Button("Submit") {
                    submit()
                }
            }
            """,
            reactCode: """
            interface FormData {
              name: string;
              email: string;
            }

            export function ContactForm() {
              const [formData, setFormData] = useState<FormData>({ name: '', email: '' });

              const handleSubmit = (e: React.FormEvent) => {
                e.preventDefault();
                // Handle submission
              };

              return (
                <form onSubmit={handleSubmit} className="space-y-4">
                  <input
                    type="text"
                    placeholder="Name"
                    value={formData.name}
                    onChange={e => setFormData(prev => ({ ...prev, name: e.target.value }))}
                    className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                  />
                  <input
                    type="email"
                    placeholder="Email"
                    value={formData.email}
                    onChange={e => setFormData(prev => ({ ...prev, email: e.target.value }))}
                    className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                  />
                  <button
                    type="submit"
                    className="w-full py-3 bg-blue-500 text-white font-semibold rounded-lg hover:bg-blue-600"
                  >
                    Submit
                  </button>
                </form>
              );
            }
            """
        ))

        return templates
    }

    // MARK: - Property Builders

    private static func buttonProperties() -> [ConfigurableProperty] {
        [
            ConfigurableProperty(key: "title", name: "Title", type: .text, defaultValue: .string("Button"), group: "Content"),
            ConfigurableProperty(key: "cornerRadius", name: "Corner Radius", type: .slider(min: 0, max: 22), defaultValue: .number(10), group: "Shape"),
            ConfigurableProperty(key: "fontSize", name: "Font Size", type: .slider(min: 12, max: 24), defaultValue: .number(17), group: "Typography"),
            ConfigurableProperty(key: "backgroundColor", name: "Background", type: .color, defaultValue: .color(CanvasColor(red: 0, green: 0.48, blue: 1, alpha: 1)), group: "Appearance")
        ]
    }

    private static func navigationProperties() -> [ConfigurableProperty] {
        [
            ConfigurableProperty(key: "title", name: "Title", type: .text, defaultValue: .string("Title"), group: "Content"),
            ConfigurableProperty(key: "largeTitles", name: "Large Titles", type: .toggle, defaultValue: .bool(true), group: "Style"),
            ConfigurableProperty(key: "backgroundColor", name: "Background", type: .color, defaultValue: .color(CanvasColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)), group: "Appearance")
        ]
    }

    private static func listProperties() -> [ConfigurableProperty] {
        [
            ConfigurableProperty(key: "style", name: "List Style", type: .dropdown(["Plain", "Grouped", "Inset Grouped"]), defaultValue: .string("Inset Grouped"), group: "Style"),
            ConfigurableProperty(key: "showSeparators", name: "Show Separators", type: .toggle, defaultValue: .bool(true), group: "Appearance")
        ]
    }

    private static func tabViewProperties() -> [ConfigurableProperty] {
        [
            ConfigurableProperty(key: "tabCount", name: "Tab Count", type: .slider(min: 2, max: 5), defaultValue: .number(3), group: "Content"),
            ConfigurableProperty(key: "tintColor", name: "Tint Color", type: .color, defaultValue: .color(CanvasColor(red: 0, green: 0.48, blue: 1, alpha: 1)), group: "Appearance")
        ]
    }

    private static func cardProperties() -> [ConfigurableProperty] {
        [
            ConfigurableProperty(key: "cornerRadius", name: "Corner Radius", type: .slider(min: 0, max: 32), defaultValue: .number(16), group: "Shape"),
            ConfigurableProperty(key: "shadowRadius", name: "Shadow Radius", type: .slider(min: 0, max: 20), defaultValue: .number(10), group: "Effects"),
            ConfigurableProperty(key: "padding", name: "Padding", type: .slider(min: 0, max: 32), defaultValue: .number(16), group: "Layout")
        ]
    }

    private static func tableViewCellProperties() -> [ConfigurableProperty] {
        [
            ConfigurableProperty(key: "style", name: "Cell Style", type: .dropdown(["Default", "Subtitle", "Value1", "Value2"]), defaultValue: .string("Subtitle"), group: "Style"),
            ConfigurableProperty(key: "accessory", name: "Accessory", type: .dropdown(["None", "Disclosure", "Checkmark", "Detail"]), defaultValue: .string("Disclosure"), group: "Content")
        ]
    }

    private static func modalProperties() -> [ConfigurableProperty] {
        [
            ConfigurableProperty(key: "presentationStyle", name: "Presentation", type: .dropdown(["Sheet", "Fullscreen", "Popover"]), defaultValue: .string("Sheet"), group: "Style"),
            ConfigurableProperty(key: "showDragIndicator", name: "Drag Indicator", type: .toggle, defaultValue: .bool(true), group: "Appearance")
        ]
    }

    private static func formProperties() -> [ConfigurableProperty] {
        [
            ConfigurableProperty(key: "spacing", name: "Field Spacing", type: .slider(min: 8, max: 24), defaultValue: .number(16), group: "Layout"),
            ConfigurableProperty(key: "borderStyle", name: "Border Style", type: .dropdown(["Rounded", "Line", "None"]), defaultValue: .string("Rounded"), group: "Appearance")
        ]
    }

    // MARK: - Layer Builders

    private static func listLayers() -> [CanvasLayer] {
        (0..<3).map { index in
            CanvasLayer(
                name: "Row \(index + 1)",
                frame: CanvasFrame(origin: CGPoint(x: 0, y: Double(index) * 50), size: CGSize(width: 350, height: 48)),
                zIndex: index,
                layerType: .element,
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 1, green: 1, blue: 1, alpha: 1))
            )
        }
    }

    private static func tabViewLayers() -> [CanvasLayer] {
        [
            CanvasLayer(
                name: "Content Area",
                frame: CanvasFrame(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 390, height: 794)),
                layerType: .container
            ),
            CanvasLayer(
                name: "Tab Bar",
                frame: CanvasFrame(origin: CGPoint(x: 0, y: 794), size: CGSize(width: 390, height: 50)),
                zIndex: 1,
                layerType: .container,
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1))
            )
        ]
    }

    private static func tableViewCellLayers() -> [CanvasLayer] {
        [
            CanvasLayer(
                name: "Cell",
                frame: CanvasFrame(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 350, height: 64)),
                layerType: .container,
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 1, green: 1, blue: 1, alpha: 1))
            )
        ]
    }

    private static func modalLayers() -> [CanvasLayer] {
        [
            CanvasLayer(
                name: "Backdrop",
                frame: CanvasFrame(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 390, height: 844)),
                opacity: 0.5,
                layerType: .shape,
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 0, green: 0, blue: 0, alpha: 1))
            ),
            CanvasLayer(
                name: "Modal Content",
                frame: CanvasFrame(origin: CGPoint(x: 20, y: 200), size: CGSize(width: 350, height: 400)),
                zIndex: 1,
                layerType: .container,
                borderConfig: BorderConfig(cornerRadius: 20),
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 1, green: 1, blue: 1, alpha: 1))
            )
        ]
    }

    private static func formLayers() -> [CanvasLayer] {
        [
            CanvasLayer(
                name: "Name Field",
                frame: CanvasFrame(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 300, height: 44)),
                layerType: .element,
                borderConfig: BorderConfig(color: CanvasColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1), width: 1, cornerRadius: 8),
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 1, green: 1, blue: 1, alpha: 1))
            ),
            CanvasLayer(
                name: "Email Field",
                frame: CanvasFrame(origin: CGPoint(x: 0, y: 60), size: CGSize(width: 300, height: 44)),
                zIndex: 1,
                layerType: .element,
                borderConfig: BorderConfig(color: CanvasColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1), width: 1, cornerRadius: 8),
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 1, green: 1, blue: 1, alpha: 1))
            ),
            CanvasLayer(
                name: "Submit Button",
                frame: CanvasFrame(origin: CGPoint(x: 0, y: 120), size: CGSize(width: 300, height: 50)),
                zIndex: 2,
                layerType: .element,
                borderConfig: BorderConfig(cornerRadius: 8),
                backgroundFill: FillConfig(fillType: .solid, color: CanvasColor(red: 0, green: 0.48, blue: 1, alpha: 1))
            )
        ]
    }
}

import SwiftUI

public struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (StarterTemplate) -> Void

    @State private var selectedPlatform: TemplatePlatform = .swiftUI
    @State private var searchText = ""

    private let library = StarterTemplateLibrary.shared

    public init(onSelect: @escaping (StarterTemplate) -> Void) {
        self.onSelect = onSelect
    }

    private var filteredTemplates: [StarterTemplate] {
        var templates = library.templates(for: selectedPlatform)

        if !searchText.isEmpty {
            templates = templates.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return templates
    }

    private var groupedTemplates: [String: [StarterTemplate]] {
        Dictionary(grouping: filteredTemplates, by: \.category)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                platformPicker

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(groupedTemplates.keys.sorted(), id: \.self) { category in
                            if let templates = groupedTemplates[category] {
                                categorySection(category, templates: templates)
                            }
                        }
                    }
                    .padding()
                }
            }
            .searchable(text: $searchText, prompt: "Search templates")
            .navigationTitle("Start from Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var platformPicker: some View {
        Picker("Platform", selection: $selectedPlatform) {
            ForEach(TemplatePlatform.allCases, id: \.self) { platform in
                Label(platform.rawValue, systemImage: platform.iconName)
                    .tag(platform)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    private func categorySection(_ category: String, templates: [StarterTemplate]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category)
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                ForEach(templates) { template in
                    TemplateCard(template: template) {
                        onSelect(template)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TemplateCard: View {
    let template: StarterTemplate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 80)

                    Image(systemName: iconForTemplate(template))
                        .font(.title)
                        .foregroundColor(.accentColor)
                }

                Text(template.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                Text(template.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func iconForTemplate(_ template: StarterTemplate) -> String {
        switch template.name {
        case "Button", "UIButton": return "button.horizontal"
        case "NavigationStack", "UINavigationBar": return "rectangle.topthird.inset.filled"
        case "List": return "list.bullet"
        case "TabView": return "square.stack"
        case "Card": return "rectangle.portrait"
        case "Modal": return "rectangle.center.inset.filled"
        case "Form": return "doc.text"
        case "UITableViewCell": return "list.dash"
        default: return "square"
        }
    }
}
