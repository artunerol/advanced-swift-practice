import Foundation

/// **Domain katmanı → Use case (iş kuralı).** Yeni bir okuma notu ekler.
///
/// İş kuralları BURADA, tek yerde yaşar:
/// 1. Baştaki ve sondaki boşluklar/satır sonları kırpılır (ortadaki satır sonları korunur; not çok satırlı olabilir).
/// 2. Kırpılmış metin boş olamaz.
/// 3. En fazla `maxLength` (280) karakter.
///
/// Neden view controller'da ya da view model'de değil? Aynı kural hem VIPER (UIKit) hem MVVM (SwiftUI) ekranında
/// geçerli. Kuralı arayüze yazsaydık iki kopya olurdu ve bir gün biri değişip diğeri unutulurdu. Use case'te olunca
/// iki arayüz de **aynı kuralı, aynı hata mesajıyla** uygular; kural da UI olmadan, milisaniyeler içinde test edilir.
///
/// Bağımlılıklar `init` ile verilir (*constructor injection*):
/// - `repository`: somut bir sınıf değil, domain'in kendi `NotesRepository` protokolü (Dependency Inversion).
/// - `now`: "şu anki zaman" bile bir bağımlılıktır. `Date()`'i içeride çağırsaydık testte `createdAt`'i bilemezdik;
///   dışarıdan bir fonksiyon olarak alınca test sabit bir tarih verir. Varsayılan değer gerçek saattir.
struct AddNoteUseCase: Sendable {
    /// Bir notun en fazla kaç karakter olabileceği. Arayüzler sayaç göstermek için de bunu okur.
    static let maxLength = 280

    private let repository: any NotesRepository
    private let now: @Sendable () -> Date

    init(repository: any NotesRepository, now: @escaping @Sendable () -> Date = { Date() }) {
        self.repository = repository
        self.now = now
    }

    /// Kuralın uyguladığı kırpma. Arayüzler karakter sayacını kuralla AYNI hesapla göstersin diye ayrı ve `static`.
    static func normalized(_ rawText: String) -> String {
        rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Metni iş kurallarına göre doğrular ve kaydedilecek (kırpılmış) hali döndürür.
    ///
    /// *Typed throws* (`throws(NoteValidationError)`): Fonksiyon yalnızca doğrulama hatası fırlatabilir ve imzası
    /// bunu söylüyor; çağıran `catch` bloğunda `error`'u doğrudan `NoteValidationError` olarak alır, `as?` gerekmez.
    /// Senkron olduğu için arayüz, kaydetmeden önce anında geri bildirim vermek isterse de kullanabilir.
    ///
    /// Karakter sayımı: `String.count` **grapheme cluster** sayar, yani kullanıcının gördüğü karakterleri.
    /// "👍🏽" (iki Unicode scalar) 1 karakterdir. `utf16.count` kullansaydık emoji'li notlar haksız yere kısalırdı.
    func validate(_ rawText: String) throws(NoteValidationError) -> String {
        let text = Self.normalized(rawText)
        guard !text.isEmpty else {
            throw .empty
        }
        guard text.count <= Self.maxLength else {
            throw .tooLong(count: text.count, limit: Self.maxLength)
        }
        return text
    }

    /// Doğrular, notu oluşturur ve depoya kaydeder. Kaydedilen notu döndürür.
    ///
    /// Hata türleri: `NoteValidationError` (iş kuralı) veya depodan gelen hata (ör. `NotesRepositoryError`).
    /// İki farklı kaynak olduğu için burada typed throws değil, düz `throws` kullanıyoruz.
    @discardableResult
    func execute(text rawText: String, bookID: Book.ID? = nil) async throws -> ReadingNote {
        let text = try validate(rawText)
        let note = ReadingNote(text: text, bookID: bookID, createdAt: now())
        try await repository.save(note)
        return note
    }
}

/// Not ekleme kurallarının ihlali. Mesajlar Türkçe ve kullanıcıya gösterilmeye hazır (`LocalizedError`):
/// VIPER presenter'ı da MVVM view model'i de `error.localizedDescription`'ı olduğu gibi gösterir.
///
/// `Equatable`: testlerde `XCTAssertEqual(error, .empty)` yazabilmek için.
enum NoteValidationError: Error, Equatable, LocalizedError {
    case empty
    case tooLong(count: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .empty:
            "Not boş olamaz."
        case .tooLong(let count, let limit):
            "Not en fazla \(limit) karakter olabilir (şu an \(count))."
        }
    }
}
