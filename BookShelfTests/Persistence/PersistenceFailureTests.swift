import CoreData
import XCTest
@testable import BookShelf

/// Mutlu yolun dışı: bozuk veri, eksik klasör, model dosyası. Sözleşme testi "her şey yolundayken" davranışı sınar;
/// bu dosya "işler ters gidince veri kaybolmuyor mu?" sorusunu.
final class PersistenceFailureTests: XCTestCase {
    private var location: PersistenceLocation!

    override func setUp() {
        super.setUp()
        location = .isolated(name: "PersistenceFailure-\(UUID().uuidString)")
    }

    override func tearDown() {
        location.erase()
        location = nil
        super.tearDown()
    }

    // MARK: - Bozuk veri: sessizce "boş" sayılmamalı

    func testCorruptUserDefaultsValueThrowsAndIsNotOverwritten() async throws {
        let garbage = Data("bu JSON değil".utf8)
        location.defaults.set(garbage, forKey: UserDefaultsNotesRepository.defaultKey)
        let repository = UserDefaultsNotesRepository(defaults: location.defaults)

        await assertStorageFailure { _ = try await repository.fetchAll() }
        // Boş dizi sanıp üzerine yazsaydı kullanıcının bütün notları giderdi.
        await assertStorageFailure { try await repository.save(ReadingNote(text: "yeni")) }
        XCTAssertEqual(location.defaults.data(forKey: UserDefaultsNotesRepository.defaultKey), garbage)
    }

    func testCorruptFileThrowsAndIsNotOverwritten() async throws {
        let fileURL = location.fileURL("notes.json")
        try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)
        let garbage = Data("{ yarım kalmış".utf8)
        try garbage.write(to: fileURL)
        let repository = FileNotesRepository(fileURL: fileURL)

        await assertStorageFailure { _ = try await repository.fetchAll() }
        await assertStorageFailure { try await repository.save(ReadingNote(text: "yeni")) }
        XCTAssertEqual(try Data(contentsOf: fileURL), garbage)
    }

    // MARK: - Dosya

    /// Application Support (ve altındaki klasörler) olmayabilir; ilk yazma onları oluşturmalı.
    func testFileRepositoryCreatesMissingDirectories() async throws {
        let fileURL = location.directory.appending(path: "a/b/notes.json")
        let repository = FileNotesRepository(fileURL: fileURL)

        try await repository.save(ReadingNote(text: "ilk"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))
    }

    /// Dosya biçimi sabit: başka bir araç (ya da uygulamanın eski bir sürümü) da okuyabilsin diye düz bir JSON dizisi.
    func testFileRepositoryWritesPlainJSONArray() async throws {
        let fileURL = location.fileURL("notes.json")
        let note = ReadingNote(text: "biçim", bookID: 3, createdAt: Date(timeIntervalSinceReferenceDate: 0))
        try await FileNotesRepository(fileURL: fileURL).save(note)

        let decoded = try JSONDecoder().decode([ReadingNote].self, from: Data(contentsOf: fileURL))
        XCTAssertEqual(decoded, [note])
    }

    // MARK: - Core Data modeli

    /// Model `.xcdatamodeld`'den derlenip pakete girmeli ve entity, elle yazdığımız `NoteEntity` sınıfına bağlı olmalı.
    func testCoreDataModelMapsNoteEntityClass() throws {
        let model = CoreDataNotesRepository.sharedModel
        let entity = try XCTUnwrap(model.entitiesByName[NoteEntity.entityName])
        XCTAssertEqual(entity.managedObjectClassName, "NoteEntity")
        XCTAssertEqual(Set(entity.attributesByName.keys), ["noteID", "text", "bookID", "createdAt"])
        XCTAssertEqual(entity.attributesByName["bookID"]?.isOptional, true)
    }

    // MARK: - Yedek repository

    func testUnavailableRepositoryThrowsItsErrorForEveryOperation() async {
        // Protokol üzerinden kullanıyoruz: Ekranlar da onu böyle görür (ve çağrılar böylece `async` olur).
        let repository: any NotesRepository = UnavailableNotesRepository(error: .storageFailure(reason: "disk dolu"))

        await assertStorageFailure { _ = try await repository.fetchAll() }
        await assertStorageFailure { try await repository.save(ReadingNote(text: "x")) }
        await assertStorageFailure { try await repository.delete(id: UUID()) }
        await assertStorageFailure { try await repository.deleteAll() }
    }

    // MARK: - Yardımcı

    private func assertStorageFailure(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("NotesRepositoryError bekleniyordu.", file: file, line: line)
        } catch {
            guard case NotesRepositoryError.storageFailure = error else {
                return XCTFail("Beklenmeyen hata: \(error)", file: file, line: line)
            }
        }
    }
}
