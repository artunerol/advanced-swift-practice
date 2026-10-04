import UIKit

/// **VIPER → Router** (bazı ekiplerde "Wireframe"). İki görevi var:
/// 1. **Modülü kurmak** (`build`): parçaları oluşturup birbirine bağlar. Dışarıdan bakan kişi VIPER'ın iç yapısını
///    bilmez; sadece `NotesListRouter.build(repository:)` çağırır ve bir `UIViewController` alır.
/// 2. **Navigasyon**: Presenter "editörü aç" der; nasıl açılacağını (alert mi, push mu, sheet mi) router bilir.
///    Yarın editör tam ekran bir view controller olsa presenter'ın tek satırı değişmez.
@MainActor
final class NotesListRouter {
    /// **weak**: VC'nin sahibi navigasyon yığını/SwiftUI; router onu sadece "buradan ekran aç" diye kullanır.
    /// Strong olsaydı VC → presenter → router → VC döngüsü oluşurdu.
    weak var viewController: UIViewController?

    /// Modülü kurar ve kök view controller'ı döndürür.
    ///
    /// Bağımlılık enjeksiyonu iki biçimde:
    /// - **Constructor injection** (zorunlu ve strong bağımlılıklar): use case'ler → interactor, interactor/router/
    ///   formatter → presenter, presenter → VC. Nesne bunlar olmadan oluşturulamaz.
    /// - **Property injection** (geri dönen weak referanslar): `presenter.view`, `interactor.output`,
    ///   `router.viewController`. Neden init ile değil? Tavuk-yumurta: presenter oluşturulurken VC henüz yok,
    ///   VC ise init'inde presenter istiyor. Döngünün bir yönü nesneler oluştuktan SONRA bağlanmak zorunda.
    ///
    /// `repository` parametresi somut bir sınıf değil, `any NotesRepository`: modül hangi depoyla çalıştığını bilmez.
    /// Bu fonksiyon modülün küçük **composition root**'udur; uygulamanınki `AppDependencies.makeForLaunch`.
    static func build(
        repository: any NotesRepository,
        formatter: any NoteFormatter = DateNoteFormatter()
    ) -> UIViewController {
        let interactor = NotesListInteractor(useCases: NotesUseCases(repository: repository))
        let router = NotesListRouter()
        let presenter = NotesListPresenter(interactor: interactor, router: router, formatter: formatter)
        let viewController = NotesListViewController(presenter: presenter)

        presenter.view = viewController
        interactor.output = presenter
        router.viewController = viewController
        return viewController
    }

    /// Not yazma arayüzü: tek metin alanlı bir `UIAlertController`.
    /// Oluşturma ayrı ve `static`: pencere (window) olmadan test edilebilsin, `self` yakalanamasın.
    static func makeNoteEditor(onSave: @escaping @MainActor (String) -> Void) -> UIAlertController {
        typealias ID = AccessibilityID.ReadingNotes.VIPER

        let alert = UIAlertController(
            title: "Yeni not",
            message: "En fazla \(AddNoteUseCase.maxLength) karakter.",
            preferredStyle: .alert
        )
        alert.view.accessibilityIdentifier = ID.editorAlert
        alert.addTextField { textField in
            textField.placeholder = "Kitaptan aklında kalan…"
            textField.autocapitalizationType = .sentences
            textField.accessibilityIdentifier = ID.editorTextField
        }

        let cancel = UIAlertAction(title: "Vazgeç", style: .cancel)
        cancel.accessibilityIdentifier = ID.editorCancelButton

        // `[weak alert]`: Düğme alert'e ait, closure düğmeye ait. Closure alert'i strong yakalasaydı
        // alert → düğme → closure → alert döngüsü kurulurdu.
        let save = UIAlertAction(title: "Kaydet", style: .default) { [weak alert] _ in
            onSave(alert?.textFields?.first?.text ?? "")
        }
        save.accessibilityIdentifier = ID.editorSaveButton

        alert.addAction(cancel)
        alert.addAction(save)
        alert.preferredAction = save
        return alert
    }
}

extension NotesListRouter: NotesListRouterProtocol {
    func presentNoteEditor(onSave: @escaping @MainActor (String) -> Void) {
        viewController?.present(Self.makeNoteEditor(onSave: onSave), animated: true)
    }
}
