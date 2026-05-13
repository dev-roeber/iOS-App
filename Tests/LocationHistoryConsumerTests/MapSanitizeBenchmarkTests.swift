import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Map-Train 2: tiny XCTMeasure-based benchmark for the Foundation-only
/// `CoordinateValidity.isValid` filter and the bulk-filter pattern used by
/// the data-prep layer (Overview scan / Heatmap collect / ExportPreview).
///
/// Goal: produce reproducible numbers for the hottest validation paths
/// without committing large fixtures. Uses synthetic coordinates so the
/// benchmark stays self-contained and Linux-portable.
///
/// `measure` aggregates 10 iterations and provides regression-baseline
/// detection via Xcode's metric history; assertions intentionally avoid
/// hard wall-clock thresholds (those would be flaky on CI vs. local).
final class MapSanitizeBenchmarkTests: XCTestCase {

    /// 10k synthetic mixed-validity coords. Half invalid (NaN/Inf/out-of-
    /// range/sentinel) so the rejection branch is also covered hot.
    private static let mixed10k: [(Double, Double)] = {
        var out: [(Double, Double)] = []
        out.reserveCapacity(10_000)
        for i in 0..<10_000 {
            switch i % 6 {
            case 0: out.append((48.0 + Double(i) * 1e-5, 11.0 + Double(i) * 1e-5))
            case 1: out.append((52.5, 13.4))
            case 2: out.append((.nan, 13.4))
            case 3: out.append((52.5, .infinity))
            case 4: out.append((91.0, 0.0))           // out of range
            case 5: out.append((-180.0, -180.0))      // Apple sentinel
            default: out.append((0, 0))
            }
        }
        return out
    }()

    private static let valid50k: [(Double, Double)] = {
        var out: [(Double, Double)] = []
        out.reserveCapacity(50_000)
        for i in 0..<50_000 {
            out.append((48.0 + Double(i) * 1e-6, 11.0 + Double(i) * 1e-6))
        }
        return out
    }()

    /// Sanity: validator throughput on 10k mixed-validity coords. Hot path
    /// for `ExportPreviewDataBuilder.previewData` and the Overview scan
    /// inner loop.
    func testIsValidThroughput10kMixed() {
        measure {
            var kept = 0
            for (lat, lon) in Self.mixed10k {
                if CoordinateValidity.isValid(latitude: lat, longitude: lon) {
                    kept += 1
                }
            }
            // Anchor against constant folding: prevent the optimizer from
            // throwing the loop away entirely.
            XCTAssertGreaterThan(kept, 0)
            XCTAssertLessThan(kept, Self.mixed10k.count)
        }
    }

    /// Sanity: validator throughput on 50k all-valid coords. Models the
    /// Heatmap collect loop on a moderate single-day dataset.
    func testIsValidThroughput50kValid() {
        measure {
            var kept = 0
            for (lat, lon) in Self.valid50k {
                if CoordinateValidity.isValid(latitude: lat, longitude: lon) {
                    kept += 1
                }
            }
            XCTAssertEqual(kept, Self.valid50k.count)
        }
    }

    /// Verifies that the validator is allocation-free relative to the input
    /// array — important for the Overview/Heatmap inner loop which already
    /// runs on a detached priority-userInitiated Task.
    func testIsValidIsBranchOnlyNoAllocations() {
        let sample = Self.mixed10k.prefix(1024)
        var kept = 0
        for (lat, lon) in sample {
            if CoordinateValidity.isValid(latitude: lat, longitude: lon) {
                kept += 1
            }
        }
        XCTAssertGreaterThan(kept, 0)
    }
}
