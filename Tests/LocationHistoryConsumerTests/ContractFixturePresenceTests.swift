import Foundation
import XCTest
@testable import LocationHistoryConsumer

final class ContractFixturePresenceTests: XCTestCase {
    func testContractArtifactsExist() throws {
        let expected = [
            "app_export.schema.json",
            "CONTRACT_SOURCE.json",
            "golden_app_export_contract_gate.json",
            "golden_app_export_sample_small.json",
            "golden_app_export_sample_medium.json",
            "golden_app_export_consumer_forward_compatible_additive_fields.json",
            "golden_app_export_empty_collections_minimal.json",
            "golden_app_export_multi_day_varied_structure.json",
            "golden_app_export_no_days_zero.json",
        ]

        let fixtures = try TestSupport.contractFixturesDirectory()
        for name in expected {
            let path = fixtures.appendingPathComponent(name)
            XCTAssertTrue(FileManager.default.fileExists(atPath: path.path), name)
        }
    }

    func testContractVersionMatchesExpectedConsumerSchema() {
        XCTAssertEqual(ContractVersion.currentSchemaVersion, "1.0")
    }

    func testContractSourceManifestDocumentsImportedAndLocalFixtures() throws {
        let manifestURL = try TestSupport.contractFixtureURL(named: "CONTRACT_SOURCE.json")
        let data = try Data(contentsOf: manifestURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let imported = try XCTUnwrap(json["imported_artifacts"] as? [String])
        let local = try XCTUnwrap(json["consumer_local_artifacts"] as? [String])
        let producerCommit = try XCTUnwrap(json["producer_commit"] as? String)

        XCTAssertTrue(imported.contains("app_export.schema.json"))
        XCTAssertTrue(imported.contains("app_export_contract_gate.json"))
        XCTAssertTrue(local.contains("golden_app_export_consumer_forward_compatible_additive_fields.json"))
        XCTAssertTrue(local.contains("golden_app_export_empty_collections_minimal.json"))
        XCTAssertTrue(local.contains("golden_app_export_multi_day_varied_structure.json"))
        XCTAssertTrue(local.contains("golden_app_export_no_days_zero.json"))
        XCTAssertEqual(producerCommit.count, 7)
    }
}
