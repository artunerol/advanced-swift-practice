import Foundation

/// **VIPER → Interactor.** İş mantığını çalıştırır: use case'leri çağırır, sonucu `output`'a (presenter'a) bildirir.
///
/// Ne bilmez? UIKit, ekran, metin biçimlendirme. Ne bilir? Domain (use case'ler, `ReadingNote`, hatalar).
/// İş kuralları (boş not olmaz, en fazla 280 karakter) burada da değil, use case'lerde; interactor onları sıraya
/// koyar: "kaydet, sonra listeyi yeniden oku".
///
/// Async köprüsü: Presenter'dan gelen çağrılar senkron (UIKit olayları senkron). Interactor her iş için bir `Task`
/// açar. Task `@MainActor` bağlamını miras alır; `await` sırasında ana thread serbest kalır, use case'ler (nonisolated
/// async) arka planda çalışır ve sonuç yine ana actor'de `output`'a iletilir.
///
/// Neden task'ları saklayıp iptal etmiyoruz? Hepsi kısa ömürlü ve kullanıcının niyetini temsil ediyor ("kaydet" dendi →
/// ekran kapansa bile kayıt tamamlanmalı). Task'lar `self`'i yalnızca `[weak self]` ile ve sadece iş BİTTİKTEN sonra
/// kullanır; beklerken modülü hayatta tutmaz. Modül kapandıysa sonuç sessizce düşer (`self?.output?` → `nil`).
@MainActor
final class NotesListInteractor {
    /// **weak** + **property injection**: presenter interactor'ı strong tutuyor. `build(...)` tarafından atanır.
    weak var output: (any NotesListInteractorOutput)?

    /// **constructor injection**: interactor'ın tek bağımlılığı. Somut bir depo değil, domain'in use case'leri.
    private let useCases: NotesUseCases

    init(useCases: NotesUseCases) {
        self.useCases = useCases
    }

    /// Depodaki güncel listeyi okur. Ekle/sil sonrası da çağrılır: ekranın tek doğruluk kaynağı depodur;
    /// presenter kendi kopyasını elle güncellemez, iki kaynak birbirinden ayrışamaz.
    private static func fetchNotes(_ useCases: NotesUseCases) async -> Result<[ReadingNote], any Error> {
        do {
            return .success(try await useCases.fetch.execute())
        } catch {
            return .failure(error)
        }
    }

    private func deliver(_ result: Result<[ReadingNote], any Error>) {
        switch result {
        case .success(let notes): output?.didLoadNotes(notes)
        case .failure(let error): output?.didFail(with: error)
        }
    }
}

extension NotesListInteractor: NotesListInteractorInput {
    func loadNotes() {
        // Task'ın ihtiyacı olan değeri yerel sabite kopyalıyoruz (`NotesUseCases` bir `Sendable` struct).
        let useCases = useCases
        Task { [weak self] in
            let result = await Self.fetchNotes(useCases)
            self?.deliver(result)
        }
    }

    func addNote(text: String) {
        let useCases = useCases
        Task { [weak self] in
            do {
                try await useCases.add.execute(text: text)
            } catch let error as NoteValidationError {
                // İş kuralı ihlali bir kullanıcı hatasıdır, sistem hatası değil: ayrı bir çıkışla bildiriyoruz.
                self?.output?.didRejectNote(error)
                return
            } catch {
                self?.output?.didFail(with: error)
                return
            }
            let result = await Self.fetchNotes(useCases)
            self?.deliver(result)
        }
    }

    func deleteNote(id: ReadingNote.ID) {
        let useCases = useCases
        Task { [weak self] in
            do {
                try await useCases.delete.execute(id: id)
            } catch {
                // Silinemedi: satır ekranda zaten duruyor (VIPER tarafında iyimser silme yok), sadece haber ver.
                self?.output?.didFail(with: error)
                return
            }
            let result = await Self.fetchNotes(useCases)
            self?.deliver(result)
        }
    }
}
