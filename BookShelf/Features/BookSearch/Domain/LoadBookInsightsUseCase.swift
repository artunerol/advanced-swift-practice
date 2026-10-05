import Foundation

/// Bir kitabın "özet" bilgisi: iki ayrı servis cevabından türetilmiş **domain** değeri.
///
/// Ham `[Review]` ya da `AuthorProfile` değil, ekranın ihtiyaç duyduğu sonuçlar: kaç yorum, ortalama kaç, yazarın kaç
/// kitabı var. Bu hesaplar (ortalama, yuvarlama, "başka kitabı var mı?") iş kuralıdır; presenter yalnızca metne çevirir.
struct BookInsights: Equatable, Sendable {
    let book: Book
    let reviewCount: Int
    /// Bir ondalığa yuvarlanmış ortalama puan (ör. 4,67 → 4,7). Hiç yorum yoksa `nil`: "0,0" yanıltıcı olurdu.
    let averageRating: Double?
    /// Yazarın kitaplıktaki kitap sayısı. Yazar profili alınamadıysa `nil` (kısmi hata politikası, aşağıda).
    let authorBookCount: Int?

    /// Türetilmiş bayrak: "yazarın başka kitabı da var". Profil yoksa bilinmiyor → `nil`.
    var authorHasOtherBooks: Bool? {
        authorBookCount.map { $0 > 1 }
    }
}

/// Kitap özeti use case'inin sözleşmesi.
protocol LoadBookInsightsUseCaseProtocol: Sendable {
    func execute(for book: Book) async throws -> BookInsights
}

/// **Use case türü: Birleştirme (aggregation).** İki bağımsız isteği **aynı anda** yapar, sonuçları tek bir domain
/// değerinde (`BookInsights`) birleştirir.
///
/// Neden use case? İki karar burada:
/// 1. **Eşzamanlılık:** Yorumlar ve yazar profili birbirine bağlı değil; `async let` ile paralel istenir. Toplam süre
///    ≈ en yavaş istek (sırayla olsaydı ikisinin toplamı). Bu, "nasıl yüklenir" bilgisidir; presenter'ın işi değil.
/// 2. **Kısmi hata politikası** (bir iş kuralı!): İsteklerden biri başarısız olursa ne olacak?
///    - **Yorumlar zorunlu:** Özetin ana bilgisi yorumlar. Gelmezse hata fırlatılır, kullanıcı hata görür.
///    - **Yazar profili isteğe bağlı:** Gelmezse özet yine gösterilir, yazar alanları `nil` olur ("bilgi alınamadı").
///    Bu kararı presenter'a bıraksaydık presenter iki ayrı sonucu ve iki ayrı hatayı bilmek zorunda kalırdı; servise
///    (repository) koysaydık servis "ekranın neye ihtiyacı var" bilgisini taşırdı. Politika, ikisinin arasında: burada.
///
/// İptal: Interactor bu işi bir `Task` içinde çalıştırır. Task iptal edilirse `async let` ile başlayan iki alt görev de
/// otomatik iptal edilir (structured concurrency). Dikkat: İsteğe bağlı istekte `try?` yazmak iptali de yutar ve iptal
/// edilmiş bir işi "yazar bilgisi yok" diye sürdürürdü. Yalnızca `catch is CancellationError` da yetmez: `URLSession`
/// iptal edilen isteği `URLError(.cancelled)` ile bitirir. Bu yüzden hatanın türüne değil `Task.isCancelled`'a bakıp
/// iptali `CancellationError` olarak yeniden fırlatıyoruz.
struct LoadBookInsightsUseCase: LoadBookInsightsUseCaseProtocol {
    private let service: any BookServiceProtocol

    init(service: any BookServiceProtocol) {
        self.service = service
    }

    func execute(for book: Book) async throws -> BookInsights {
        // İkisi de BU SATIRDA başlar; `await` edilene kadar arka planda paralel çalışır.
        async let reviewsRequest = service.fetchReviews(for: book.id)
        async let authorRequest = service.fetchAuthorProfile(named: book.author)

        // Zorunlu: Hata fırlarsa fonksiyondan çıkılır; kapsamdan çıkan `authorRequest` otomatik iptal edilip beklenir.
        let reviews = try await reviewsRequest

        // İsteğe bağlı: Hata → `nil`. Ama iptal bir "hata" değildir; yukarı iletilmeli. Ölçüt task'ın durumu, hatanın
        // türü değil: İptal `CancellationError` da olabilir, `URLError(.cancelled)` da.
        let authorBookCount: Int?
        do {
            authorBookCount = try await authorRequest.bookCount
        } catch {
            if Task.isCancelled { throw CancellationError() }
            authorBookCount = nil
        }

        return BookInsights(
            book: book,
            reviewCount: reviews.count,
            averageRating: Self.averageRating(of: reviews),
            authorBookCount: authorBookCount
        )
    }

    /// Ortalama, bir ondalığa yuvarlanmış. `rounded()` varsayılan olarak "en yakına, eşitlikte sıfırdan uzağa" yuvarlar:
    /// 4,25 → 4,3. Yorum yoksa `nil` (0'a bölme yok).
    static func averageRating(of reviews: [Review]) -> Double? {
        guard !reviews.isEmpty else { return nil }
        let average = Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)
        return (average * 10).rounded() / 10
    }
}
