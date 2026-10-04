import Foundation
@testable import BookShelf

/// Test verisi üreticileri ("fixture"). Varsayılan değerli parametreler sayesinde her test
/// sadece kendisi için önemli olan alanı belirtir: `Book.fixture(id: 7)`.

extension Book {
    static func fixture(
        id: Int = 1,
        title: String = "Test Kitabı",
        author: String = "Test Yazar",
        year: Int = 2000,
        isbn: String = "978-605-000-001-6",
        pageCount: Int = 200,
        summary: String = "Kısa bir özet."
    ) -> Book {
        Book(id: id, title: title, author: author, year: year, isbn: isbn, pageCount: pageCount, summary: summary)
    }

    static let fixtures: [Book] = [
        .fixture(id: 1, title: "Birinci Kitap", author: "Yazar A"),
        .fixture(id: 2, title: "İkinci Kitap", author: "Yazar B"),
        .fixture(id: 3, title: "Üçüncü Kitap", author: "Yazar A"),
    ]
}

extension Review {
    static func fixture(
        id: Int = 100,
        bookID: Book.ID = 1,
        reviewer: String = "Test Okur",
        rating: Int = 4,
        comment: String = "Güzel kitap."
    ) -> Review {
        Review(id: id, bookID: bookID, reviewer: reviewer, rating: rating, comment: comment)
    }
}

extension AuthorProfile {
    static func fixture(name: String = "Test Yazar", bio: String = "Kısa biyografi.", bookCount: Int = 2) -> AuthorProfile {
        AuthorProfile(name: name, bio: bio, bookCount: bookCount)
    }
}
