import Foundation

/// Yazar hakkında kısa bilgi. Kitap detay ekranında yorumlarla **paralel** (`async let`) yüklenir.
struct AuthorProfile: Hashable, Codable, Sendable {
    let name: String
    let bio: String
    /// Kitaplıkta bu yazara ait kaç kitap var.
    let bookCount: Int
}
