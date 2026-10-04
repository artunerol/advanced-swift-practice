import Foundation
@testable import BookShelf

/// Okuma notları mimari testlerinin sahte nesneleri (test doubles).
///
/// Hepsi bir `enum`'un içinde: Test hedefi tek bir modül; başka bir özelliğin testleri de `ViewSpy` ya da
/// `FailingRepository` adında bir tip tanımlarsa çakışmasın. Kullanım: `NotesArchitectureDoubles.ViewSpy()`.
///
/// Terimler:
/// - **Spy (casus):** Kendisine yapılan çağrıları kaydeder; test sonra "şu çağrıldı mı?" diye bakar.
/// - **Stub:** Önceden belirlenmiş cevap döndürür.
/// - **Fake:** Gerçeğin basit ama çalışan bir uygulaması (ör. `InMemoryNotesRepository`).
enum NotesArchitectureDoubles {

    /// VIPER View'ının yerine geçer: presenter'ın ona ne çizdirdiğini kaydeder.
    @MainActor
    final class ViewSpy: NotesListViewProtocol {
        private(set) var renderedStates: [NotesListViewState] = []
        private(set) var shownErrors: [(title: String, message: String)] = []

        func render(_ state: NotesListViewState) {
            renderedStates.append(state)
        }

        func showError(title: String, message: String) {
            shownErrors.append((title, message))
        }
    }

    /// VIPER Interactor'ının yerine geçer: presenter'ın hangi işleri istediğini kaydeder, hiçbir şey çalıştırmaz.
    @MainActor
    final class InteractorSpy: NotesListInteractorInput {
        private(set) var loadNotesCallCount = 0
        private(set) var addedTexts: [String] = []
        private(set) var deletedIDs: [ReadingNote.ID] = []

        func loadNotes() { loadNotesCallCount += 1 }
        func addNote(text: String) { addedTexts.append(text) }
        func deleteNote(id: ReadingNote.ID) { deletedIDs.append(id) }
    }

    /// VIPER Router'ının yerine geçer. Editörü "açmaz"; verilen closure'ı saklar ki test "kullanıcı Kaydet'e bastı"
    /// durumunu `simulateSave(_:)` ile taklit edebilsin.
    @MainActor
    final class RouterSpy: NotesListRouterProtocol {
        private(set) var presentEditorCallCount = 0
        private var onSave: (@MainActor (String) -> Void)?

        func presentNoteEditor(onSave: @escaping @MainActor (String) -> Void) {
            presentEditorCallCount += 1
            self.onSave = onSave
        }

        func simulateSave(_ text: String) {
            onSave?(text)
        }
    }

    /// VIPER View'ın gördüğü presenter'ın yerine geçer (view controller testleri için).
    @MainActor
    final class PresenterSpy: NotesListPresenterProtocol {
        private(set) var viewDidLoadCallCount = 0
        private(set) var addTapCount = 0
        private(set) var deleteRequests: [ReadingNote.ID] = []

        func viewDidLoad() { viewDidLoadCallCount += 1 }
        func didTapAddNote() { addTapCount += 1 }
        func didRequestDeleteNote(id: ReadingNote.ID) { deleteRequests.append(id) }
    }

    /// Interactor'ın çıkışını dinler. Interactor işini bir `Task` içinde, **sonra** bitirir; test beklemek için
    /// `onEvent` closure'ına bir `XCTestExpectation`'ın `fulfill()`'ını koyar.
    @MainActor
    final class InteractorOutputSpy: NotesListInteractorOutput {
        enum Event: Equatable {
            case loaded([ReadingNote])
            case rejected(NoteValidationError)
            case failed(String)
        }

        private(set) var events: [Event] = []
        var onEvent: (() -> Void)?

        func didLoadNotes(_ notes: [ReadingNote]) { record(.loaded(notes)) }
        func didRejectNote(_ error: NoteValidationError) { record(.rejected(error)) }
        func didFail(with error: any Error) { record(.failed(error.localizedDescription)) }

        private func record(_ event: Event) {
            events.append(event)
            onEvent?()
        }
    }

    /// Her işlemde hata fırlatan depo: hata yollarını test etmek için (stub).
    struct FailingRepository: NotesRepository {
        static let error = NotesRepositoryError.storageFailure(reason: "disk dolu")

        func fetchAll() async throws -> [ReadingNote] { throw Self.error }
        func save(_ note: ReadingNote) async throws { throw Self.error }
        func delete(id: ReadingNote.ID) async throws { throw Self.error }
        func deleteAll() async throws { throw Self.error }
    }

    /// Okuma çalışır, yazma (kaydet/sil) başarısız: "liste geldi ama silme olmadı" senaryosu için.
    actor ReadOnlyRepository: NotesRepository {
        private let notes: [ReadingNote]

        init(notes: [ReadingNote]) {
            self.notes = notes
        }

        func fetchAll() -> [ReadingNote] { notes }
        func save(_ note: ReadingNote) throws { throw FailingRepository.error }
        func delete(id: ReadingNote.ID) throws { throw FailingRepository.error }
        func deleteAll() throws { throw FailingRepository.error }
    }

    /// Tarih ve dilden bağımsız, sabit çıktılı biçimlendirici: testler metni birebir karşılaştırabilsin.
    struct FixedFormatter: NoteFormatter {
        func detail(for note: ReadingNote) -> String { "ayrıntı: \(note.text)" }
    }

    /// Belirli bir saniyede oluşturulmuş not. Sıralama testlerinde tarihleri kontrol etmek için.
    static func note(_ text: String, at seconds: TimeInterval) -> ReadingNote {
        ReadingNote(text: text, createdAt: Date(timeIntervalSince1970: seconds))
    }
}
