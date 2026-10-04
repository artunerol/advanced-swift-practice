import Foundation

/// `BookServiceProtocol`'ün uygulamada kullanılan somut hali.
///
/// Gerçek bir sunucu yok: kitaplar uygulama paketindeki `books.json`'dan okunur ve ağ gecikmesi
/// `Task.sleep` ile **taklit edilir**. Böylece async/await'i gerçekçi bir senaryoda görebiliriz.
///
/// Neden `struct`? Servisin değiştirilebilir bir durumu yok; sadece iki ayar (`latency`, `simulatesFailure`) var.
/// Tüm alanları `Sendable` (`Duration`, `Bool`) olduğu için struct otomatik olarak `Sendable`'dır,
/// yani protokolün `Sendable` şartını ekstra kod yazmadan karşılar.
///
/// Bu tip hiçbir actor'e bağlı değil (*nonisolated*). `@MainActor`'deki bir view model
/// `await service.fetchBooks()` dediğinde, fonksiyon gövdesi ana thread'de değil Swift'in
/// **global concurrent executor**'ünde (arka plan thread havuzu) çalışır. JSON çözümleme gibi işler UI'ı dondurmaz.
struct LocalBookService: BookServiceProtocol {
    /// Her isteğin taklit edilen gecikmesi. UI testlerinde `.zero` veririz ki testler hızlı ve kararlı olsun.
    var latency: Duration = .milliseconds(600)
    /// `true` ise her istek `BookServiceError.networkUnavailable` fırlatır (hata ekranını denemek için).
    var simulatesFailure = false

    func fetchBooks() async throws -> [Book] {
        try await simulateNetworkRoundTrip(latency)
        return try loadBooksFromBundle()
    }

    func fetchReviews(for bookID: Book.ID) async throws -> [Review] {
        try await simulateNetworkRoundTrip(latency)
        // Gerçek veri yok; kitap id'sine göre şablonlardan her seferinde AYNI (deterministik) 3 yorum üretiyoruz.
        // Deterministik olması testlerin kararlı olması için önemli.
        return (0..<3).map { index in
            let template = Self.reviewTemplates[(bookID + index) % Self.reviewTemplates.count]
            return Review(
                id: bookID * 100 + index,
                bookID: bookID,
                reviewer: template.reviewer,
                rating: template.rating,
                comment: template.comment
            )
        }
    }

    func fetchAuthorProfile(named authorName: String) async throws -> AuthorProfile {
        // Bilerek 2 kat yavaş: Detay ekranında yorumlar + yazar profili `async let` ile PARALEL yüklenince
        // toplam süre ≈ en yavaş istek (2x) olur; sırayla yüklenseydi 1x + 2x = 3x sürerdi.
        try await simulateNetworkRoundTrip(latency * 2)
        let books = try loadBooksFromBundle()
        let bookCount = books.filter { $0.author == authorName }.count
        guard bookCount > 0 else { throw BookServiceError.authorNotFound(authorName) }
        return AuthorProfile(
            name: authorName,
            bio: Self.authorBios[authorName] ?? "Bu yazar hakkında henüz bilgi yok.",
            bookCount: bookCount
        )
    }

    // MARK: - Yardımcılar

    /// Ağ gidiş-dönüşünü taklit eder.
    private func simulateNetworkRoundTrip(_ delay: Duration) async throws {
        if delay > .zero {
            // `Task.sleep` thread'i BLOKLAMAZ (Thread.sleep'in aksine). Task askıya alınır, thread serbest kalır.
            // Task iptal edilirse (ör. kullanıcı ekrandan çıktı ve `.task` modifier'ı iptal etti)
            // `Task.sleep` hemen `CancellationError` fırlatır.
            try await Task.sleep(for: delay)
        }
        // Gecikme sıfır olsa bile iptal edilmiş bir task'ın boşuna çalışmaya devam etmemesi için kontrol ediyoruz.
        try Task.checkCancellation()
        if simulatesFailure {
            throw BookServiceError.networkUnavailable
        }
    }

    /// `books.json` dosyasını uygulama paketinden okuyup `[Book]`'a çözer.
    private func loadBooksFromBundle() throws -> [Book] {
        guard let url = Bundle.main.url(forResource: "books", withExtension: "json") else {
            throw BookServiceError.resourceMissing
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Book].self, from: data)
        } catch {
            throw BookServiceError.decodingFailed
        }
    }

    // MARK: - Sabit veri

    private struct ReviewTemplate: Sendable {
        let reviewer: String
        let rating: Int
        let comment: String
    }

    /// `static let` global bir değişken gibidir. Swift 6'da global/statik değişkenlerin `Sendable` olması gerekir;
    /// `ReviewTemplate` sadece `Sendable` alanlar içerdiği için sorun yok.
    private static let reviewTemplates: [ReviewTemplate] = [
        ReviewTemplate(reviewer: "Ayşe", rating: 5, comment: "Bir solukta okudum, karakterler çok canlı."),
        ReviewTemplate(reviewer: "Mehmet", rating: 4, comment: "Dili biraz ağır ama emeğe değer."),
        ReviewTemplate(reviewer: "Zeynep", rating: 5, comment: "Her okuyuşta yeni bir şey keşfediyorum."),
        ReviewTemplate(reviewer: "Can", rating: 3, comment: "Ortası biraz uzun geldi, sonu çok iyi."),
        ReviewTemplate(reviewer: "Elif", rating: 4, comment: "Kulüpte tartışması en keyifli kitaplardan."),
    ]

    private static let authorBios: [String: String] = [
        "Oğuz Atay": "Türk edebiyatında modernizmin öncülerinden; ironik ve çok katmanlı anlatımıyla tanınır.",
        "Sabahattin Ali": "Öykü ve romanlarında bireyin yalnızlığını ve toplumsal adaletsizliği işleyen yazar.",
        "Ahmet Hamdi Tanpınar": "Şair ve romancı; zaman, hafıza ve Doğu-Batı arasında kalmışlık temalarıyla bilinir.",
        "Yaşar Kemal": "Çukurova'yı ve Anadolu insanını destansı bir dille anlatan romancı.",
        "Orhan Pamuk": "Nobel Edebiyat Ödülü sahibi romancı; İstanbul ve kimlik temalarını işler.",
    ]
}
