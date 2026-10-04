import Foundation

// MARK: - VIPER sözleşmeleri (contracts)
//
// VIPER = View · Interactor · Presenter · Entity · Router. Her harf ayrı bir sorumluluk, her ok bir protokol.
// Bu dosya modülün haritası: önce burayı oku, sonra sınıflara geç.
//
//   View (NotesListViewController)
//     │  olaylar: viewDidLoad, "Not ekle", "Sil"              ▲  render(durum), showError(...)
//     ▼                                                       │
//   Presenter (NotesListPresenter) ── "editörü aç" ──▶ Router (NotesListRouter)
//     │  loadNotes / addNote / deleteNote                     ▲  didLoadNotes / didRejectNote / didFail
//     ▼                                                       │
//   Interactor (NotesListInteractor) ── use case'ler ──▶ Domain (Entity: ReadingNote, NotesRepository)
//
// SAHİPLİK (mülakatın en sevdiği kısım):
//
//   Referans                              Tür      Neden
//   ───────────────────────────────────────────────────────────────────────────────────────────────────────────
//   ViewController → Presenter            strong   Modülü hayatta tutan zincirin başı. VC yaşadıkça modül yaşar.
//   Presenter → Interactor, Router        strong   Presenter onları kullanır ve onların tek sahibidir.
//   Presenter → View                      weak     VC zaten presenter'ı tutuyor; bu da strong olsaydı döngü olurdu.
//   Interactor → Presenter (output)       weak     Presenter interactor'ı tutuyor; aynı sebeple weak.
//   Router → ViewController               weak     VC'nin sahibi navigasyon yığını; router ondan ekran açar.
//
// Kural: Modülün tek dış sahibi ekranı gösteren yapıdır (navigation controller, SwiftUI). O, VC'yi bırakınca zincirin
// tamamı serbest kalır. Geriye dönen her referans `weak`, çünkü strong olsaydı her biri bir retain cycle kurardı.
// Bu yüzden View ve InteractorOutput protokolleri `AnyObject`: `weak` yalnızca sınıf örneklerine uygulanabilir.
// Kanıtı: `NotesListRouterTests.testReleasingViewControllerReleasesWholeModule`.
//
// Hepsi `@MainActor`: View'a dokunan herkes ana thread'de olmalı; derleyici bunu derleme anında denetler.
// Bu dosya UIKit import etmiyor: sözleşmeler UI çatısından bağımsız, testler sahte (mock) uygulamalar yazabilir.

/// **View** ← Presenter. Pasif: karar vermez, sadece söyleneni gösterir.
@MainActor
protocol NotesListViewProtocol: AnyObject {
    func render(_ state: NotesListViewState)
    func showError(title: String, message: String)
}

/// **Presenter** ← View. Kullanıcı olaylarını alır, kime ne yaptıracağına karar verir.
@MainActor
protocol NotesListPresenterProtocol {
    func viewDidLoad()
    func didTapAddNote()
    func didRequestDeleteNote(id: ReadingNote.ID)
}

/// **Interactor girişi** ← Presenter. İş mantığını (use case'leri) çalıştırır; UIKit bilmez.
/// Metotlar sonuç döndürmez: sonuç `NotesListInteractorOutput` üzerinden **sonra** gelir (klasik VIPER akışı).
@MainActor
protocol NotesListInteractorInput {
    func loadNotes()
    func addNote(text: String)
    func deleteNote(id: ReadingNote.ID)
}

/// **Interactor çıkışı** → Presenter. Interactor bu protokolü uygulayan nesneyi (presenter'ı) `weak` tutar.
@MainActor
protocol NotesListInteractorOutput: AnyObject {
    func didLoadNotes(_ notes: [ReadingNote])
    func didRejectNote(_ error: NoteValidationError)
    func didFail(with error: any Error)
}

/// **Router** ← Presenter. Navigasyon: hangi ekran, nasıl açılır. Modülü kuran `build(...)` de router'da durur.
@MainActor
protocol NotesListRouterProtocol {
    /// Not yazma arayüzünü açar. Kullanıcı "Kaydet"e basınca metni `onSave` ile geri verir.
    func presentNoteEditor(onSave: @escaping @MainActor (String) -> Void)
}

/// Presenter'ın View'a verdiği **hazır** durum. View'ın tek yaptığı bunu çizmek.
/// (VIPER'da buna sıkça "view model" de denir; MVVM'deki `NotesListViewModel` sınıfıyla karışmasın diye "state" dedik.)
enum NotesListViewState: Equatable, Sendable {
    case loading
    case empty(message: String)
    case notes(summary: String, rows: [NoteRow])
}
