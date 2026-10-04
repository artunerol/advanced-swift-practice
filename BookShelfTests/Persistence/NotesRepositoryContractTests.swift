import XCTest
@testable import BookShelf

/// **Sözleşme testi (contract test):** `NotesRepository`'nin TÜM uygulamaları aynı test rutininden geçer.
///
/// Bu, Liskov yerine geçme ilkesinin (SOLID'deki "L") testidir: Protokolü kullanan kod hangi uygulamayı alırsa
/// alsın aynı davranışı görmeli. "En yeni en başta", "upsert", "silmek idempotent" gibi kurallar protokolün
/// belgesinde yazıyor; derleyici bunları denetleyemez, bu test denetler. Yeni bir depolama türü eklemek =
/// buraya bir satır eklemek.
///
/// Her test kendi yalıtılmış konumunu (geçici klasör + ayrı UserDefaults suite'i) kullanır ve sonunda siler.
/// Böylece testler gerçek kullanıcı verisine dokunmaz ve sıraları değişse de birbirini etkilemez.
final class NotesRepositoryContractTests: XCTestCase {
    private var location: PersistenceLocation!

    override func setUp() {
        super.setUp()
        location = .isolated(name: "NotesContract-\(UUID().uuidString)")
    }

    override func tearDown() {
        location.erase()
        location = nil
        super.tearDown()
    }

    // MARK: - Uygulamalar

    func testInMemoryRepositoryHonorsContract() async throws {
        try await assertHonorsContract(persistsAcrossInstances: false) {
            InMemoryNotesRepository()
        }
    }

    func testUserDefaultsRepositoryHonorsContract() async throws {
        // `UserDefaults` Sendable olmadığı için tek bir örneği yakalayıp her actor'e vermek derlenmez ("sending ... risks
        // causing data races"). `location` ise Sendable; her çağrıda aynı suite'e bakan yeni bir örnek açıyoruz.
        let location = self.location!
        try await assertHonorsContract(persistsAcrossInstances: true) {
            UserDefaultsNotesRepository(defaults: location.defaults)
        }
    }

    func testFileRepositoryHonorsContract() async throws {
        let fileURL = location.fileURL("notes.json")
        try await assertHonorsContract(persistsAcrossInstances: true) {
            FileNotesRepository(fileURL: fileURL)
        }
    }

    func testCoreDataInMemoryRepositoryHonorsContract() async throws {
        try await assertHonorsContract(persistsAcrossInstances: false) {
            try CoreDataNotesRepository(store: .inMemory)
        }
    }

    func testCoreDataSQLiteRepositoryHonorsContract() async throws {
        let storeURL = location.fileURL("Notes.sqlite")
        try await assertHonorsContract(persistsAcrossInstances: true) {
            try CoreDataNotesRepository(store: .sqlite(storeURL))
        }
    }

    func testSwiftDataInMemoryRepositoryHonorsContract() async throws {
        try await assertHonorsContract(persistsAcrossInstances: false) {
            try SwiftDataNotesRepository(store: .inMemory)
        }
    }

    func testSwiftDataFileRepositoryHonorsContract() async throws {
        let storeURL = location.fileURL("Notes.store")
        try await assertHonorsContract(persistsAcrossInstances: true) {
            try SwiftDataNotesRepository(store: .file(storeURL))
        }
    }

    // MARK: - Ortak rutin

    /// Sözleşmenin tamamını sırayla sınar. Test edilen şey somut tip değil, `any NotesRepository`: Ekranlar da
    /// repository'yi tam olarak böyle görür.
    ///
    /// - Parameters:
    ///   - persistsAcrossInstances: Aynı depoya bağlanan YENİ bir örnek eski veriyi görmeli mi?
    ///     Diskteki depolar için evet (uygulamayı kapatıp açmanın benzetimi), bellekteki depolar için hayır.
    ///   - makeRepository: Her çağrıda aynı depoya bağlanan yeni bir örnek üretir.
    private func assertHonorsContract(
        persistsAcrossInstances: Bool,
        file: StaticString = #filePath,
        line: UInt = #line,
        makeRepository: () throws -> any NotesRepository
    ) async throws {
        let repository = try makeRepository()

        // 1. Boş başlangıç
        var notes = try await repository.fetchAll()
        XCTAssertEqual(notes, [], "1. Yeni depo boş başlamalı.", file: file, line: line)

        // 2. Kaydet ve getir: sıra eklenme sırasından bağımsız olarak "en yeni en başta".
        // Tarihler sabit (testler her çalıştırmada aynı); kesirli saniye, tarihin depolamada yuvarlanmadığını da sınar.
        let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let oldest = ReadingNote(text: "En eski", bookID: 1, createdAt: base)
        let middle = ReadingNote(text: "Ortadaki", bookID: 8, createdAt: base.addingTimeInterval(60.123_456))
        let newest = ReadingNote(text: "En yeni", bookID: nil, createdAt: base.addingTimeInterval(120))
        for note in [middle, oldest, newest] {
            try await repository.save(note)
        }
        notes = try await repository.fetchAll()
        XCTAssertEqual(notes, [newest, middle, oldest], "2. Notlar tüm alanlarıyla ve en yeni en başta dönmeli.", file: file, line: line)

        // 3. Upsert: aynı id ile kaydetmek yeni not eklemez, mevcut notu günceller.
        var edited = middle
        edited.text = "Ortadaki (düzenlendi)"
        edited.bookID = nil
        try await repository.save(edited)
        notes = try await repository.fetchAll()
        XCTAssertEqual(notes, [newest, edited, oldest], "3. Aynı id ile kaydetmek güncellemeli (upsert).", file: file, line: line)

        // 4. Silme idempotent: aynı notu iki kez ya da hiç olmayan bir notu silmek hata değildir.
        try await repository.delete(id: oldest.id)
        try await repository.delete(id: oldest.id)
        try await repository.delete(id: UUID())
        notes = try await repository.fetchAll()
        XCTAssertEqual(notes, [newest, edited], "4. Silinen not gitmeli, diğerleri kalmalı.", file: file, line: line)

        // 5. Yeni örnek aynı depoyu görüyor mu?
        let reopened = try makeRepository()
        notes = try await reopened.fetchAll()
        XCTAssertEqual(
            notes,
            persistsAcrossInstances ? [newest, edited] : [],
            persistsAcrossInstances
                ? "5. Diskteki depo: yeni örnek kaydedilmiş notları görmeli."
                : "5. Bellekteki depo: yeni örnek boş başlamalı.",
            file: file, line: line
        )

        // 6. Hepsini sil (idempotent) ve kalıcı depoda silmenin de kalıcı olduğunu doğrula.
        try await repository.deleteAll()
        try await repository.deleteAll()
        notes = try await repository.fetchAll()
        XCTAssertEqual(notes, [], "6. deleteAll sonrası depo boş olmalı.", file: file, line: line)
        notes = try await makeRepository().fetchAll()
        XCTAssertEqual(notes, [], "6. deleteAll sonrası açılan yeni örnek de boş görmeli.", file: file, line: line)
    }
}
