#if canImport(SwiftUI)
import SwiftUI

/// Displays the list of recently opened location history files.
///
/// Shown on the empty/import start screen when there are stored recent entries.
/// Tapping a valid entry triggers re-import; stale entries are greyed out and
/// can only be removed.
public struct RecentFilesView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @State private var showsAllEntries = false

    let entries: [RecentFileEntry]
    let onOpen: (RecentFileEntry) -> Void
    let onRemove: (UUID) -> Void
    let onClearAll: () -> Void

    public init(
        entries: [RecentFileEntry],
        onOpen: @escaping (RecentFileEntry) -> Void,
        onRemove: @escaping (UUID) -> Void,
        onClearAll: @escaping () -> Void
    ) {
        self.entries = entries
        self.onOpen = onOpen
        self.onRemove = onRemove
        self.onClearAll = onClearAll
    }

    public var body: some View {
        LHCard {
            HStack {
                LHSectionHeader(t("Recently Used"))
                Spacer()
                if entries.count > 3 && !showsAllEntries {
                    Button(t("Show All")) {
                        showsAllEntries = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.primaryBlue)
                    .buttonStyle(.plain)
                }
            }
            .accessibilityIdentifier("home.recentFiles")

            if entries.isEmpty {
                Label(t("No recent files."), systemImage: "doc.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(visibleEntries) { entry in
                    recentFileRow(entry)
                }
            }
        }
        .contextMenu {
            if !entries.isEmpty {
                Button(role: .destructive, action: onClearAll) {
                    Text(t("Clear History"))
                }
            }
        }
    }

    @ViewBuilder
    private func recentFileRow(_ entry: RecentFileEntry) -> some View {
        let isAvailable = RecentFilesStore.isAvailable(entry: entry)

        Button {
            guard isAvailable else { return }
            onOpen(entry)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isAvailable ? Color.primary : Color.secondary)
                            .lineLimit(1)
                        Text(metadataLine(for: entry, isAvailable: isAvailable))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isAvailable ? LH2GPXTheme.primaryBlue.opacity(0.9) : .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 2)
        }
        .padding(.vertical, 6)
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .contentShape(Rectangle())
        .contextMenu {
            if isAvailable {
                Button(t("Open Again")) { onOpen(entry) }
            }
            Button(role: .destructive) { onRemove(entry.id) } label: {
                Text(t("Remove Entry"))
            }
        }

        if entry.id != visibleEntries.last?.id {
            Divider()
        }
    }

    private var visibleEntries: [RecentFileEntry] {
        showsAllEntries ? entries : Array(entries.prefix(3))
    }

    private func metadataLine(for entry: RecentFileEntry, isAvailable: Bool) -> String {
        let parts = [displayDate(entry.lastOpenedAt), entry.fileSizeBytes.flatMap(fileSizeString), isAvailable ? nil : t("Unavailable")]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    private func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = preferences.appLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func fileSizeString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

#endif
