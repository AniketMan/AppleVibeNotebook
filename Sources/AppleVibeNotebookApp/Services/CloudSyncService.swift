import Foundation
import Combine
import AppleVibeNotebook

@Observable @MainActor
public final class CloudSyncService {
    public var syncState: SyncState = .idle
    public var lastSyncDate: Date?
    public var pendingChanges: Int = 0
    public var isConnected: Bool = false
    public var syncError: SyncError?

    private var fileCoordinator: NSFileCoordinator?
    private var metadataQuery: NSMetadataQuery?
    private var documentWatcher: DocumentWatcher?
    private let syncQueue = DispatchQueue(label: "com.canvascode.cloudsync", qos: .utility)

    private var ubiquityContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)
    }

    public init() {
        setupICloudObservers()
    }

    public func startMonitoring() {
        guard let containerURL = ubiquityContainerURL else {
            syncError = .iCloudUnavailable
            return
        }

        isConnected = true

        metadataQuery = NSMetadataQuery()
        metadataQuery?.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery?.predicate = NSPredicate(format: "%K LIKE '*.canvascode'", NSMetadataItemFSNameKey)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: metadataQuery
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidFinishGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery
        )

        metadataQuery?.start()

        documentWatcher = DocumentWatcher(containerURL: containerURL)
        documentWatcher?.onDocumentChange = { [weak self] url in
            self?.handleDocumentChange(at: url)
        }
        documentWatcher?.startWatching()
    }

    public func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery = nil
        documentWatcher?.stopWatching()
        documentWatcher = nil
        isConnected = false
    }

    public func save(_ document: CanvasDocument, filename: String) async throws {
        guard let containerURL = ubiquityContainerURL else {
            throw SyncError.iCloudUnavailable
        }

        syncState = .syncing

        let documentsURL = containerURL.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)

        let fileURL = documentsURL.appendingPathComponent("\(filename).canvascode")

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinatorError) { url in
                do {
                    let data = try JSONEncoder().encode(document)
                    try data.write(to: url, options: .atomic)

                    Task { @MainActor in
                        self.syncState = .synced
                        self.lastSyncDate = Date()
                        self.pendingChanges = 0
                    }

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error = coordinatorError {
                continuation.resume(throwing: error)
            }
        }
    }

    public func load(filename: String) async throws -> CanvasDocument {
        guard let containerURL = ubiquityContainerURL else {
            throw SyncError.iCloudUnavailable
        }

        let fileURL = containerURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("\(filename).canvascode")

        syncState = .syncing

        try await downloadIfNeeded(url: fileURL)

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var document: CanvasDocument?

        coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { url in
            do {
                let data = try Data(contentsOf: url)
                document = try JSONDecoder().decode(CanvasDocument.self, from: data)
            } catch {
                syncError = .decodingFailed(error.localizedDescription)
            }
        }

        if let error = coordinatorError {
            throw SyncError.coordinationFailed(error.localizedDescription)
        }

        guard let loadedDocument = document else {
            throw SyncError.documentNotFound
        }

        syncState = .synced
        return loadedDocument
    }

    public func listDocuments() async throws -> [CloudDocument] {
        guard let containerURL = ubiquityContainerURL else {
            throw SyncError.iCloudUnavailable
        }

        let documentsURL = containerURL.appendingPathComponent("Documents")

        let contents = try FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .ubiquitousItemDownloadingStatusKey],
            options: [.skipsHiddenFiles]
        )

        return try contents
            .filter { $0.pathExtension == "canvascode" }
            .map { url in
                let attributes = try url.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .ubiquitousItemDownloadingStatusKey
                ])

                let downloadStatus: DownloadStatus
                if let status = attributes.ubiquitousItemDownloadingStatus {
                    switch status {
                    case .current: downloadStatus = .downloaded
                    case .downloaded: downloadStatus = .downloaded
                    case .notDownloaded: downloadStatus = .notDownloaded
                    default: downloadStatus = .unknown
                    }
                } else {
                    downloadStatus = .local
                }

                return CloudDocument(
                    id: UUID(),
                    name: url.deletingPathExtension().lastPathComponent,
                    url: url,
                    modificationDate: attributes.contentModificationDate ?? Date(),
                    fileSize: attributes.fileSize ?? 0,
                    downloadStatus: downloadStatus
                )
            }
            .sorted { $0.modificationDate > $1.modificationDate }
    }

    public func delete(filename: String) async throws {
        guard let containerURL = ubiquityContainerURL else {
            throw SyncError.iCloudUnavailable
        }

        let fileURL = containerURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("\(filename).canvascode")

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            coordinator.coordinate(writingItemAt: fileURL, options: .forDeleting, error: &coordinatorError) { url in
                do {
                    try FileManager.default.removeItem(at: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error = coordinatorError {
                continuation.resume(throwing: error)
            }
        }
    }

    public func forceSync() async {
        syncState = .syncing

        do {
            _ = try await listDocuments()
            syncState = .synced
            lastSyncDate = Date()
        } catch {
            syncState = .error
            syncError = .syncFailed(error.localizedDescription)
        }
    }

    private func setupICloudObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudAccountChanged),
            name: .NSUbiquityIdentityDidChange,
            object: nil
        )
    }

    @objc private func iCloudAccountChanged() {
        if ubiquityContainerURL != nil {
            isConnected = true
            startMonitoring()
        } else {
            isConnected = false
            stopMonitoring()
            syncError = .iCloudUnavailable
        }
    }

    @objc private func metadataQueryDidUpdate(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        processMetadataResults(query.results as? [NSMetadataItem] ?? [])
    }

    @objc private func metadataQueryDidFinishGathering(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        processMetadataResults(query.results as? [NSMetadataItem] ?? [])
    }

    private func processMetadataResults(_ items: [NSMetadataItem]) {
        pendingChanges = items.filter { item in
            guard let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String else {
                return false
            }
            return status != NSMetadataUbiquitousItemDownloadingStatusCurrent
        }.count
    }

    private func downloadIfNeeded(url: URL) async throws {
        let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])

        if resourceValues.ubiquitousItemDownloadingStatus != .current {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)

            for _ in 0..<60 {
                let status = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                if status.ubiquitousItemDownloadingStatus == .current {
                    return
                }
                try await Task.sleep(nanoseconds: 500_000_000)
            }

            throw SyncError.downloadTimeout
        }
    }

    private func handleDocumentChange(at url: URL) {
        Task { @MainActor in
            pendingChanges += 1
            syncState = .pendingSync
        }
    }
}

public enum SyncState: Equatable {
    case idle
    case syncing
    case synced
    case pendingSync
    case error

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .syncing: return "Syncing..."
        case .synced: return "Synced"
        case .pendingSync: return "Pending"
        case .error: return "Error"
        }
    }

    public var iconName: String {
        switch self {
        case .idle: return "cloud"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud"
        case .pendingSync: return "icloud.and.arrow.up"
        case .error: return "exclamationmark.icloud"
        }
    }
}

public enum SyncError: Error, LocalizedError {
    case iCloudUnavailable
    case documentNotFound
    case coordinationFailed(String)
    case decodingFailed(String)
    case encodingFailed(String)
    case downloadTimeout
    case syncFailed(String)

    public var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud is not available. Please sign in to iCloud in Settings."
        case .documentNotFound:
            return "Document not found in iCloud."
        case .coordinationFailed(let message):
            return "File coordination failed: \(message)"
        case .decodingFailed(let message):
            return "Failed to decode document: \(message)"
        case .encodingFailed(let message):
            return "Failed to encode document: \(message)"
        case .downloadTimeout:
            return "Download from iCloud timed out."
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

public struct CloudDocument: Identifiable {
    public let id: UUID
    public let name: String
    public let url: URL
    public let modificationDate: Date
    public let fileSize: Int
    public let downloadStatus: DownloadStatus

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    public var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: modificationDate, relativeTo: Date())
    }
}

public enum DownloadStatus {
    case downloaded
    case notDownloaded
    case downloading
    case local
    case unknown

    public var iconName: String {
        switch self {
        case .downloaded: return "checkmark.circle.fill"
        case .notDownloaded: return "icloud.and.arrow.down"
        case .downloading: return "arrow.down.circle"
        case .local: return "internaldrive"
        case .unknown: return "questionmark.circle"
        }
    }
}

private final class DocumentWatcher {
    private let containerURL: URL
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    var onDocumentChange: ((URL) -> Void)?

    init(containerURL: URL) {
        self.containerURL = containerURL
    }

    func startWatching() {
        let documentsURL = containerURL.appendingPathComponent("Documents")

        fileDescriptor = open(documentsURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            guard let self else { return }
            self.onDocumentChange?(documentsURL)
        }

        source?.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source?.resume()
    }

    func stopWatching() {
        source?.cancel()
        source = nil
    }
}

@Observable
public final class HandoffManager {
    public var isHandoffSupported: Bool = true
    public var activeActivity: NSUserActivity?

    private let activityType = "com.canvascode.editing"

    public init() {}

    public func startActivity(document: CanvasDocument, filename: String) {
        let activity = NSUserActivity(activityType: activityType)
        activity.title = "Editing \(filename)"
        activity.userInfo = [
            "filename": filename,
            "documentId": document.id.uuidString
        ]
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        #if os(iOS)
        activity.isEligibleForPrediction = true
        #endif

        activeActivity = activity
        activity.becomeCurrent()
    }

    public func stopActivity() {
        activeActivity?.invalidate()
        activeActivity = nil
    }

    public func handleIncomingActivity(_ activity: NSUserActivity) -> (filename: String, documentId: UUID)? {
        guard activity.activityType == activityType,
              let userInfo = activity.userInfo,
              let filename = userInfo["filename"] as? String,
              let documentIdString = userInfo["documentId"] as? String,
              let documentId = UUID(uuidString: documentIdString) else {
            return nil
        }

        return (filename, documentId)
    }
}

import SwiftUI

public struct CloudSyncStatusView: View {
    @Bindable var syncService: CloudSyncService

    public init(syncService: CloudSyncService) {
        self.syncService = syncService
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: syncService.syncState.iconName)
                .symbolEffect(.pulse, isActive: syncService.syncState == .syncing)
                .foregroundColor(colorForState(syncService.syncState))

            VStack(alignment: .leading, spacing: 2) {
                Text(syncService.syncState.displayName)
                    .font(.caption.weight(.medium))

                if let lastSync = syncService.lastSyncDate {
                    Text(lastSync, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if syncService.pendingChanges > 0 {
                Text("\(syncService.pendingChanges)")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }

    private func colorForState(_ state: SyncState) -> Color {
        switch state {
        case .idle: return .secondary
        case .syncing: return .blue
        case .synced: return .green
        case .pendingSync: return .orange
        case .error: return .red
        }
    }
}

public struct CloudDocumentListView: View {
    @Bindable var syncService: CloudSyncService
    @State private var documents: [CloudDocument] = []
    @State private var isLoading = false
    @State private var error: SyncError?

    var onSelect: (CloudDocument) -> Void

    public init(syncService: CloudSyncService, onSelect: @escaping (CloudDocument) -> Void) {
        self.syncService = syncService
        self.onSelect = onSelect
    }

    public var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if documents.isEmpty {
                ContentUnavailableView(
                    "No Documents",
                    systemImage: "doc.text",
                    description: Text("Your CanvasCode documents will appear here")
                )
            } else {
                ForEach(documents) { doc in
                    Button {
                        onSelect(doc)
                    } label: {
                        CloudDocumentRow(document: doc)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteDocuments)
            }
        }
        .refreshable {
            await loadDocuments()
        }
        .task {
            await loadDocuments()
        }
        .alert("Sync Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
    }

    private func loadDocuments() async {
        isLoading = true
        defer { isLoading = false }

        do {
            documents = try await syncService.listDocuments()
        } catch let syncError as SyncError {
            error = syncError
        } catch {
            self.error = .syncFailed(error.localizedDescription)
        }
    }

    private func deleteDocuments(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let doc = documents[index]
                try? await syncService.delete(filename: doc.name)
            }
            await loadDocuments()
        }
    }
}

private struct CloudDocumentRow: View {
    let document: CloudDocument

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(document.formattedDate)
                    Text("•")
                    Text(document.formattedSize)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: document.downloadStatus.iconName)
                .foregroundColor(document.downloadStatus == .downloaded ? .green : .secondary)
        }
        .padding(.vertical, 4)
    }
}
