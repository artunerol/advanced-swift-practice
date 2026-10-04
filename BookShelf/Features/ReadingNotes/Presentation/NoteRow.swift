import Foundation

/// Listede gösterilecek **hazır metinler**: bir notun ekrana çevrilmiş hali.
///
/// Entity (`ReadingNote`) ile ekran arasındaki çeviri katmanıdır. Ekran tarih biçimlendirmez, karakter saymaz;
/// sadece bu iki metni gösterir. Böylece biçimlendirme UI açmadan test edilir.
/// VIPER'da bu çeviriyi presenter, MVVM'de view model yapar; ikisi de aynı `NoteFormatter`'ı kullanır.
///
/// `Hashable`: UIKit'in diffable data source'u satırları bununla ayırt eder. `Identifiable`: SwiftUI `List` için.
struct NoteRow: Identifiable, Hashable, Sendable {
    let id: ReadingNote.ID
    /// Notun kendisi; çok satırlı olabilir (satır yüksekliği içeriğe göre büyür).
    let text: String
    /// İkincil satır, ör. "3 Eki 2026 14:05" ya da "42 karakter". Hangisi olacağını enjekte edilen biçimlendirici
    /// (`NoteFormatter`) belirler.
    let detail: String

    init(id: ReadingNote.ID, text: String, detail: String) {
        self.id = id
        self.text = text
        self.detail = detail
    }

    /// `some NoteFormatter`: generic parametre. `any NoteFormatter` tipinde bir değerle çağrılsa bile derleyici kutuyu
    /// açar (implicitly opened existential, Swift 5.7+); çağıranın ayrıca bir şey yapmasına gerek yok.
    init(note: ReadingNote, formatter: some NoteFormatter) {
        self.init(id: note.id, text: note.text, detail: formatter.detail(for: note))
    }
}
