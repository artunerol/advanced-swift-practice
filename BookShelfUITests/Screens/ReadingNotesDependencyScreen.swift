import XCTest

/// "Dependency Inversion vs Dependency Injection" demosu (`DependencyInjectionDemoView`).
@MainActor
struct ReadingNotesDependencyScreen: Screen {
    private typealias ID = AccessibilityID.ReadingNotes.DependencyDemo

    let app: XCUIApplication

    var rootElement: XCUIElement { repositoryPicker }

    var list: XCUIElement { app.collectionViews[ID.list] }
    var repositoryPicker: XCUIElement { app.segmentedControls[ID.repositoryPicker] }
    var formatterPicker: XCUIElement { app.segmentedControls[ID.formatterPicker] }

    var tightlyCoupledCount: XCUIElement { app.staticTexts[ID.tightlyCoupledCount] }
    var concreteInjectedCount: XCUIElement { app.staticTexts[ID.concreteInjectedCount] }
    var injectedCount: XCUIElement { app.staticTexts[ID.injectedCount] }
    var formatterOutput: XCUIElement { app.staticTexts[ID.formatterOutput] }

    func selectRepository(_ segmentLabel: String) {
        repositoryPicker.buttons[segmentLabel].tap()
    }

    /// Biçimlendirici bölümü listenin altında kalabilir; önce görünür olana kadar kaydırır.
    func selectFormatter(_ segmentLabel: String) {
        list.scrollUp(toReveal: formatterOutput)
        formatterPicker.buttons[segmentLabel].tap()
    }
}
