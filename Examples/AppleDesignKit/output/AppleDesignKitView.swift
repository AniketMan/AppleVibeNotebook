// Generated SwiftUI Code from AppleDesignKit.jsx
// React2SwiftUI Canvas - Figma Fast Path (1:1 Apple Design Resources Mapping)
// This demonstrates direct conversion from React Apple-style components to native SwiftUI

import SwiftUI

// MARK: - Navigation Bar → NavigationStack + .navigationTitle

struct NavigationBarView: View {
    let title: String
    var leftAction: NavigationAction?
    var rightAction: NavigationAction?

    struct NavigationAction {
        let label: String
        let onPress: () -> Void
    }

    var body: some View {
        // NavigationBar maps directly to NavigationStack toolbar
        // In SwiftUI, this is typically handled by NavigationStack
        EmptyView()
    }
}

// MARK: - Tab Bar → TabView

struct TabBarView: View {
    let tabs: [TabItem]
    @Binding var selectedIndex: Int

    struct TabItem: Identifiable {
        let id: String
        let icon: String
        let label: String
    }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                EmptyView()
                    .tabItem {
                        Image(systemName: tab.icon)
                        Text(tab.label)
                    }
                    .tag(index)
            }
        }
    }
}

// MARK: - List Cell → List Row with NavigationLink

struct ListCellView: View {
    let title: String
    var subtitle: String?
    var leadingIcon: String?
    var trailingContent: AnyView?
    var onPress: (() -> Void)?
    var destructive: Bool = false

    var body: some View {
        Button(action: { onPress?() }) {
            HStack {
                if let icon = leadingIcon {
                    Image(systemName: icon)
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(destructive ? .red : .primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let trailing = trailingContent {
                    trailing
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toggle → Toggle (Direct 1:1 Mapping)

struct ToggleView: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Toggle(label, isOn: $isOn)
    }
}

// MARK: - Segmented Control → Picker with .segmented style

struct SegmentedControlView: View {
    let segments: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        Picker("", selection: $selectedIndex) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                Text(segment).tag(index)
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Apple Button → Button with various styles

struct AppleButtonView: View {
    let title: String
    let onPress: () -> Void
    var style: ButtonStyleType = .filled
    var size: ButtonSize = .regular
    var disabled: Bool = false

    enum ButtonStyleType {
        case filled, tinted, gray, plain
    }

    enum ButtonSize {
        case small, regular, large
    }

    var body: some View {
        Button(action: onPress) {
            Text(title)
                .frame(maxWidth: size == .large ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(controlSize)
        .disabled(disabled)
    }

    private var controlSize: ControlSize {
        switch size {
        case .small: return .small
        case .regular: return .regular
        case .large: return .large
        }
    }
}

// MARK: - Text Field → TextField (Direct 1:1 Mapping)

struct TextFieldView: View {
    let placeholder: String
    @Binding var value: String
    var secure: Bool = false
    var clearButton: Bool = true

    var body: some View {
        HStack {
            if secure {
                SecureField(placeholder, text: $value)
            } else {
                TextField(placeholder, text: $value)
            }

            if clearButton && !value.isEmpty {
                Button {
                    value = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .textFieldStyle(.roundedBorder)
    }
}

// MARK: - Search Bar → .searchable modifier

struct SearchBarView: View {
    let placeholder: String
    @Binding var value: String
    var onCancel: (() -> Void)?

    var body: some View {
        // In SwiftUI, search is typically done with .searchable modifier
        // This is a standalone version for demonstration
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(placeholder, text: $value)

                if !value.isEmpty {
                    Button {
                        value = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            if !value.isEmpty {
                Button("Cancel") {
                    value = ""
                    onCancel?()
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Action Sheet Item → Button in confirmationDialog

struct ActionSheetItemView: View {
    let title: String
    var icon: String?
    let onPress: () -> Void
    var destructive: Bool = false

    var body: some View {
        Button(role: destructive ? .destructive : nil, action: onPress) {
            if let icon = icon {
                Label(title, systemImage: icon)
            } else {
                Text(title)
            }
        }
    }
}

// MARK: - Card → Section in List with .insetGrouped style

struct CardView<Content: View, Header: View, Footer: View>: View {
    @ViewBuilder let content: () -> Content
    @ViewBuilder var header: () -> Header = { EmptyView() as! Header }
    @ViewBuilder var footer: () -> Footer = { EmptyView() as! Footer }

    var body: some View {
        Section {
            content()
        } header: {
            header()
        } footer: {
            footer()
        }
    }
}

// MARK: - Progress View → ProgressView (Direct 1:1 Mapping)

struct ProgressViewComponent: View {
    let value: Double
    var total: Double = 1.0
    var tint: Color = .blue

    var body: some View {
        ProgressView(value: value, total: total)
            .tint(tint)
    }
}

// MARK: - Activity Indicator → ProgressView() (Direct 1:1 Mapping)

struct ActivityIndicatorView: View {
    var size: IndicatorSize = .medium

    enum IndicatorSize {
        case small, medium, large
    }

    var body: some View {
        ProgressView()
            .controlSize(controlSize)
    }

    private var controlSize: ControlSize {
        switch size {
        case .small: return .small
        case .medium: return .regular
        case .large: return .large
        }
    }
}

// MARK: - Main Settings Screen → Complete SwiftUI View

struct SettingsScreenView: View {
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                List {
                    Section("General") {
                        HStack {
                            Label("Notifications", systemImage: "bell.fill")
                            Spacer()
                            Toggle("", isOn: $notificationsEnabled)
                                .labelsHidden()
                        }

                        HStack {
                            Label("Dark Mode", systemImage: "moon.fill")
                            Spacer()
                            Toggle("", isOn: $darkModeEnabled)
                                .labelsHidden()
                        }

                        NavigationLink {
                            PrivacySettingsView()
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Privacy")
                                    Text("Manage your data")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "lock.fill")
                            }
                        }
                    }

                    Section("Account") {
                        Button(role: .destructive) {
                            // Sign out action
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Settings")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            // Done action
                        }
                    }
                }
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(0)

            NavigationStack {
                Text("Profile")
                    .navigationTitle("Profile")
            }
            .tabItem {
                Image(systemName: "person.circle")
                Text("Profile")
            }
            .tag(1)

            NavigationStack {
                Text("Search")
                    .navigationTitle("Search")
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .tag(2)
        }
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        List {
            Section {
                Text("Privacy settings content")
            }
        }
        .navigationTitle("Privacy")
    }
}

// MARK: - Design Tokens (Extracted from CSS)

enum DesignTokens {
    enum Colors {
        static let systemBlue = Color(red: 0/255, green: 122/255, blue: 255/255)
        static let systemGreen = Color(red: 52/255, green: 199/255, blue: 89/255)
        static let systemIndigo = Color(red: 88/255, green: 86/255, blue: 214/255)
        static let systemOrange = Color(red: 255/255, green: 149/255, blue: 0/255)
        static let systemPink = Color(red: 255/255, green: 45/255, blue: 85/255)
        static let systemPurple = Color(red: 175/255, green: 82/255, blue: 222/255)
        static let systemRed = Color(red: 255/255, green: 59/255, blue: 48/255)
        static let systemTeal = Color(red: 90/255, green: 200/255, blue: 250/255)
        static let systemYellow = Color(red: 255/255, green: 204/255, blue: 0/255)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
    }

    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }
}

// MARK: - Preview

#Preview("Settings Screen") {
    SettingsScreenView()
}

#Preview("Components") {
    VStack(spacing: 20) {
        AppleButtonView(title: "Primary Button", onPress: {})

        AppleButtonView(title: "Disabled", onPress: {}, disabled: true)

        ProgressViewComponent(value: 0.7)

        ActivityIndicatorView()
    }
    .padding()
}
