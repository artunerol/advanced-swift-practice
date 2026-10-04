import Foundation

/// **VIPER → Presenter.** Modülün "trafik polisi": View'dan olay alır, Interactor'a iş, Router'a navigasyon yaptırır,
/// Interactor'dan gelen sonucu View'ın doğrudan çizebileceği metinlere (`NotesListViewState`) çevirir.
///
/// Bilerek `import UIKit` YOK. Presenter `UILabel`, `UIColor`, `UIAlertController` bilmez; bu yüzden birim testleri
/// ekran kurmadan, sahte (mock) View/Interactor/Router ile tamamen senkron çalışır (bkz. `NotesListPresenterTests`).
///
/// Bağımlılıklar:
/// - `interactor`, `router`, `formatter`: **constructor injection** + **strong**. Presenter onların sahibidir.
/// - `view`: **property injection** + **weak**. View (VC) presenter'ı zaten strong tutuyor. Ayrıca presenter
///   oluşturulurken VC henüz yok; bu yüzden `build(...)` VC'yi oluşturduktan SONRA bu özelliğe atar.
@MainActor
final class NotesListPresenter {
    weak var view: (any NotesListViewProtocol)?
    let interactor: any NotesListInteractorInput
    let router: any NotesListRouterProtocol
    private let formatter: any NoteFormatter

    init(
        interactor: any NotesListInteractorInput,
        router: any NotesListRouterProtocol,
        formatter: any NoteFormatter
    ) {
        self.interactor = interactor
        self.router = router
        self.formatter = formatter
    }

    /// Editörde "Kaydet"e basıldığında router'ın verdiği closure bu metodu çağırır.
    /// Doğrulama burada YAPILMAZ: kural domain'de (`AddNoteUseCase`). Presenter sadece metni iletir.
    func didSubmitNote(text: String) {
        interactor.addNote(text: text)
    }

    /// Notları ekran durumuna çeviren **saf** (pure) fonksiyon: aynı girdi → aynı çıktı, yan etki yok.
    /// `static` olduğu için `self`'e (ve dolayısıyla View'a) erişemez; test etmesi en kolay kod budur.
    static func viewState(for notes: [ReadingNote], formatter: some NoteFormatter) -> NotesListViewState {
        guard !notes.isEmpty else {
            return .empty(message: "Henüz not yok. İlk notunu eklemek için \"Not ekle\"ye dokun.")
        }
        return .notes(
            summary: "\(notes.count) not · en yeni en üstte",
            rows: notes.map { NoteRow(note: $0, formatter: formatter) }
        )
    }
}

// MARK: - View → Presenter

extension NotesListPresenter: NotesListPresenterProtocol {
    func viewDidLoad() {
        view?.render(.loading)
        interactor.loadNotes()
    }

    func didTapAddNote() {
        // Router editörü açar; sonucu bu closure ile geri verir. `[weak self]`: closure, ekrandaki alert'in düğmesinde
        // saklanır. Presenter'ı strong yakalasaydı alert açıkken modül kapanırsa presenter gereksiz yere yaşardı.
        router.presentNoteEditor { [weak self] text in
            self?.didSubmitNote(text: text)
        }
    }

    func didRequestDeleteNote(id: ReadingNote.ID) {
        interactor.deleteNote(id: id)
    }
}

// MARK: - Interactor → Presenter

extension NotesListPresenter: NotesListInteractorOutput {
    func didLoadNotes(_ notes: [ReadingNote]) {
        view?.render(Self.viewState(for: notes, formatter: formatter))
    }

    func didRejectNote(_ error: NoteValidationError) {
        view?.showError(title: "Not eklenemedi", message: error.localizedDescription)
    }

    func didFail(with error: any Error) {
        view?.showError(title: "Bir sorun oluştu", message: error.localizedDescription)
    }
}
