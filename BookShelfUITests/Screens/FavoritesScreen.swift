import XCTest

/// "Favoriler" sekmesi (`FavoritesViewController`, UIKit).
///
/// UIKit'te kimlik `accessibilityIdentifier` özelliğiyle verilir; XCUITest açısından SwiftUI'dan hiçbir farkı yoktur.
/// Test, ekranın hangi çatıyla yazıldığını bilmez; sadece erişilebilirlik ağacını görür:
/// ```
/// NavigationBar "Favoriler"
///   Button "favorites.clearAll"            label: "Tümünü temizle"
/// Table "favorites.table"
///   Cell "favorites.cell.3"                (UITableViewCell)
///     StaticText "Saatleri Ayarlama Enstitüsü"
/// StaticText "favorites.emptyState"        (liste boşken)
/// ```
@MainActor
struct FavoritesScreen: Screen {
    private typealias ID = AccessibilityID.Favorites

    let app: XCUIApplication

    var rootElement: XCUIElement { table }

    var table: XCUIElement { app.tables[ID.table] }
    var emptyStateLabel: XCUIElement { app.staticTexts[ID.emptyState] }
    var errorMessage: XCUIElement { app.staticTexts[ID.errorMessage] }
    var retryButton: XCUIElement { app.buttons[ID.retryButton] }
    var clearAllButton: XCUIElement { app.buttons[ID.clearAllButton] }

    func cell(bookID: Int) -> XCUIElement {
        app.cells[ID.cell(bookID: bookID)]
    }

    // MARK: "Tümünü temizle" onay penceresi (UIAlertController)

    var clearAllAlert: XCUIElement { app.alerts[ID.clearAllAlert] }

    /// Onay penceresindeki düğmeler iOS 26'da ağaçta iç içe İKİ kez görünür (aynı kimlik ve etiketle).
    /// Doğrudan `tap()` "Multiple matching elements" hatası verir; `.firstMatch` ilk eşleşmeyi seçer.
    var clearAllConfirmButton: XCUIElement { app.buttons[ID.clearAllConfirmButton].firstMatch }
    var clearAllCancelButton: XCUIElement { app.buttons[ID.clearAllCancelButton].firstMatch }

    // MARK: Eylemler

    /// Satırı sola kaydırıp çıkan "Kaldır" eylemine dokunur.
    ///
    /// `UIContextualAction` bir `UIView` değildir, `accessibilityIdentifier`'ı yoktur. Bu yüzden onu görünen başlığıyla
    /// buluruz. Başlık `Shared/` altındaki sabitten geldiği için uygulama ile test yine aynı metni kullanır.
    /// `swipeLeft()` koordinat istemez: Kaydırmayı hücrenin kendi çerçevesi içinde yapar.
    func removeWithSwipe(bookID: Int) {
        cell(bookID: bookID).swipeLeft()
        app.buttons[ID.removeActionTitle].tap()
    }

    /// Hücreye dokunur; UIKit, SwiftUI detay ekranını (`UIHostingController`) navigasyon yığınına push eder.
    func openBook(
        id bookID: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> BookDetailScreen {
        cell(bookID: bookID).tap()
        return BookDetailScreen(app: app).waitUntilDisplayed(file: file, line: line)
    }
}
