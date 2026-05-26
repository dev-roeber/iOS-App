import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Regressions-Tests für die erweiterten Segment-Action-API von
/// `AppFilesView` (Phase: Lokal-Import-Button im Files-Tab).
///
/// Hintergrund: Beim Hinzufügen des „Datei importieren"-Buttons im
/// Lokal-Segment wurde `AppFilesView` um den Closure-Parameter
/// `onImportLocalFile` erweitert (sowohl der Produktions- als auch der
/// Test-Init). Zusätzlich wurde die AccessibilityID
/// `AppAccessibilityID.Files.importLocal` eingeführt.
///
/// Da SwiftUI-View-Bodies im Unit-Test nicht direkt invocable sind,
/// sichern diese Tests bewusst minimal die Compile-Stabilität der
/// erweiterten API und die Stringkonstanten der AccessibilityIDs.
/// Echte Tap-Interaktion wird via XCUITest (Mac-only) im UI-Target
/// abgedeckt.
final class AppFilesViewSegmentActionTests: XCTestCase {

    // MARK: - AccessibilityID-Konstanten (Regression)

    func testFilesImportLocalAccessibilityIDIsStable() {
        XCTAssertEqual(AppAccessibilityID.Files.importLocal, "files.importLocal")
    }

    func testFilesChooseFileAccessibilityIDRemainsUnchanged() {
        // Regression: chooseFile darf durch den Umbau nicht umbenannt
        // worden sein — externe XCUITests adressieren diesen Identifier.
        XCTAssertEqual(AppAccessibilityID.Files.chooseFile, "files.chooseFile")
    }

    func testFilesImportLocalAndChooseFileAreDistinct() {
        XCTAssertNotEqual(
            AppAccessibilityID.Files.importLocal,
            AppAccessibilityID.Files.chooseFile,
            "Lokal-Import und Cloud-Choose müssen unterschiedliche IDs haben."
        )
    }

    // MARK: - API-Kompatibilität (Compile-Stabilität)

    /// Stellt sicher, dass der Test-Init mit injectablen ViewModels und
    /// beiden Action-Closures (`onChooseCloudFile`, `onImportLocalFile`)
    /// ohne Crash konstruiert werden kann. Wir prüfen außerdem, dass die
    /// jeweiligen Default-Closures (leere Tupel) ebenfalls akzeptiert
    /// werden — d. h. Aufrufstellen ohne Closure brechen nicht.
    #if canImport(SwiftUI) && canImport(Combine)
    @MainActor
    func testAppFilesViewTestInitAcceptsBothActionClosures() {
        let scanner = InMemoryLocalFileScanner(snapshots: [])
        let filesVM = AppFilesViewModel(scanner: scanner)
        let cloudVM = AppCloudFileViewModel(manager: InMemoryCloudFileManager())

        var chooseHits = 0
        var importHits = 0

        // Voll-parametrisiert: beide Closures explizit gesetzt.
        let view = AppFilesView(
            viewModel: filesVM,
            cloudViewModel: cloudVM,
            onChooseCloudFile: { chooseHits += 1 },
            onImportLocalFile: { importHits += 1 }
        )
        _ = view

        // Defaults: View darf auch ohne Closures konstruiert werden.
        let viewDefault = AppFilesView(
            viewModel: filesVM,
            cloudViewModel: cloudVM
        )
        _ = viewDefault

        // Sanity: Counter werden im Unit-Test nicht inkrementiert,
        // weil wir den SwiftUI-Body hier nicht rendern können.
        XCTAssertEqual(chooseHits, 0)
        XCTAssertEqual(importHits, 0)
    }

    /// Production-Init (ohne injected ViewModel): muss ebenfalls den
    /// neuen `onImportLocalFile`-Parameter akzeptieren und mit Defaults
    /// konstruierbar bleiben.
    @MainActor
    func testAppFilesViewProductionInitAcceptsImportLocalClosure() {
        let cloudVM = AppCloudFileViewModel(manager: InMemoryCloudFileManager())

        let viewWithBoth = AppFilesView(
            cloudViewModel: cloudVM,
            onChooseCloudFile: {},
            onImportLocalFile: {}
        )
        _ = viewWithBoth

        let viewDefault = AppFilesView(cloudViewModel: cloudVM)
        _ = viewDefault
    }
    #endif
}
