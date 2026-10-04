import Foundation

/// Uygulamanın paylaşılan bağımlılıklarını bir arada tutan basit bir "kap" (container).
/// Mimari dilinde burası **composition root**'tur: somut tiplerin seçilip birbirine bağlandığı TEK yer.
/// Ekranlar ve view model'ler somut tipleri değil, buradan gelen soyutlamaları (protokolleri) görür.
///
/// Bu bir `struct`, ama içindeki `favorites` bir **actor** yani bir *referans tipi*.
/// Struct kopyalandığında içindeki referans da kopyalanır; kopyaların hepsi **aynı** actor örneğini gösterir.
/// (Struct'ın değer semantiği sadece struct'ın *kendi* alanları için geçerlidir; gösterdiği nesneler paylaşılır.)
/// Bu yüzden `AppDependencies`'i ekranlara kopyalayarak vermemiz sorun değil; herkes aynı favori listesini görür.
///
/// `Sendable`: İçerdiği her şey `Sendable` (`any BookServiceProtocol` / `any NotesRepository` → protokoller
/// `Sendable`'dan türüyor, `FavoritesStore` → actor'ler her zaman `Sendable`). Bu yüzden task'lar arasında güvenle taşınabilir.
struct AppDependencies: Sendable {
    let bookService: any BookServiceProtocol
    let favorites: FavoritesStore
    /// Okuma notlarının deposu. Hangi depolama türünün kullanılacağına burada karar verilir (Dependency Injection).
    let notesRepository: any NotesRepository

    init(
        bookService: any BookServiceProtocol,
        favorites: FavoritesStore = FavoritesStore(),
        notesRepository: any NotesRepository = InMemoryNotesRepository()
    ) {
        self.bookService = bookService
        self.favorites = favorites
        self.notesRepository = notesRepository
    }

    /// Başlatma argümanlarına göre bağımlılıkları kurar.
    /// - `-ui-testing`: gecikme sıfır, notlar bellekte → UI testleri hızlı, kararlı ve her seferinde temiz durumla başlar.
    /// - `-simulate-network-error`: servis her istekte hata fırlatır → hata ekranı test edilebilir.
    static func makeForLaunch(arguments: [String]) -> AppDependencies {
        let isUITesting = arguments.contains(LaunchArgument.uiTesting)
        let service = LocalBookService(
            latency: isUITesting ? .zero : .milliseconds(600),
            simulatesFailure: arguments.contains(LaunchArgument.simulateNetworkError)
        )
        let notes = NotesRepositoryFactory.make(isUITesting ? .inMemory : NotesStorageKind.appDefault)
        return AppDependencies(bookService: service, notesRepository: notes)
    }

    /// SwiftUI Preview'ları ve testler için hızlı bir örnek.
    static let preview = AppDependencies(bookService: LocalBookService(latency: .milliseconds(300)))
}
