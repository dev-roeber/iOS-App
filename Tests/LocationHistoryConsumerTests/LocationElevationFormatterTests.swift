import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Train 9.2 — scaffolding only. These tests **must not** be executed in
/// build-only Trains; they will be run as part of "Punkt 10 — Vollständige
/// Tests / Xcode Cloud / TestFlight". They lock down the central
/// "is the altitude trustworthy?" rule that the Live UI, the
/// `RecordedTrackPoint` persistence and the GPX `<ele>` emitter all share.
final class LocationElevationFormatterTests: XCTestCase {

    // MARK: reading()

    func test_reading_withPositiveAccuracyAndFiniteAltitude_returnsAvailable() {
        let reading = LocationElevationFormatter.reading(altitudeM: 42.0, verticalAccuracyM: 8.0)
        XCTAssertEqual(reading, .available(altitudeM: 42.0, accuracyM: 8.0))
    }

    func test_reading_withNegativeAccuracy_returnsUnavailableInvalidAccuracy() {
        let reading = LocationElevationFormatter.reading(altitudeM: 100.0, verticalAccuracyM: -1.0)
        XCTAssertEqual(reading, .unavailable(reason: .invalidAccuracy))
    }

    func test_reading_withZeroAccuracy_returnsUnavailableInvalidAccuracy() {
        let reading = LocationElevationFormatter.reading(altitudeM: 100.0, verticalAccuracyM: 0.0)
        XCTAssertEqual(reading, .unavailable(reason: .invalidAccuracy))
    }

    func test_reading_withNaNAltitude_returnsUnavailableNonFinite() {
        let reading = LocationElevationFormatter.reading(altitudeM: .nan, verticalAccuracyM: 5.0)
        XCTAssertEqual(reading, .unavailable(reason: .nonFiniteValue))
    }

    func test_reading_withInfiniteAccuracy_returnsUnavailableNonFinite() {
        let reading = LocationElevationFormatter.reading(altitudeM: 50.0, verticalAccuracyM: .infinity)
        XCTAssertEqual(reading, .unavailable(reason: .nonFiniteValue))
    }

    func test_reading_withNilInputs_returnsUnavailableMissing() {
        XCTAssertEqual(
            LocationElevationFormatter.reading(altitudeM: nil, verticalAccuracyM: nil),
            .unavailable(reason: .missing)
        )
        XCTAssertEqual(
            LocationElevationFormatter.reading(altitudeM: nil, verticalAccuracyM: 5.0),
            .unavailable(reason: .missing)
        )
        XCTAssertEqual(
            LocationElevationFormatter.reading(altitudeM: 42.0, verticalAccuracyM: nil),
            .unavailable(reason: .missing)
        )
    }

    // MARK: isValidAltitude()

    func test_isValidAltitude_mirrorsAvailableReadingDetection() {
        XCTAssertTrue(LocationElevationFormatter.isValidAltitude(altitudeM: 42.0, verticalAccuracyM: 8.0))
        XCTAssertFalse(LocationElevationFormatter.isValidAltitude(altitudeM: 42.0, verticalAccuracyM: -1.0))
        XCTAssertFalse(LocationElevationFormatter.isValidAltitude(altitudeM: nil, verticalAccuracyM: 5.0))
        XCTAssertFalse(LocationElevationFormatter.isValidAltitude(altitudeM: .nan, verticalAccuracyM: 5.0))
    }

    // MARK: displayText()

    func test_displayText_availableEnglish_formatsElevationWithAccuracy() {
        let text = LocationElevationFormatter.displayText(
            for: .available(altitudeM: 42.4, accuracyM: 8.1),
            german: false
        )
        XCTAssertEqual(text, "Elevation 42 m ± 8 m")
    }

    func test_displayText_availableGerman_usesGermanLabel() {
        let text = LocationElevationFormatter.displayText(
            for: .available(altitudeM: 1234.0, accuracyM: 12.0),
            german: true
        )
        XCTAssertEqual(text, "Höhe 1234 m ± 12 m")
    }

    func test_displayText_unavailableEnglish_returnsUnavailableFallback() {
        let text = LocationElevationFormatter.displayText(
            for: .unavailable(reason: .invalidAccuracy),
            german: false
        )
        XCTAssertEqual(text, "Elevation unavailable")
    }

    func test_displayText_unavailableGerman_returnsLocalizedFallback() {
        let text = LocationElevationFormatter.displayText(
            for: .unavailable(reason: .missing),
            german: true
        )
        XCTAssertEqual(text, "Höhe nicht verfügbar")
    }

    // MARK: compact helpers

    func test_compactHelpers_availableReturnsMetricValues() {
        let reading: LocationElevationFormatter.Reading = .available(altitudeM: 250.7, accuracyM: 4.0)
        XCTAssertEqual(LocationElevationFormatter.compactAltitudeText(for: reading), "251 m")
        XCTAssertEqual(LocationElevationFormatter.compactAccuracyText(for: reading), "± 4 m")
    }

    func test_compactHelpers_unavailableReturnsNil() {
        let reading: LocationElevationFormatter.Reading = .unavailable(reason: .invalidAccuracy)
        XCTAssertNil(LocationElevationFormatter.compactAltitudeText(for: reading))
        XCTAssertNil(LocationElevationFormatter.compactAccuracyText(for: reading))
    }
}
