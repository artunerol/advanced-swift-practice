import Foundation

/// Notların saklanabileceği yerler. Mimari ve kalıcılık demolarında kullanıcı bunlar arasında geçiş yapabilir:
/// ekran kodu değişmeden depolama değişir → Dependency Inversion'ın canlı kanıtı.
enum NotesStorageKind: String, CaseIterable, Identifiable, Sendable {
    case inMemory
    case userDefaults
    case file
    case coreData
    case swiftData

    var id: String { rawValue }

    /// Uygulamanın normal çalışırken kullandığı depolama: **SwiftData**.
    ///
    /// Gerekçe: Proje iOS 17+ hedefliyor, yani SwiftData her cihazda var. Notlar büyüyebilen, sıralanan ve
    /// ileride sorgulanacak (ör. "şu kitabın notları") bir veri; bu yüzden UserDefaults ya da tek JSON dosyası değil,
    /// bir veritabanı. SwiftData ile Core Data aynı işi görür; SwiftData daha az kodla (`@Model`, `#Predicate`) ve
    /// Swift concurrency ile doğal uyumla (`@ModelActor`) geliyor. Core Data'yı seçmek için iyi nedenler: iOS 16 ve
    /// öncesini desteklemek, `NSFetchedResultsController`, batch işlemler ya da zaten Core Data kullanan bir kod tabanı.
    /// Karar tek satır: Değiştirmek için burayı `.coreData` yapmak yeter; hiçbir ekran değişmez.
    static let appDefault: NotesStorageKind = .swiftData

    /// Kullanıcıya gösterilen kısa ad.
    var storageTitle: String {
        switch self {
        case .inMemory: "Bellek (in-memory)"
        case .userDefaults: "UserDefaults"
        case .file: "Dosya (JSON)"
        case .coreData: "Core Data"
        case .swiftData: "SwiftData"
        }
    }

    /// Uygulama kapanıp açılınca veri kalır mı?
    var survivesRelaunch: Bool {
        self != .inMemory
    }

    /// Bu türün verisinin nerede durduğu (insan için). Dosya adları `NotesRepositoryFactory` ile aynı.
    func storageDescription(in location: PersistenceLocation) -> String {
        switch self {
        case .inMemory: "Yalnızca bellekte (uygulama kapanınca silinir)"
        case .userDefaults: "UserDefaults → \"\(UserDefaultsNotesRepository.defaultKey)\" anahtarı"
        case .file: location.fileURL(NotesRepositoryFactory.FileName.json).lastPathComponent
        case .coreData: location.fileURL(NotesRepositoryFactory.FileName.coreData).lastPathComponent
        case .swiftData: location.fileURL(NotesRepositoryFactory.FileName.swiftData).lastPathComponent
        }
    }
}

/// Seçilen türe göre somut repository üretir (Factory). Hangi sınıfın, hangi konumla oluşturulacağı bilgisi
/// tek yerde toplanır; çağıran yalnızca `any NotesRepository` görür.
enum NotesRepositoryFactory {
    /// Konumdaki dosya adları. Her tür kendi dosyasını kullanır; birbirlerinin verisini görmezler.
    enum FileName {
        static let json = FileNotesRepository.defaultFileName
        static let coreData = "Notes.sqlite"
        static let swiftData = "Notes.store"
    }

    /// Bu sürecin geçerli konumunda (`PersistenceLocation.current`) bir repository üretir: normalde uygulamanın
    /// gerçek konumu, `-ui-testing` ile her açılışta sıfırlanan ayrı bir alan. Böylece bu fabrikayı kullanan her ekran,
    /// UI testlerinde gerçek veriye dokunmaz ve önceki testten kalan veriyi görmez.
    static func make(_ kind: NotesStorageKind) -> any NotesRepository {
        make(kind, location: .current)
    }

    /// Verilen konumda bir repository üretir. Testler ve UI testleri yalıtılmış konum verir.
    ///
    /// Core Data ve SwiftData deposu açılırken hata olabilir. İmza hata fırlatmıyor; onun yerine hatayı
    /// taşıyan `UnavailableNotesRepository` döner ve hata, ilk kullanımda ekrana kadar ulaşır.
    static func make(_ kind: NotesStorageKind, location: PersistenceLocation) -> any NotesRepository {
        do {
            switch kind {
            case .inMemory:
                return InMemoryNotesRepository()
            case .userDefaults:
                return UserDefaultsNotesRepository(defaults: location.defaults)
            case .file:
                return FileNotesRepository(fileURL: location.fileURL(FileName.json))
            case .coreData:
                return try CoreDataNotesRepository(store: .sqlite(location.fileURL(FileName.coreData)))
            case .swiftData:
                return try SwiftDataNotesRepository(store: .file(location.fileURL(FileName.swiftData)))
            }
        } catch let error as NotesRepositoryError {
            return UnavailableNotesRepository(error: error)
        } catch {
            return UnavailableNotesRepository(error: .storageFailure(reason: error.localizedDescription))
        }
    }
}
