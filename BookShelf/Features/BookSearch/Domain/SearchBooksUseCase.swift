import Foundation

/// Arama sorgusunun iş kuralı ihlali.
///
/// Bilerek `LocalizedError` DEĞİL: Kullanıcıya ne yazılacağına (ör. "Aramak için en az 2 harf yaz.") presenter karar
/// verir. Domain yalnızca "kural neydi, nasıl çiğnendi" bilgisini taşır; metin bir sunum kararıdır.
/// (Okuma notlarında `NoteValidationError` mesajı kendisi taşıyor; iki yaklaşımı yan yana görmek için farklı bıraktık.)
enum SearchQueryError: Error, Equatable, Sendable {
    /// Kırpılmış sorgu `minimumLength` karakterden kısa.
    case tooShort(minimumLength: Int)
}

/// Kitap arama use case'inin sözleşmesi. Interactor testleri bunun yerine bir spy verir (bkz. `BookSearchUseCases`).
protocol SearchBooksUseCaseProtocol: Sendable {
    /// Kural 1, senkron ve anında: kırp, en az 2 karakter; geçerliyse kırpılmış sorguyu döndürür.
    /// Interactor bunu ağa çıkmadan ÖNCE çağırır: tek harf için ne debounce beklenir ne de servis çağrılır.
    func validatedQuery(_ rawQuery: String) throws(SearchQueryError) -> String

    /// Sorguyu (yeniden) doğrular, kitapları servisten alır, eşleşenleri sıralı döndürür.
    /// Hatalar: `SearchQueryError` (kural), `BookServiceError` (servis) ya da `CancellationError` (iptal).
    func execute(query rawQuery: String) async throws -> [Book]
}

/// **Use case türü: Sorgu + iş kuralı (uzak servis üzerinde).** Kitapları servisten alır, kuralları uygular, sıralar.
///
/// Neden use case? Burada üç **iş kuralı** var ve hiçbiri sunuma ya da veri kaynağına ait değil:
/// 1. **Geçerli sorgu:** kırpılır, en az `minimumQueryLength` (2) karakter. Tek harf ("a") kitaplıktaki 8 kitabın
///    8'ini de bulur; sonuç anlamsız, istek boşuna. Bu "ürün kararı" ekranda değil burada yaşar ki başka bir arayüz
///    (ör. SwiftUI) aynı kuralı paylaşsın.
/// 2. **Eşleşme:** başlıkta ve yazarda, Türkçe kurallarıyla büyük/küçük harf ve aksan farkı gözetmeden (bkz. `searchKey(for:)`).
/// 3. **Sıralama:** önce başlıkta eşleşenler, sonra yalnızca yazarda eşleşenler; her grup kendi içinde Türkçe alfabetik.
///
/// Neden presenter'da değil? Presenter "ne gösterilecek"i bilir, "hangi kitap uygundur"u değil. Kural presenter'da olsaydı
/// test için ekran durumu kurmak gerekirdi ve ikinci bir arayüz kuralı kopyalardı.
/// Neden repository'de (servis) değil? Servis veri getirir; filtre ve sıralama uygulamanın politikası. Yarın gerçek bir
/// sunucu arama yapsa bile "önce başlık" gibi bir sıralama kararı çoğu zaman yine istemcide kalır.
///
/// `nonisolated` + `Sendable` struct: UI'a dokunmaz, durumu yok (tek alanı `Sendable` bir servis). Bu projede
/// nonisolated `async` fonksiyonlar global concurrent executor'de çalışır: `@MainActor` interactor `await` ile çağırınca
/// filtreleme ve sıralama ana thread'i meşgul etmez.
struct SearchBooksUseCase: SearchBooksUseCaseProtocol {
    /// Bir sorgunun en az kaç karakter olması gerektiği (kırpıldıktan sonra).
    static let minimumQueryLength = 2

    /// Sıralama ve karşılaştırma Türkçe kurallarla: cihaz İngilizce olsa da sonuç aynı olsun (testler de cihazdan bağımsız).
    private static let turkish = Locale(identifier: "tr_TR")

    private let service: any BookServiceProtocol

    init(service: any BookServiceProtocol) {
        self.service = service
    }

    func execute(query rawQuery: String) async throws -> [Book] {
        // Doğrulama burada da var: `execute`'u `validatedQuery` olmadan çağıran biri kuralı atlayamasın.
        let query = try validatedQuery(rawQuery)
        let books = try await service.fetchBooks()
        // Servis cevap verdi ama bu arada arama iptal edildiyse (kullanıcı yeni harf yazdı) boşuna sıralama yapma.
        try Task.checkCancellation()
        return Self.matches(in: books, for: query)
    }

    // MARK: - Kurallar (saf fonksiyonlar: aynı girdi → aynı çıktı, `await` yok, test etmesi en kolay kod)

    /// Protokol gereksinimi; kuralın kendisi `static` `validate(_:)`'ta (test double'ları da aynı kuralı paylaşsın diye).
    func validatedQuery(_ rawQuery: String) throws(SearchQueryError) -> String {
        try Self.validate(rawQuery)
    }

    /// Kural 1: kırp, en az 2 karakter. Typed throws: imza yalnızca `SearchQueryError` fırlatabileceğini söyler; çağıranın
    /// `catch` bloğunda `error` doğrudan `SearchQueryError`'dır. `count` grapheme cluster sayar: "ğü" 2 karakterdir.
    static func validate(_ rawQuery: String) throws(SearchQueryError) -> String {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= minimumQueryLength else {
            throw .tooShort(minimumLength: minimumQueryLength)
        }
        return query
    }

    /// Kural 2 ve 3: eşleşenleri bulur ve sıralar.
    static func matches(in books: [Book], for query: String) -> [Book] {
        let key = searchKey(for: query)
        let titleMatches = books.filter { searchKey(for: $0.title).contains(key) }
        let authorOnlyMatches = books.filter { book in
            !titleMatches.contains(book) && searchKey(for: book.author).contains(key)
        }
        return alphabetized(titleMatches) + alphabetized(authorOnlyMatches)
    }

    /// Karşılaştırma anahtarı: metni "nasıl yazılmış olursa olsun aynı görünen" bir biçime indirir.
    ///
    /// Adımlar ve her birinin sebebi (her biri `BookSearchUseCaseTests`'te ayrı bir testle sabitlendi):
    /// 1. `lowercased(with: tr_TR)`: Türkçe büyük/küçük harf kuralı. "İ" → "i", "I" → "ı".
    ///    Tuzak: Varsayılan `lowercased()` "İ"yi **iki** Unicode scalar'a çevirir ("i" + U+0307 birleşen nokta), bu yüzden
    ///    `"İnce Memed".lowercased().contains("ince")` **false** döner.
    /// 2. `.diacriticInsensitive` katlama: "ğ" → "g", "ü" → "u", "ş" → "s", "ö" → "o", "ç" → "c", "â" → "a".
    ///    KARAR: "oguz" araması "Oğuz Atay"ı BULUR. Türkçe klavyesi olmayan (ya da acele eden) kullanıcı da aradığını
    ///    bulmalı; aramada kaçırılan sonuç, fazladan gelen sonuçtan daha pahalıdır.
    /// 3. "ı" → "i": Unicode'da "ı" aksanlı bir "i" değil, **ayrı bir harftir**; 2. adım ona dokunmaz. Aynı karar gereği
    ///    elle eşliyoruz: "kirmizi" → "Kırmızı", "tanpinar" → "Tanpınar", "INCE" (1. adımda "ınce") → "İnce".
    ///    Sonuç: I, ı, İ, i dördü de aynı harf sayılır. Bedeli: "sık" ile "sik" ayırt edilmez; kitap aramasında kabul edilebilir.
    ///
    /// Karşılaştır: Mülakat merkezinin araması (`InterviewTopic.filtered`) `localizedStandardContains` kullanır ve orada
    /// "sinif" araması "sınıf"ı bulmaz. İki ekran, iki farklı (bilinçli) karar.
    static func searchKey(for text: String) -> String {
        text.lowercased(with: turkish)
            .folding(options: .diacriticInsensitive, locale: turkish)
            .replacingOccurrences(of: "ı", with: "i")
    }

    /// Başlığa göre Türkçe alfabetik sıra: "Çalıkuşu", "Cevdet Bey"den sonra ve "Dede Korkut"tan önce gelir.
    /// Düz `sorted()` Unicode kod noktasına göre sıralar ve Ç, İ, Ö, Ş, Ü ile başlayanları en sona atardı.
    private static func alphabetized(_ books: [Book]) -> [Book] {
        books.sorted { lhs, rhs in
            lhs.title.compare(rhs.title, options: [.caseInsensitive], range: nil, locale: turkish) == .orderedAscending
        }
    }
}
