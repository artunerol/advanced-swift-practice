import XCTest

/// Hata durumları: Uygulama `-simulate-network-error` ile açılınca servis her istekte hata fırlatır.
///
/// Gerçek bir ağ hatasını UI testinde üretmek zordur ve güvenilmezdir (uçak modu, sahte sunucu...). Bunun yerine
/// uygulamaya bir **başlatma argümanı** veririz; uygulama da buna bakıp hata veren bir servis kurar
/// (`AppDependencies.makeForLaunch(arguments:)`). Test, uygulamanın kodunu değiştirmeden onu istediği duruma sokar.
final class ErrorStateUITests: BookShelfUITestCase {

    @MainActor
    func testNetworkErrorShowsErrorViewWithRetryButton() {
        let app = launchApp(extraArguments: [LaunchArgument.simulateNetworkError])
        let bookList = BookListScreen(app: app)

        XCTContext.runActivity(named: "Liste yerine hata ekranı ve 'Tekrar Dene' düğmesi görünür") { _ in
            assertAppears(bookList.errorView)
            assertLabel(bookList.errorMessage, equals: "Bağlantı kurulamadı. Lütfen tekrar deneyin.")
            assertAppears(bookList.retryButton)
            XCTAssertTrue(bookList.retryButton.isHittable, "'Tekrar Dene' görünür ve dokunulabilir olmalı.")
            XCTAssertFalse(bookList.list.exists, "Hata durumunda kitap listesi gösterilmemeli.")
        }

        XCTContext.runActivity(named: "'Tekrar Dene': servis hâlâ hata verdiği için hata ekranı geri gelir") { _ in
            bookList.retryButton.tap()
            // Yeniden deneme sırasında bir an yükleme göstergesi görünür, sonra hata ekranı geri gelir.
            // Sıfır gecikmede bu çok hızlı olur; biz yalnızca SON durumu (yine hata) bekleyerek doğrularız.
            assertAppears(bookList.retryButton)
            assertLabel(bookList.errorMessage, equals: "Bağlantı kurulamadı. Lütfen tekrar deneyin.")
            XCTAssertFalse(bookList.row(bookID: 1).exists)
        }
    }

    @MainActor
    func testFavoritesTabShowsErrorAndRetryButton() {
        let app = launchApp(extraArguments: [LaunchArgument.simulateNetworkError])

        // Favoriler ekranı da kataloğu aynı servisten yükler; UIKit tarafındaki hata arayüzü de test edilmeli.
        let favorites = TabBarScreen(app: app).openFavorites()

        assertLabel(favorites.errorMessage, equals: "Bağlantı kurulamadı. Lütfen tekrar deneyin.")
        assertAppears(favorites.retryButton)
        XCTAssertFalse(favorites.emptyStateLabel.exists, "Hata durumunda 'henüz favorin yok' yazmak yanıltıcı olur.")
    }
}
