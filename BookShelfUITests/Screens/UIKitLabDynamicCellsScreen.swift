import XCTest

/// Dinamik hücreler lab'ı (`DynamicCellsViewController`, klasik `UITableViewDataSource`).
///
/// Kitap hücresinin `value`'su (accessibilityValue) özetin durumunu söyler: "Açık" ya da "Kapalı".
/// Yükseklik gibi görsel bir şeyi doğrudan sormak yerine, uygulamanın erişilebilirlik ağacına yazdığı durumu okuruz.
@MainActor
struct UIKitLabDynamicCellsScreen: Screen {
    private typealias ID = AccessibilityID.UIKitLabs.DynamicCells

    let app: XCUIApplication

    var rootElement: XCUIElement { table }

    var table: XCUIElement { app.tables[ID.table] }

    func bookCell(_ bookID: Int) -> XCUIElement {
        app.cells[ID.bookCell(bookID)]
    }
}
