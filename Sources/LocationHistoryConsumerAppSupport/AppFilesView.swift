#if canImport(SwiftUI)
import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

private enum AppFilesSegment: String, CaseIterable, Identifiable {
    case local
    case cloud
    case pending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: return "Lokal"
        case .cloud: return "iCloud"
        case .pending: return "Wartend"
        }
    }
}

public struct AppFilesView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @StateObject private var viewModel: AppFilesViewModel
    @ObservedObject private var cloudViewModel: AppCloudFileViewModel
    @State private var pendingDelete: LocalFileEntry?
    @State private var pendingCloudDelete: CloudFileEntry?
    @State private var selectedSegment: AppFilesSegment = .local
    /// Handle für den initialen Refresh-Task. Beim Disappear cancellt,
    /// damit das ViewModel keinen Disk-Scan mehr fortführt, wenn der User
    /// den Tab bereits verlassen hat (vermeidet überflüssige I/O und
    /// Race-Conditions auf den State).
    @State private var initialRefreshTask: Task<Void, Never>?

    /// Picker-Trigger-Closure. Parent (`AppContentSplitView`) hostet den
    /// `.fileImporter` selbst — verschachtelte fileImporter in
    /// Tab-Subviews crashen sofort beim Tap (iOS 17/18 Bug).
    private let onChooseCloudFile: () -> Void

    public init(
        cloudViewModel: AppCloudFileViewModel,
        onChooseCloudFile: @escaping () -> Void = {}
    ) {
        // Local-File-Scanner wird hier lazy gebaut.
        let scanner: LocalFileScanning
        if let roots = try? LocalFileBucketRoots.production() {
            scanner = DiskLocalFileScanner(roots: roots)
        } else {
            scanner = InMemoryLocalFileScanner(snapshots: [])
        }
        _viewModel = StateObject(wrappedValue: AppFilesViewModel(scanner: scanner))
        _cloudViewModel = ObservedObject(initialValue: cloudViewModel)
        self.onChooseCloudFile = onChooseCloudFile
    }

    /// Explizit für Tests: nimmt beide ViewModels.
    public init(
        viewModel: AppFilesViewModel,
        cloudViewModel: AppCloudFileViewModel,
        onChooseCloudFile: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _cloudViewModel = ObservedObject(initialValue: cloudViewModel)
        self.onChooseCloudFile = onChooseCloudFile
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleHeader
                statusCard
                segmentPicker
                actionBar
                if let message = mergedActionMessage {
                    actionMessageBanner(message, failed: mergedActionFailed)
                }
                switch selectedSegment {
                case .local:
                    filterField
                    ForEach(LocalFileBucket.allCases, id: \.self) { bucket in
                        bucketCard(bucket)
                    }
                case .cloud:
                    cloudCard
                case .pending:
                    pendingCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear {
            // Disk-Scan nur, wenn noch keine Daten vorliegen. Task-Handle
            // hängt am @State, damit ein Tab-Wechsel den Scan abbrechen
            // kann (siehe `.onDisappear`). Ersatz für das vorherige
            // `.task { ... }`, das beim Disappear NICHT propagiert wurde.
            guard initialRefreshTask == nil, viewModel.snapshots.isEmpty else { return }
            initialRefreshTask = Task { @MainActor in
                await viewModel.refresh()
            }
        }
        .onDisappear {
            initialRefreshTask?.cancel()
            initialRefreshTask = nil
        }
        // fileImporter wurde aus dieser View entfernt — siehe
        // AppContentSplitView. Verschachtelte fileImporter in Tab-
        // Subviews crashen auf iOS 17/18 sofort beim Tap.
        .alert("Datei löschen?", isPresented: deleteAlertBinding, presenting: pendingDelete) { entry in
            Button("Abbrechen", role: .cancel) {
                pendingDelete = nil
            }
            Button("Löschen", role: .destructive) {
                let target = entry
                pendingDelete = nil
                Task { await viewModel.delete(target) }
            }
        } message: { entry in
            Text("„\(entry.fileName)“ wird unwiderruflich entfernt.")
        }
        .alert("Cloud-Datei löschen?", isPresented: cloudDeleteAlertBinding, presenting: pendingCloudDelete) { entry in
            Button("Abbrechen", role: .cancel) {
                pendingCloudDelete = nil
            }
            Button("Datei löschen", role: .destructive) {
                let target = entry
                pendingCloudDelete = nil
                Task { await cloudViewModel.delete(target) }
            }
        } message: { entry in
            Text("„\(entry.fileName)“ wird aus iCloud gelöscht. Lokale Dateien bleiben erhalten.")
        }
    }

    // MARK: - Sections

    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dateien")
                .font(.largeTitle).bold()
            Text("Lokale Gesamtgröße: \(viewModel.totalSizeGerman)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusCard: some View {
        let summary = cloudViewModel.statusSummary(localCount: localCloudUploadableEntries.count)
        return LHCard {
            VStack(alignment: .leading, spacing: 10) {
                LHSectionHeader("Status")
                HStack {
                    Label(summary.isCloudAvailable ? "iCloud erreichbar" : "iCloud nicht erreichbar",
                          systemImage: summary.isCloudAvailable ? "icloud.fill" : "icloud.slash")
                    .foregroundStyle(summary.isCloudAvailable ? .green : .orange)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Letzte Aktualisierung: \(summary.lastRefreshAt.map(modifiedString) ?? "Nie")")
                    Text("Lokale Einträge: \(summary.localCount)")
                    Text("Cloud-Einträge: \(summary.cloudCount)")
                    Text("Wartende Sicherungen: \(summary.pendingCount)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(AppAccessibilityID.Files.statusCard)
    }

    private var segmentPicker: some View {
        Picker("Dateien", selection: $selectedSegment) {
            ForEach(AppFilesSegment.allCases) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AppAccessibilityID.Files.segmentedControl)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    await viewModel.refresh()
                    await cloudViewModel.refreshCloudFiles()
                }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.actionState == .scanning || cloudViewModel.actionState == .refreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(isRefreshing ? "Aktualisiere…" : "Aktualisieren")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.actionState != .idle || cloudViewModel.actionState != .idle)
            .accessibilityIdentifier(AppAccessibilityID.Files.refresh)
            Button {
                onChooseCloudFile()
            } label: {
                Label("Datei auswählen", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)
            .disabled(!canUseCloudFiles)
            .accessibilityIdentifier(AppAccessibilityID.Files.chooseFile)
            Spacer()
        }
    }

    private func actionMessageBanner(_ message: String, failed: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: failed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(failed ? .red : .green)
            Text(message)
                .font(.footnote)
                .foregroundStyle(failed ? .red : .primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            // „X" zum Verwerfen — verhindert dass alte Fehler-Meldungen
            // (z. B. Permission-Fehler aus vorherigem Build) ewig
            // stehenbleiben.
            Button {
                cloudViewModel.clearActionMessage()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Meldung verwerfen")
            .accessibilityIdentifier("files.actionMessage.dismiss")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill((failed ? Color.red : Color.green).opacity(0.10))
        )
    }

    private var filterField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Dateien filtern", text: $viewModel.filterText)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(AppAccessibilityID.Files.filter)
        }
    }

    private func bucketCard(_ bucket: LocalFileBucket) -> some View {
        let entries = viewModel.filteredEntries(for: bucket)
        let snap = viewModel.snapshots.first(where: { $0.bucket == bucket })
        return LHCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(bucket.germanTitle).font(.headline)
                    Spacer()
                    Text(LocalFileSizeFormatter.germanString(forBytes: snap?.totalSizeBytes ?? 0))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(bucket.germanCaption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Divider()
                if entries.isEmpty {
                    Text("Keine Dateien in diesem Bereich.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        entryRow(entry)
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: LocalFileEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: entry.kind))
                .frame(width: 24)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(entry.kind.germanLabel)
                    Text("·")
                    Text(LocalFileSizeFormatter.germanString(forBytes: entry.sizeBytes))
                    if let modified = entry.modifiedAt {
                        Text("·")
                        Text(modifiedString(modified))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if CloudFileKind.from(filename: entry.fileName) != nil {
                Button {
                    Task { await cloudViewModel.uploadLocalEntry(entry) }
                } label: {
                    Image(systemName: "icloud.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .disabled(!canUseCloudFiles || cloudViewModel.actionState != .idle)
                .accessibilityLabel("Datei hochladen")
                .accessibilityIdentifier(AppAccessibilityID.Files.upload)
            }
            Button(role: .destructive) {
                pendingDelete = entry
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            // Fix B-Neu6: lokaler Delete blockiert auch während Cloud-Aktion,
            // verhindert parallele Mutationen am selben Eintrag.
            .disabled(viewModel.actionState != .idle || cloudViewModel.actionState != .idle)
            .accessibilityLabel("Datei löschen")
            // Fix B-Neu3: fehlender accessibilityIdentifier am lokalen Trash.
            .accessibilityIdentifier("files.entry.delete")
        }
        .padding(.vertical, 4)
    }

    private var cloudCard: some View {
        LHCard {
            VStack(alignment: .leading, spacing: 10) {
                LHSectionHeader("iCloud")
                Text("Cloud-Dateien werden nur nach Datei-Auswahl oder Upload-Button hochgeladen. Enthält möglicherweise Standortdaten.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Divider()
                if cloudViewModel.cloudEntries.isEmpty {
                    Text("Keine Cloud-Dateien geladen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cloudViewModel.cloudEntries) { entry in
                        cloudEntryRow(entry)
                    }
                }
            }
        }
    }

    private var pendingCard: some View {
        LHCard {
            VStack(alignment: .leading, spacing: 10) {
                LHSectionHeader("Wartend")
                if cloudViewModel.pendingUploads.isEmpty {
                    Text("Keine wartenden Sicherungen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cloudViewModel.pendingUploads, id: \.sha256Hex) { candidate in
                        pendingRow(candidate)
                        Divider()
                    }
                }
            }
        }
    }

    private func pendingRow(_ candidate: CloudFileUploadCandidate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(candidate.kind.germanLabel) · \(LocalFileSizeFormatter.germanString(forBytes: candidate.sizeBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await cloudViewModel.retryPendingUpload(candidate) }
            } label: {
                Image(systemName: "arrow.clockwise.icloud")
            }
            .buttonStyle(.borderless)
            .disabled(!canUseCloudFiles || cloudViewModel.actionState != .idle)
            .accessibilityLabel("Erneut hochladen")
            .accessibilityIdentifier("files.pending.retry")
            Button(role: .destructive) {
                cloudViewModel.discardPendingUpload(sha256Hex: candidate.sha256Hex)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Wartender Eintrag entfernen")
            .accessibilityIdentifier("files.pending.discard")
        }
        .padding(.vertical, 4)
    }

    private func cloudEntryRow(_ entry: CloudFileEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.badge.ellipsis")
                .frame(width: 24)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(entry.kind.germanLabel) · \(LocalFileSizeFormatter.germanString(forBytes: entry.sizeBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Fix B-Neu4: Download ist noch Stub. Button bleibt sichtbar,
            // aber visuell als „in Arbeit" markiert (kein normaler Tap-Effekt).
            Button {
                Task { await cloudViewModel.downloadPrepared(entry) }
            } label: {
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Datei herunterladen (in Arbeit)")
            .accessibilityHint("Vollständige Wiederherstellung folgt in einer Folgephase.")
            .accessibilityIdentifier(AppAccessibilityID.Files.download)
            Button(role: .destructive) {
                pendingCloudDelete = entry
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Datei löschen")
            .accessibilityIdentifier(AppAccessibilityID.Files.delete)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { isPresented in
                if !isPresented { pendingDelete = nil }
            }
        )
    }

    private var cloudDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingCloudDelete != nil },
            set: { isPresented in
                if !isPresented { pendingCloudDelete = nil }
            }
        )
    }

    private var localCloudUploadableEntries: [LocalFileEntry] {
        LocalFileBucket.allCases.flatMap { bucket in
            viewModel.filteredEntries(for: bucket).filter { CloudFileKind.from(filename: $0.fileName) != nil }
        }
    }

    private var canUseCloudFiles: Bool {
        preferences.iCloudSyncEnabled && preferences.syncCloudFilesEnabled
            && cloudViewModel.isCloudAvailable && cloudViewModel.actionState == .idle
    }

    private var isRefreshing: Bool {
        viewModel.actionState == .scanning || cloudViewModel.actionState == .refreshing
    }

    private var mergedActionMessage: String? {
        cloudViewModel.actionMessage ?? viewModel.actionMessage
    }

    private var mergedActionFailed: Bool {
        cloudViewModel.actionMessage != nil ? cloudViewModel.actionFailed : viewModel.actionFailed
    }

    // Picker-Logik komplett nach AppContentSplitView ausgelagert.

    private func iconName(for kind: LocalFileKind) -> String {
        switch kind {
        case .gpx, .kml, .kmz: return "map"
        case .zip: return "archivebox"
        case .json: return "curlybraces"
        case .csv: return "tablecells"
        case .sqlite: return "cylinder"
        case .other: return "doc"
        }
    }

    private func modifiedString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
#endif
