import SwiftUI
import AppleVibeNotebook

// MARK: - Device Frame View

/// Realistic device chrome (bezels, notch, Dynamic Island) for simulation.
/// Provides an authentic preview experience across different device types.
struct DeviceFrameView<Content: View>: View {
    let device: DevicePreset
    let colorScheme: ColorScheme
    @ViewBuilder let content: () -> Content

    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Device frame
            deviceFrame

            // Screen content
            GeometryReader { geometry in
                ZStack {
                    // Background
                    #if os(iOS)
                    Rectangle()
                        .fill(Color(.systemBackground))
                    #else
                    Rectangle()
                        .fill(Color.white)
                    #endif

                    // Content
                    content()

                    // Status bar overlay
                    VStack {
                        statusBar
                            .padding(.horizontal, safeAreaInsets.leading)
                        Spacer()
                    }

                    // Home indicator (for notched devices)
                    if hasHomeIndicator {
                        VStack {
                            Spacer()
                            homeIndicator
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: screenCornerRadius))
            }
            .frame(width: screenSize.width, height: screenSize.height)
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .onReceive(timer) { time in
            currentTime = time
        }
    }

    // MARK: - Device Frame

    @ViewBuilder
    private var deviceFrame: some View {
        ZStack {
            // Outer frame
            RoundedRectangle(cornerRadius: frameCornerRadius)
                .fill(frameColor)

            // Inner bezel
            RoundedRectangle(cornerRadius: frameCornerRadius - bezelWidth)
                .fill(Color.black)
                .padding(bezelWidth)

            // Screen cutout
            RoundedRectangle(cornerRadius: screenCornerRadius)
                .fill(Color.clear)
                .frame(width: screenSize.width, height: screenSize.height)

            // Notch or Dynamic Island
            if hasDynamicIsland {
                dynamicIsland
            } else if hasNotch {
                notch
            }

            // Side buttons
            sideButtons
        }
    }

    // MARK: - Dynamic Island

    @ViewBuilder
    private var dynamicIsland: some View {
        VStack {
            Capsule()
                .fill(Color.black)
                .frame(width: 126, height: 37)
                .offset(y: bezelWidth + 11)
            Spacer()
        }
    }

    // MARK: - Notch

    @ViewBuilder
    private var notch: some View {
        VStack {
            NotchShape()
                .fill(Color.black)
                .frame(width: 209, height: 30)
                .offset(y: bezelWidth)
            Spacer()
        }
    }

    // MARK: - Status Bar

    @ViewBuilder
    private var statusBar: some View {
        HStack {
            // Time
            Text(currentTime.formatted(.dateTime.hour().minute()))
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            // Status icons
            HStack(spacing: 5) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 13))
        }
        .foregroundColor(colorScheme == .dark ? .white : .black)
        .padding(.top, statusBarTopPadding)
        .padding(.horizontal, 20)
    }

    // MARK: - Home Indicator

    @ViewBuilder
    private var homeIndicator: some View {
        Capsule()
            .fill(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.3))
            .frame(width: 134, height: 5)
            .padding(.bottom, 8)
    }

    // MARK: - Side Buttons

    @ViewBuilder
    private var sideButtons: some View {
        HStack {
            // Left side - Volume + Silent switch
            VStack(spacing: 12) {
                // Silent switch
                RoundedRectangle(cornerRadius: 2)
                    .fill(frameColor.opacity(0.8))
                    .frame(width: 3, height: 30)

                // Volume up
                RoundedRectangle(cornerRadius: 2)
                    .fill(frameColor.opacity(0.8))
                    .frame(width: 3, height: 50)

                // Volume down
                RoundedRectangle(cornerRadius: 2)
                    .fill(frameColor.opacity(0.8))
                    .frame(width: 3, height: 50)
            }
            .offset(x: -1, y: -100)

            Spacer()

            // Right side - Power button
            RoundedRectangle(cornerRadius: 2)
                .fill(frameColor.opacity(0.8))
                .frame(width: 3, height: 80)
                .offset(x: 1, y: -80)
        }
    }

    // MARK: - Computed Properties

    private var screenSize: CGSize {
        device.size
    }

    private var frameSize: CGSize {
        CGSize(
            width: screenSize.width + (bezelWidth * 2),
            height: screenSize.height + (bezelWidth * 2)
        )
    }

    private var bezelWidth: CGFloat {
        switch device {
        case .iPhoneSE:
            return 60
        case .iPhone15, .iPhone15Pro, .iPhone15ProMax:
            return 12
        case .iPadMini, .iPad, .iPadPro11, .iPadPro13:
            return 20
        case .macBookAir, .macBookPro14, .macBookPro16:
            return 0
        default:
            return 12
        }
    }

    private var frameCornerRadius: CGFloat {
        switch device {
        case .iPhoneSE:
            return 12
        case .iPhone15, .iPhone15Pro, .iPhone15ProMax:
            return 55
        case .iPadMini, .iPad, .iPadPro11, .iPadPro13:
            return 20
        default:
            return 55
        }
    }

    private var screenCornerRadius: CGFloat {
        switch device {
        case .iPhoneSE:
            return 0
        case .iPhone15, .iPhone15Pro, .iPhone15ProMax:
            return 47
        case .iPadMini, .iPad, .iPadPro11, .iPadPro13:
            return 12
        default:
            return 47
        }
    }

    private var frameColor: Color {
        Color(white: 0.15)
    }

    private var hasNotch: Bool {
        false  // Older models only
    }

    private var hasDynamicIsland: Bool {
        switch device {
        case .iPhone15, .iPhone15Pro, .iPhone15ProMax:
            return true
        default:
            return false
        }
    }

    private var hasHomeIndicator: Bool {
        switch device {
        case .iPhoneSE:
            return false
        case .iPhone15, .iPhone15Pro, .iPhone15ProMax:
            return true
        case .iPadMini, .iPad, .iPadPro11, .iPadPro13:
            return true
        default:
            return true
        }
    }

    private var statusBarTopPadding: CGFloat {
        switch device {
        case .iPhone15, .iPhone15Pro, .iPhone15ProMax:
            return 54
        case .iPhoneSE:
            return 20
        default:
            return 20
        }
    }

    private var safeAreaInsets: EdgeInsets {
        switch device {
        case .iPhone15, .iPhone15Pro, .iPhone15ProMax:
            return EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        case .iPhoneSE:
            return EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)
        default:
            return EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0)
        }
    }
}

// MARK: - Notch Shape

struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let notchWidth: CGFloat = 209
        let notchHeight: CGFloat = 30
        let cornerRadius: CGFloat = 20

        // Start from left
        path.move(to: CGPoint(x: 0, y: 0))

        // Left curve down
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: notchHeight),
            control: CGPoint(x: 0, y: notchHeight)
        )

        // Bottom line
        path.addLine(to: CGPoint(x: notchWidth - cornerRadius, y: notchHeight))

        // Right curve up
        path.addQuadCurve(
            to: CGPoint(x: notchWidth, y: 0),
            control: CGPoint(x: notchWidth, y: notchHeight)
        )

        path.closeSubpath()

        return path
    }
}

// MARK: - Device Picker View

struct DevicePickerView: View {
    @Binding var selectedDevice: DevicePreset

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(deviceGroups, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            ForEach(group.devices, id: \.self) { device in
                                DevicePickerButton(
                                    device: device,
                                    isSelected: selectedDevice == device,
                                    action: { selectedDevice = device }
                                )
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var deviceGroups: [(name: String, devices: [DevicePreset])] {
        [
            ("iPhone", [.iPhoneSE, .iPhone15, .iPhone15Pro, .iPhone15ProMax]),
            ("iPad", [.iPadMini, .iPad, .iPadPro11, .iPadPro13]),
            ("Mac", [.macBookAir, .macBookPro14, .macBookPro16])
        ]
    }
}

struct DevicePickerButton: View {
    let device: DevicePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: deviceIcon)
                    .font(.system(size: 20))

                Text(device.rawValue)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .secondary)
    }

    private var deviceIcon: String {
        switch device {
        case .iPhoneSE, .iPhone15, .iPhone15Pro, .iPhone15ProMax:
            return "iphone"
        case .iPadMini, .iPad, .iPadPro11, .iPadPro13:
            return "ipad"
        case .macBookAir, .macBookPro14, .macBookPro16:
            return "laptopcomputer"
        default:
            return "display"
        }
    }
}

// MARK: - Preview

#Preview {
    DeviceFrameView(device: .iPhone15, colorScheme: .light) {
        VStack(spacing: 20) {
            Text("Hello, World!")
                .font(.largeTitle.bold())

            Button("Get Started") { }
                .buttonStyle(.borderedProminent)
        }
    }
    .padding(50)
    .background(Color(white: 0.2))
}
