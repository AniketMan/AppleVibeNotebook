import SwiftUI
import PhotosUI
import AppleVibeNotebook

/// Image to Canvas conversion view
/// Allows importing images and converting them to canvas layers
public struct ImageToCanvasView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var generatedLayers: [CanvasLayer] = []
    @State private var error: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                imagePicker

                if isProcessing {
                    ProgressView("Processing image...")
                }

                if let error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Image to UI")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    await processSelectedItem(newItem)
                }
            }
        }
    }

    private var imagePicker: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Import Image")
                .font(.headline)

            PhotosPicker(
                selection: $selectedItem,
                matching: .images
            ) {
                Label("Choose Image", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func processSelectedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                error = "Failed to load image data"
                return
            }

            // Placeholder - actual processing would go here
            generatedLayers = []
            error = nil
        } catch {
            self.error = "Error loading image: \(error.localizedDescription)"
        }
    }
}
