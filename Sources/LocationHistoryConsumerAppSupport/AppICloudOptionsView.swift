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

    private let service: CloudSyncService

    init(service: CloudSyncService) {
        self.service = service
        self.status = service.status
        self.isEnabled = service.isEnabled
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

    public init(preferences: AppPreferences) {
        self._preferences = ObservedObject(wrappedValue: preferences)
        let service = CloudSyncServiceFactory.makeProductionService(
            isEnabled: preferences.iCloudSyncEnabled
        )
        self._viewModel = StateObject(
            wrappedValue: ICloudSyncViewModel(service: service)
        )
    }

    public var body: some View {
        ScrollView {
            LHPageScaffold {
                LHXSyncStatusCard(
                    kind: Self.cardKind(for: viewModel.status.accountStatus),
                    title: t("iCloud Sync"),
                    detail: detailText(for: viewModel.status.accountStatus),
                    lastSyncText: nil,
                    toggleActionTitle: viewModel.isEnabled
                        ? t("Disable iCloud Sync")
                        : t("Enable iCloud Sync"),
                    toggleAction: {
                        preferences.iCloudSyncEnabled.toggle()
                    },
                    accessibilityIdentifier: "options.icloud.statusCard"
                )

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label(t("Refresh status"), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.status.isWorking)
                .accessibilityIdentifier("options.icloud.refresh")
                .accessibilityLabel(t("Refresh iCloud account status"))
                .accessibilityHint(viewModel.status.isWorking
                    ? t("Checking iCloud — please wait until the current check finishes.")
                    : t("Re-checks whether iCloud is available on this device. No data is uploaded."))

                iCloudDriveExportHintCard

                metadataSyncPreparationCard
                statusAutoRefreshCard
                networkPolicyCard
                conflictPolicyCard
                containerInfoCard
                deferredCloudActionsCard

                LHXInfoCard(
                    kind: .info,
                    title: t("Privacy"),
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
    }

    // MARK: - Variant B Pro · Extended iCloud Settings (Train 2026-05-25)

    @ViewBuilder
    private var metadataSyncPreparationCard: some View {
        LHCard {
            LHSectionHeader(t("Metadata Sync"))
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.syncLiveTrackMetadataEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Prepare live-track metadata sync"))
                            .font(.subheadline.weight(.semibold))
                        Text(t("Acknowledges the LiveTrackMeta private-database schema. No records are written or read yet — this gate only opts the device in to the future sync engine."))
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier("options.icloud.metadataSync.toggle")
                .accessibilityHint(Text(t("Off until the dedicated sync-engine train ships. Toggling this preference today has no network or CloudKit effect.")))
            }
        }
        .accessibilityIdentifier("options.icloud.metadataSync.card")
    }

    @ViewBuilder
    private var statusAutoRefreshCard: some View {
        LHCard {
            LHSectionHeader(t("Status Refresh"))
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.iCloudStatusAutoRefreshEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Refresh iCloud status automatically"))
                            .font(.subheadline.weight(.semibold))
                        Text(t("When on, the app re-checks iCloud account availability whenever this screen appears. The manual refresh button keeps working in either case."))
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
            LHSectionHeader(t("Network Policy"))
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.iCloudSyncAllowCellular) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Allow iCloud sync over cellular"))
                            .font(.subheadline.weight(.semibold))
                        Text(t("Reserved for the future sync engine. Off keeps any future record traffic on Wi-Fi only. Has no effect today because no records are written."))
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
            LHSectionHeader(t("Conflict Policy"))
            VStack(alignment: .leading, spacing: 10) {
                Picker(t("Conflict Policy"), selection: $preferences.iCloudSyncConflictPolicy) {
                    ForEach(AppICloudSyncConflictPolicy.allCases, id: \.self) { policy in
                        Text(t(policy.titleKey)).tag(policy)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("options.icloud.conflictPolicy.picker")
                .accessibilityHint(Text(t("Stored only. Will be applied by the future sync engine.")))

                Text(t(preferences.iCloudSyncConflictPolicy.captionKey))
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
            LHSectionHeader(t("Container"))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(t("Identifier"))
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
                Text(t("Private CloudKit database only. No public or shared database is ever queried. No team identifier is shown."))
                    .font(.caption2)
                    .foregroundStyle(LH2GPXTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("options.icloud.container.card")
    }

    @ViewBuilder
    private var deferredCloudActionsCard: some View {
        LHCard {
            LHSectionHeader(t("Deferred Cloud Actions"))
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Delete cloud metadata"))
                            .font(.subheadline.weight(.semibold))
                        Text(t("Available after the sync engine ships. No records exist yet, so there is nothing to delete on the server side."))
                            .font(.caption)
                            .foregroundStyle(LH2GPXTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "trash.slash")
                        .foregroundStyle(LH2GPXTheme.textTertiary)
                }
                .opacity(0.55)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("options.icloud.deferred.deleteMetadata")
                .accessibilityHint(Text(t("Disabled. Will become available once the iCloud sync engine writes records.")))

                Text(t("No imported-history sync. No automatic upload. Metadata schema only until the sync engine is enabled."))
                    .font(.caption2)
                    .foregroundStyle(LH2GPXTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("options.icloud.deferred.disclaimer")
            }
        }
        .accessibilityIdentifier("options.icloud.deferred.card")
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
            return t("iCloud sync is turned off. All your data stays on this device.")
        case .available:
            return t("Signed in to iCloud. Status is checked on demand — no data is uploaded automatically.")
        case .signedOut:
            return t("Sign in to iCloud in System Settings to use this feature.")
        case .restricted:
            return t("iCloud is restricted on this device (parental controls or device management).")
        case .couldNotDetermine:
            return t("Checking iCloud account status…")
        case .temporarilyUnavailable:
            return t("iCloud is temporarily unavailable. Please retry in a moment.")
        case .error(let message):
            return message
        }
    }

    private var privacyFooterText: String {
        t("Your imported location history is never uploaded. This screen only checks Apple's iCloud account availability — no records are written, no automatic sync happens, no data leaves the device in this version.")
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
            LHSectionHeader(t("Export Destination"))
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $preferences.preferCloudDriveExport) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Suggest iCloud Drive in export sheet"))
                            .font(.subheadline.weight(.semibold))
                        Text(t("Adds a visible hint next to the Export Destination card. The system save sheet still asks you which folder to use — nothing is uploaded automatically."))
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
        t("This hint is purely cosmetic. The app does not require iCloud Drive — local export keeps working, and the system picker controls the final destination.")
    }

    private func t(_ english: String) -> String { preferences.localized(english) }
}

#endif
