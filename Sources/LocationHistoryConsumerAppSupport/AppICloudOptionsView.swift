#if canImport(SwiftUI)
import SwiftUI

// MARK: - ICloudSyncViewModel

/// Thin SwiftUI-friendly wrapper around the Foundation-only
/// `CloudSyncService`. Keeps `CloudSyncService.swift` free of any
/// SwiftUI / Combine import so the package keeps building on Linux,
/// while letting the iCloud Settings page observe status changes.
@MainActor
final class ICloudSyncViewModel: ObservableObject {
    @Published private(set) var status: CloudSyncStatus
    @Published private(set) var isEnabled: Bool
    @Published private(set) var healthStatus: ICloudHealthStatus
    @Published private(set) var storageOverview: ICloudStorageOverview
    @Published private(set) var pendingBackupCount: Int

    private let service: CloudSyncService
    private let healthCheckService: ICloudHealthChecking
    private let backupService: LiveTrackCloudBackupCoordinator

    init(
        service: CloudSyncService,
        healthCheckService: ICloudHealthChecking,
        backupService: LiveTrackCloudBackupCoordinator
    ) {
        self.service = service
        self.healthCheckService = healthCheckService
        self.backupService = backupService
        self.status = service.status
        self.isEnabled = service.isEnabled
        self.healthStatus = healthCheckService.status
        self.storageOverview = backupService.overview
        self.pendingBackupCount = backupService.pendingCount
    }

    func setEnabled(_ enabled: Bool) async {
        guard service.isEnabled != enabled else { return }
        service.isEnabled = enabled
        isEnabled = service.isEnabled
        status = service.status
        if enabled {
            await refresh()
        }
    }

    func refresh() async {
        await service.refresh()
        status = service.status
        isEnabled = service.isEnabled
        healthStatus = await healthCheckService.runHealthCheck(isEnabled: isEnabled)
        storageOverview = await backupService.refreshOverview()
        pendingBackupCount = backupService.pendingCount
    }

    func refreshOverview() async {
        storageOverview = await backupService.refreshOverview()
        pendingBackupCount = backupService.pendingCount
    }

    func retryPendingBackups() async {
        await backupService.retryPendingBackups()
        storageOverview = await backupService.refreshOverview()
        pendingBackupCount = backupService.pendingCount
    }

    func deleteCloudData() async {
        do {
            try await backupService.deleteCloudData()
            storageOverview = backupService.overview
            pendingBackupCount = backupService.pendingCount
        } catch {
            storageOverview.errorMessage = "Cloud-Daten konnten nicht gelöscht werden."
        }
    }
}

// MARK: - AppICloudOptionsView

/// Train F.4 — first visible adoption of `LHXSyncStatusCard`. Renders
/// only the iCloud account / capability status against the configured
/// private container; performs **no** record reads, writes,
/// subscriptions, or assets. The screen is the user-facing surface for
/// the existing `AppPreferences.iCloudSyncEnabled` opt-in — toggling
/// the card flips that preference and triggers a single
/// `CKContainer.accountStatus()` round-trip via `CloudSyncService`.
public struct AppICloudOptionsView: View {
    @ObservedObject private var preferences: AppPreferences
    @StateObject private var viewModel: ICloudSyncViewModel
    @State private var showsCloudDeleteConfirmation = false

    public init(preferences: AppPreferences) {
        self._preferences = ObservedObject(wrappedValue: preferences)
        let service = CloudSyncServiceFactory.makeProductionService(
            isEnabled: preferences.iCloudSyncEnabled
        )
        #if canImport(CloudKit)
        let healthCheckService: ICloudHealthChecking = CloudKitICloudHealthCheckService()
        #else
        let healthCheckService: ICloudHealthChecking = InMemoryICloudHealthCheckService()
        #endif
        let backupService = LiveTrackCloudBackupFactory.makeProductionService {
            preferences.liveTrackCloudBackupSettings
        }
        self._viewModel = StateObject(
            wrappedValue: ICloudSyncViewModel(
                service: service,
                healthCheckService: healthCheckService,
                backupService: backupService
            )
        )
    }

    public var body: some View {
        ScrollView {
            LHPageScaffold {
                LHXSyncStatusCard(
                    kind: Self.cardKind(for: viewModel.status.accountStatus),
                    title: "iCloud-Sync",
                    detail: detailText(for: viewModel.status.accountStatus),
                    lastSyncText: nil,
                    toggleActionTitle: viewModel.isEnabled
                        ? "iCloud-Sync deaktivieren"
                        : "iCloud-Sync aktivieren",
                    toggleAction: {
                        preferences.iCloudSyncEnabled.toggle()
                    },
                    accessibilityIdentifier: "options.icloud.statusCard"
                )

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Status aktualisieren", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.status.isWorking)
                .accessibilityIdentifier("options.icloud.refresh")
                .accessibilityLabel("iCloud-Status aktualisieren")
                .accessibilityHint(viewModel.status.isWorking
                    ? "iCloud wird geprüft. Bitte warte, bis die aktuelle Prüfung abgeschlossen ist."
                    : "Prüft iCloud-Konto und privaten CloudKit-Bereich mit einem nicht-sensiblen Testrecord.")

                iCloudDriveExportHintCard

                healthCheckCard
                iCloudBackupSelectionCard
                automaticLiveTrackBackupCard
                storageOverviewCard
                statusAutoRefreshCard
                networkPolicyCard
                conflictPolicyCard
                containerInfoCard

                LHXInfoCard(
                    kind: .info,
                    title: "Datenschutz",
                    message: privacyFooterText,
                    systemImage: "lock.shield",
                    accessibilityIdentifier: "options.icloud.footer"
                )
            }
        }
        .navigationTitle(t("iCloud"))
        .accessibilityIdentifier("options.icloud.title")
        .scrollContentBackground(.hidden)
        .background(LH2GPXTheme.VariantBPro.bgWarm.ignoresSafeArea())
        .task {
            await viewModel.refresh()
        }
        .onChange(of: preferences.iCloudSyncEnabled) { _, newValue in
            Task { await viewModel.setEnabled(newValue) }
        }
        .onChange(of: preferences.iCloudStatusAutoRefreshEnabled) { _, newValue in
            guard newValue else { return }
            Task { await viewModel.refresh() }
        }
        .confirmationDialog(
            "Cloud-Daten löschen?",
            isPresented: $showsCloudDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cloud-Daten löschen", role: .destructive) {
                Task { await viewModel.deleteCloudData() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Dies löscht die von dieser App gespeicherten iCloud-Daten im privaten iCloud-Bereich. Lokale Daten bleiben erhalten.")
        }
    }

    // MARK: - Variant B Pro · Extended iCloud Settings (Train 2026-05-25)

    @ViewBuilder
    private var iCloudBackupSelectionCard: some View {
        LHCard {
            LHSectionHeader("In iCloud sichern")
            VStack(alignment: .leading, spacing: 10) {
                if !preferences.iCloudSyncEnabled {
                    Label("iCloud-Sync ist deaktiviert — bitte oben aktivieren, um Sicherungsoptionen auszuwählen.", systemImage: "icloud.slash")
                        .font(.caption)
                        .foregroundStyle(LH2GPXTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("options.icloud.backupSelection.gateHint")
                }
                Toggle(isOn: $preferences.syncLiveTrackMetadataEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LiveTrack-Metadaten")
                            .font(.subheadline.weight(.semibold))
                        Text("Name, Zeitraum, Distanz und technische Zusammenfassung eines LiveTracks.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(!preferences.iCloudSyncEnabled)
                .accessibilityIdentifier("options.icloud.metadataSync.toggle")
                .accessibilityHint(Text("Sichert keine Koordinaten. Der Hauptschalter iCloud-Sync muss aktiv sein."))

                Toggle(isOn: $preferences.syncLiveTrackPointBatchesEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .accessibilityHidden(true)
                            Text("LiveTrack-Routenpunkte")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("Enthält genaue Standortpunkte eines LiveTracks. Diese Option ist standardmäßig deaktiviert.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(!preferences.iCloudSyncEnabled)
                .accessibilityIdentifier("options.icloud.pointBatches.toggle")
                .accessibilityLabel(Text("LiveTrack-Routenpunkte. Sensible Standortdaten."))

                Toggle(isOn: $preferences.syncAppSettingsEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App-Einstellungen")
                            .font(.subheadline.weight(.semibold))
                        Text("Nur iCloud-bezogene Einstellungen und Anzeigeoptionen.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(!preferences.iCloudSyncEnabled)
                .accessibilityIdentifier("options.icloud.appSettings.toggle")

                Toggle(isOn: $preferences.syncExportHintsEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Export-Hinweise")
                            .font(.subheadline.weight(.semibold))
                        Text("Nur lokale Exportziel-Hinweise, keine automatisch hochgeladenen GPX-Dateien.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(!preferences.iCloudSyncEnabled)
                .accessibilityIdentifier("options.icloud.exportHints.toggle")
            }
        }
        .accessibilityIdentifier("options.icloud.metadataSync.card")
    }

    @ViewBuilder
    private var automaticLiveTrackBackupCard: some View {
        LHCard {
            LHSectionHeader("Automatische Sicherung")
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.automaticLiveTrackICloudBackupEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LiveTracks automatisch in iCloud sichern")
                            .font(.subheadline.weight(.semibold))
                        Text("Wenn aktiviert, werden neu abgeschlossene LiveTracks nach dem Speichern zusätzlich in deinem privaten iCloud-Bereich gesichert. Importierte Google-History-Daten werden nicht automatisch hochgeladen.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(!preferences.iCloudSyncEnabled || !preferences.syncLiveTrackMetadataEnabled)
                .accessibilityIdentifier("options.icloud.automaticLiveTrackBackup.toggle")
            }
        }
        .accessibilityIdentifier("options.icloud.automaticLiveTrackBackup.card")
    }

    @ViewBuilder
    private var healthCheckCard: some View {
        LHCard {
            LHSectionHeader("CloudKit-Health-Check")
            VStack(alignment: .leading, spacing: 8) {
                Label(viewModel.healthStatus.userFacingStatusKey, systemImage: healthIconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(healthIconColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let probe = viewModel.healthStatus.lastProbeResult {
                    Text("Letzte Prüfung: \(Self.shortDateFormatter.string(from: probe.checkedAt)) · \(String(format: "%.2f", probe.durationSeconds)) s")
                        .font(.caption)
                        .foregroundStyle(LH2GPXTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Schreiben \(probe.writeSucceeded ? "✓" : "–") · Lesen \(probe.readSucceeded ? "✓" : "–") · Löschen \(probe.deleteSucceeded ? "✓" : "–")")
                        .font(.caption2.monospaced())
                        .foregroundStyle(LH2GPXTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let detail = healthErrorDetail(for: probe) {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("options.icloud.health.errorDetail")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("options.icloud.health.card")
    }

    private var healthIconName: String {
        switch viewModel.healthStatus.accountStatus {
        case .available where viewModel.healthStatus.privateDatabaseReachability == .reachable:
            return "checkmark.seal.fill"
        case .available:
            return "checkmark.seal"
        case .signedOut:
            return "person.crop.circle.badge.exclamationmark"
        case .restricted:
            return "lock.shield"
        case .error, .couldNotDetermine, .temporarilyUnavailable:
            return "exclamationmark.triangle"
        case .disabled:
            return "icloud.slash"
        }
    }

    private var healthIconColor: Color {
        switch viewModel.healthStatus.accountStatus {
        case .available where viewModel.healthStatus.privateDatabaseReachability == .reachable:
            return .green
        case .available:
            return .primary
        case .error, .signedOut, .restricted, .couldNotDetermine, .temporarilyUnavailable:
            return .orange
        case .disabled:
            return .secondary
        }
    }

    /// Maps a HealthProbe failure to a user-facing German cause without
    /// leaking sensitive details. Returns `nil` when the probe succeeded.
    private func healthErrorDetail(for probe: ICloudHealthProbeResult) -> String? {
        if probe.writeSucceeded, probe.readSucceeded, probe.deleteSucceeded {
            return nil
        }
        switch viewModel.healthStatus.accountStatus {
        case .signedOut:
            return "Nicht bei iCloud angemeldet."
        case .restricted:
            return "iCloud ist auf diesem Gerät eingeschränkt."
        case .temporarilyUnavailable:
            return "Netzwerk nicht verfügbar oder iCloud vorübergehend offline."
        case .couldNotDetermine:
            return "CloudKit-Container nicht erreichbar."
        case .error:
            if !probe.writeSucceeded {
                return "Schreiben in privaten CloudKit-Bereich fehlgeschlagen."
            } else if !probe.readSucceeded {
                return "Lesen aus privatem CloudKit-Bereich fehlgeschlagen."
            } else if !probe.deleteSucceeded {
                return "Löschen aus privatem CloudKit-Bereich fehlgeschlagen."
            }
            return "Unbekannter CloudKit-Fehler."
        case .disabled, .available:
            return nil
        }
    }

    @ViewBuilder
    private var storageOverviewCard: some View {
        LHCard {
            LHSectionHeader("In iCloud gesichert")
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.storageOverview.summaryCount == 0,
                   viewModel.storageOverview.pointBatchCount == 0 {
                    Text(viewModel.status.accountStatus == .available
                        ? "Noch keine Daten in iCloud gesichert."
                        : "Übersicht verfügbar, sobald iCloud erreichbar ist.")
                        .font(.caption)
                        .foregroundStyle(LH2GPXTheme.textSecondary)
                } else {
                    overviewRow("LiveTrack-Metadaten", value: "\(viewModel.storageOverview.summaryCount)")
                    overviewRow("Routenpunkt-Batches", value: "\(viewModel.storageOverview.pointBatchCount)")
                    overviewRow("Geschätzte Routenpunkte", value: "\(viewModel.storageOverview.estimatedPointCount)")
                    overviewRow("Geschätzter Speicherverbrauch", value: ByteCountFormatter.string(fromByteCount: Int64(viewModel.storageOverview.estimatedStorageBytes), countStyle: .file))
                }
                if viewModel.pendingBackupCount > 0 {
                    overviewRow("Wartende Sicherungen", value: "\(viewModel.pendingBackupCount)")
                }
                HStack {
                    Button("Übersicht aktualisieren") {
                        Task { await viewModel.refreshOverview() }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("options.icloud.overview.refresh")

                    Button("Erneut versuchen") {
                        Task { await viewModel.retryPendingBackups() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.pendingBackupCount == 0)
                    .opacity(viewModel.pendingBackupCount == 0 ? 0.5 : 1.0)
                    .accessibilityIdentifier("options.icloud.backup.retry")
                    .accessibilityHint(Text("Versucht wartende iCloud-Sicherungen erneut."))
                }
                if viewModel.storageOverview.summaryCount > 0 || viewModel.storageOverview.pointBatchCount > 0 {
                    Button("Cloud-Daten löschen", role: .destructive) {
                        showsCloudDeleteConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("options.icloud.cloudData.delete")
                }
            }
        }
        .accessibilityIdentifier("options.icloud.storageOverview.card")
    }

    @ViewBuilder
    private var statusAutoRefreshCard: some View {
        LHCard {
            LHSectionHeader("Statusaktualisierung")
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.iCloudStatusAutoRefreshEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud-Status automatisch aktualisieren")
                            .font(.subheadline.weight(.semibold))
                        Text("Wenn aktiv, prüft die App die iCloud-Verfügbarkeit erneut, sobald diese Seite erscheint. Die manuelle Aktualisierung bleibt immer verfügbar.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier("options.icloud.autoRefresh.toggle")
            }
        }
        .accessibilityIdentifier("options.icloud.autoRefresh.card")
    }

    @ViewBuilder
    private var networkPolicyCard: some View {
        LHCard {
            LHSectionHeader("Netzwerkrichtlinie")
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.iCloudSyncAllowCellular) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mobilfunk für iCloud-Sync erlauben")
                            .font(.subheadline.weight(.semibold))
                        Text("Wenn aus, werden CloudKit-Sicherungen nicht über Mobilfunk gestartet.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier("options.icloud.cellular.toggle")
            }
        }
        .accessibilityIdentifier("options.icloud.cellular.card")
    }

    @ViewBuilder
    private var conflictPolicyCard: some View {
        LHCard {
            LHSectionHeader("Konfliktbehandlung")
            VStack(alignment: .leading, spacing: 10) {
                Picker("Konfliktbehandlung", selection: $preferences.iCloudSyncConflictPolicy) {
                    ForEach(AppICloudSyncConflictPolicy.allCases, id: \.self) { policy in
                        Text(policy.titleKey).tag(policy)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("options.icloud.conflictPolicy.picker")
                .accessibilityHint(Text("Wird bei späteren Konflikten konservativ angewendet."))

                Text(preferences.iCloudSyncConflictPolicy.captionKey)
                    .font(.caption)
                    .foregroundStyle(LH2GPXTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("options.icloud.conflictPolicy.caption")
            }
        }
        .accessibilityIdentifier("options.icloud.conflictPolicy.card")
    }

    @ViewBuilder
    private var containerInfoCard: some View {
        LHCard {
            LHSectionHeader("CloudKit-Container")
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Kennung")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LH2GPXTheme.textSecondary)
                    Spacer()
                    Text(CloudKitCloudSyncService.defaultContainerIdentifier)
                        .font(.caption2.monospaced())
                        .foregroundStyle(LH2GPXTheme.VariantBPro.terra300)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("options.icloud.container.id")
                }
                Text("Nur private CloudKit-Datenbank. Öffentliche und geteilte CloudKit-Datenbanken werden nicht verwendet. Keine Team-ID wird angezeigt.")
                    .font(.caption2)
                    .foregroundStyle(LH2GPXTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("options.icloud.container.card")
    }

    // MARK: - Mapping helpers

    static func cardKind(for status: CloudSyncAccountStatus) -> LHXSyncStatusCard.StatusKind {
        switch status {
        case .disabled:
            return .disabled
        case .available:
            return .available
        case .signedOut:
            return .signedOut
        case .restricted, .couldNotDetermine, .temporarilyUnavailable:
            return .unavailable
        case .error:
            return .error
        }
    }

    private func detailText(for status: CloudSyncAccountStatus) -> String {
        switch status {
        case .disabled:
            return "iCloud-Sync ist ausgeschaltet. Deine Daten bleiben auf diesem Gerät."
        case .available:
            return "Bei iCloud angemeldet. Der Status wird nur bei Bedarf geprüft."
        case .signedOut:
            return "Melde dich in den Systemeinstellungen bei iCloud an, um diese Funktion zu nutzen."
        case .restricted:
            return "iCloud ist auf diesem Gerät eingeschränkt."
        case .couldNotDetermine:
            return "iCloud-Kontostatus wird geprüft…"
        case .temporarilyUnavailable:
            return "iCloud ist vorübergehend nicht verfügbar. Bitte versuche es gleich erneut."
        case .error(let message):
            return message
        }
    }

    private var privacyFooterText: String {
        "Importierte Standortverläufe und Google-History-Daten werden nicht automatisch gesichert. LiveTrack-Backups sind Opt-in, nutzen ausschließlich deinen privaten CloudKit-Bereich und zeigen den Speicherverbrauch nur geschätzt an."
    }

    // MARK: - iCloud Drive export hint (Train F.3)

    /// User-initiated export-destination preference. Pure UX hint —
    /// toggling this does **not** change which file APIs the app uses
    /// or which entitlements the bundle ships with. The system
    /// `fileExporter` sheet already lists iCloud Drive automatically
    /// whenever the user is signed in to iCloud Drive. This toggle just
    /// surfaces an explicit "Suggest iCloud Drive" hint in the export
    /// screen so the destination is obvious before the system sheet
    /// opens.
    @ViewBuilder
    private var iCloudDriveExportHintCard: some View {
        LHCard {
            LHSectionHeader("Exportziel")
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.preferCloudDriveExport) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud Drive im Exportdialog vorschlagen")
                            .font(.subheadline.weight(.semibold))
                        Text("Zeigt einen Hinweis beim Export. Der Systemdialog fragt weiterhin nach dem Zielordner. GPX-Dateien werden nicht automatisch hochgeladen.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier("options.icloud.driveExportToggle")

                Text(iCloudDriveHintFooter)
                    .font(.caption2)
                    .foregroundStyle(LH2GPXTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("options.icloud.driveExportFooter")
            }
        }
    }

    private var iCloudDriveHintFooter: String {
        "Dieser Hinweis ist rein lokal. Die App benötigt iCloud Drive nicht; lokale Exporte funktionieren weiter."
    }

    private func t(_ english: String) -> String { preferences.localized(english) }

    @ViewBuilder
    private func overviewRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption)
                .foregroundStyle(LH2GPXTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#endif
