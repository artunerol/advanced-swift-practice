import XCTest

/// UITableView vs UICollectionView lab'ı (`TableVsCollectionViewController`).
///
/// Üç görünüm aynı alanı paylaşır; yalnızca seçili olan görünür. XCUITest gizli (`isHidden`) view'ları ağaçta
/// göstermez, bu yüzden "bu mod seçiliyken şu tablo/collection view var mı?" sorusu modun gerçekten değiştiğini kanıtlar.
@MainActor
struct UIKitLabTableVsCollectionScreen: Screen {
    private typealias ID = AccessibilityID.UIKitLabs.TableVsCollection

    let app: XCUIApplication

    var rootElement: XCUIElement { modePicker }

    var modePicker: XCUIElement { app.segmentedControls[ID.modePicker] }
    var caption: XCUIElement { app.staticTexts[ID.caption] }

    var table: XCUIElement { app.tables[ID.table] }
    var listCollection: XCUIElement { app.collectionViews[ID.listCollection] }
    var gridCollection: XCUIElement { app.collectionViews[ID.gridCollection] }

    func tableCell(_ bookID: Int) -> XCUIElement { table.cells[ID.tableCell(bookID)] }
    func listCell(_ bookID: Int) -> XCUIElement { listCollection.cells[ID.listCell(bookID)] }
    func featuredCell(_ bookID: Int) -> XCUIElement { gridCollection.cells[ID.featuredCell(bookID)] }
    func gridCell(_ bookID: Int) -> XCUIElement { gridCollection.cells[ID.gridCell(bookID)] }

    /// Mod seçicide bir bölüme dokunur (ör. `AccessibilityID.UIKitLabs.TableVsCollection.listSegment`).
    func selectMode(_ segmentLabel: String) {
        modePicker.buttons[segmentLabel].tap()
    }
}
