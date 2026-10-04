import XCTest
@testable import BookShelf

/// Kalıcılık demosunun mantığı: not denetçisi, "yeniden aç" açıklaması, token maskeleme ve karşılaştırma tablosu.
/// Hepsi SwiftUI'sız test edilebiliyor, çünkü view'lar yalnızca bu tipleri gösteriyor.
final class NotesStorageInspectorTests: XCTestCase {
    private var location: PersistenceLocation!

    override func setUp() {
        super.setUp()
        location = .isolated(name: "NotesInspector-\(UUID().uuidString)")
    }

    override func tearDown() {
        location.erase()
        location = nil
        super.tearDown()
    }

    // MARK: - NotesStorageInspector

    @MainActor
    func testLoadShowsZeroNotesForEveryKindInFreshLocation() async {
        let inspector = NotesStorageInspector(location: location)

        await inspector.load()

        for kind in NotesStorageKind.allCases {
            XCTAssertEqual(inspector.counts[kind], 0, "\(kind)")
        }
        XCTAssertNil(inspector.message, "Hata mesajı olmamalı: \(inspector.message ?? "")")
    }

    @MainActor
    func testAddSampleChangesOnlySelectedKind() async {
        let inspector = NotesStorageInspector(location: location)
        await inspector.load()

        await inspector.select(.userDefaults)
        await inspector.addSample()
        await inspector.addSample()

        XCTAssertEqual(inspector.counts[.userDefaults], 2)
        XCTAssertEqual(inspector.counts[.file], 0)
        XCTAssertEqual(inspector.selectedNotes.count, 2)
        // En yeni en üstte: ikinci örnek başta.
        XCTAssertEqual(inspector.selectedNotes.first?.text, "Örnek not 2 · UserDefaults")
    }

    /// "Yeni örnekle yeniden aç": Diskteki depo veriyi korur, bellekteki depo kaybeder.
    @MainActor
    func testReopenKeepsDiskNotesButLosesInMemoryNotes() async {
        let inspector = NotesStorageInspector(location: location)

        await inspector.select(.coreData)
        await inspector.addSample()
        await inspector.reopen()
        XCTAssertEqual(inspector.counts[.coreData], 1)
        XCTAssertEqual(inspector.message, "Yeni örnek 1 not gördü: veri kalıcı.")

        await inspector.select(.inMemory)
        await inspector.addSample()
        await inspector.reopen()
        XCTAssertEqual(inspector.counts[.inMemory], 0)
        XCTAssertEqual(inspector.message, "Yeni örnek 0 not gördü: veri yalnızca eski örneğin belleğindeydi.")
    }

    @MainActor
    func testDeleteAllEmptiesSelectedKind() async {
        let inspector = NotesStorageInspector(location: location)
        await inspector.select(.swiftData)
        await inspector.addSample()

        await inspector.deleteAll()

        XCTAssertEqual(inspector.counts[.swiftData], 0)
        XCTAssertTrue(inspector.selectedNotes.isEmpty)
    }

    func testReopenVerdicts() {
        XCTAssertEqual(NotesStorageInspector.reopenVerdict(before: 0, after: 0), "Depo zaten boştu; önce bir not ekle, sonra yeniden aç.")
        XCTAssertEqual(NotesStorageInspector.reopenVerdict(before: 3, after: 3), "Yeni örnek 3 not gördü: veri kalıcı.")
        XCTAssertEqual(NotesStorageInspector.reopenVerdict(before: 3, after: 0), "Yeni örnek 0 not gördü: veri yalnızca eski örneğin belleğindeydi.")
        XCTAssertEqual(NotesStorageInspector.reopenVerdict(before: 3, after: 5), "Yeni örnek 5 not gördü (öncesinde 3).")
    }

    // MARK: - DemoToken

    func testTokenMaskingShowsOnlyEdges() {
        XCTAssertEqual(DemoToken.masked(DemoToken.value), "bk_d••••••••9F4K")
        XCTAssertEqual(DemoToken.masked("12345678"), "••••••••", "Kısa sırlar tamamen gizlenmeli.")
        XCTAssertEqual(DemoToken.masked(""), "")
    }

    // MARK: - Karşılaştırma tablosu

    func testComparisonTableIsCompleteAndUnique() {
        let options = StorageComparisonItem.all
        XCTAssertEqual(Set(options.map(\.id)).count, options.count, "Kimlikler benzersiz olmalı.")
        for option in options {
            let fields = [option.name, option.useCase, option.capacity, option.threading, option.encryption, option.querying, option.migration]
            XCTAssertFalse(fields.contains(where: \.isEmpty), "\(option.id) satırında boş alan var.")
        }
        // Mülakat sorusunda adı geçen seçenekler tabloda olmalı.
        for required in ["userDefaults", "keychain", "file", "coreData", "swiftData", "nsCache", "urlCache", "iCloud"] {
            XCTAssertTrue(options.contains { $0.id == required }, "\(required) eksik.")
        }
    }
}
