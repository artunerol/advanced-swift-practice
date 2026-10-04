import XCTest

/// Uygulamanın kök iskeleti: dört sekmeli sekme çubuğu (`RootTabView`).
///
/// Sekme düğmeleri **etiket metniyle** bulunur (`AccessibilityID.Tab` sabitleri aynı zamanda sekme başlıklarıdır).
/// Kimlik kullanamıyoruz, çünkü sekme düğmelerini SwiftUI'ın `TabView`'ı oluşturuyor ve kimliklerini biz vermiyoruz.
/// iOS 26 simülatöründe bu düğmelerin kimliği bile sabit değil: Bazen hiç yok, bazen seçili sekmenin SF Symbol adı
/// (ör. Favoriler seçiliyken `heart`, Laboratuvar seçiliyken `flask`). Etiket ise hep aynı.
@MainActor
struct TabBarScreen: Screen {
    let app: XCUIApplication

    var rootElement: XCUIElement { app.tabBars.firstMatch }

    func tabButton(_ title: String) -> XCUIElement {
        app.tabBars.buttons[title]
    }

    @discardableResult
    func openBooks() -> BookListScreen {
        tabButton(AccessibilityID.Tab.books).tap()
        return BookListScreen(app: app)
    }

    @discardableResult
    func openFavorites() -> FavoritesScreen {
        tabButton(AccessibilityID.Tab.favorites).tap()
        return FavoritesScreen(app: app)
    }

    @discardableResult
    func openLab() -> LabScreen {
        tabButton(AccessibilityID.Tab.lab).tap()
        return LabScreen(app: app)
    }

    @discardableResult
    func openInterview() -> InterviewHubScreen {
        tabButton(AccessibilityID.Tab.interview).tap()
        return InterviewHubScreen(app: app)
    }
}
