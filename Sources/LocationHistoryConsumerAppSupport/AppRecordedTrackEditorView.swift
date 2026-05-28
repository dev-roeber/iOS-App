#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit

@available(iOS 17.0, macOS 14.0, *)
struct AppRecordedTrackEditorView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var liveLocation: LiveLocationFeatureModel
    @State private var draft: RecordedTrackEditorDraft
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isShowingDeleteConfirmation = false

    init(track: RecordedTrack, liveLocation: LiveLocationFeatureModel) {
        self._liveLocation = ObservedObject(wrappedValue: liveLocation)
        self._draft = State(initialValue: RecordedTrackEditorDraft(track: track))
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            if isLandscape {
                landscapeLayout
            } else {
                // Phase B-7 (Train F.7): scaffolded layout on iOS 26+.
                // Legacy `portraitLayout` bleibt als iOS-17/25-Fallback und
                // als One-Line-Revert. Toolbar-Buttons (Done/Reset/Save/
                // Delete), Save-disabled-Condition, ImportedPath-/Recorded-
                // Track-Persistenz, Auto-Center und Draft-State unangetastet.
                if #available(iOS 26.0, *) {
                    scaffoldedEditorLayout
                } else {
                    portraitLayout
                }
            }
        }
        .navigationTitle(t("Edit Saved Track"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(t("Done")) {
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if draft.isModified {
                    Button(t("Reset")) {
                        draft.reset()
                    }
                }
                Button(t("Save")) {
                    saveTrack()
                }
                .disabled(draft.savedTrack == nil || !draft.isModified)
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(t("Delete"), role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
            }
        }
        .confirmationDialog(
            t("Delete saved track?"),
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(t("Delete Track"), role: .destructive) {
                liveLocation.deleteRecordedTrack(id: draft.originalTrack.id)
                dismiss()
            }
        } message: {
            Text(t("This removes the saved track from local storage."))
        }
        .task {
            centerMapOnTrack()
        }
        .onChange(of: draft.points) { _, _ in
            centerMapOnTrack()
        }
    }

    private var portraitLayout: some View {
        Form {
            summarySection
            mapSection
            pointsSection
        }
    }

    // MARK: - Phase B-7 (Train F.7): Scaffolded Editor Layout (iOS 26+)
    //
    // Map = bestehende `editorMap` mit `MapPolyline`-Halo+Stroke und Start-
    // /End-Markern, plus `editorMapLayerMenu` als topTrailing-Overlay direkt
    // am `editorMap` (Safe-Area-bewusst via LHMapBase-Tokens). FloatingChrome
    // slot ist bewusst `EmptyView()` — `editorMapLayerMenu` ist die einzige
    // Editor-Map-Affordance, ein zweites `LHMapFloatingChrome` wuerde sie
    // doppeln (dokumentierte Ausnahme, spiegelt Insights B-3, Map-Tab B-4,
    // Export B-5, Heatmap B-6).
    //
    // Sheet hostet Summary (Datum, Start/End, Punktanzahl, Distanz,
    // Validierungs-Message) und die Punkte-Liste. Toolbar mit Done/Reset/
    // Save/Delete bleibt aussen auf der `NavigationStack` — Save-disabled-
    // Condition `draft.savedTrack == nil || !draft.isModified` und alle
    // Aktionen unveraendert.
    //
    // Performance-Schutz: keine neue Route-Simplification, kein neuer
    // map/reduce/sorted-Hotloop, kein zusaetzlicher Camera-Reset, kein
    // neuer Task.detached. Track-Polyline-Cap und `MapTrackStyle.Width
    // .editor` bleiben strikt erhalten.

    @available(iOS 26.0, *)
    @ViewBuilder
    private var scaffoldedEditorLayout: some View {
        let bottomSafe = lhDeviceBottomSafeInset()
        let clearance = LHMapBase.bottomSheetTabBarClearance(
            deviceBottomSafeInset: bottomSafe
        )
        LHMapFirstPageScaffold(
            topSafeInset: lhDeviceTopSafeInset(),
            bottomSafeInset: bottomSafe,
            sheetBottomClearance: clearance
        ) {
            scaffoldedEditorMap
        } floatingChrome: {
            EmptyView()
        } sheet: {
            LHGlassBottomSheetDashboard(
                detents: .dayDetail,
                initialDetent: .medium,
                bottomClearance: clearance,
                accessibilityPrefix: "editor.scaffold.sheet"
            ) {
                scaffoldedEditorSheetHeader
            } body: {
                scaffoldedEditorSheetBody
            }
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var scaffoldedEditorMap: some View {
        editorMap
            .overlay(alignment: .topTrailing) {
                editorMapLayerMenu
                    .padding(.top, lhDeviceTopSafeInset() + LHMapBase.floatingControlTopGap)
                    .padding(.trailing, LHMapBase.floatingControlSideInset)
            }
            .accessibilityIdentifier("editor.scaffold.map")
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var scaffoldedEditorSheetHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t("EDITOR"))
                .font(.caption2.weight(.heavy))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            Text(t("Edit Saved Track"))
                .font(.title3.weight(.bold))
                .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                .fixedSize(horizontal: false, vertical: true)
            if draft.isModified {
                Text(t("Unsaved changes"))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("editor.scaffold.dirty")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var scaffoldedEditorSheetBody: some View {
        // Re-Use der bestehenden Form-Sections als Card-style Inhalt im
        // Sheet. Form selbst wuerde mit eigener Hintergrundfarbe brechen,
        // deshalb plain VStack mit den Section-Body-Inhalten.
        VStack(alignment: .leading, spacing: 16) {
            scaffoldedEditorSummaryCard
            scaffoldedEditorPointsCard
        }
        .accessibilityIdentifier("editor.scaffold.sheet.body")
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var scaffoldedEditorSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Summary"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
            scaffoldedEditorRow(t("Date"), value: AppDateDisplay.longDate(draft.dayKey))
            scaffoldedEditorRow(t("Started"), value: AppDateDisplay.abbreviatedDateTime(draft.startedAt))
            scaffoldedEditorRow(t("Ended"), value: AppDateDisplay.abbreviatedDateTime(draft.endedAt))
            scaffoldedEditorRow(t("Points"), value: "\(draft.pointCount)")
            scaffoldedEditorRow(t("Distance"), value: formatDistance(draft.distanceM, unit: preferences.distanceUnit))
            if let message = draft.validationMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lgGlassSurface(cornerRadius: 16)
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var scaffoldedEditorPointsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Points"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
            pointsSection
                .accessibilityIdentifier("editor.scaffold.pointsSection")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lgGlassSurface(cornerRadius: 16)
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func scaffoldedEditorRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
        }
    }

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            landscapeMapPanel
            Divider()
            landscapeFormPanel
        }
    }

    @ViewBuilder
    private var landscapeMapPanel: some View {
        GeometryReader { geo in
            editorMap
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .topTrailing) {
                editorMapLayerMenu
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var landscapeFormPanel: some View {
        Form {
            summarySection
            pointsSection
        }
        .frame(maxWidth: 400)
    }

    private var summarySection: some View {
        Section(t("Summary")) {
            LabeledContent(t("Date"), value: AppDateDisplay.longDate(draft.dayKey))
            LabeledContent(t("Started"), value: AppDateDisplay.abbreviatedDateTime(draft.startedAt))
            LabeledContent(t("Ended"), value: AppDateDisplay.abbreviatedDateTime(draft.endedAt))
            LabeledContent(t("Points"), value: "\(draft.pointCount)")
            LabeledContent(t("Distance"), value: formatDistance(draft.distanceM, unit: preferences.distanceUnit))
            if let message = draft.validationMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var mapSection: some View {
        Section(t("Map Preview")) {
            editorMap
            .frame(height: 220)
            .overlay(alignment: .topTrailing) {
                editorMapLayerMenu
                    .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var editorMap: some View {
        Map(position: $mapPosition) {
            if let first = draft.points.first {
                Marker(
                    t("Start"),
                    coordinate: CLLocationCoordinate2D(
                        latitude: first.latitude,
                        longitude: first.longitude
                    )
                )
                .tint(.green)
            }

            if let last = draft.points.last {
                Marker(
                    t("End"),
                    coordinate: CLLocationCoordinate2D(
                        latitude: last.latitude,
                        longitude: last.longitude
                    )
                )
                .tint(.red)
            }

            if draft.points.count >= 2 {
                let editorCoords = draft.points.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                MapPolyline(coordinates: editorCoords)
                    .stroke(
                        Color.white.opacity(MapTrackStyle.haloOpacity),
                        style: MapTrackStyle.stroke(width: MapTrackStyle.Width.editor * MapTrackStyle.haloMultiplier)
                    )
                MapPolyline(coordinates: editorCoords)
                    .stroke(.blue, style: MapTrackStyle.stroke(width: MapTrackStyle.Width.editor))
            }
        }
        .mapStyle(AppMapStyleResolver.mapStyle(
            for: preferences.preferredMapStyle,
            showsRealisticElevation: preferences.mapShowsRealisticElevation
        ))
    }

    private var editorMapLayerMenu: some View {
        MapLayerMenu(configuration: MapLayerMenu.Configuration(
            showsTrackColor: false,
            fitToData: draft.points.count >= 2 ? centerMapOnTrack : nil
        ))
        .accessibilityIdentifier("recordedTrackEditor.map.layerMenu")
    }

    private var pointsSection: some View {
        Section(t("Points")) {
            ForEach(Array(draft.points.enumerated()), id: \.offset) { index, point in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(pointLabel(index + 1))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(AppTimeDisplay.time(point.timestamp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextField(
                        t("Latitude"),
                        value: latitudeBinding(for: index),
                        format: .number.precision(.fractionLength(0...6))
                    )
                    .textFieldStyle(.roundedBorder)

                    TextField(
                        t("Longitude"),
                        value: longitudeBinding(for: index),
                        format: .number.precision(.fractionLength(0...6))
                    )
                    .textFieldStyle(.roundedBorder)

                    TextField(
                        t("Accuracy (m)"),
                        value: accuracyBinding(for: index),
                        format: .number.precision(.fractionLength(0...1))
                    )
                    .textFieldStyle(.roundedBorder)

                    HStack {
                        if index < draft.points.count - 1 {
                            Button {
                                draft.insertMidpoint(after: index)
                            } label: {
                                Label(t("Insert Midpoint"), systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            draft.deletePoints(at: IndexSet(integer: index))
                        } label: {
                            Label(t("Delete"), systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func latitudeBinding(for index: Int) -> Binding<Double> {
        Binding(
            get: { draft.points[index].latitude },
            set: { draft.updateCoordinate(at: index, latitude: $0) }
        )
    }

    private func longitudeBinding(for index: Int) -> Binding<Double> {
        Binding(
            get: { draft.points[index].longitude },
            set: { draft.updateCoordinate(at: index, longitude: $0) }
        )
    }

    private func accuracyBinding(for index: Int) -> Binding<Double> {
        Binding(
            get: { draft.points[index].horizontalAccuracyM },
            set: { draft.updateAccuracy(at: index, horizontalAccuracyM: max($0, 0)) }
        )
    }

    private func saveTrack() {
        guard let track = draft.savedTrack else {
            return
        }

        liveLocation.updateRecordedTrack(track)
        dismiss()
    }

    private func centerMapOnTrack() {
        guard let region = fittedRegion else {
            return
        }

        mapPosition = .region(region)
    }

    private var fittedRegion: MKCoordinateRegion? {
        guard let first = draft.points.first else {
            return nil
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for point in draft.points {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
                longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
            )
        )
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    private func pointLabel(_ index: Int) -> String {
        preferences.localized(format: "Point %d", arguments: [index])
    }
}
#endif
