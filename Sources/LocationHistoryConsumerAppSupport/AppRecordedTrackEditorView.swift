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
                portraitLayout
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
                    MapPolyline(coordinates: draft.points.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
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
                    MapPolyline(coordinates: draft.points.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
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
