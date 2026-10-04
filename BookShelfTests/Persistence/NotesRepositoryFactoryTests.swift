import XCTest
@testable import BookShelf

/// Fabrika ve konum testleri: Doğru tür doğru konumda mı üretiliyor, depo açılamazsa ne oluyor?
final class NotesRepositoryFactoryTests: XCTestCase {
    private var location: PersistenceLocation!

    override func setUp() {
        super.setUp()
        location = .isolated(name: "NotesFactory-\(UUID().uuidString)")
    }

    override func tearDown() {
        location.erase()
        location = nil
        super.tearDown()
    }

    func testFactoryBuildsMatchingImplementationForEveryKind() {
        for kind in NotesStorageKind.allCases {
            let repository = NotesRepositoryFactory.make(kind, location: location)
            let expected: Any.Type = switch kind {
            case .inMemory: InMemoryNotesRepository.self
            case .userDefaults: UserDefaultsNotesRepository.self
            case .file: FileNotesRepository.self
            case .coreData: CoreDataNotesRepository.self
            case .swiftData: SwiftDataNotesRepository.self
            }
            XCTAssertTrue(type(of: repository) == expected, "\(kind) için \(type(of: repository)) üretildi.")
        }
    }

    /// Depo açılamazsa uygulama çökmez: Fabrika, hatayı ilk kullanımda bildiren bir yedek repository döndürür.
    func testFactoryReturnsFailingRepositoryWhenStoreCannotBeOpened() async throws {
        // Klasörün olması gereken yere sıradan bir DOSYA koyuyoruz: Klasör oluşturulamaz, depo açılamaz.
        let blocker = location.directory.deletingLastPathComponent()
            .appending(path: location.directory.lastPathComponent, directoryHint: .notDirectory)
        try Data("klasör değil".utf8).write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }

        for kind in [NotesStorageKind.coreData, .swiftData] {
            let repository = NotesRepositoryFactory.make(kind, location: location)
            XCTAssertTrue(repository is UnavailableNotesRepository, "\(kind): yedek repository bekleniyordu.")
            do {
                _ = try await repository.fetchAll()
                XCTFail("\(kind): fetchAll hata fırlatmalıydı.")
            } catch {
                XCTAssertTrue(error is NotesRepositoryError, "\(kind): beklenmeyen hata tipi \(type(of: error)).")
            }
        }
    }

    /// Uygulamanın varsayılan deposu kalıcı olmalı; in-memory yalnızca testler içindir.
    func testAppDefaultSurvivesRelaunch() {
        XCTAssertTrue(NotesStorageKind.appDefault.survivesRelaunch)
        XCTAssertFalse(NotesStorageKind.inMemory.survivesRelaunch)
    }

    /// Her tür kendi dosyasını kullanır; aynı dosyayı iki farklı biçimde yazmaya çalışmazlar.
    func testFileBasedKindsUseDistinctFiles() {
        let names = [
            NotesRepositoryFactory.FileName.json,
            NotesRepositoryFactory.FileName.coreData,
            NotesRepositoryFactory.FileName.swiftData,
        ]
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testProductionLocationIsApplicationSupportAndStandardDefaults() {
        let production = PersistenceLocation.production
        XCTAssertEqual(production.directory.deletingLastPathComponent(), URL.applicationSupportDirectory)
        XCTAssertNil(production.defaultsSuiteName)
        XCTAssertTrue(production.defaults === UserDefaults.standard)
    }

    /// Birim testleri `-ui-testing` olmadan çalışır; bu süreçte "geçerli konum" gerçek konumdur.
    func testCurrentLocationIsProductionWithoutUITestingArgument() {
        XCTAssertFalse(ProcessInfo.processInfo.arguments.contains(LaunchArgument.uiTesting))
        XCTAssertEqual(PersistenceLocation.current, .production)
    }

    func testEraseRemovesFilesAndDefaults() throws {
        try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: location.fileURL("x.txt"))
        location.defaults.set(42, forKey: "answer")

        location.erase()

        XCTAssertFalse(FileManager.default.fileExists(atPath: location.directory.path(percentEncoded: false)))
        XCTAssertNil(location.defaults.object(forKey: "answer"))
    }

    /// UI testleri uygulama modülünü göremediği için ham değerleri `Shared/` altında tekrar ediyor; ikisi aynı kalmalı.
    func testStorageKindRawValuesMatchAccessibilityConstants() {
        typealias Raw = AccessibilityID.Persistence.StorageKindRawValue
        XCTAssertEqual(NotesStorageKind.inMemory.rawValue, Raw.inMemory)
        XCTAssertEqual(NotesStorageKind.userDefaults.rawValue, Raw.userDefaults)
        XCTAssertEqual(NotesStorageKind.file.rawValue, Raw.file)
        XCTAssertEqual(NotesStorageKind.coreData.rawValue, Raw.coreData)
        XCTAssertEqual(NotesStorageKind.swiftData.rawValue, Raw.swiftData)
    }
}
