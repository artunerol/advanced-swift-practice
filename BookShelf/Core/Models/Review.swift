import Foundation

/// Bir kitaba yazılmış okur yorumu. `Book` gibi bu da değişmez (immutable) bir değer tipidir.
struct Review: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let bookID: Book.ID
    let reviewer: String
    /// 1...5 arası puan.
    let rating: Int
    let comment: String
}
