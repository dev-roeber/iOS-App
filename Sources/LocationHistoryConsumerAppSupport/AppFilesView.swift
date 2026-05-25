#if canImport(SwiftUI)
import SwiftUI

/// Prompt 1 — Datei-Tab UI.
///
/// Zeigt vier Buckets (Exporte/Importe/Favoriten/Caches) als
/// einklappbare `LHCard`-Sektionen mit Dateigröße, Änderungsdatum und
/// Lösch-Aktion. Filterleiste oben filtert über alle Buckets. Sichtbarer
/// Action-State + Fehlermeldung verhindern das „Button-tot"-Problem,
/// das Phase D.4 für die iCloud-Seite gelöst hat.
public struct AppFilesView: View {
    @StateObject private var viewModel: AppFilesViewModel
    @State private var pendingDelete: LocalFileEntry?

    public init(viewModel: AppFilesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Convenience-Init für den Compact-Tab, der den Produktions-Scanner
    /// erst lazy beim ersten Tab-Aufruf erstellt.
    public init() {
        let scanner: LocalFileScanning
        if let roots = try? LocalFileBucketRoots.production() {
            scanner = DiskLocalFileScanner(roots: roots)
        } else {
            scanner = InMemoryLocalFileScanner(snapshots: [])
        }
        _viewModel = StateObject(wrappedValue: AppFilesViewModel(scanner: scanner))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleHeader
                actionBar
                if let message = viewModel.actionMessage {
                    actionMessageBanner(message, failed: viewModel.actionFailed)
                }
                filterField
                ForEach(LocalFileBucket.allCases, id: \.self) { bucket in
                    bucketCard(bucket)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .task {
            if viewModel.snapshots.isEmpty {
                await viewModel.refresh()
            }
        }
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
    }

    // MARK: - Sections

    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dateien")
                .font(.largeTitle).bold()
            Text("Gesamtgröße: \(viewModel.totalSizeGerman)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.actionState == .scanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(viewModel.actionState == .scanning ? "Aktualisiere…" : "Aktualisieren")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.actionState != .idle)
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
            Spacer()
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
            Button(role: .destructive) {
                pendingDelete = entry
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.actionState != .idle)
            .accessibilityLabel("Datei löschen")
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
