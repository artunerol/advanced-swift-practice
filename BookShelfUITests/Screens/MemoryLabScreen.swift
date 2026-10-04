import XCTest

/// Sızıntı laboratuvarı (`MemoryLeakLabViewController`, UIKit): "ARC ve retain cycle" konusunun demosu.
///
/// Senaryo seçici bir UIKit `UISegmentedControl`; bölümleri görünen etiketleriyle seçilir.
/// Sonuç etiketlerinin metinleri `AccessibilityID.MemoryLab` sabitlerindedir (uygulama da aynılarını kullanır).
@MainActor
struct MemoryLabScreen: Screen {
    private typealias ID = AccessibilityID.MemoryLab

    let app: XCUIApplication

    var rootElement: XCUIElement { scenarioPicker }

    var scenarioPicker: XCUIElement { app.segmentedControls[ID.scenarioPicker] }
    var openLeakingButton: XCUIElement { app.buttons[ID.openLeakingButton] }
    var openFixedButton: XCUIElement { app.buttons[ID.openFixedButton] }
    var verdictLabel: XCUIElement { app.staticTexts[ID.verdictLabel] }
    var verdictDetailLabel: XCUIElement { app.staticTexts[ID.verdictDetailLabel] }
    var leakCountLabel: XCUIElement { app.staticTexts[ID.leakCountLabel] }
    var cleanUpButton: XCUIElement { app.buttons[ID.cleanUpButton] }

    // MARK: Eylemler

    /// Ör. `selectScenario(AccessibilityID.MemoryLab.taskSegment)`.
    func selectScenario(_ segmentLabel: String) {
        scenarioPicker.buttons[segmentLabel].tap()
    }

    /// Seçili senaryonun sızdıran sürümünü açar ve kurban ekranının görünmesini bekler.
    func openLeaking(file: StaticString = #filePath, line: UInt = #line) -> MemoryLabVictimScreen {
        openLeakingButton.tap()
        return MemoryLabVictimScreen(app: app).waitUntilDisplayed(file: file, line: line)
    }

    func openFixed(file: StaticString = #filePath, line: UInt = #line) -> MemoryLabVictimScreen {
        openFixedButton.tap()
        return MemoryLabVictimScreen(app: app).waitUntilDisplayed(file: file, line: line)
    }

    /// Düğme yalnızca bellekte kalan kurban varken ve ölçüm sürmüyorken etkindir; önce etkinleşmesini bekleriz.
    func cleanUpLeaks(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(cleanUpButton.waitUntilEnabled(), "'Sızıntıları temizle' etkinleşmedi.", file: file, line: line)
        cleanUpButton.tap()
    }
}
