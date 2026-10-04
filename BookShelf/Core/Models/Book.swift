import Foundation

/// Bir kitabı temsil eden **değer tipi** (`struct`).
///
/// Neden `class` değil de `struct`?
/// - Kitap verisi bir *değer*dir: iki kitabın tüm alanları aynıysa ikisi de "aynı kitap"tır.
///   Nesnenin *kimliği* (identity, bellekteki adresi) bizim için önemli değil.
/// - Struct'lar atanırken / fonksiyona verilirken **kopyalanır**. Bir kopyayı değiştirmek diğerini etkilemez,
///   bu yüzden "birisi benim verimi arkamdan değiştirdi" türü hatalar oluşmaz.
/// - Tüm alanları `Sendable` olduğu için struct da `Sendable` olur ve thread'ler / actor'ler arasında
///   güvenle taşınabilir. (Aynı şeyi bir `class` için sağlamak çok daha zordur.)
///
/// Uyulan protokoller:
/// - `Identifiable`: SwiftUI `List` / `ForEach` satırları `id` ile ayırt eder.
/// - `Hashable`: `Set`, UIKit diffable data source ve `NavigationLink(value:)` için gerekli.
///   Tüm alanlar `Hashable` olduğundan derleyici `==` ve `hash(into:)`'u **otomatik üretir** (synthesized conformance).
/// - `Codable`: JSON <-> Swift dönüşümü. JSON anahtarları property adlarıyla birebir aynı olduğu için ek kod gerekmez.
/// - `Sendable`: Concurrency sınırlarını güvenle geçebilir. Swift 6 derleyicisi bunu derleme anında denetler.
struct Book: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let title: String
    let author: String
    let year: Int
    /// Tireli ISBN-13 (ör. "978-605-000-001-6"). Geçerliliğini Objective-C tarafındaki `ISBNValidator` denetler.
    let isbn: String
    let pageCount: Int
    let summary: String
}
