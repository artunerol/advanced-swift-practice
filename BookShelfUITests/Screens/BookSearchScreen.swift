import XCTest

/// "VIPER'da servis çağrısı" konusunun demosu: Kitap Arama VIPER modülü (`BookSearchViewController`, UIKit).
///
/// Test VIPER'ı bilmez; erişilebilirlik ağacını görür:
/// ```
/// SearchField "bookSearch.searchField"            (UISearchBar'ın metin alanı)
/// Table "bookSearch.table"
///   Cell "bookSearch.result.1"                    StaticText "Tutunamayanlar", "Oğuz Atay · 1972"
///   Cell "bookSearch.recent.0"                    (kutu boşken, son aramalar)
/// StaticText "bookSearch.message"                 (boş / hata / ipucu)
/// Button "bookSearch.retry"                       "Tekrar dene"
/// Alert "bookSearch.insights"                     (sola kaydır → "Özet")
/// Button "bookSearch.backToResults"               (detay ekranının alt araç çubuğunda)
/// ```
@MainActor
struct BookSearchScreen: Screen {
    private typealias ID = AccessibilityID.BookSearch

    let app: XCUIApplication

    var rootElement: XCUIElement { searchField }

    var searchField: XCUIElement { app.searchFields[ID.searchField] }
    var table: XCUIElement { app.tables[ID.table] }
    var messageLabel: XCUIElement { app.staticTexts[ID.messageLabel] }
    var retryButton: XCUIElement { app.buttons[ID.retryButton] }
    var statusLabel: XCUIElement { app.staticTexts[ID.statusLabel] }

    func resultCell(bookID: Int) -> XCUIElement {
        app.cells[ID.resultCell(bookID: bookID)]
    }

    func recentCell(_ index: Int) -> XCUIElement {
        app.cells[ID.recentCell(index)]
    }

    /// Tablodaki sonuç satırları (geçmiş satırları hariç). Kimlik önekiyle süzülür.
    var resultCells: XCUIElementQuery {
        table.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", "bookSearch.result."))
    }

    var insightsAlert: XCUIElement { app.alerts[ID.insightsAlert] }
    /// iOS 26'da alert düğmeleri ağaçta iki kez görünebilir; `.firstMatch` ilk eşleşmeyi seçer.
    var insightsOKButton: XCUIElement { app.buttons[ID.insightsOKButton].firstMatch }
    var backToResultsButton: XCUIElement { app.buttons[ID.backToResultsButton] }

    // MARK: Eylemler

    /// Arama kutusuna yazar (harf harf; her harf bir `textDidChange`). Klavye açık kalır.
    func type(_ text: String) {
        searchField.tap()
        searchField.typeText(text)
    }

    /// Yazar ve klavyedeki "Ara"ya basar (`\n`): klavye kapanır, arama beklemeden yapılır.
    func search(_ text: String) {
        type(text + "\n")
    }

    /// Kutudaki metni harf harf siler (her silme bir `textDidChange`; sonunda boş metin → son aramalar).
    /// "Temizle" (x) düğmesi yalnızca düzenleme sırasında görünür ve etiketi sistem diline bağlı; silme tuşu daha kararlı.
    func clear() {
        searchField.tap()
        let length = (searchField.value as? String)?.count ?? 0
        searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: max(length, 1)))
    }

    /// Sonuç satırına dokunur ve kitap detayının açılmasını bekler.
    func openBook(id: Int, file: StaticString = #filePath, line: UInt = #line) -> BookDetailScreen {
        resultCell(bookID: id).tap()
        return BookDetailScreen(app: app).waitUntilDisplayed(file: file, line: line)
    }

    /// Satırı sola kaydırır ve görünen başlığı `title` olan eyleme dokunur ("Özet" ya da "Favori").
    /// `UIContextualAction` bir view olmadığı için kimliği yok; XCUITest onu başlığıyla bulur.
    func swipeAction(_ title: String, onBook id: Int) {
        resultCell(bookID: id).swipeLeft()
        app.buttons[title].firstMatch.tap()
    }

    /// Detay ekranından alt araç çubuğundaki "Sonuçlara dön" ile aramaya döner.
    @discardableResult
    func backToResults() -> Self {
        backToResultsButton.tap()
        return waitUntilDisplayed()
    }
}
