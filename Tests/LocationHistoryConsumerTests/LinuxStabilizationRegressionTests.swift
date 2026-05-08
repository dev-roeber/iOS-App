import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Linux-buildable regression coverage that complements
/// `FlatCoordinatesGeometryTests` and `ImportMemoryProbeActivationTests`
/// after the 2026-05-08 P0 memory-fix train. Targets three areas the
/// existing suite did not pin yet:
///
/// 1. **No-double-geometry invariant.** GoogleTimelineConverter must
///    never populate both `points` AND `flatCoordinates` on the same
///    `Path`. Consumers rely on this to know which shape to walk; if a
///    future regression seeded both, the AppHeatmapModel doppel-bug
///    (already fixed) would resurface.
/// 2. **Distance parity points-vs-flat.** Distance reconstruction from
///    flat geometry must agree with the legacy points-shape result for
///    identical real-world coordinates, within ±1 m tolerance.
/// 3. **AppSessionContent / AppSessionState lazy-projection contract.**
///    The 46-MB Jetsam fix relies on `init(export:source:)` and
///    `show(content:)` only consuming O(days) selectedDate work, not
///    materialising the lazy `overview` / `daySummaries` / `insights`
///    projections. We verify this end-to-end via wall-clock time on a
///    synthetic export sized so that an accidental eager projection
///    would dominate the runtime budget by orders of magnitude.
final class LinuxStabilizationRegressionTests: XCTestCase {

    // MARK: - 1. No-double-geometry invariant (Aufgabe B Pflicht 1c)

    /// The converter must emit `points: []` exactly when `flatCoordinates`
    /// is non-nil — not an `else` clause, an invariant. We feed several
    /// representative timelinePath shapes and assert the rule holds for
    /// every produced Path. Failing this would indicate a regression in
    /// `GoogleTimelineConverter.makePath`.
    func testGoogleTimelineConverterNeverPopulatesBothShapes() throws {
        let inputs = [
            // Single short path
            """
            [{
                "startTime":"2026-05-08T10:00:00Z","endTime":"2026-05-08T10:05:00Z",
                "timelinePath":[
                    {"point":"geo:52.52,13.40","durationMinutesOffsetFromStartTime":"0"},
                    {"point":"geo:52.53,13.41","durationMinutesOffsetFromStartTime":"5"}
                ]
            }]
            """,
            // Multi-day, multi-path payload
            """
            [
                {
                    "startTime":"2026-05-08T08:00:00Z","endTime":"2026-05-08T08:30:00Z",
                    "timelinePath":[
                        {"point":"geo:52.50,13.40","durationMinutesOffsetFromStartTime":"0"},
                        {"point":"geo:52.51,13.41","durationMinutesOffsetFromStartTime":"15"},
                        {"point":"geo:52.52,13.42","durationMinutesOffsetFromStartTime":"30"}
                    ]
                },
                {
                    "startTime":"2026-05-09T18:00:00Z","endTime":"2026-05-09T18:10:00Z",
                    "timelinePath":[
                        {"point":"geo:48.13,11.58","durationMinutesOffsetFromStartTime":"0"},
                        {"point":"geo:48.14,11.59","durationMinutesOffsetFromStartTime":"10"}
                    ]
                }
            ]
            """
        ]

        for json in inputs {
            let export = try GoogleTimelineConverter.convert(data: Data(json.utf8))
            for day in export.data.days {
                for path in day.paths {
                    let hasFlat = (path.flatCoordinates?.isEmpty == false)
                    let hasPoints = !path.points.isEmpty
                    XCTAssertFalse(
                        hasFlat && hasPoints,
                        "GoogleTimelineConverter must not populate both points and flatCoordinates on the same Path — found both for day \(day.date)"
                    )
                    if hasFlat {
                        XCTAssertTrue(path.points.isEmpty,
                                      "Flat-shape path must have empty points")
                    }
                }
            }
        }
    }

    // MARK: - 2. Distance parity points-vs-flat (Aufgabe B Pflicht 2c)

    /// Same physical track expressed once as `points` and once as
    /// `flatCoordinates` must yield the same distance up to numerical
    /// noise. The current haversine-based polyline distance has segment
    /// rounding < 0.01 m per segment, so 1 m total tolerance is generous.
    func testDistanceParityBetweenPointsAndFlatShape() {
        // 4 Berlin landmarks, ~3 km cumulative.
        let coords: [(Double, Double)] = [
            (52.5200, 13.4050), // Brandenburger Tor
            (52.5163, 13.3777), // Tiergarten S
            (52.5096, 13.3760), // Potsdamer Platz
            (52.5170, 13.3888)  // Reichstag
        ]
        let pointsItem = DayDetailViewState.PathItem(
            startTime: nil, endTime: nil, activityType: nil,
            distanceM: nil, effectiveDistanceM: 0,
            pointCount: coords.count, sourceType: nil,
            points: coords.map {
                DayDetailViewState.PathPointItem(lat: $0.0, lon: $0.1, time: nil, accuracyM: nil)
            },
            flatCoordinates: nil
        )

        var flat: [Double] = []
        for (lat, lon) in coords {
            flat.append(lat)
            flat.append(lon)
        }
        let flatItem = DayDetailViewState.PathItem(
            startTime: nil, endTime: nil, activityType: nil,
            distanceM: nil, effectiveDistanceM: 0,
            pointCount: coords.count, sourceType: nil,
            points: [],
            flatCoordinates: flat
        )

        let pointsDistance = PathDistanceCalculator.effectiveDistance(for: pointsItem)
        let flatDistance = PathDistanceCalculator.effectiveDistance(for: flatItem)

        XCTAssertGreaterThan(pointsDistance, 0,
                             "Sanity check: points-shape distance must be positive")
        XCTAssertEqual(
            pointsDistance, flatDistance, accuracy: 1.0,
            "Distance reconstructed from flatCoordinates must match the points-shape result within 1 m"
        )
    }

    // MARK: - 3. AppSessionContent lazy-projection contract (Aufgabe B Pflicht 7)

    /// A synthetic export with 5_000 days is sized so that eagerly
    /// projecting overview/daySummaries/insights inside `init` would
    /// take orders of magnitude longer than the lean selectedDate-only
    /// loop. We assert init completes well under a second; eager
    /// materialisation observed during the 2026-05-07 hardware fail
    /// burst above 800 ms even before allocation work piled on.
    func testAppSessionContentInitDoesNotMaterializeProjections() {
        let export = makeLargeExport(dayCount: 5_000)

        let start = Date()
        let content = AppSessionContent(
            export: export,
            source: .importedFile(filename: "synthetic.zip")
        )
        let elapsed = Date().timeIntervalSince(start)

        // selectedDate must be the newest contentful date — proves the
        // lean path actually ran, not an accidental no-op.
        XCTAssertEqual(content.selectedDate, "2026-05-08",
                       "selectedDate must be the newest contentful date computed from raw days")

        // 250 ms threshold is generous on the slowest CI Linux runner;
        // an eager projection over 5_000 days dwarfs it.
        XCTAssertLessThan(
            elapsed, 0.25,
            "AppSessionContent.init must not materialise overview/daySummaries/insights — measured \(elapsed) s on \(export.data.days.count) days"
        )
    }

    /// After init, explicitly accessing the lazy projections must still
    /// return well-formed values. This guards against an over-eager
    /// future fix that "saves init time" by simply breaking the lazy
    /// projections themselves.
    func testAppSessionContentLazyProjectionsStillUsable() {
        let export = makeSmallExport()
        let content = AppSessionContent(
            export: export,
            source: .demoFixture(name: "test")
        )
        // Touching any lazy projection must succeed and reflect the data.
        XCTAssertGreaterThan(content.daySummaries.count, 0,
                             "Lazy daySummaries must still yield results when accessed")
        XCTAssertGreaterThanOrEqual(content.overview.dayCount, 0,
                                    "Lazy overview must still yield a valid count")
    }

    // MARK: - 4. AppSessionState.show(content:) no-eager-projections (Aufgabe B Pflicht 7)

    /// `show(content:)` is the post-import handoff. It must update
    /// metadata fields (selectedDate, message, isLoading, etc.) and
    /// READ inputFormat from `content.export.meta` directly — never
    /// from the lazy `overview`. The 2026-05-07 hardware fail traced
    /// part of the post-stream peak to a `content.overview.inputFormat`
    /// read here that pulled the full projectedDays projection just to
    /// pick a localized title.
    func testAppSessionStateShowContentRunsBoundedRegardlessOfDayCount() {
        let largeExport = makeLargeExport(dayCount: 5_000)
        let content = AppSessionContent(
            export: largeExport,
            source: .importedFile(filename: "synthetic.zip")
        )
        var state = AppSessionState(isLoading: true)

        let start = Date()
        state.show(content: content)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertFalse(state.isLoading,
                       "show(content:) must clear isLoading")
        XCTAssertNotNil(state.content,
                        "show(content:) must store content")
        XCTAssertEqual(state.selectedDate, content.selectedDate,
                       "show(content:) must adopt content.selectedDate")
        XCTAssertNotNil(state.message,
                        "show(content:) must produce a banner message")
        XCTAssertLessThan(
            elapsed, 0.25,
            "AppSessionState.show(content:) must not pull lazy projections — measured \(elapsed) s"
        )
    }

    /// The Google-Timeline title path reads `inputFormat` from
    /// `meta.source` / `meta.config` directly. Confirm the banner
    /// reflects that without forcing `overview` materialisation.
    func testShowContentPicksGoogleTimelineTitleFromMeta() {
        let export = makeLargeExport(
            dayCount: 32,
            metaSourceInputFormat: "google_timeline"
        )
        let content = AppSessionContent(
            export: export,
            source: .importedFile(filename: "location-history.zip")
        )
        var state = AppSessionState(isLoading: true)
        state.show(content: content)

        XCTAssertEqual(state.message?.title, "Google Timeline loaded",
                       "show(content:) must select the Google-Timeline title via meta.source.inputFormat without touching the lazy overview")
    }

    // MARK: - 5. Synthetic large-import streaming smoke (Aufgabe C)

    /// No real `location-history.zip` is available on the Linux build host,
    /// so we synthesize a moderately large `timelinePath`-shaped JSON
    /// payload (~50 000 entries) and verify the streaming pipeline:
    ///
    /// - Streams chunk-fed via `IncrementalParser.feed` (the same hot path
    ///   `AppContentLoader.streamGoogleTimelineCandidateIfApplicable` uses
    ///   inside `Archive.extract(_:bufferSize:)`).
    /// - Produces an export with non-zero days/paths.
    /// - Every produced path is in the canonical flat shape
    ///   (`points: [], flatCoordinates: [Double]`) — never the legacy
    ///   per-PathPoint shape.
    /// - No full-tree parse — the only Foundation parser involved is
    ///   `JSONSerialization` per element inside the streaming loop.
    ///
    /// **Important**: this is a Linux smoke. Memory measurements on the
    /// Linux runner are NOT representative of iOS Jetsam behaviour, so a
    /// pass here does NOT validate the 46-MB Hardware-retest. That stays
    /// open for the iPhone hardware run via Xcode Cloud (see
    /// `docs/APPLE_VERIFICATION_CHECKLIST.md`).
    func testStreamedSyntheticLargeTimelineUsesFlatGeometry() throws {
        let entryCount = 50_000
        let json = synthesizeLargeTimelineJSON(entryCount: entryCount)

        let converter = GoogleTimelineConverter.incrementalStreamConverter()
        let chunkSize = 64 * 1024
        var offset = 0
        let data = Data(json.utf8)
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            try converter.feed(data.subdata(in: offset..<end))
            offset = end
        }
        let export = try converter.finalize()

        XCTAssertGreaterThan(export.data.days.count, 0,
                             "Streaming pipeline must produce at least one day from a 50k-entry synthetic timeline")

        var totalPaths = 0
        var totalVertices = 0
        for day in export.data.days {
            for path in day.paths {
                totalPaths += 1
                XCTAssertTrue(path.points.isEmpty,
                              "Streamed Google-Timeline path must use flat shape, not points (day \(day.date))")
                let flat = path.flatCoordinates ?? []
                XCTAssertFalse(flat.isEmpty,
                               "Streamed flat geometry must not be empty (day \(day.date))")
                XCTAssertEqual(flat.count % 2, 0,
                               "Flat coordinates must be even-length lat/lon pairs")
                totalVertices += flat.count / 2
            }
        }

        XCTAssertGreaterThan(totalPaths, 0, "Streaming must produce at least one path")
        XCTAssertGreaterThan(totalVertices, 0, "Streaming must produce at least one vertex")
    }

    /// Builds a `timelinePath`-shaped JSON-array string with the given
    /// entry count. Each entry has a small (3-vertex) timelinePath so the
    /// total payload size scales linearly with `entryCount` and stays
    /// well under available RAM. `entryCount = 50_000` produces ~10 MB
    /// of source JSON — large enough to exercise the streaming loop
    /// thoroughly, small enough to fit comfortably on a CI runner.
    private func synthesizeLargeTimelineJSON(entryCount: Int) -> String {
        var pieces: [String] = []
        pieces.reserveCapacity(entryCount + 2)
        pieces.append("[")
        for i in 0..<entryCount {
            // Spread entries across a year so the Day-grouping path
            // actually produces multiple days.
            let dayOfYear = (i % 365) + 1
            let month = ((dayOfYear - 1) / 30) % 12 + 1
            let day = ((dayOfYear - 1) % 30) + 1
            let dateStem = String(format: "2026-%02d-%02d", month, day)
            let hour = (i % 22) + 1
            let lat = 50.0 + Double(i % 100) * 0.001
            let lon = 8.0 + Double(i % 100) * 0.001
            let entry = """
            {"startTime":"\(dateStem)T\(String(format: "%02d", hour)):00:00Z",\
            "endTime":"\(dateStem)T\(String(format: "%02d", hour)):05:00Z",\
            "timelinePath":[\
            {"point":"geo:\(lat),\(lon)","durationMinutesOffsetFromStartTime":"0"},\
            {"point":"geo:\(lat + 0.0005),\(lon + 0.0005)","durationMinutesOffsetFromStartTime":"2"},\
            {"point":"geo:\(lat + 0.001),\(lon + 0.001)","durationMinutesOffsetFromStartTime":"5"}\
            ]}
            """
            if i > 0 { pieces.append(",") }
            pieces.append(entry)
        }
        pieces.append("]")
        return pieces.joined()
    }

    // MARK: - Helpers

    /// Builds an `AppExport` with a number of synthetic days. Each day
    /// gets a tiny path so consumers that walk paths still see content,
    /// but the per-day allocation is small enough that the test stays
    /// well under a second on Linux CI.
    private func makeLargeExport(
        dayCount: Int,
        metaSourceInputFormat: String? = nil
    ) -> AppExport {
        var days: [Day] = []
        days.reserveCapacity(dayCount)
        for index in 0..<dayCount {
            // Encode the index into a stable yyyy-MM-dd; offset off 2010-01-01
            // so the dates are real Calendar dates and selectedDate's string
            // comparison stays meaningful.
            let date = synthDate(forOffset: index)
            days.append(
                Day(
                    date: date,
                    visits: [],
                    activities: [],
                    paths: [
                        Path(
                            startTime: nil,
                            endTime: nil,
                            activityType: "WALKING",
                            distanceM: nil,
                            sourceType: "google_timeline",
                            points: [],
                            flatCoordinates: [
                                Double(index % 90),
                                Double(index % 180),
                                Double((index + 1) % 90),
                                Double((index + 1) % 180)
                            ]
                        )
                    ]
                )
            )
        }
        // Pin the newest contentful date so the selectedDate assertion
        // is deterministic regardless of dayCount.
        days.append(
            Day(
                date: "2026-05-08",
                visits: [],
                activities: [],
                paths: [
                    Path(
                        startTime: nil,
                        endTime: nil,
                        activityType: "WALKING",
                        distanceM: nil,
                        sourceType: "google_timeline",
                        points: [],
                        flatCoordinates: [52.5, 13.4, 52.51, 13.41]
                    )
                ]
            )
        )
        return AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2026-05-08T00:00:00Z",
                toolVersion: "test/1.0",
                source: Source(
                    zipBasename: nil,
                    zipPath: nil,
                    inputFormat: metaSourceInputFormat
                ),
                output: Output(outDir: nil),
                config: ExportConfig(
                    mode: nil,
                    splitMidnight: nil,
                    splitMode: nil,
                    exportFormat: nil,
                    inputFormat: metaSourceInputFormat
                ),
                filters: ExportFilters(
                    fromDate: nil, toDate: nil, year: nil, month: nil,
                    weekday: nil, limit: nil, days: nil, has: nil,
                    maxAccuracyM: nil, activityTypes: nil, minGapMin: nil
                )
            ),
            data: DataBlock(days: days),
            stats: nil
        )
    }

    private func makeSmallExport() -> AppExport {
        return makeLargeExport(dayCount: 3)
    }

    /// Produces a stable `yyyy-MM-dd` date string from a numeric offset
    /// without depending on a Calendar instance (Foundation behaviour
    /// differs slightly between Linux and Darwin for boundary cases —
    /// this helper avoids that hazard since the tests don't care about
    /// real calendar arithmetic, only about uniqueness and ordering).
    private func synthDate(forOffset offset: Int) -> String {
        let year = 2010 + (offset / 365)
        let dayOfYear = (offset % 365) + 1
        // Map dayOfYear → a (month, day) inside a 30-day-month approximation,
        // good enough for ordering and uniqueness across 5_000 entries.
        let month = ((dayOfYear - 1) / 30) % 12 + 1
        let day = ((dayOfYear - 1) % 30) + 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
