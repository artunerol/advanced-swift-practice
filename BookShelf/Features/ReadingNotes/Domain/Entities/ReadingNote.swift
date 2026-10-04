import Foundation

/// **Domain katmanı → Entity.** Okurun bir kitap hakkında aldığı not.
///
/// Clean Architecture'da entity, uygulamanın en içteki halkasıdır: hiçbir çerçeveyi (UIKit, SwiftUI,
/// Core Data, SwiftData) bilmez, sadece Foundation kullanır. Veriyi nerede sakladığımız ya da nasıl gösterdiğimiz
/// değişse bile bu tip değişmez.
///
/// Dikkat: Bu bir Core Data `NSManagedObject`'i ya da SwiftData `@Model`'i DEĞİL. Depolama katmanı kendi kayıt
/// tipini kullanır ve sınırdan geçerken bu `struct`'a çevirir (mapping). Böylece:
/// - Managed object'ler thread'ler arasında sızmaz (Core Data'nın en klasik hatası),
/// - Üst katmanlar depolama teknolojisinden habersiz kalır.
struct ReadingNote: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var text: String
    /// Notun ilişkili olduğu kitap. `nil` = genel not.
    var bookID: Book.ID?
    let createdAt: Date

    init(id: UUID = UUID(), text: String, bookID: Book.ID? = nil, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.bookID = bookID
        self.createdAt = createdAt
    }
}
