#if canImport(SwiftUI)
import SwiftUI

/// Displays the list of recently opened location history files.
///
/// Shown on the empty/import start screen when there are stored recent entries.
/// Tapping a valid entry triggers re-import; stale entries are greyed out and
/// can only be removed.
public struct RecentFilesView: View {
    @EnvironmentObject private var preferences: AppPreferences

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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(t("Recent Files"), systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                if !entries.isEmpty {
                    Button(role: .destructive) {
                        onClearAll()
                    } label: {
                        Text(t("Clear All"))
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }

            if entries.isEmpty {
                Label(t("No recent files."), systemImage: "doc.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(entries) { entry in
                    recentFileRow(entry)
                }
            }
        }
        .padding()
        .background(LH2GPXTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LH2GPXTheme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func recentFileRow(_ entry: RecentFileEntry) -> some View {
        let isAvailable = RecentFilesStore.isAvailable(entry: entry)

        HStack(spacing: 10) {
            Image(systemName: isAvailable ? "doc.text.fill" : "doc.slash")
                .foregroundStyle(isAvailable ? Color.accentColor : Color.secondary)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isAvailable ? Color.primary : Color.secondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(relativeDate(entry.lastOpenedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !isAvailable {
                        Text("· \(t("Not available"))")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
            }

            Spacer()

            if isAvailable {
                Button {
                    onOpen(entry)
                } label: {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t("Open") + " " + entry.displayName)
            }

            Button(role: .destructive) {
                onRemove(entry.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t("Remove") + " " + entry.displayName)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isAvailable else { return }
            onOpen(entry)
        }

        if entry.id != entries.last?.id {
            Divider()
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = preferences.appLocale
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

#endif
