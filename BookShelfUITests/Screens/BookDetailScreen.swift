import XCTest

/// Kitap detay ekranı (`BookDetailView`, SwiftUI).
///
/// Aynı ekran iki yoldan açılır ve bu nesne ikisinde de çalışır:
/// - Kitaplar sekmesinden: SwiftUI `NavigationStack` push'u. Kalp düğmesi navigasyon çubuğunda.
/// - Favoriler sekmesinden: UIKit `UINavigationController` + `UIHostingController`. Kalp düğmesi içerikte.
/// Düğmenin kimliği iki durumda da aynı olduğu için `favoriteButton` sorgusu değişmez. Page Object'in kazancı
/// burada görünür: Yerleşim farkı testlere hiç yansımaz.
@MainActor
struct BookDetailScreen: Screen {
    private typealias ID = AccessibilityID.BookDetail

    let app: XCUIApplication

    var rootElement: XCUIElement { title }

    var list: XCUIElement { app.collectionViews[ID.list] }
    var title: XCUIElement { app.staticTexts[ID.title] }
    var author: XCUIElement { app.staticTexts[ID.author] }
    /// ISBN rozeti; `label` "Geçerli" ya da "Geçersiz" (Objective-C doğrulayıcısının sonucu).
    var isbnStatus: XCUIElement { app.staticTexts[ID.isbnStatus] }
    /// Objective-C ile hesaplanan tahmini okuma süresi, ör. "18 sa 6 dk".
    var readingTime: XCUIElement { app.staticTexts[ID.readingTime] }
    var authorBio: XCUIElement { app.staticTexts[ID.authorBio] }
    var loadDuration: XCUIElement { app.staticTexts[ID.loadDuration] }

    /// Kalp düğmesi.
    ///
    /// Düğme navigasyon çubuğundayken ağaçta aynı kimlikle İKİ öğe var: SwiftUI araç çubuğu öğesinin sarmalayıcısı
    /// (`Other`) ve asıl `Button` (iOS 26 simülatöründe `app.debugDescription` ile görüldü).
    /// `app.buttons[...]` yalnızca `Button` türüne baktığı için tek eşleşme bulur. `app.descendants(matching: .any)[...]`
    /// yazsaydık "Multiple matching elements" hatası alırdık. Sorguyu öğenin türüyle yazmanın bir faydası daha.
    var favoriteButton: XCUIElement { app.buttons[ID.favoriteButton] }

    func review(id: Int) -> XCUIElement { app.otherElements[ID.review(id: id)] }

    // MARK: Eylemler

    func toggleFavorite() {
        favoriteButton.tap()
    }

    /// Ekranın altındaki yazar/süre bölümlerini görünür hale getirir (liste tembel olduğu için gerekli).
    func revealExtras() {
        list.scrollUp(toReveal: loadDuration)
    }

    /// Geri düğmesiyle Kitaplar listesine döner.
    @discardableResult
    func goBackToBookList() -> BookListScreen {
        tapBackButton()
        return BookListScreen(app: app)
    }

    /// Geri düğmesiyle Favoriler (UIKit) ekranına döner.
    @discardableResult
    func goBackToFavorites() -> FavoritesScreen {
        tapBackButton()
        return FavoritesScreen(app: app)
    }
}
