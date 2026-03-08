import SwiftUI
import AppleVibeNotebook

struct CanvasWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(CanvasState.self) private var canvasState
    @Environment(CloudSyncService.self) private var cloudSync

    @State private var showPropertyInspectorPanel = true
    @State private var showLayerPanelState = true
    @State private var showObjectLibrary = false
    @State private var showCodeEditor = false
    @State private var showSimulation = false
    @State private var showExportSheet = false
    @State private var selectedExportTarget: ExportTarget = .pureSwift
    @State private var syncEngine = CanvasSyncEngine()
    @State private var simulationEngine = SimulationEngine()

    var body: some View {
        @Bindable var state = appState

        GeometryReader { geometry in
            ZStack {
                mainCanvasArea

                floatingPanels(geometry: geometry)

                CanvasToolbar(canvasState: canvasState)
                    .position(x: geometry.size.width / 2, y: 60)
            }
        }
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showObjectLibrary) {
            ObjectLibraryView(canvasState: canvasState)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showExportSheet) {
            exportSheet
        }
        .inspector(isPresented: $showPropertyInspectorPanel) {
            PropertyInspectorView(canvasState: canvasState)
                .inspectorColumnWidth(min: 280, ideal: 300, max: 350)
        }
    }

    @ViewBuilder
    private var mainCanvasArea: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            iPhoneCanvasView(canvasState: canvasState)
        } else {
            iPadCanvasView(canvasState: canvasState)
        }
        #else
        HSplitView {
            InfiniteCanvasView(canvasState: canvasState)
                .frame(minWidth: 400)

            if showCodeEditor {
                CodeEditorView(canvasState: canvasState, syncEngine: syncEngine)
                    .frame(minWidth: 300, maxWidth: 500)
            }

            if showSimulation {
                simulationPanel
                    .frame(minWidth: 320, maxWidth: 400)
            }
        }
        #endif
    }

    @ViewBuilder
    private func floatingPanels(geometry: GeometryProxy) -> some View {
        VStack {
            HStack {
                Spacer()

                CloudSyncStatusView(syncService: cloudSync)
                    .padding(.trailing, 16)
            }

            Spacer()
        }
        .padding(.top, 100)

        if showLayerPanelState {
            VStack {
                Spacer()
                HStack {
                    layerPanel
                        .frame(width: 200)
                        .padding()
                    Spacer()
                }
            }
        }
    }

    private var layerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Layers")
                    .font(.headline)
                Spacer()
                Button {
                    showLayerPanelState = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.bar)

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(canvasState.document.layers.sorted(by: { $0.zIndex > $1.zIndex })) { layer in
                        layerRow(layer)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }

    private func layerRow(_ layer: CanvasLayer) -> some View {
        HStack(spacing: 8) {
            Button {
                canvasState.updateLayer(id: layer.id) { updated in
                    updated.isVisible.toggle()
                }
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .font(.caption)
                    .foregroundColor(layer.isVisible ? .primary : .secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: iconForLayerType(layer.layerType))
                .font(.caption)
                .foregroundColor(.secondary)

            Text(layer.name)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(canvasState.selectedLayerIDs.contains(layer.id) ? .accentColor : .primary)

            Spacer()

            if layer.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(canvasState.selectedLayerIDs.contains(layer.id) ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            canvasState.selectLayer(layer.id)
        }
    }

    private var simulationPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()

                Menu {
                    ForEach(DevicePreset.allCases, id: \.self) { preset in
                        Button(preset.rawValue) {
                            // Update device preset
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("iPhone 15 Pro")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
            }
            .padding()
            .background(.bar)

            Divider()

            SimulationEnvironmentView(
                engine: simulationEngine,
                document: canvasState.document
            )
        }
        .background(.ultraThinMaterial)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showObjectLibrary.toggle()
            } label: {
                Label("Components", systemImage: "plus.square")
            }

            Divider()

            Toggle(isOn: Binding(
                get: { showCodeEditor },
                set: { showCodeEditor = $0 }
            )) {
                Label("Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Toggle(isOn: Binding(
                get: { showSimulation },
                set: { showSimulation = $0 }
            )) {
                Label("Preview", systemImage: "play.rectangle")
            }

            Divider()

            Button {
                showExportSheet.toggle()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }

        ToolbarItemGroup(placement: .secondaryAction) {
            Button {
                showPropertyInspectorPanel.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }

            Button {
                showLayerPanelState.toggle()
            } label: {
                Label("Layers", systemImage: "square.3.layers.3d")
            }
        }
    }

    private var exportSheet: some View {
        NavigationStack {
            Form {
                Section("Export Target") {
                    Picker("Target", selection: $selectedExportTarget) {
                        ForEach(ExportTarget.allCases, id: \.self) { target in
                            Text(target.rawValue).tag(target)
                        }
                    }
                    .pickerStyle(.inline)

                    Text(selectedExportTarget.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Export Project") {
                        exportProject()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showExportSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func exportProject() {
        Task {
            let options = ExportOptions(target: selectedExportTarget)
            let exporter = ProjectExporter(options: options)

            do {
                let project = try await exporter.export(
                    document: canvasState.document,
                    projectName: "CanvasCodeExport"
                )

                print("Exported \(project.files.count) files")
                showExportSheet = false
            } catch {
                print("Export failed: \(error)")
            }
        }
    }

    private func iconForLayerType(_ type: LayerType) -> String {
        switch type {
        case .element: return "square"
        case .container: return "square.stack"
        case .component: return "puzzlepiece"
        case .group: return "folder"
        case .artboard: return "rectangle.portrait"
        case .mask: return "theatermasks"
        case .shape: return "square.on.circle"
        case .text: return "textformat"
        case .image: return "photo"
        }
    }
}

struct WorkspaceSimulationView: View {
    let engine: SimulationEngine
    let devicePreset: DevicePreset

    var body: some View {
        VStack {
            DeviceFrameView(device: devicePreset, colorScheme: .light) {
                EmptyView()
            }
            .scaleEffect(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
    }
}

#Preview {
    CanvasWorkspaceView()
        .environment(AppState())
        .environment(CanvasState())
        .environment(CloudSyncService())
}
