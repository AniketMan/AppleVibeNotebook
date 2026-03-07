import Foundation

// MARK: - SwiftUI View Types

/// Represents all valid SwiftUI view types that can be generated.
/// This enum defines the bounded output vocabulary - the model cannot
/// generate any view type not present here.
public enum SwiftUIViewType: String, CaseIterable, Codable, Sendable {
    // Layout Containers
    case vStack = "VStack"
    case hStack = "HStack"
    case zStack = "ZStack"
    case lazyVStack = "LazyVStack"
    case lazyHStack = "LazyHStack"
    case lazyVGrid = "LazyVGrid"
    case lazyHGrid = "LazyHGrid"
    case grid = "Grid"
    case gridRow = "GridRow"
    case scrollView = "ScrollView"
    case list = "List"
    case form = "Form"
    case group = "Group"
    case section = "Section"
    case groupBox = "GroupBox"
    case controlGroup = "ControlGroup"
    case viewThatFits = "ViewThatFits"

    // Navigation
    case navigationStack = "NavigationStack"
    case navigationSplitView = "NavigationSplitView"
    case navigationLink = "NavigationLink"
    case tabView = "TabView"
    case tab = "Tab"

    // Text & Labels
    case text = "Text"
    case label = "Label"
    case link = "Link"
    case textEditor = "TextEditor"

    // Input Controls
    case button = "Button"
    case textField = "TextField"
    case secureField = "SecureField"
    case toggle = "Toggle"
    case picker = "Picker"
    case datePicker = "DatePicker"
    case slider = "Slider"
    case stepper = "Stepper"
    case colorPicker = "ColorPicker"
    case menu = "Menu"

    // Images & Media
    case image = "Image"
    case asyncImage = "AsyncImage"

    // Shapes
    case rectangle = "Rectangle"
    case roundedRectangle = "RoundedRectangle"
    case circle = "Circle"
    case ellipse = "Ellipse"
    case capsule = "Capsule"
    case path = "Path"
    case unevenRoundedRectangle = "UnevenRoundedRectangle"

    // Container Views
    case spacer = "Spacer"
    case divider = "Divider"
    case emptyView = "EmptyView"
    case forEach = "ForEach"
    case color = "Color"

    // Effects & Materials
    case material = "Material"
    case glassEffect = "glassEffect"

    // Progress & Activity
    case progressView = "ProgressView"
    case gauge = "Gauge"

    // Disclosure
    case disclosureGroup = "DisclosureGroup"
    case outlineGroup = "OutlineGroup"
}

// MARK: - SwiftUI Modifiers

/// Represents all valid SwiftUI view modifiers.
/// These are the only modifiers the engine can emit.
public enum SwiftUIModifier: String, CaseIterable, Codable, Sendable {
    // Layout
    case frame
    case padding
    case offset
    case position
    case alignmentGuide
    case layoutPriority
    case fixedSize
    case aspectRatio
    case scaledToFit
    case scaledToFill
    case ignoresSafeArea
    case safeAreaInset
    case safeAreaPadding
    case containerRelativeFrame

    // Stacking & Alignment
    case zIndex

    // Appearance
    case foregroundStyle
    case foregroundColor
    case tint
    case background
    case backgroundStyle
    case overlay
    case border
    case clipShape
    case cornerRadius
    case mask
    case opacity
    case hidden
    case blendMode
    case compositingGroup
    case drawingGroup

    // Shadows & Effects
    case shadow
    case blur
    case brightness
    case contrast
    case saturation
    case grayscale
    case hueRotation
    case colorInvert
    case colorMultiply

    // Typography
    case font
    case fontWeight
    case fontDesign
    case fontWidth
    case bold
    case italic
    case underline
    case strikethrough
    case kerning
    case tracking
    case baselineOffset
    case lineLimit
    case lineSpacing
    case multilineTextAlignment
    case truncationMode
    case allowsTightening
    case minimumScaleFactor
    case textCase
    case textSelection

    // Transforms
    case rotationEffect
    case rotation3DEffect
    case scaleEffect
    case transformEffect
    case projectionEffect

    // Gestures
    case onTapGesture
    case onLongPressGesture
    case gesture
    case highPriorityGesture
    case simultaneousGesture

    // Navigation & Presentation
    case navigationTitle
    case navigationBarTitleDisplayMode
    case toolbar
    case toolbarBackground
    case sheet
    case fullScreenCover
    case popover
    case alert
    case confirmationDialog
    case inspector

    // Scrolling
    case scrollIndicators
    case scrollDisabled
    case scrollContentBackground
    case scrollClipDisabled
    case scrollTargetBehavior
    case scrollPosition
    case defaultScrollAnchor
    case contentMargins

    // Animation
    case animation
    case transition
    case matchedGeometryEffect
    case matchedTransitionSource
    case navigationTransition
    case contentTransition
    case symbolEffect
    case phaseAnimator
    case keyframeAnimator

    // Interaction
    case disabled
    case interactionActivityTrackingTag
    case allowsHitTesting
    case contentShape
    case hoverEffect
    case focusable
    case focused
    case focusScope
    case focusedValue
    case focusedSceneValue
    case prefersDefaultFocus
    case defaultFocus
    case focusEffectDisabled

    // State & Data
    case environment
    case environmentObject
    case transformEnvironment
    case preference
    case anchorPreference
    case onPreferenceChange

    // Lifecycle
    case onAppear
    case onDisappear
    case onChange
    case onReceive
    case task
    case refreshable

    // Accessibility
    case accessibilityLabel
    case accessibilityValue
    case accessibilityHint
    case accessibilityIdentifier
    case accessibilityHidden
    case accessibilityAction
    case accessibilityAddTraits
    case accessibilityRemoveTraits
    case accessibilityElement
    case accessibilityRepresentation
    case accessibilitySortPriority
    case accessibilityInputLabels
    case accessibilityShowsLargeContentViewer
    case accessibilityZoomAction
    case speechAdjustedPitch
    case speechAlwaysIncludesPunctuation
    case speechAnnouncementsQueued
    case speechSpellsOutCharacters

    // Style
    case buttonStyle
    case toggleStyle
    case pickerStyle
    case textFieldStyle
    case labelStyle
    case listStyle
    case listRowBackground
    case listRowInsets
    case listRowSeparator
    case listRowSeparatorTint
    case listSectionSeparator
    case listSectionSeparatorTint
    case navigationSplitViewStyle
    case tabViewStyle
    case gaugeStyle
    case progressViewStyle
    case groupBoxStyle
    case datePickerStyle
    case menuStyle
    case formStyle
    case controlGroupStyle
    case indexViewStyle

    // Sizing
    case frame_minIdealMax = "frame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:alignment:)"
    case containerBackground

    // Context Menu
    case contextMenu

    // Drag & Drop
    case draggable
    case dropDestination
    case onDrag
    case onDrop

    // Search
    case searchable
    case searchSuggestions

    // Selection
    case tag
    case selectionDisabled

    // Status Bar
    case statusBarHidden
    case persistentSystemOverlays

    // Keyboard
    case keyboardType
    case textContentType
    case submitLabel
    case autocorrectionDisabled
    case textInputAutocapitalization
    case onSubmit

    // Help & Hints
    case help

    // ID & Identification
    case id

    // Debug
    case debugBorder = "_debugBorder"
}

// MARK: - SwiftUI Property Wrappers

/// Property wrappers used for state management in SwiftUI.
/// Maps from React hooks to SwiftUI state patterns.
public enum SwiftUIPropertyWrapper: String, CaseIterable, Codable, Sendable {
    case state = "@State"
    case binding = "@Binding"
    case stateObject = "@StateObject"
    case observedObject = "@ObservedObject"
    case environmentObject = "@EnvironmentObject"
    case environment = "@Environment"
    case focusState = "@FocusState"
    case gestureState = "@GestureState"
    case sceneStorage = "@SceneStorage"
    case appStorage = "@AppStorage"
    case query = "@Query"
    case namespace = "@Namespace"
    case accessibilityFocusState = "@AccessibilityFocusState"
}

// MARK: - Animation Types

/// SwiftUI animation timing curves.
public enum SwiftUIAnimationTiming: String, CaseIterable, Codable, Sendable {
    case `default` = ".default"
    case linear = ".linear"
    case easeIn = ".easeIn"
    case easeOut = ".easeOut"
    case easeInOut = ".easeInOut"
    case spring = ".spring"
    case bouncy = ".bouncy"
    case snappy = ".snappy"
    case smooth = ".smooth"
    case interactiveSpring = ".interactiveSpring"
    case interpolatingSpring = ".interpolatingSpring"
}

/// SwiftUI transition types.
public enum SwiftUITransition: String, CaseIterable, Codable, Sendable {
    case identity = ".identity"
    case opacity = ".opacity"
    case scale = ".scale"
    case slide = ".slide"
    case move = ".move"
    case push = ".push"
    case offset = ".offset"
    case asymmetric = ".asymmetric"
    case blurReplace = ".blurReplace"
    case symbolEffect = ".symbolEffect"
}
