import XCTest

/// "Delegate" konusunun demosu (`DelegationDemoView`): Canlı / Sahiplik / Hangisi? bölümleri.
///
/// "Canlı" bölümü UIKit (`BookRatingViewController`): yıldızlar `UIButton`, etiketler `UILabel`, kilit `UISwitch`.
/// "Sahiplik" bölümü SwiftUI `List` (XCUITest'te `collectionViews`).
@MainActor
struct DelegationDemoScreen: Screen {
    private typealias ID = AccessibilityID.Delegation

    let app: XCUIApplication

    var rootElement: XCUIElement { panePicker }

    var panePicker: XCUIElement { app.segmentedControls[ID.panePicker] }

    // MARK: Canlı

    func starButton(_ number: Int) -> XCUIElement { app.buttons[ID.starButton(number)] }
    var delegateLabel: XCUIElement { app.staticTexts[ID.delegateLabel] }
    var closureLabel: XCUIElement { app.staticTexts[ID.closureLabel] }
    var targetActionLabel: XCUIElement { app.staticTexts[ID.targetActionLabel] }
    var lockSwitch: XCUIElement { app.switches[ID.lockSwitch] }
    var statusLabel: XCUIElement { app.staticTexts[ID.statusLabel] }

    // MARK: Sahiplik

    var ownershipList: XCUIElement { app.collectionViews[ID.ownershipList] }
    var lifetimeExperimentButton: XCUIElement { app.buttons[ID.lifetimeExperimentButton] }
    var lifetimeResultLabel: XCUIElement { app.staticTexts[ID.lifetimeResultLabel] }

    // MARK: Eylemler

    /// Ör. `showPane(AccessibilityID.Delegation.ownershipSegment)`.
    func showPane(_ segmentLabel: String) {
        panePicker.buttons[segmentLabel].tap()
    }

    func rate(_ stars: Int) {
        starButton(stars).tap()
    }

    func toggleLock() {
        lockSwitch.tap()
    }

    /// Deney düğmesini (gerekirse listeyi kaydırarak) bulur ve dokunur.
    func runLifetimeExperiment(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            ownershipList.scrollUp(toReveal: lifetimeExperimentButton),
            "Sahiplik deneyi düğmesi bulunamadı.",
            file: file, line: line
        )
        lifetimeExperimentButton.tap()
    }
}
