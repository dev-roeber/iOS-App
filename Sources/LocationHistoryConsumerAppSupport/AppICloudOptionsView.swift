#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    /// Phase D.4 — visible action state for the storage-overview buttons.
    /// Lets the UI distinguish „button never pressed" / „running" /
    /// „succeeded but values unchanged" / „CloudKit-Fehler". Without this,
    /// the buttons looked dead in TestFlight.
    @Published private(set) var overviewActionState: ICloudOverviewActionState = .idle
    @Published private(set) var overviewActionMessage: String?
    @Published private(set) var overviewActionFailed: Bool = false

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

    /// Phase D.2 — used by the `.task` hook when the user has opted out
    /// of automatic CloudKit health checks. We still want to surface a
    /// fresh AccountStatus on screen appear (no network record traffic),
    /// but skip the heavier write/read/delete probe.
    func refreshAccountStatusOnly() async {
        await service.refresh()
        status = service.status
        isEnabled = service.isEnabled
    }

    func refreshOverview() async {
        guard overviewActionState == .idle else { return }
        overviewActionState = .refreshing
        overviewActionMessage = nil
        overviewActionFailed = false
        let updated = await backupService.refreshOverview()
        storageOverview = updated
        pendingBackupCount = backupService.pendingCount
        if let errorMessage = updated.errorMessage, !errorMessage.isEmpty {
            overviewActionFailed = true
            overviewActionMessage = errorMessage
        } else {
            overviewActionFailed = false
            overviewActionMessage = "Übersicht aktualisiert."
        }
        overviewActionState = .idle
    }

    func retryPendingBackups() async {
        guard overviewActionState == .idle else { return }
        // Phase D.4 — don't look dead when there is nothing to retry.
        guard pendingBackupCount > 0 else {
            overviewActionFailed = false
            overviewActionMessage = "Keine wartenden Sicherungen."
            return
        }
        overviewActionState = .retrying
        overviewActionMessage = nil
        overviewActionFailed = false
        await backupService.retryPendingBackups()
        let updated = await backupService.refreshOverview()
        storageOverview = updated
        pendingBackupCount = backupService.pendingCount
        if let errorMessage = updated.errorMessage, !errorMessage.isEmpty {
            overviewActionFailed = true
            overviewActionMessage = errorMessage
        } else if pendingBackupCount == 0 {
            overviewActionFailed = false
            overviewActionMessage = "Wartende Sicherungen erfolgreich gesendet."
        } else {
            overviewActionFailed = false
            overviewActionMessage = "Erneut versucht — \(pendingBackupCount) Sicherung(en) noch wartend."
        }
        overviewActionState = .idle
    }

    func deleteCloudData() async {
        guard overviewActionState == .idle else { return }
        overviewActionState = .deleting
        overviewActionMessage = nil
        overviewActionFailed = false
        do {
            try await backupService.deleteCloudData()
            storageOverview = backupService.overview
            pendingBackupCount = backupService.pendingCount
            overviewActionFailed = false
            overviewActionMessage = "Cloud-Daten gelöscht."
        } catch {
            overviewActionFailed = true
            // Surface the underlying CKError code where possible so the
            // user/TestFlight tester knows whether it was a permission,
            // schema, network or quota issue (Phase D.4). CKError bridges
            // to NSError with domain == CKErrorDomain — we read `.code`
            // and map it via the Foundation-only `ICloudCKErrorMapping`.
            let ckHint = ICloudActionErrorRendering.hint(for: error)
            overviewActionMessage = "Cloud-Daten konnten nicht gelöscht werden: \(ckHint)"
            storageOverview.errorMessage = overviewActionMessage
        }
        overviewActionState = .idle
    }
}

/// Phase D.4 — visible action state for storage-overview buttons.
public enum ICloudOverviewActionState: String, Equatable, Sendable {
    case idle
    case refreshing
    case retrying
    case deleting
}

/// Phase D.4 — Foundation-only helper that extracts a German hint from
/// any `Error` that bridges to `NSError(domain: CKErrorDomain)`. Stays
/// on the value-type side so Linux tests do not need `import CloudKit`.
public enum ICloudActionErrorRendering {
    public static let cloudKitErrorDomain = "CKErrorDomain"

    public static func hint(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == cloudKitErrorDomain {
            let mapping = ICloudCKErrorMapping.mapping(forRawCode: nsError.code)
            // Korrigiert: zeige IMMER den Roh-Fehler von Apple mit, nicht
            // nur unseren Hint. Frühere Versionen haben „Schema deployen"
            // als alleinigen Text gezeigt, was bei bereits deploytem Schema
            // den Nutzer auf eine falsche Spur geführt hat.
            var raw = nsError.localizedDescription
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                raw += " · Underlying: \(underlying.domain) #\(underlying.code) \(underlying.localizedDescription)"
            }
            if let serverMsg = nsError.userInfo["ServerErrorDescription"] as? String, !serverMsg.isEmpty {
                raw += " · Server: \(serverMsg)"
            }
            return "CKError #\(nsError.code) \(mapping.codeName) — \(mapping.germanHint)\n\nRoh: \(raw)"
        }
        return nsError.localizedDescription.isEmpty
            ? "Unbekannter Fehler."
            : nsError.localizedDescription
    }
}

// MARK: - LGICloudSection

/// Prompt 04 — Liquid-Glass-Section-Shell für die iCloud-Settings. Ersetzt
/// das vorher genutzte `LHCard` (dunkles Warm-Variant-B-Pro-Chrome) durch
/// die helle `LHLiquidGlassSurface`. Drop-in-Wrapper: gleiche Semantik
/// (VStack, leading-aligned, spacing 12) wie `LHCard`, nur eben Light-LG.
/// Bewusst lokal gehalten, damit andere Screens unverändert weiterlaufen.
struct LGICloudSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        LHLiquidGlassSurface {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    @StateObject private var liveTrackCloudActions: LiveTrackCloudRestoreService
    @StateObject private var favoriteCloudSync: FavoriteEntryCloudSyncCoordinator
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
        let backupService: LiveTrackCloudBackupService = {
            // Phase D.2 / Prompt 2 — pluggable health-gate. Reads the
            // latest health-check service status, so manual upload does
            // not bypass a red private-database probe.
            return LiveTrackCloudBackupFactory.makeProductionService(
                settingsProvider: { preferences.liveTrackCloudBackupSettings },
                healthGate: { healthCheckService.status.isOperational }
            )
        }()
        self._viewModel = StateObject(
            wrappedValue: ICloudSyncViewModel(
                service: service,
                healthCheckService: healthCheckService,
                backupService: backupService
            )
        )
        self._liveTrackCloudActions = StateObject(
            wrappedValue: LiveTrackCloudRestoreService(
                coordinator: backupService,
                trackStore: RecordedTrackFileStore()
            )
        )
        // Phase F — Coordinator für FavoriteEntry-CloudKit-Sync.
        let favoriteStore = (try? FavoriteEntryStore()) ?? FavoriteEntryStore.makeInMemoryFallback()
        let favoriteCloud: FavoriteEntryCloudSyncing
        #if canImport(CloudKit)
        favoriteCloud = CloudKitFavoriteEntryCloudSync()
        #else
        favoriteCloud = NoopFavoriteEntryCloudSync()
        #endif
        self._favoriteCloudSync = StateObject(
            wrappedValue: FavoriteEntryCloudSyncCoordinator(
                store: favoriteStore,
                cloud: favoriteCloud
            )
        )
    }

    public var body: some View {
        ScrollView {
            LHPageScaffold {
                LHXSyncStatusCard(
                    kind: Self.cardKind(for: viewModel.status.accountStatus,
                                        healthStatus: viewModel.healthStatus),
                    title: "iCloud-Sync",
                    detail: topStatusDetailText(),
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
                manualLiveTrackCloudActionsCard
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
        // Prompt 04 — iCloud-Settings auf Liquid Glass (Light-Map-Stil).
        // Vorher: warmes Dunkelbraun `bgWarm`, das nicht zum Rest der
        // Settings-Unterseiten passte (Audit P0.2 + P1.5). Jetzt: gleicher
        // Light-Hintergrund wie alle anderen LG-Screens, mit dezenten
        // Karten-Wave-Linien.
        .background(LHLiquidGlassBackground())
        .task {
            // Phase D.2 — respect the user preference. The dedicated
            // „Status aktualisieren" button stays available regardless.
            if preferences.iCloudStatusAutoRefreshEnabled {
                await viewModel.refresh()
            } else {
                await viewModel.refreshAccountStatusOnly()
            }
        }
        .onChange(of: preferences.iCloudSyncEnabled) { _, newValue in
            Task { await viewModel.setEnabled(newValue) }
        }
        .onChange(of: preferences.iCloudStatusAutoRefreshEnabled) { _, newValue in
            guard newValue else { return }
            Task { await viewModel.refresh() }
        }
        // Prompt 04 — Audit C10: Vorher `.alert`, dessen Hintergrund im
        // alten Dark-Mode-Layer (IMG_5101) kaum lesbar war. Wir wechseln
        // auf `.confirmationDialog`, weil dieser automatisch System-Glas
        // nutzt und in Light + Dark adaptiv rendert.
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
        LGICloudSection {
            LHSectionHeader("In iCloud sichern")
            VStack(alignment: .leading, spacing: 10) {
                if !preferences.iCloudSyncEnabled {
                    Label("iCloud-Sync ist deaktiviert — bitte oben aktivieren, um Sicherungsoptionen auszuwählen.", systemImage: "icloud.slash")
                        .font(.caption)
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("options.icloud.backupSelection.gateHint")
                }
                Toggle(isOn: $preferences.syncLiveTrackMetadataEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LiveTrack-Metadaten")
                            .font(.subheadline.weight(.semibold))
                        Text("Name, Zeitraum, Distanz und technische Zusammenfassung eines LiveTracks.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
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
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(!preferences.iCloudSyncEnabled)
                .accessibilityIdentifier("options.icloud.pointBatches.toggle")
                .accessibilityLabel(Text("LiveTrack-Routenpunkte. Sensible Standortdaten."))

                Toggle(isOn: $preferences.syncCloudFilesEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .accessibilityHidden(true)
                            Text("Cloud-Dateien")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("GPX-, KML- und ZIP-Dateien werden nur nach ausdrücklicher Datei-Auswahl hochgeladen. Enthält möglicherweise Standortdaten.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(!preferences.iCloudSyncEnabled)
                .accessibilityIdentifier("options.icloud.cloudFiles.toggle")
                .accessibilityLabel(Text("Cloud-Dateien. Enthält möglicherweise Standortdaten."))

                // Phase F — echter CloudKit-Sync für lokale Favoriten.
                Toggle(isOn: $preferences.syncFavoritesEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)
                            Text(t("Favorites"))
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("Synchronisiert deine lokalen Favoriten (Tage) bidirektional mit der privaten iCloud-Datenbank. Keine Standortdaten.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(!preferences.iCloudSyncEnabled)
                .accessibilityIdentifier("options.icloud.favorites.toggle")
                .onChange(of: preferences.syncFavoritesEnabled) { _, newValue in
                    // Phase F — beim Aktivieren sofort einen Sync triggern.
                    // Das legt den LH2GPXFavoriteEntry-RecordType im
                    // CloudKit-Schema automatisch an (Apple's first-save-
                    // defines-schema-Mechanik).
                    if newValue && preferences.iCloudSyncEnabled {
                        Task { await favoriteCloudSync.sync() }
                    }
                }

                if preferences.syncFavoritesEnabled && preferences.iCloudSyncEnabled {
                    HStack(spacing: 8) {
                        Button {
                            Task { await favoriteCloudSync.sync() }
                        } label: {
                            if favoriteCloudSync.actionState == .syncing {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("Synchronisiere…")
                                }
                            } else {
                                Label("Favoriten jetzt synchronisieren",
                                      systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(favoriteCloudSync.actionState != .idle)
                        .accessibilityIdentifier("options.icloud.favorites.syncNow")
                        Spacer()
                    }
                    if let message = favoriteCloudSync.actionMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(favoriteCloudSync.actionFailed ? .orange : LH2GPXTheme.LiquidGlass.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("options.icloud.favorites.message")
                    }
                }

                Toggle(isOn: $preferences.syncAppSettingsEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App-Einstellungen")
                            .font(.subheadline.weight(.semibold))
                        Text("Nur iCloud-bezogene Einstellungen und Anzeigeoptionen.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
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
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
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
        LGICloudSection {
            LHSectionHeader("Automatische Sicherung")
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.automaticLiveTrackICloudBackupEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LiveTracks automatisch in iCloud sichern")
                            .font(.subheadline.weight(.semibold))
                        Text("Wenn aktiviert, werden neu abgeschlossene LiveTracks nach dem Speichern zusätzlich in deinem privaten iCloud-Bereich gesichert. Importierte Google-History-Daten werden nicht automatisch hochgeladen.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(!preferences.iCloudSyncEnabled || !preferences.syncLiveTrackMetadataEnabled)
                .accessibilityIdentifier("options.icloud.automaticLiveTrackBackup.toggle")

                if preferences.iCloudSyncEnabled
                    && preferences.syncLiveTrackMetadataEnabled
                    && preferences.automaticLiveTrackICloudBackupEnabled
                    && !viewModel.healthStatus.isOperational {
                    Label("Sicherung pausiert — CloudKit-Health-Check ist rot. Neue LiveTracks werden lokal vorgemerkt und automatisch hochgeladen, sobald der private CloudKit-Speicher wieder erreichbar ist.",
                          systemImage: "pause.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("options.icloud.automaticLiveTrackBackup.pauseHint")
                }
            }
        }
        .accessibilityIdentifier("options.icloud.automaticLiveTrackBackup.card")
    }

    @ViewBuilder
    private var manualLiveTrackCloudActionsCard: some View {
        LGICloudSection {
            LHSectionHeader("LiveTracks manuell sichern")
            VStack(alignment: .leading, spacing: 12) {
                Text("Upload und Wiederherstellung nutzen die bestehenden LiveTrack-Records in deinem privaten iCloud-Bereich. Google-History-Importe und exportierte Dateien werden hier nicht hochgeladen.")
                    .font(.caption)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await liveTrackCloudActions.uploadLatestLocalTrack(
                                includePointBatches: preferences.syncLiveTrackPointBatchesEnabled
                            )
                            await viewModel.refreshOverview()
                        }
                    } label: {
                        if liveTrackCloudActions.actionState == .uploading {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Lade hoch…")
                            }
                        } else {
                            Text(t("Upload Latest"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        !preferences.iCloudSyncEnabled
                        || !preferences.syncLiveTrackMetadataEnabled
                        || liveTrackCloudActions.actionState != .idle
                    )
                    .accessibilityIdentifier(AppAccessibilityID.ICloud.liveTrackActionsUpload)

                    Button {
                        Task { await liveTrackCloudActions.loadAvailable() }
                    } label: {
                        if liveTrackCloudActions.actionState == .loading {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Lade…")
                            }
                        } else {
                            Text("Cloud-LiveTracks laden")
                        }
                    }
                    .buttonStyle(.bordered)
                    // Fix B-Neu5: Gate identisch zum Upload-Button (auch
                    // syncLiveTrackMetadataEnabled fordern, sonst lädt Restore
                    // gegen ein vom Nutzer abgeschaltetes Sync-Feature).
                    .disabled(
                        !preferences.iCloudSyncEnabled
                        || !preferences.syncLiveTrackMetadataEnabled
                        || liveTrackCloudActions.actionState != .idle
                    )
                    .accessibilityIdentifier(AppAccessibilityID.ICloud.liveTrackActionsLoadCloud)
                }

                if !preferences.iCloudSyncEnabled || !preferences.syncLiveTrackMetadataEnabled {
                    Label("Aktiviere iCloud-Sync und LiveTrack-Metadaten, bevor du manuell hochlädst.", systemImage: "icloud.slash")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !liveTrackCloudActions.availableEnvelopes.isEmpty {
                    Divider()
                    ForEach(liveTrackCloudActions.availableEnvelopes) { envelope in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(envelope.summary.title)
                                    .font(.caption.weight(.semibold))
                                Text("\(Self.shortDateFormatter.string(from: envelope.summary.startedAt)) · \(envelope.summary.pointCount) Punkte")
                                    .font(.caption2)
                                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                            }
                            Spacer()
                            Button {
                                Task { _ = await liveTrackCloudActions.restore(envelope) }
                            } label: {
                                if liveTrackCloudActions.actionState == .restoring {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text(t("Restore"))
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(liveTrackCloudActions.actionState != .idle)
                            .accessibilityIdentifier(AppAccessibilityID.ICloud.liveTrackActionsRestore)
                        }
                    }
                }

                if let message = liveTrackCloudActions.actionMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(liveTrackCloudActions.actionFailed ? .orange : LH2GPXTheme.LiquidGlass.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(AppAccessibilityID.ICloud.liveTrackActionsMessage)
                }
            }
            .animation(.default, value: liveTrackCloudActions.actionState)
        }
        .accessibilityIdentifier(AppAccessibilityID.ICloud.liveTrackActionsCard)
    }

    @ViewBuilder
    private var healthCheckCard: some View {
        LGICloudSection {
            LHSectionHeader("CloudKit-Health-Check")
            VStack(alignment: .leading, spacing: 8) {
                Label(viewModel.healthStatus.userFacingStatusKey, systemImage: healthIconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(healthIconColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let probe = viewModel.healthStatus.lastProbeResult {
                    Text("Letzte Prüfung: \(Self.shortDateFormatter.string(from: probe.checkedAt)) · \(String(format: "%.2f", probe.durationSeconds)) s")
                        .font(.caption)
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Schreiben \(probe.writeSucceeded ? "✓" : "–") · Lesen \(probe.readSucceeded ? "✓" : "–") · Löschen \(probe.deleteSucceeded ? "✓" : "–")")
                        .font(.caption2.monospaced())
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // Phase D.2 — surface the exact failure stage + CKError code so
                    // TestFlight diagnostics no longer hide the root cause behind
                    // a generic „Schreiben fehlgeschlagen".
                    if let stage = probe.errorStage {
                        Text("Fehler in Phase: \(Self.germanStageLabel(stage))")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("options.icloud.health.errorStage")
                    }
                    if let ckName = probe.ckErrorCodeName {
                        Text("CKError.\(ckName)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("options.icloud.health.ckErrorCode")
                    }
                    if let retry = probe.retryAfterSeconds {
                        Text("Erneut in \(Int(retry.rounded())) s versuchen")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("options.icloud.health.retryAfter")
                    }
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
        // Phase D.2 — prefer the precise mapping hint from the CKError-code
        // table when available; fall back to a generic per-stage message.
        if let message = probe.errorMessage, !message.isEmpty {
            return message
        }
        switch probe.errorStage {
        case .accountStatus:
            return "iCloud-Kontostatus konnte nicht gelesen werden."
        case .write:
            return "Schreiben in privaten CloudKit-Bereich fehlgeschlagen."
        case .read:
            return "Lesen aus privatem CloudKit-Bereich fehlgeschlagen."
        case .delete:
            return "Löschen aus privatem CloudKit-Bereich fehlgeschlagen."
        case nil:
            // No CK error but flags say not-all-three; treat as generic.
            return "CloudKit-Test unvollständig."
        }
    }

    @ViewBuilder
    private var storageOverviewCard: some View {
        LGICloudSection {
            LHSectionHeader("In iCloud gesichert")
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.storageOverview.summaryCount == 0,
                   viewModel.storageOverview.pointBatchCount == 0 {
                    Text(viewModel.status.accountStatus == .available
                        ? "Noch keine Daten in iCloud gesichert."
                        : "Übersicht verfügbar, sobald iCloud erreichbar ist.")
                        .font(.caption)
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                } else {
                    overviewRow("LiveTrack-Metadaten", value: "\(viewModel.storageOverview.summaryCount)")
                    overviewRow("Routenpunkt-Batches", value: "\(viewModel.storageOverview.pointBatchCount)")
                    overviewRow("Geschätzte Routenpunkte", value: "\(viewModel.storageOverview.estimatedPointCount)")
                    overviewRow("Geschätzter Speicherverbrauch", value: ByteCountFormatter.string(fromByteCount: Int64(viewModel.storageOverview.estimatedStorageBytes), countStyle: .file))
                }
                if viewModel.pendingBackupCount > 0 {
                    overviewRow("Wartende Sicherungen", value: "\(viewModel.pendingBackupCount)")
                }
                // Phase D.4 — visible „last checked" timestamp so the user
                // can tell whether the overview is fresh.
                if let lastChecked = viewModel.storageOverview.lastCloudKitStatusCheckAt {
                    Text("Zuletzt geprüft: \(Self.shortDateFormatter.string(from: lastChecked))")
                        .font(.caption2)
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                        .accessibilityIdentifier("options.icloud.overview.lastChecked")
                }
                // Phase D.4 — action HStack with progress-aware labels and
                // single-flight gating via `overviewActionState`.
                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.refreshOverview() }
                    } label: {
                        if viewModel.overviewActionState == .refreshing {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Aktualisiere…")
                            }
                        } else {
                            Text(t("Refresh Overview"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.overviewActionState != .idle)
                    .accessibilityIdentifier("options.icloud.overview.refresh")

                    // Phase D.4 — only render retry button when there is
                    // actually pending work; eliminates the „dead button"
                    // perception when count is zero.
                    if viewModel.pendingBackupCount > 0 {
                        Button {
                            Task { await viewModel.retryPendingBackups() }
                        } label: {
                            if viewModel.overviewActionState == .retrying {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("Wiederhole…")
                                }
                            } else {
                                Text(t("Try Again"))
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.overviewActionState != .idle)
                        .accessibilityIdentifier("options.icloud.backup.retry")
                        .accessibilityHint(Text("Versucht wartende iCloud-Sicherungen erneut."))
                    }
                }
                if viewModel.storageOverview.summaryCount > 0 || viewModel.storageOverview.pointBatchCount > 0 {
                    Divider()
                    Button(role: .destructive) {
                        showsCloudDeleteConfirmation = true
                    } label: {
                        if viewModel.overviewActionState == .deleting {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Lösche…")
                            }
                        } else {
                            Text("Cloud-Daten löschen")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.overviewActionState != .idle)
                    .accessibilityIdentifier("options.icloud.cloudData.delete")
                }
                // Phase D.4 — visible action feedback. Without this the
                // buttons looked dead in TestFlight even when CloudKit
                // was fine and the values just hadn't changed.
                if let message = viewModel.overviewActionMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(viewModel.overviewActionFailed ? .orange : LH2GPXTheme.LiquidGlass.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("options.icloud.overview.actionMessage")
                }
                if let storageError = viewModel.storageOverview.errorMessage,
                   !storageError.isEmpty,
                   storageError != viewModel.overviewActionMessage {
                    Text(storageError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("options.icloud.overview.errorMessage")
                }
            }
            .animation(.default, value: viewModel.overviewActionState)
        }
        .accessibilityIdentifier("options.icloud.storageOverview.card")
    }

    @ViewBuilder
    private var statusAutoRefreshCard: some View {
        LGICloudSection {
            LHSectionHeader("Statusaktualisierung")
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.iCloudStatusAutoRefreshEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud-Status automatisch aktualisieren")
                            .font(.subheadline.weight(.semibold))
                        Text("Wenn aktiv, prüft die App die iCloud-Verfügbarkeit erneut, sobald diese Seite erscheint. Die manuelle Aktualisierung bleibt immer verfügbar.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
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
        LGICloudSection {
            LHSectionHeader("Netzwerkrichtlinie")
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.iCloudSyncAllowCellular) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mobilfunk für iCloud-Sync erlauben")
                            .font(.subheadline.weight(.semibold))
                        Text("Wenn aus, werden CloudKit-Sicherungen nicht über Mobilfunk gestartet.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
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
        LGICloudSection {
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
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("options.icloud.conflictPolicy.caption")
            }
            // Phase D.3 layout fix — the `.menu` picker's intrinsic width
            // is narrow, which made this card visibly shrink-wrap while
            // the sibling cards (Toggle/HStack-based) auto-expand. Force
            // the inner VStack to fill the available width so all iCloud
            // cards look uniform.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("options.icloud.conflictPolicy.card")
    }

    @ViewBuilder
    private var containerInfoCard: some View {
        LGICloudSection {
            LHSectionHeader("CloudKit-Container")
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(t("Identifier"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                    Spacer()
                    Text(CloudKitCloudSyncService.defaultContainerIdentifier)
                        .font(.caption2.monospaced())
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("options.icloud.container.id")
                    // Prompt 04 — Copy-Button für Container-ID. Spec verlangt
                    // einen sichtbaren Knopf, der die ID ins Clipboard legt.
                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = CloudKitCloudSyncService.defaultContainerIdentifier
                        #endif
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("CloudKit-Container-ID kopieren")
                    .accessibilityIdentifier("options.icloud.container.copy")
                }
                Text("Nur private CloudKit-Datenbank. Öffentliche und geteilte CloudKit-Datenbanken werden nicht verwendet. Keine Team-ID wird angezeigt.")
                    .font(.caption2)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
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

    /// Phase D.2 — the top status card must NOT look green when iCloud
    /// account is available but the private CloudKit database probe is
    /// red. Downgrade the visual badge in that combined case.
    static func cardKind(
        for status: CloudSyncAccountStatus,
        healthStatus: ICloudHealthStatus
    ) -> LHXSyncStatusCard.StatusKind {
        let raw = cardKind(for: status)
        if raw == .available && healthStatus.privateDatabaseReachability == .failed {
            return .error
        }
        return raw
    }

    /// Phase D.2 — combined detail text: account status + private DB summary,
    /// so the top card never claims everything is fine when the health
    /// probe failed.
    private func topStatusDetailText() -> String {
        switch viewModel.healthStatus.accountStatus {
        case .available:
            switch viewModel.healthStatus.privateDatabaseReachability {
            case .reachable:
                return "iCloud-Konto verfügbar · privater CloudKit-Speicher erreichbar."
            case .failed:
                return "iCloud-Konto verfügbar · privater CloudKit-Speicher NICHT schreibbar (siehe Health-Check)."
            case .unavailable:
                return "iCloud-Konto verfügbar · CloudKit-Speicher derzeit nicht erreichbar."
            case .notChecked:
                return "iCloud-Konto verfügbar · CloudKit-Speicher noch nicht geprüft."
            }
        default:
            return detailText(for: viewModel.healthStatus.accountStatus)
        }
    }

    /// Phase D.2 — German label for `ICloudHealthProbeStage` shown in the
    /// Health-Check card so the user understands which stage failed.
    static func germanStageLabel(_ stage: ICloudHealthProbeStage) -> String {
        switch stage {
        case .accountStatus: return "Kontostatus"
        case .write:         return "Schreiben"
        case .read:          return "Lesen"
        case .delete:        return "Löschen"
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
        LGICloudSection {
            LHSectionHeader("Exportziel")
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.preferCloudDriveExport) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud Drive im Exportdialog vorschlagen")
                            .font(.subheadline.weight(.semibold))
                        Text("Zeigt einen Hinweis beim Export. Der Systemdialog fragt weiterhin nach dem Zielordner. GPX-Dateien werden nicht automatisch hochgeladen.")
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier("options.icloud.driveExportToggle")

                Text(iCloudDriveHintFooter)
                    .font(.caption2)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
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
                .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
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
