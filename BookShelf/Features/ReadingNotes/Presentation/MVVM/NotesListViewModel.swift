import Foundation
import Observation

/// **MVVM → ViewModel.** Okuma notları ekranının durumunu ve kullanıcı eylemlerini yönetir.
///
/// VIPER ile karşılaştır (aynı özellik, aynı use case'ler):
/// - VIPER'da Presenter, View'ı bir protokol üzerinden **bilir** ve ona komut verir: `view?.render(...)`.
/// - MVVM'de ViewModel View'ı **hiç bilmez**. Durumu yayınlar; SwiftUI view'ı `@Observable` sayesinde okuduğu
///   özellikler değişince kendini yeniden çizer. Geri referans yok → weak/strong derdi de yok.
/// - VIPER'daki Interactor + Presenter'ın işi burada tek sınıfta; Router'ın işi (editörü açmak) view'da bir durum
///   (`isEditorPresented`). Daha az dosya, daha az tören; ama ekran büyüdükçe bu sınıf da şişmesin diye iş kuralları
///   use case'lerde kalmalı (burada da öyle).
///
/// `@MainActor`: SwiftUI bu nesneyi ana thread'de okur; tüm durum ana actor'e bağlı, data race'i derleyici engeller.
/// SwiftUI import etmiyor: birim testleri view açmadan, doğrudan `await viewModel.load()` diye çalışır.
@MainActor
@Observable
final class NotesListViewModel {
    /// Birbirini dışlayan ekran durumları. Boş liste ayrı bir durum değil: `.loaded([])`.
    enum State: Equatable {
        case loading
        case loaded([NoteRow])
        case failed(message: String)
    }

    private(set) var state: State = .loading

    /// Editör sayfasındaki metin. View `$viewModel.draftText` ile iki yönlü bağlar (`@Bindable`).
    /// Kullanıcı yazmaya devam edince eski hata mesajı kalksın diye `didSet` (gözlem, `@Observable` ile çalışır).
    var draftText = "" {
        didSet { editorMessage = nil }
    }

    /// Editörde gösterilen hata: doğrulama ("Not boş olamaz.") ya da kaydetme hatası. Mesaj domain'den gelir;
    /// VIPER tarafındaki alert ile birebir aynı metin.
    private(set) var editorMessage: String?

    /// Silme başarısız olursa gösterilen uyarı. View `nil` yaparak kapatır.
    var alertMessage: String?

    // `let` özellikler `@Observable` tarafından izlenmez; zaten hiç değişmezler.
    private let useCases: NotesUseCases
    private let formatter: any NoteFormatter

    /// Constructor injection: VIPER interactor'ının aldığı use case paketinin aynısı.
    init(useCases: NotesUseCases, formatter: any NoteFormatter = DateNoteFormatter()) {
        self.useCases = useCases
        self.formatter = formatter
    }

    /// "12/280". Sayım, iş kuralıyla aynı kırpmayı kullanır (`AddNoteUseCase.normalized`).
    var characterCountText: String {
        "\(AddNoteUseCase.normalized(draftText).count)/\(AddNoteUseCase.maxLength)"
    }

    var isDraftTooLong: Bool {
        AddNoteUseCase.normalized(draftText).count > AddNoteUseCase.maxLength
    }

    // MARK: - Eylemler

    /// View'daki `.task { await viewModel.load() }` çağırır.
    func load() async {
        do {
            state = .loaded(rows(for: try await useCases.fetch.execute()))
        } catch is CancellationError {
            // View ekrandan kalktı ve SwiftUI `.task`'ı iptal etti; bu bir hata değil. Durum aynı kalır,
            // view tekrar göründüğünde `.task` yeniden çalışır.
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    /// Editör açılırken çağrılır: her yeni not temiz bir sayfayla başlar (`didSet` eski mesajı da siler).
    func startNewNote() {
        draftText = ""
    }

    /// Taslağı kaydeder. Başarılıysa `true` döner; view bunu görünce editörü kapatır.
    /// Başarısızsa editör açık kalır ve `editorMessage` dolar (kullanıcının yazdığı kaybolmaz).
    func saveDraft() async -> Bool {
        do {
            try await useCases.add.execute(text: draftText)
        } catch {
            // `NoteValidationError` da depo hatası da `LocalizedError`: ikisi de gösterilmeye hazır Türkçe mesaj verir.
            editorMessage = error.localizedDescription
            return false
        }
        draftText = ""
        await load()
        return true
    }

    /// Satırı siler. **İyimser güncelleme** (optimistic update): satır önce ekrandan kalkar, sonra depodan silinir.
    /// SwiftUI kaydırma eyleminden sonra satırın hemen kaybolmasını bekler; depo cevabını beklemek titreme yapardı.
    /// Silme başarısız olursa liste depodan yeniden okunur (satır geri gelir) ve uyarı gösterilir.
    func delete(_ row: NoteRow) async {
        if case .loaded(let rows) = state {
            state = .loaded(rows.filter { $0.id != row.id })
        }
        do {
            try await useCases.delete.execute(id: row.id)
        } catch {
            alertMessage = error.localizedDescription
        }
        await load()
    }

    // MARK: - Yardımcı

    private func rows(for notes: [ReadingNote]) -> [NoteRow] {
        notes.map { NoteRow(note: $0, formatter: formatter) }
    }
}
