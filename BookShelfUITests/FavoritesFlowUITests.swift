import XCTest

/// Favoriler akışı: SwiftUI detay ekranında favorile → UIKit Favoriler sekmesinde gör → kaldır.
///
/// Bu testler üç parçanın birlikte çalıştığını doğrular: SwiftUI ekranları, UIKit ekranı ve aralarındaki tek doğruluk
/// kaynağı olan `FavoritesStore` actor'ü. Birim testleri parçaları tek tek doğrular; "kalbe dokununca diğer sekmedeki
/// tablo güncelleniyor mu?" sorusunu ancak uçtan uca bir UI testi cevaplar.
final class FavoritesFlowUITests: BookShelfUITestCase {

    @MainActor
    func testFavoritingInDetailUpdatesListRowAndFavoritesTab() {
        let bookList = BookListScreen(app: launchApp()).waitUntilDisplayed()

        let detail = bookList.openBook(id: 2)
        XCTContext.runActivity(named: "Detayda kalbe dokun: düğmenin value'su değişir") { _ in
            assertValue(detail.favoriteButton, equals: AccessibilityID.BookValue.notFavorite)
            detail.toggleFavorite()
            // Dokunuş bir `Task` açar ve actor'ü `await` eder; value hemen değişmeyebilir. Bu yüzden bekleyerek doğrularız.
            assertValue(detail.favoriteButton, equals: AccessibilityID.BookValue.favorite)
        }

        XCTContext.runActivity(named: "Listeye dön: satır favori olarak işaretli") { _ in
            detail.goBackToBookList()
            // Liste, actor'ün AsyncStream'inden gelen yeni kümeyle güncellenir.
            assertValue(bookList.row(bookID: 2), equals: AccessibilityID.BookValue.favorite)
        }

        XCTContext.runActivity(named: "Favoriler sekmesinde (UIKit) kitabın hücresi var") { _ in
            let favorites = bookList.tabBar.openFavorites().waitUntilDisplayed()
            assertAppears(favorites.cell(bookID: 2))
            XCTAssertFalse(favorites.emptyStateLabel.exists, "Favori varken boş liste mesajı görünmemeli.")
            XCTAssertTrue(favorites.clearAllButton.isEnabled, "Favori varken 'Tümünü temizle' etkin olmalı.")
        }
    }

    @MainActor
    func testSwipeToRemoveShowsEmptyState() {
        let bookList = BookListScreen(app: launchApp()).waitUntilDisplayed()
        let detail = bookList.openBook(id: 1)
        detail.toggleFavorite()
        assertValue(detail.favoriteButton, equals: AccessibilityID.BookValue.favorite)

        let favorites = detail.tabBar.openFavorites().waitUntilDisplayed()
        assertAppears(favorites.cell(bookID: 1))

        XCTContext.runActivity(named: "Hücreyi sola kaydır ve 'Kaldır'a dokun") { _ in
            favorites.removeWithSwipe(bookID: 1)
        }

        XCTContext.runActivity(named: "Hücre kaybolur, boş liste mesajı görünür") { _ in
            assertDisappears(favorites.cell(bookID: 1))
            assertAppears(favorites.emptyStateLabel)
            // Boş listede temizlenecek bir şey yok; düğme devre dışı. `isEnabled` bir anlık okuma olduğu için
            // önce hücrenin kaybolmasını bekledik (durum o sırada zaten güncellenmiş oluyor).
            XCTAssertFalse(favorites.clearAllButton.isEnabled)
        }
    }

    @MainActor
    func testOpeningFavoriteShowsSwiftUIDetailInsideUIKit() {
        let bookList = BookListScreen(app: launchApp()).waitUntilDisplayed()
        let detailFromList = bookList.openBook(id: 3)
        detailFromList.toggleFavorite()
        assertValue(detailFromList.favoriteButton, equals: AccessibilityID.BookValue.favorite)

        let favorites = detailFromList.tabBar.openFavorites().waitUntilDisplayed()

        // UIKit tablosu hücreye dokununca SwiftUI `BookDetailView`'i bir `UIHostingController` içinde push eder.
        let detail = XCTContext.runActivity(named: "Favori hücresine dokun: UIKit içinde SwiftUI detay açılır") { _ in
            favorites.openBook(id: 3)
        }

        XCTContext.runActivity(named: "Detay aynı kitabı ve güncel favori durumunu gösterir") { _ in
            assertLabel(detail.title, equals: "Saatleri Ayarlama Enstitüsü")
            assertLabel(detail.isbnStatus, equals: AccessibilityID.BookValue.isbnValid)
            // Bu ekranda kalp düğmesi araç çubuğunda değil, içerikte; ama kimliği aynı olduğu için sorgu da aynı.
            assertValue(detail.favoriteButton, equals: AccessibilityID.BookValue.favorite)
        }

        XCTContext.runActivity(named: "Favoriden çıkar ve geri dön: hücre kaybolur") { _ in
            detail.toggleFavorite()
            assertValue(detail.favoriteButton, equals: AccessibilityID.BookValue.notFavorite)

            detail.goBackToFavorites()
            assertDisappears(favorites.cell(bookID: 3))
            assertAppears(favorites.emptyStateLabel)
        }
    }

    @MainActor
    func testClearAllAsksForConfirmationAndRemovesEveryFavorite() {
        let bookList = BookListScreen(app: launchApp()).waitUntilDisplayed()
        for bookID in [4, 5] {
            let detail = bookList.openBook(id: bookID)
            detail.toggleFavorite()
            assertValue(detail.favoriteButton, equals: AccessibilityID.BookValue.favorite)
            detail.goBackToBookList()
        }

        let favorites = bookList.tabBar.openFavorites().waitUntilDisplayed()
        assertAppears(favorites.cell(bookID: 4))
        assertAppears(favorites.cell(bookID: 5))

        XCTContext.runActivity(named: "'Tümünü temizle': önce onay penceresi (UIAlertController) açılır") { _ in
            favorites.clearAllButton.tap()
            assertAppears(favorites.clearAllAlert)
        }

        XCTContext.runActivity(named: "'Tümünü kaldır' ile onayla: tüm hücreler gider") { _ in
            favorites.clearAllConfirmButton.tap()
            assertDisappears(favorites.clearAllAlert)
            assertDisappears(favorites.cell(bookID: 4))
            assertDisappears(favorites.cell(bookID: 5))
            assertAppears(favorites.emptyStateLabel)
        }
    }
}
