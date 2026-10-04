import XCTest

/// "Temeller" sekmesinin giriş ekranı (`FundamentalsView`): üç deneye giden bağlantılar.
@MainActor
struct FundamentalsScreen: Screen {
    private typealias ID = AccessibilityID.Fundamentals

    let app: XCUIApplication

    var rootElement: XCUIElement { structVsClassLink }

    var structVsClassLink: XCUIElement { app.buttons[ID.structVsClassLink] }
    var protocolsLink: XCUIElement { app.buttons[ID.protocolsLink] }
    var isbnCheckerLink: XCUIElement { app.buttons[ID.isbnCheckerLink] }

    func openStructVsClass(file: StaticString = #filePath, line: UInt = #line) -> StructVsClassScreen {
        structVsClassLink.tap()
        return StructVsClassScreen(app: app).waitUntilDisplayed(file: file, line: line)
    }

    func openISBNChecker(file: StaticString = #filePath, line: UInt = #line) -> ISBNCheckerScreen {
        isbnCheckerLink.tap()
        return ISBNCheckerScreen(app: app).waitUntilDisplayed(file: file, line: line)
    }
}
