import XCTest

/// "Kitaplar" sekmesinin kök ekranı (`BookListView`, SwiftUI).
///
/// Erişilebilirlik ağacında (iOS 26):
/// ```
/// CollectionView  "bookList.list"
///   Cell
///     Button  "bookList.row.1"   label: "Tutunamayanlar, Oğuz Atay · 1972"   value: "" ya da "Favori"
/// ```
/// `NavigationLink` satırı bir `Button` olarak görünür ve satırdaki iki metin, düğmenin `label`'ında virgülle
/// birleşir. Kimliği `NavigationLink`'e verdiğimiz için `app.buttons[...]` tam da dokunulacak öğeyi bulur.
@MainActor
struct BookListScreen: Screen {
    private typealias ID = AccessibilityID.BookList

    let app: XCUIApplication

    /// Liste yalnızca kitaplar yüklendiğinde vardır. Hata durumunda onun yerine `errorView` görünür.
    var rootElement: XCUIElement { list }

    var list: XCUIElement { app.collectionViews[ID.list] }

    func row(bookID: Int) -> XCUIElement {
        app.buttons[ID.row(bookID: bookID)]
    }

    // MARK: Hata durumu

    var errorView: XCUIElement { app.otherElements[ID.errorView] }
    var errorMessage: XCUIElement { app.staticTexts[ID.errorMessage] }
    var retryButton: XCUIElement { app.buttons[ID.retryButton] }

    // MARK: Eylemler

    /// Satır ekranın altındaysa (küçük ekranlı cihazlar) önce görünür hale getirir.
    @discardableResult
    func revealRow(bookID: Int) -> XCUIElement {
        let row = row(bookID: bookID)
        list.scrollUp(toReveal: row)
        return row
    }

    /// Satıra dokunur ve açılan detay ekranını bekler.
    func openBook(
        id bookID: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> BookDetailScreen {
        revealRow(bookID: bookID).tap()
        return BookDetailScreen(app: app).waitUntilDisplayed(file: file, line: line)
    }
}
