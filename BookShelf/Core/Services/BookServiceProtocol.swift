import Foundation

/// Kitap verisine erişim için bir **sözleşme** (protocol).
///
/// Ekranlar ve view model'ler somut bir tipe (`LocalBookService`) değil, bu protokole bağımlıdır.
/// Buna *Dependency Inversion* denir ve iki büyük faydası vardır:
/// 1. **Test edilebilirlik:** Testlerde gerçek servis yerine anında cevap veren ya da bilerek hata fırlatan
///    sahte bir servis (stub / mock) verebiliriz.
/// 2. **Değiştirilebilirlik:** Yarın gerçek bir ağ servisi (`URLSession`) yazarsak ekran koduna dokunmayız.
///
/// Neden `: Sendable`?
/// Servis hem `@MainActor`'deki view model'lerden hem de arka plandaki task'lardan çağrılır.
/// Protokolü `Sendable` yapmak, onu uygulayan **her** tipin thread-safe olmasını derleyiciye zorunlu kıldırır.
/// Ayrıca `any BookServiceProtocol` değerleri de böylece concurrency sınırlarını geçebilir.
protocol BookServiceProtocol: Sendable {
    /// Tüm kitapları getirir.
    /// - `async`: Sonuç beklenirken thread **bloklanmaz**; fonksiyon askıya alınır (suspend) ve thread başka işe döner.
    /// - `throws`: Ağ / çözümleme hatası fırlatabilir; çağıran taraf `try await` yazmak zorundadır.
    func fetchBooks() async throws -> [Book]

    /// Bir kitabın yorumlarını getirir.
    func fetchReviews(for bookID: Book.ID) async throws -> [Review]

    /// Yazar profilini getirir. (Yerel serviste bilerek daha yavaştır.)
    func fetchAuthorProfile(named authorName: String) async throws -> AuthorProfile
}

/// Servisin fırlatabileceği hatalar. `Equatable` olması testlerde `XCTAssertEqual(error, .networkUnavailable)` yazabilmek içindir.
enum BookServiceError: Error, Equatable, LocalizedError {
    case resourceMissing
    case decodingFailed
    case networkUnavailable
    case authorNotFound(String)

    /// `LocalizedError` sayesinde `error.localizedDescription` bu metni döndürür; UI'da doğrudan gösterebiliriz.
    var errorDescription: String? {
        switch self {
        case .resourceMissing: "Kitap verisi bulunamadı."
        case .decodingFailed: "Kitap verisi okunamadı."
        case .networkUnavailable: "Bağlantı kurulamadı. Lütfen tekrar deneyin."
        case .authorNotFound(let name): "\(name) adlı yazar bulunamadı."
        }
    }
}
