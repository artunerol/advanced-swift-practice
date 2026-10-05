import SwiftUI
import UIKit

/// **VIPER → Router.** İki görev:
/// 1. **Modülü kurmak** (`build`): parçaları oluşturup bağlar. Dışarıdan bakan VIPER'ın iç yapısını bilmez; bir
///    `UIViewController` alır.
/// 2. **Navigasyon**: Presenter "bu kitabı göster" der; nasıl gösterileceğini (push, sheet, alert) router bilir.
///
/// Okuma Notları router'ından farkı: O yalnızca bir alert (editör) açar. Bu router **gerçek bir navigasyon** yapar:
/// SwiftUI ile yazılmış `BookDetailView`'ı bir `UIHostingController`'a sarıp navigasyon yığınına **push** eder.
/// (UIKit içinde SwiftUI; `FavoritesViewController` ile aynı köprü.)
@MainActor
final class BookSearchRouter {
    /// **weak**: VC'nin sahibi navigasyon yığını; router ondan ekran açar. Strong olsaydı VC → presenter → router → VC
    /// döngüsü kurulurdu.
    weak var viewController: UIViewController?

    /// Detay ekranının ihtiyaç duyduğu bağımlılıklar (servis + favoriler). Değer tipi; kopyalar aynı actor'ü paylaşır.
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    /// Modülü kurar ve kök view controller'ı döndürür. Bu fonksiyon modülün küçük **composition root**'udur.
    ///
    /// Bağımlılık enjeksiyonu iki biçimde (Okuma Notları ile aynı):
    /// - **Constructor injection** (zorunlu, strong): use case'ler + ayar → interactor; interactor + router → presenter;
    ///   presenter → VC.
    /// - **Property injection** (geri dönen weak referanslar): `presenter.view`, `interactor.output`,
    ///   `router.viewController`. Tavuk-yumurta: presenter oluşturulurken VC henüz yok; döngünün bir yönü nesneler
    ///   oluştuktan SONRA bağlanmak zorunda.
    ///
    /// - Parameters:
    ///   - dependencies: Uygulamanın paylaşılan servisi ve favori actor'ü (`AppDependencies`).
    ///   - recentSearchesStore: Son aramaların deposu. Uygulama UserDefaults, testler bellek deposu verir.
    ///   - configuration: Debounce süresi. Uygulama `forLaunch(arguments:)` ile seçer; interactor `ProcessInfo` okumaz.
    static func build(
        dependencies: AppDependencies,
        recentSearchesStore: any RecentSearchesStore,
        configuration: BookSearchConfiguration = .standard
    ) -> UIViewController {
        let useCases = BookSearchUseCases(
            service: dependencies.bookService,
            favorites: dependencies.favorites,
            recentSearchesStore: recentSearchesStore
        )
        let interactor = BookSearchInteractor(useCases: useCases, configuration: configuration)
        let router = BookSearchRouter(dependencies: dependencies)
        let presenter = BookSearchPresenter(interactor: interactor, router: router)
        let viewController = BookSearchViewController(presenter: presenter)

        presenter.view = viewController
        interactor.output = presenter
        router.viewController = viewController
        return viewController
    }

    // MARK: - Ekran fabrikaları (static: pencere olmadan test edilebilir, `self` yakalanamaz)

    /// Kitap detayı: SwiftUI view'ı saran sıradan bir `UIViewController`.
    ///
    /// `favoriteButtonPlacement: .header`: SwiftUI'ın `.toolbar`'ı UIKit navigasyon çubuğuna taşınmıyor (bkz.
    /// `BookDetailView` belgesi) ve bu modülde UIKit çubuğu zaten gizli. Kalp düğmesi içerikte gösterilir.
    ///
    /// `toolbarItems`: Geri dönüş düğmesi. Navigasyon çubuğu gizli olduğu için sistemin geri düğmesi yok; yığının alt
    /// araç çubuğunda (toolbar) "Sonuçlara dön" gösterilir. Araç çubuğunu ne zaman göstereceğine `BookSearchVIPERContainer`
    /// karar verir: `toolbarItems`'ı olan ekranda görünür, olmayanda gizli.
    static func makeBookDetail(for book: Book, dependencies: AppDependencies) -> UIViewController {
        let detail = UIHostingController(
            rootView: BookDetailView(book: book, dependencies: dependencies, favoriteButtonPlacement: .header)
        )
        detail.title = book.title
        // `[weak detail]`: Düğme → action → closure; closure detail'i strong tutsaydı detail → toolbarItems → düğme →
        // closure → detail döngüsü kurulurdu. `navigationController` her dokunuşta yeniden okunur.
        let back = UIBarButtonItem(
            title: "Sonuçlara dön",
            image: UIImage(systemName: "chevron.backward"),
            primaryAction: UIAction { [weak detail] _ in
                detail?.navigationController?.popViewController(animated: true)
            }
        )
        back.accessibilityIdentifier = AccessibilityID.BookSearch.backToResultsButton
        detail.toolbarItems = [back, UIBarButtonItem(systemItem: .flexibleSpace)]
        return detail
    }

    /// Kitap özeti: tek "Tamam" düğmeli bir alert. Metni presenter hazırladı; router yalnızca gösterir.
    static func makeInsightsAlert(for summary: BookInsightsSummary) -> UIAlertController {
        typealias ID = AccessibilityID.BookSearch
        let alert = UIAlertController(title: summary.title, message: summary.message, preferredStyle: .alert)
        alert.view.accessibilityIdentifier = ID.insightsAlert
        let ok = UIAlertAction(title: "Tamam", style: .default)
        ok.accessibilityIdentifier = ID.insightsOKButton
        alert.addAction(ok)
        return alert
    }
}

extension BookSearchRouter: BookSearchRouterProtocol {
    /// Push için bir `UINavigationController` gerekir. VC bir yığının içinde değilse (ör. testte tek başına) sessizce atlanır.
    func showBookDetail(_ book: Book) {
        guard let navigationController = viewController?.navigationController else { return }
        navigationController.pushViewController(Self.makeBookDetail(for: book, dependencies: dependencies), animated: true)
    }

    func showInsights(_ summary: BookInsightsSummary) {
        viewController?.present(Self.makeInsightsAlert(for: summary), animated: true)
    }
}
