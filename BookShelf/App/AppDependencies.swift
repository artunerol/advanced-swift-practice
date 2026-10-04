import Foundation

/// Uygulamanın paylaşılan bağımlılıklarını bir arada tutan basit bir "kap" (container).
///
/// Bu bir `struct`, ama içindeki `favorites` bir **actor** yani bir *referans tipi*.
/// Struct kopyalandığında içindeki referans da kopyalanır; kopyaların hepsi **aynı** actor örneğini gösterir.
/// (Struct'ın değer semantiği sadece struct'ın *kendi* alanları için geçerlidir; gösterdiği nesneler paylaşılır.)
/// Bu yüzden `AppDependencies`'i ekranlara kopyalayarak vermemiz sorun değil; herkes aynı favori listesini görür.
///
/// `Sendable`: İçerdiği her şey `Sendable` (`any BookServiceProtocol` → protokol `Sendable`'dan türüyor,
/// `FavoritesStore` → actor'ler her zaman `Sendable`). Bu yüzden task'lar arasında güvenle taşınabilir.
struct AppDependencies: Sendable {
    let bookService: any BookServiceProtocol
    let favorites: FavoritesStore

    init(bookService: any BookServiceProtocol, favorites: FavoritesStore = FavoritesStore()) {
        self.bookService = bookService
        self.favorites = favorites
    }

    /// Başlatma argümanlarına göre bağımlılıkları kurar.
    /// - `-ui-testing`: gecikme sıfır → UI testleri hızlı ve kararlı.
    /// - `-simulate-network-error`: servis her istekte hata fırlatır → hata ekranı test edilebilir.
    static func makeForLaunch(arguments: [String]) -> AppDependencies {
        let isUITesting = arguments.contains(LaunchArgument.uiTesting)
        let service = LocalBookService(
            latency: isUITesting ? .zero : .milliseconds(600),
            simulatesFailure: arguments.contains(LaunchArgument.simulateNetworkError)
        )
        return AppDependencies(bookService: service)
    }

    /// SwiftUI Preview'ları ve testler için hızlı bir örnek.
    static let preview = AppDependencies(bookService: LocalBookService(latency: .milliseconds(300)))
}
