import Foundation

/// Foundation-only Presentation-Schicht für `LocalTimelineImportProgress`
/// (Phase-10A P1-A/B → Weg 2).
///
/// Wandelt einen Progress-Snapshot in stabile, lokalisierungsfreundliche
/// UI-Strings um, ohne Standortdaten, Dateipfade, Tokens oder URLs zu
/// exponieren. Wird sowohl von der SwiftUI-Progress-View als auch von
/// Linux-Tests konsumiert; Linux-testbar bleibt der gesamte Output.
public struct LocalTimelineImportProgressPresentation: Equatable, Sendable {

    /// Hauptstatus, der die aktuelle Phase als Headline-Zeile beschreibt.
    public let statusText: String
    /// Maschinenlesbares Phase-Label (Untertitel) — bewusst getrennt vom
    /// `statusText`, damit Tests phasen-spezifisch assertieren können.
    public let phaseLabel: String
    /// Detail-Zeile mit Counter-Block, z. B.
    /// "Entries 1,234 · Visits 56 · Activities 12 · Paths 3".
    public let countsText: String
    /// Sekundäre Zeile mit `skippedEntries`, falls > 0; sonst nil.
    public let skippedText: String?
    /// Aktueller Day-Bucket (z. B. "2024-07-12") als Hint, falls vorhanden.
    public let currentDayText: String?
    /// Optionaler Bytes-Hint ("12.3 MB / 46.8 MB"), nur wenn `totalBytes`
    /// gesetzt ist und einen sinnvollen Prozentwert ergibt.
    public let bytesText: String?
    /// Prozent (0…100, gerundet) — nur dann gesetzt, wenn `totalBytes`
    /// bekannt **und** `bytesRead <= totalBytes` und `totalBytes > 0`.
    public let percentText: String?
    /// Tester-orientierte einzeilige Zusammenfassung, in der Banner-Sektion
    /// nutzbar.
    public let oneLineSummary: String
    /// Cancel-Button-Sichtbarkeit — exakt äquivalent zum Snapshot-Flag,
    /// aber als gesondertes Feld, damit die View es ohne den Snapshot lesen
    /// kann.
    public let isCancellable: Bool
    /// Snapshot-Phase — durchgereicht für Tests/Routing.
    public let phase: LocalTimelineImportProgress.Phase

    public init(progress: LocalTimelineImportProgress) {
        self.phase = progress.phase
        self.isCancellable = progress.isCancellable
        self.statusText = Self.statusText(for: progress.phase)
        self.phaseLabel = Self.phaseLabel(for: progress.phase)
        self.countsText = Self.countsText(progress: progress)
        self.skippedText = Self.skippedText(progress: progress)
        self.currentDayText = Self.currentDayText(progress: progress)
        let percent = Self.percent(progress: progress)
        self.percentText = percent.flatMap(Self.formatPercent)
        self.bytesText = Self.bytesText(progress: progress)
        self.oneLineSummary = Self.oneLineSummary(
            phaseLabel: Self.phaseLabel(for: progress.phase),
            counts: Self.countsText(progress: progress),
            percent: percent
        )
    }

    // MARK: - Idle

    public static let idle: LocalTimelineImportProgressPresentation =
        LocalTimelineImportProgressPresentation(
            progress: LocalTimelineImportProgress.initial()
        )

    // MARK: - Helpers

    private static func statusText(for phase: LocalTimelineImportProgress.Phase) -> String {
        switch phase {
        case .idle:        return "Waiting…"
        case .preparing:   return "Preparing import…"
        case .sniffing:    return "Detecting file format…"
        case .importing:   return "Importing entries…"
        case .finalizing:  return "Finalising import…"
        case .completed:   return "Import complete"
        case .cancelled:   return "Import cancelled"
        case .failed:      return "Import failed"
        }
    }

    private static func phaseLabel(for phase: LocalTimelineImportProgress.Phase) -> String {
        switch phase {
        case .idle:        return "idle"
        case .preparing:   return "preparing"
        case .sniffing:    return "sniffing"
        case .importing:   return "importing"
        case .finalizing:  return "finalizing"
        case .completed:   return "completed"
        case .cancelled:   return "cancelled"
        case .failed:      return "failed"
        }
    }

    private static func countsText(progress: LocalTimelineImportProgress) -> String {
        let entries = formatCount(progress.entriesProcessed)
        let visits = formatCount(progress.visitsWritten)
        let activities = formatCount(progress.activitiesWritten)
        let paths = formatCount(progress.pathsWritten)
        return "Entries \(entries) · Visits \(visits) · Activities \(activities) · Paths \(paths)"
    }

    private static func skippedText(progress: LocalTimelineImportProgress) -> String? {
        guard progress.skippedEntries > 0 else { return nil }
        return "Skipped \(formatCount(progress.skippedEntries))"
    }

    /// Day-Buckets sind keine Standortdaten — lediglich der Datums-String aus
    /// dem Importer (z. B. "2024-07-12"). Wir geben ihn nur dann durch, wenn
    /// er der bekannten Form `YYYY-MM-DD` entspricht; alles andere wird
    /// fallengelassen, damit kein versehentlich durchgeschleifter Pfad oder
    /// Token in der UI landet.
    private static func currentDayText(progress: LocalTimelineImportProgress) -> String? {
        guard let day = progress.currentDay, isISODate(day) else { return nil }
        return "Day \(day)"
    }

    private static func percent(progress: LocalTimelineImportProgress) -> Int? {
        guard let total = progress.totalBytes, total > 0,
              let read = progress.bytesRead, read >= 0, read <= total else {
            return nil
        }
        let raw = Double(read) / Double(total) * 100.0
        return min(100, max(0, Int(raw.rounded())))
    }

    private static func formatPercent(_ value: Int) -> String {
        "\(value)%"
    }

    private static func bytesText(progress: LocalTimelineImportProgress) -> String? {
        guard let total = progress.totalBytes, total > 0,
              let read = progress.bytesRead, read >= 0, read <= total else {
            return nil
        }
        return "\(formatBytes(read)) / \(formatBytes(total))"
    }

    private static func oneLineSummary(
        phaseLabel: String,
        counts: String,
        percent: Int?
    ) -> String {
        if let percent {
            return "[\(phaseLabel)] \(percent)% — \(counts)"
        }
        return "[\(phaseLabel)] \(counts)"
    }

    private static func formatCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func formatBytes(_ value: Int64) -> String {
        let mb = Double(value) / (1024.0 * 1024.0)
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        }
        let kb = Double(value) / 1024.0
        if kb >= 1.0 {
            return String(format: "%.1f KB", kb)
        }
        return "\(value) B"
    }

    private static func isISODate(_ s: String) -> Bool {
        guard s.count == 10 else { return false }
        let chars = Array(s)
        guard chars[4] == "-", chars[7] == "-" else { return false }
        let digits = chars.enumerated().allSatisfy { idx, c in
            if idx == 4 || idx == 7 { return c == "-" }
            return c.isASCII && c.isNumber
        }
        return digits
    }
}
