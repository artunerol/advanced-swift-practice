import Foundation

/// Kalıcı verinin **nereye** yazılacağı: klasör, UserDefaults alanı (suite) ve Keychain "service" adı.
///
/// Neden ayrı bir tip? Depolama kodu (repository'ler, ayarlar, Keychain) konumu kendisi seçerse testler
/// gerçek kullanıcı verisine yazar ve birbirini kirletir. Konum dışarıdan verilince (dependency injection):
/// - Uygulama `production` konumunu kullanır,
/// - Birim testleri her test için ayrı, geçici bir konum (`isolated(name:)`) kullanır,
/// - UI testleri (`-ui-testing`) her açılışta sıfırlanan bir konum kullanır (`current`).
///
/// `UserDefaults` Swift 6'da `Sendable` değildir (SDK'da işaretli değil; Apple'ın belgesi thread-safe olduğunu
/// söylese de derleyici bunu bilemez). Bu yüzden örneğin kendisini değil **adını** saklıyoruz; ihtiyaç anında
/// `defaults` ile açıyoruz. Böylece bu struct `Sendable` kalıyor ve `static let` olarak tutulabiliyor.
struct PersistenceLocation: Sendable, Equatable {
    /// Dosya tabanlı depoların klasörü: JSON dosyası, Core Data ve SwiftData SQLite dosyaları.
    let directory: URL
    /// UserDefaults alanı. `nil` → `UserDefaults.standard`.
    let defaultsSuiteName: String?
    /// Keychain kayıtlarının `kSecAttrService` değeri. Farklı konumların sırları birbirine karışmasın diye ayrı.
    let keychainService: String

    /// Bu konuma ait UserDefaults. Aynı suite adıyla açılan her örnek aynı veriyi görür.
    var defaults: UserDefaults {
        defaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    /// Bu konumdaki bir dosyanın adresi, ör. `fileURL("notes.json")`.
    func fileURL(_ name: String) -> URL {
        directory.appending(path: name, directoryHint: .notDirectory)
    }

    /// Konumdaki her şeyi siler: klasör ve (varsa) UserDefaults suite'i. `production` için ÇAĞRILMAZ.
    ///
    /// Keychain'e dokunmuyoruz: Keychain kayıtları bu konumun `keychainService`'iyle ayrıldığı için
    /// gerçek kayıtlarla karışmaz; onları silmek Keychain demosunun işi.
    func erase() {
        precondition(self != .production, "Gerçek kullanıcı verisi silinmemeli.")
        try? FileManager.default.removeItem(at: directory)
        if let defaultsSuiteName {
            UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName)
        }
    }
}

extension PersistenceLocation {
    /// Uygulamanın gerçek konumu.
    ///
    /// - Klasör: `Library/Application Support/Notes`. Kullanıcıya gösterilmeyen ama kaybolmaması gereken veri
    ///   buraya yazılır; iCloud/bilgisayar yedeğine girer. (`Documents` kullanıcının Dosyalar uygulamasında görebileceği
    ///   belgeler, `Caches` ise sistemin yer açmak için silebileceği, yeniden üretilebilir veri içindir.)
    /// - UserDefaults: `.standard` (uygulamanın kendi alanı).
    static let production = PersistenceLocation(
        directory: URL.applicationSupportDirectory.appending(path: "Notes", directoryHint: .isDirectory),
        defaultsSuiteName: nil,
        keychainService: Bundle.main.bundleIdentifier ?? "dev.learning.BookShelf"
    )

    /// Testler için birbirinden yalıtılmış bir konum: geçici klasörde `name` adlı alt klasör + aynı adlı suite.
    /// İşin bitince `erase()` ile temizle.
    static func isolated(name: String) -> PersistenceLocation {
        PersistenceLocation(
            directory: FileManager.default.temporaryDirectory.appending(path: name, directoryHint: .isDirectory),
            defaultsSuiteName: name,
            keychainService: "dev.learning.BookShelf.\(name)"
        )
    }

    /// Bu süreçte (process) kullanılacak konum.
    ///
    /// `-ui-testing` ile açılışta yalıtılmış bir konum kullanılır ve **ilk erişimde bir kez** silinir.
    /// Böylece her UI testi temiz bir durumla başlar: bir testin değiştirdiği okuma hızı ya da eklediği not
    /// sonraki testin (ör. "okuma süresi 18 sa 6 dk" bekleyen testin) sonucunu bozmaz; geliştiricinin kendi
    /// simülatöründe yaptığı değişiklikler de UI testlerine sızmaz.
    ///
    /// `static let` tembeldir (lazy) ve Swift onu thread-safe biçimde YALNIZCA BİR KEZ başlatır
    /// (arka planda `dispatch_once` benzeri bir mekanizma). "Açılışta bir kez sil" garantisi buradan gelir.
    static let current: PersistenceLocation = {
        guard ProcessInfo.processInfo.arguments.contains(LaunchArgument.uiTesting) else { return .production }
        let location = PersistenceLocation.isolated(name: "BookShelf-UITesting")
        location.erase()
        return location
    }()
}
