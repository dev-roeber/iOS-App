import XCTest
import LocationHistoryConsumerAppSupport

final class RecordingIntervalPreferenceTests: XCTestCase {

    // MARK: - Default

    func testDefaultInterval() {
        XCTAssertEqual(RecordingIntervalPreference.default.value, 5)
        XCTAssertEqual(RecordingIntervalPreference.default.unit, .seconds)
        XCTAssertEqual(RecordingIntervalPreference.default.totalSeconds, 5.0)
    }

    // MARK: - totalSeconds

    func testTotalSeconds_seconds() {
        let interval = RecordingIntervalPreference(value: 30, unit: .seconds)
        XCTAssertEqual(interval.totalSeconds, 30.0)
    }

    func testTotalSeconds_minutes() {
        let interval = RecordingIntervalPreference(value: 2, unit: .minutes)
        XCTAssertEqual(interval.totalSeconds, 120.0)
    }

    func testTotalSeconds_hours() {
        let interval = RecordingIntervalPreference(value: 1, unit: .hours)
        XCTAssertEqual(interval.totalSeconds, 3600.0)
    }

    // MARK: - Validation / clamping

    func testValidation_allowsZero_seconds() {
        let clamped = RecordingIntervalPreference.validated(value: 0, unit: .seconds)
        XCTAssertEqual(clamped.value, 0)
        XCTAssertEqual(clamped.unit, .seconds)
    }

    func testValidation_clampsNegative_secondsToZero() {
        let clamped = RecordingIntervalPreference.validated(value: -1, unit: .seconds)
        XCTAssertEqual(clamped.value, 0)
    }

    func testValidation_allowsZero_minutes() {
        let clamped = RecordingIntervalPreference.validated(value: 0, unit: .minutes)
        XCTAssertEqual(clamped.value, 0)
    }

    func testValidation_preservesLarge_minutes() {
        let clamped = RecordingIntervalPreference.validated(value: 999, unit: .minutes)
        XCTAssertEqual(clamped.value, 999)
    }

    func testValidation_allowsZero_hours() {
        let clamped = RecordingIntervalPreference.validated(value: 0, unit: .hours)
        XCTAssertEqual(clamped.value, 0)
    }

    func testValidation_preservesLarge_hours() {
        let clamped = RecordingIntervalPreference.validated(value: 25, unit: .hours)
        XCTAssertEqual(clamped.value, 25)
    }

    // MARK: - Codable round-trip

    func testCodable() throws {
        let original = RecordingIntervalPreference(value: 15, unit: .minutes)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecordingIntervalPreference.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCodable_default() throws {
        let data = try JSONEncoder().encode(RecordingIntervalPreference.default)
        let decoded = try JSONDecoder().decode(RecordingIntervalPreference.self, from: data)
        XCTAssertEqual(decoded, .default)
    }

    func testCodable_zero() throws {
        let original = RecordingIntervalPreference(value: 0, unit: .hours)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecordingIntervalPreference.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Equality

    func testEquality() {
        let a = RecordingIntervalPreference(value: 10, unit: .seconds)
        let b = RecordingIntervalPreference(value: 10, unit: .seconds)
        let c = RecordingIntervalPreference(value: 10, unit: .minutes)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Unit enum

    func testUnitCaseIterable() {
        let cases = RecordingIntervalUnit.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.seconds))
        XCTAssertTrue(cases.contains(.minutes))
        XCTAssertTrue(cases.contains(.hours))
    }

    func testUnitIdentifiable() {
        XCTAssertEqual(RecordingIntervalUnit.seconds.id, "seconds")
        XCTAssertEqual(RecordingIntervalUnit.minutes.id, "minutes")
        XCTAssertEqual(RecordingIntervalUnit.hours.id, "hours")
    }

    func testUnitDisplayName() {
        XCTAssertEqual(RecordingIntervalUnit.seconds.displayName, "Seconds")
        XCTAssertEqual(RecordingIntervalUnit.minutes.displayName, "Minutes")
        XCTAssertEqual(RecordingIntervalUnit.hours.displayName, "Hours")
    }

    func testUnitSingularDisplayName() {
        XCTAssertEqual(RecordingIntervalUnit.seconds.singularDisplayName, "Second")
        XCTAssertEqual(RecordingIntervalUnit.minutes.singularDisplayName, "Minute")
        XCTAssertEqual(RecordingIntervalUnit.hours.singularDisplayName, "Hour")
    }

    func testUnitSingularKey() {
        XCTAssertEqual(RecordingIntervalUnit.seconds.singularKey, "second")
        XCTAssertEqual(RecordingIntervalUnit.minutes.singularKey, "minute")
        XCTAssertEqual(RecordingIntervalUnit.hours.singularKey, "hour")
    }

    // MARK: - displayString

    func testDisplayString_singularSecond() {
        XCTAssertEqual(RecordingIntervalPreference(value: 1, unit: .seconds).displayString, "1 second")
    }

    func testDisplayString_noMinimum() {
        XCTAssertEqual(RecordingIntervalPreference(value: 0, unit: .seconds).displayString, "No minimum")
    }

    func testDisplayString_pluralSeconds() {
        XCTAssertEqual(RecordingIntervalPreference(value: 5, unit: .seconds).displayString, "5 seconds")
    }

    func testDisplayString_singularMinute() {
        XCTAssertEqual(RecordingIntervalPreference(value: 1, unit: .minutes).displayString, "1 minute")
    }

    func testDisplayString_pluralMinutes() {
        XCTAssertEqual(RecordingIntervalPreference(value: 3, unit: .minutes).displayString, "3 minutes")
    }

    func testDisplayString_singularHour() {
        XCTAssertEqual(RecordingIntervalPreference(value: 1, unit: .hours).displayString, "1 hour")
    }

    func testDisplayString_pluralHours() {
        XCTAssertEqual(RecordingIntervalPreference(value: 2, unit: .hours).displayString, "2 hours")
    }

    func testUnlimitedDisplayString() {
        XCTAssertEqual(RecordingIntervalPreference.unlimitedDisplayString, "Unlimited")
    }
}
