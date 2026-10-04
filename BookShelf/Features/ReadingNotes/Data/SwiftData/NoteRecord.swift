import Foundation
import SwiftData

/// SwiftData'daki **kayıt tipi**. Core Data'daki `NoteEntity`'nin karşılığı, ama model dosyası yok:
/// Şema doğrudan bu sınıftan, `@Model` makrosuyla üretilir.
///
/// `@Model` ne yapar? Sınıfı `PersistentModel` protokolüne uydurur ve her saklanan özelliği, SwiftData'nın
/// değişiklikleri izleyebileceği erişimcilere (getter/setter) çevirir. Ayrıca sınıfı `Observable` yapar;
/// SwiftUI'da `@Query` ile doğrudan listelenebilir.
///
/// Neden `struct` değil de `class`? Model nesnelerinin **kimliği** vardır: Bir `ModelContext` aynı kaydı tek bir
/// nesneyle temsil eder ve değişiklikleri o nesne üzerinden izler. Bu yüzden `@Model` yalnızca class'lara uygulanır.
///
/// Sınırlar: `@Model` nesneleri `Sendable` DEĞİLDİR; yalnızca onları getiren `ModelContext`'in izolasyonunda
/// (burada `SwiftDataNotesRepository` actor'ü) kullanılır. Dışarı `ReadingNote` struct'ı olarak çıkar.
/// Başka bir actor'e bir kaydı göstermek gerekirse `persistentModelID` (`PersistentIdentifier`, Sendable) verilir.
@Model
final class NoteRecord {
    /// Adı bilerek `id` değil: `PersistentModel` zaten `Identifiable` ve kendi `id`'si (`persistentModelID`) var.
    /// Aynı adı kullanmak iki farklı kimliği karıştırırdı.
    ///
    /// `.unique`: Veritabanında bu değerden yalnızca bir kayıt olabilir. Aynı `noteID` ile ikinci bir kayıt eklenirse
    /// SwiftData yenisini eklemek yerine mevcut kaydı günceller (upsert). Biz yine de açıkça arayıp güncelliyoruz;
    /// kural burada ikinci bir güvenlik ağı.
    @Attribute(.unique) var noteID: UUID
    var text: String
    /// SwiftData opsiyonel skaler tipleri doğrudan destekler (Core Data'daki `NSNumber?` dolambacına gerek yok).
    var bookID: Int?
    var createdAt: Date

    init(note: ReadingNote) {
        noteID = note.id
        text = note.text
        bookID = note.bookID
        createdAt = note.createdAt
    }

    /// Kayıt → domain dönüşümü. Yalnızca modelin context'inin izolasyonunda çağrılmalı.
    var readingNote: ReadingNote {
        ReadingNote(id: noteID, text: text, bookID: bookID, createdAt: createdAt)
    }

    /// Domain → kayıt (güncelleme). `noteID` değişmez.
    func update(from note: ReadingNote) {
        text = note.text
        bookID = note.bookID
        createdAt = note.createdAt
    }
}
