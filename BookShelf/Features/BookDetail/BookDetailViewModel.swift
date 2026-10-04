import Foundation
import Observation

/// Kitap detay ekranının view model'i.
///
/// Bu ekran üç farklı konuyu bir arada gösterir:
/// 1. **`async let`**: yorumlar ve yazar profili AYNI ANDA (paralel) yüklenir; süre ölçülüp ekranda gösterilir.
/// 2. **actor**: favori durumu `FavoritesStore` actor'ünden `await` ile okunur ve değiştirilir.
/// 3. **Objective-C köprüsü**: ISBN doğrulaması ve okuma süresi Objective-C sınıflarıyla hesaplanır.
///
/// `@MainActor` + `@Observable` seçiminin gerekçesi için `BookListViewModel`'e bak; aynı mantık geçerli.
@MainActor
@Observable
final class BookDetailViewModel {
    /// Yorumlar + yazar profilinden oluşan "ek bilgiler"in yükleme durumu.
    /// Kitabın kendisi zaten elimizde; sadece bu ek bilgiler ağdan gelir.
    enum ExtrasState: Equatable {
        case idle
        case loading
        case loaded(Extras)
        case failed(message: String)
    }

    /// Paralel yüklemenin sonucu. İkisi birlikte gelir ya da hiçbiri gelmez (aşağıdaki `load()`'a bak).
    struct Extras: Equatable {
        let reviews: [Review]
        let author: AuthorProfile
        let timing: LoadTiming
    }

    /// Paralel yüklemenin süre ölçümü. Ekranda "paralel ≈ en yavaş istek, toplam değil" fikrini göstermek için.
    struct LoadTiming: Equatable {
        /// Yorum isteğinin tek başına süresi.
        let reviews: Duration
        /// Yazar isteğinin tek başına süresi.
        let author: Duration
        /// İkisinin birlikte (paralel) toplam süresi: ölçüm başından ikisi de bitene kadar.
        let total: Duration

        /// İstekler sırayla (`await` + `await`) yapılsaydı yaklaşık ne kadar sürerdi?
        var sequentialEstimate: Duration { reviews + author }

        /// Ör. "Yükleme süresi: 1,2 sn (paralel)"
        var totalText: String {
            "Yükleme süresi: \(Self.secondsText(total)) sn (paralel)"
        }

        /// Ör. "Yorumlar 0,6 sn · Yazar 1,2 sn · Sırayla olsaydı ≈ 1,8 sn"
        var breakdownText: String {
            "Yorumlar \(Self.secondsText(reviews)) sn · Yazar \(Self.secondsText(author)) sn · "
                + "Sırayla olsaydı ≈ \(Self.secondsText(sequentialEstimate)) sn"
        }

        /// Süreyi tek ondalıklı saniyeye çevirir: 1.234 sn → "1,2".
        /// Arayüz tamamen Türkçe olduğu için yerel ayarı (locale) sabitliyoruz; simülatör İngilizce olsa bile
        /// ondalık ayırıcı virgül olur ve UI testleri her cihazda aynı metni görür.
        static func secondsText(_ duration: Duration) -> String {
            let seconds = duration / .seconds(1) // Duration / Duration → Double (oran)
            return seconds.formatted(
                .number.precision(.fractionLength(1)).locale(Locale(identifier: "tr_TR"))
            )
        }
    }

    let book: Book

    /// Objective-C `ISBNValidator` sonucu. Kitap değişmediği için init'te bir kez hesaplanır.
    let isISBNValid: Bool

    /// Objective-C `ReadingTimeEstimator` sonucu, ör. "5 sa 30 dk".
    let readingTimeText: String

    /// Kitap favorilerde mi? Doğruluğun tek kaynağı `FavoritesStore` actor'üdür; bu onun ekrandaki kopyası.
    private(set) var isFavorite = false

    private(set) var extras: ExtrasState = .idle

    private let service: any BookServiceProtocol
    private let favorites: FavoritesStore

    /// Sadece ihtiyaç duyduğu bağımlılıkları alır (tüm `AppDependencies`'i değil). Böylece testte
    /// neyin taklit edilmesi gerektiği imzadan okunur.
    init(book: Book, service: any BookServiceProtocol, favorites: FavoritesStore) {
        self.book = book
        self.service = service
        self.favorites = favorites

        // Objective-C sınıfları köprü başlığı (bridging header) sayesinde `import` yazmadan görünür.
        // Swift'teki adları header'daki `NS_SWIFT_NAME` ile belirlenir (BKISBNValidator → ISBNValidator).
        // İkisi de senkron ve hızlı; `await` gerekmez.
        isISBNValid = ISBNValidator.isValidISBN13(book.isbn)
        readingTimeText = ReadingTimeEstimator(pagesPerHour: 40).formattedEstimate(forPageCount: book.pageCount)
    }

    /// Ekran açılınca `.task` tarafından çağrılır; "Tekrar Dene" düğmesi de bunu çağırır.
    func load() async {
        // Önce favori durumu: actor'e hızlı bir çağrı, kalp simgesi hemen doğru görünsün.
        //
        // Neden `await`? `favorites` bir actor ve biz onun DIŞINDAYIZ (ana actor'deyiz). Actor aynı anda tek bir
        // işi yürütür; başka bir ekran (ör. UIKit favoriler) o an actor'ü kullanıyorsa sıramızı beklememiz
        // gerekebilir. `await` bu olası beklemenin işaretidir; bekleme sırasında ana thread serbesttir.
        isFavorite = await favorites.contains(book.id)
        await loadExtrasIfNeeded()
    }

    /// Favori durumunu tersine çevirir.
    ///
    /// Yeni değeri actor'ün DÖNDÜRDÜĞÜ sonuçtan alıyoruz. `isFavorite.toggle()` deyip sonra actor'e yazsaydık,
    /// iki kaynak (ekrandaki kopya ve actor) birbirinden kopabilirdi. "Oku → karar ver → yaz" adımları
    /// actor'ün içinde, arada `await` olmadan yapıldığı için atomiktir.
    func toggleFavorite() async {
        isFavorite = await favorites.toggle(book.id)
    }

    // MARK: - Paralel yükleme

    private func loadExtrasIfNeeded() async {
        switch extras {
        case .loading, .loaded:
            return // Aynı anda iki yükleme olmasın; yüklendiyse tekrar indirmeyelim.
        case .idle, .failed:
            break
        }
        extras = .loading

        // Alt görevlere (`async let`) `self`'i değil, ihtiyaç duydukları `Sendable` değerleri veriyoruz.
        // Alt görevler ana actor'de ÇALIŞMAZ; `self`'in ana actor'e bağlı durumuna dokunmamaları en temizi.
        let service = self.service
        let bookID = book.id
        let authorName = book.author

        // `ContinuousClock`: monoton saat. Cihazın saati değişse bile geriye gitmez; süre ölçmek için doğru araç.
        // (Duvar saati olan `Date()` ile süre ölçmek, saat ayarı değişince yanlış sonuç verebilir.)
        let clock = ContinuousClock()
        let start = clock.now

        do {
            // `async let` = yapılandırılmış (structured) bir ALT GÖREV başlatır ve HEMEN bir sonraki satıra geçer.
            // İki istek aynı anda yola çıkar. LocalBookService'te yorumlar 1x, yazar 2x gecikmeli olduğu için
            // toplam süre ≈ 2x (en yavaşı) olur; sırayla `await` etseydik 1x + 2x = 3x sürerdi.
            async let reviewsResult = Self.measure { try await service.fetchReviews(for: bookID) }
            async let authorResult = Self.measure { try await service.fetchAuthorProfile(named: authorName) }

            // Sonuçları burada bekliyoruz. Kurallar:
            // - Bir alt görev hata fırlatırsa hata, o alt görevi `await` ettiğimiz yerde bize ulaşır.
            //   Bu `do` kapsamından hata ile çıkarken, henüz bitmemiş kardeş görev OTOMATİK iptal edilir.
            // - Parent (bu fonksiyon), alt görevleri bitmeden kapsamdan çıkamaz. `await` etmeyi unutsak bile
            //   Swift kapsam sonunda onları iptal edip bitmelerini bekler; "başıboş" görev kalmaz.
            // - `.task` iptal edilirse (kullanıcı geri döndü) iptal, alt görevlere de otomatik yayılır.
            let (reviews, author) = try await (reviewsResult, authorResult)

            let timing = LoadTiming(reviews: reviews.duration, author: author.duration, total: start.duration(to: clock.now))
            extras = .loaded(Extras(reviews: reviews.value, author: author.value, timing: timing))
        } catch is CancellationError {
            // Kullanıcı ekrandan çıktı; hata göstermeyiz. Tekrar açılırsa yükleme baştan başlayabilsin diye `.idle`.
            extras = .idle
        } catch {
            // Tasarım kararı: ya ikisi birden ya hiçbiri. Yazar bulunamazsa yorumları da göstermiyoruz ve
            // "Tekrar Dene" sunuyoruz. (Kısmi sonuç göstermek istenseydi her `async let` kendi hatasını
            // yakalayıp `Result` döndürebilirdi.)
            extras = .failed(message: error.localizedDescription)
        }
    }

    /// Bir async işi çalıştırır ve kendi süresini ölçer.
    ///
    /// `nonisolated`: Sınıf `@MainActor` olduğu için statik üyeleri de varsayılan olarak ana actor'e bağlıdır.
    /// Bu yardımcı hiçbir duruma dokunmuyor; `async let` alt görevinden ana actor'e gereksiz yere
    /// atlamasın diye izolasyonunu kaldırıyoruz.
    private nonisolated static func measure<Value: Sendable>(
        _ operation: () async throws -> Value
    ) async rethrows -> (value: Value, duration: Duration) {
        let clock = ContinuousClock()
        let start = clock.now
        let value = try await operation()
        return (value, start.duration(to: clock.now))
    }
}
