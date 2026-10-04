import Foundation
import Observation

/// "Kitaplar" listesinin durumunu ve yükleme mantığını tutan view model.
///
/// Neden `@MainActor`?
/// SwiftUI ekranı bu nesnenin özelliklerini (`state`, `refreshErrorMessage`) ana thread'de okur. Bu özellikleri
/// başka bir thread yazsaydı okuma ile yazma çakışabilirdi (data race). `@MainActor` sınıfın TÜM durumunu ana
/// actor'e bağlar: Swift 6 derleyicisi ana actor dışından yapılan her erişimi derleme anında reddeder.
/// Bonus: `@MainActor` sınıflar otomatik olarak `Sendable`'dır, yani `Task { await viewModel.load() }` gibi
/// yerlerde güvenle yakalanabilir.
///
/// Neden `@Observable` (iOS 17+), eski `ObservableObject` + `@Published` değil?
/// - `@Observable` bir makrodur; her `var` özelliğe erişim takibi ekler. SwiftUI `body` içinde hangi
///   özelliğin OKUNDUĞUNU kaydeder ve sadece o özellik değişince view'i yeniden çizer.
/// - `ObservableObject`'te herhangi bir `@Published` değiştiğinde (`objectWillChange`) o nesneyi izleyen
///   bütün view'ler yeniden hesaplanır; okunmayan özellik değişse bile.
/// - Ayrıca `@Published` yazmaya, view tarafında `@StateObject` / `@ObservedObject` ayrımına gerek kalmaz.
///
/// Bu dosya SwiftUI'ı `import` etmiyor: view model UI çatısından bağımsızdır ve birim testlerde
/// ekran açmadan doğrudan test edilebilir.
@MainActor
@Observable
final class BookListViewModel {
    /// Ekranın içinde bulunabileceği durumlar.
    ///
    /// Neden birkaç `Bool` (`isLoading`, `hasError`, `books`) yerine tek bir `enum`?
    /// Üç ayrı özellikle "hem yükleniyor hem hata var" ya da "hata var ama kitaplar da dolu" gibi
    /// **imkânsız durumlar** yazılabilir hale gelir ve her değişiklikte hepsini doğru sırayla güncellemeyi
    /// unutmamak gerekir. Enum ile ekran aynı anda **tam olarak bir** durumdadır; `switch` de derleyicinin
    /// "şu durumu ele almadın" diye uyarmasını sağlar. Veri (`[Book]`, hata mesajı) de sadece anlamlı olduğu
    /// durumun içinde (associated value) yaşar.
    ///
    /// `Equatable`: testlerde `XCTAssertEqual(viewModel.state, .loaded(kitaplar))` yazabilmek için.
    enum LoadState: Equatable {
        /// Henüz hiç yükleme yapılmadı.
        case idle
        /// İlk yükleme sürüyor; gösterilecek içerik yok.
        case loading
        /// Kitaplar geldi.
        case loaded([Book])
        /// Yükleme başarısız; kullanıcıya gösterilecek mesaj.
        case failed(message: String)
    }

    /// Ekranın güncel durumu. `private(set)`: dışarıdan sadece okunur, değiştirmek bu sınıfın işi.
    private(set) var state: LoadState = .idle

    /// Aşağı çekip yenileme (pull-to-refresh) sürüyor mu?
    /// Yenileme sırasında `state` `.loaded` olarak KALIR; eski liste ekranda görünmeye devam eder.
    private(set) var isRefreshing = false

    /// Yenileme başarısız olduğunda gösterilen mesaj. Liste silinmez, üstünde bir uyarı çıkar.
    private(set) var refreshErrorMessage: String?

    /// Somut tipe değil protokole bağımlıyız: uygulamada `LocalBookService`, testlerde `StubBookService`.
    /// (`let` özellikler `@Observable` tarafından izlenmez; zaten hiç değişmezler.)
    private let service: any BookServiceProtocol

    init(service: any BookServiceProtocol) {
        self.service = service
    }

    /// İlk yükleme. View'deki `.task { await viewModel.load() }` tarafından çağrılır.
    ///
    /// `.task` view her göründüğünde (ör. sekmeye geri dönünce) yeniden çalışır. Bu yüzden fonksiyon
    /// **idempotent** tasarlandı: kitaplar zaten yüklüyse ya da bir yükleme sürüyorsa hiçbir şey yapmaz.
    /// Listeyi bilerek yenilemek için `refresh()` kullanılır.
    func load() async {
        switch state {
        case .loading, .loaded:
            // Aynı anda iki yükleme başlamasın (ör. `.task` + "Tekrar Dene" düğmesi) ve
            // sekmeye her dönüşte gereksiz yere yeniden indirmeyelim.
            return
        case .idle, .failed:
            break
        }

        let previousState = state
        state = .loading

        do {
            // `await` = olası ASKIYA ALMA (suspension) noktası.
            // 1. `load()` burada durur ve ana thread'i BIRAKIR; ana thread bu sırada dokunmaları işler,
            //    `ProgressView`'i döndürür. Hiçbir thread "bekleyerek" bloklanmaz.
            // 2. `fetchBooks()` bizim ayarlarımızda *nonisolated* bir async fonksiyondur, bu yüzden gövdesi ana
            //    actor'de değil global concurrent executor'de (arka plan thread havuzunda) çalışır.
            //    (Xcode 26'nın yeni proje şablonlarındaki "Approachable Concurrency" açık olsaydı çağıranın
            //    actor'ünde, yani burada ana actor'de çalışırdı; arka plana geçmek için `@concurrent` gerekirdi.
            //    Projede izolasyon açıkça yazılı ve öğrenilebilir olsun diye bu ayar bilerek kapalı.)
            // 3. Sonuç gelince fonksiyon kaldığı yerden devam eder. Bu sınıf `@MainActor` olduğu için devam
            //    etme noktası da GARANTİLİ olarak ana actor'dür; alttaki `state = ...` ataması güvenlidir.
            let books = try await service.fetchBooks()
            state = .loaded(books)
        } catch is CancellationError {
            // İptal bir HATA değildir: kullanıcı ekrandan ayrıldı ve SwiftUI `.task`'ı iptal etti.
            // Hata ekranı göstermek yerine önceki duruma dönüyoruz. Bunu yapmasaydık `state` `.loading`'de
            // takılı kalırdı ve view tekrar göründüğünde yukarıdaki guard yeni yüklemeyi engellerdi.
            state = previousState
        } catch {
            // `BookServiceError` `LocalizedError` olduğu için `localizedDescription` Türkçe mesajı verir.
            state = .failed(message: error.localizedDescription)
        }
    }

    /// Aşağı çekip yenileme. View'deki `.refreshable { await viewModel.refresh() }` çağırır.
    ///
    /// `load()`'dan farkı: mevcut liste ekranda KALIR (`state` `.loading`'e dönmez). SwiftUI, bu fonksiyon
    /// bitene kadar listenin tepesindeki yenileme göstergesini kendisi döndürür.
    func refresh() async {
        guard case .loaded = state else {
            // Gösterilecek liste yoksa yenileme, normal bir yüklemeden farksızdır.
            await load()
            return
        }
        guard !isRefreshing else { return }

        isRefreshing = true
        // `defer`, fonksiyon hangi yoldan çıkarsa çıksın (başarı, hata, iptal) çalışır.
        defer { isRefreshing = false }

        do {
            let books = try await service.fetchBooks()
            state = .loaded(books)
            refreshErrorMessage = nil
        } catch is CancellationError {
            // Yenileme iptal edildi; eski liste zaten ekranda, yapacak bir şey yok.
        } catch {
            // Eski listeyi silmek kötü bir deneyim olurdu; listeyi koruyup sadece uyarı gösteriyoruz.
            refreshErrorMessage = error.localizedDescription
        }
    }
}
