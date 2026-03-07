# Apple Design Kit Example

This example demonstrates the **Figma Fast Path** - a 1:1 mapping from Apple Design Resources (Figma iOS UI Kit) to native SwiftUI components.

## Source Files (React)

| File | Description |
|------|-------------|
| `src/components/AppleDesignKit.jsx` | React components mimicking Apple iOS design |
| `src/components/AppleDesignKit.css` | CSS styles following Apple Human Interface Guidelines |

## Generated Output (SwiftUI)

| File | Description |
|------|-------------|
| `output/AppleDesignKitView.swift` | Native SwiftUI code with 1:1 mappings |

## Component Mappings

| React Component | SwiftUI Equivalent | Conversion Tier |
|-----------------|-------------------|-----------------|
| `<NavigationBar>` | `NavigationStack` + `.navigationTitle` | 🟢 Direct |
| `<TabBar>` | `TabView` | 🟢 Direct |
| `<ListCell>` | `List` row with `NavigationLink` | 🟢 Direct |
| `<Toggle>` | `Toggle` | 🟢 Direct |
| `<SegmentedControl>` | `Picker(.segmented)` | 🟢 Direct |
| `<AppleButton>` | `Button(.borderedProminent)` | 🟢 Direct |
| `<TextField>` | `TextField` / `SecureField` | 🟢 Direct |
| `<SearchBar>` | `.searchable` modifier | 🟢 Direct |
| `<Card>` | `Section` in `List(.insetGrouped)` | 🟢 Direct |
| `<ProgressView>` | `ProgressView` | 🟢 Direct |
| `<ActivityIndicator>` | `ProgressView()` | 🟢 Direct |

## CSS → SwiftUI Modifier Mappings

| CSS Property | SwiftUI Modifier |
|--------------|------------------|
| `display: flex; flex-direction: column` | `VStack` |
| `display: flex; flex-direction: row` | `HStack` |
| `padding: 16px` | `.padding(16)` |
| `border-radius: 12px` | `.clipShape(RoundedRectangle(cornerRadius: 12))` |
| `background-color: #007AFF` | `.background(Color.blue)` |
| `color: #FF3B30` | `.foregroundStyle(.red)` |
| `font-size: 17px; font-weight: 600` | `.font(.headline)` |

## Design Tokens Extracted

```swift
enum DesignTokens {
    enum Colors {
        static let systemBlue = Color(red: 0, green: 122/255, blue: 1)
        static let systemGreen = Color(red: 52/255, green: 199/255, blue: 89/255)
        // ... more colors
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
    }
}
```

## Health Score: 100% 🟢

All components in this example use Apple Design Resources patterns that map directly to SwiftUI, resulting in a perfect conversion score.
