import XCTest
@testable import BookShelf

/// DIP vs DI demosundaki örneklerin testleri: sayaçlar, strateji (biçimlendirici) ve method injection.
final class DependencyInjectionDemoTests: XCTestCase {

    // MARK: - Sayaçlar: kim oluşturuyor, neye bağlı?

    func testTightlyCoupledCounterIgnoresAnyRepositoryWeHave() async {
        // Elimizde üç notlu bir depo var ama sıkı bağlı sayaca VEREMEYİZ: deposunu kendisi oluşturuyor.
        _ = DependencyDemoSamples.filledRepository()

        let count = await TightlyCoupledNoteCounter().count()

        XCTAssertEqual(count, 0)
    }

    func testInjectedCountersUseTheGivenRepository() async throws {
        let filled = DependencyDemoSamples.filledRepository()

        let concrete = await ConcreteInjectedNoteCounter(repository: filled).count()
        let injected = try await InjectedNoteCounter(repository: filled).count()

        XCTAssertEqual(concrete, 3)
        XCTAssertEqual(injected, 3)
    }

    /// Sadece protokole bağlı sayaç, `InMemoryNotesRepository` OLMAYAN bir depoyla da çalışır.
    /// (`ConcreteInjectedNoteCounter(repository: NotesArchitectureDoubles.FailingRepository())` derlenmezdi.)
    func testProtocolInjectedCounterAcceptsAnyRepository() async {
        let counter = InjectedNoteCounter(repository: NotesArchitectureDoubles.FailingRepository())

        do {
            _ = try await counter.count()
            XCTFail("Sahte depo hata fırlatmalı")
        } catch {
            XCTAssertEqual(error as? NotesRepositoryError, NotesArchitectureDoubles.FailingRepository.error)
        }
    }

    // MARK: - Strateji ve method injection

    func testLengthFormatterCountsCharactersAndNonEmptyLines() {
        let note = ReadingNote(text: "Kürk\n\nMantolu", createdAt: .distantPast)

        XCTAssertEqual(LengthNoteFormatter().detail(for: note), "13 karakter · 2 satır")
    }

    /// Tarih biçimi işletim sisteminin dil verisine bağlı; tam metni değil, dil ve saat diliminin
    /// gerçekten enjekte edildiğini doğruluyoruz.
    func testDateFormatterUsesInjectedLocaleAndTimeZone() throws {
        // 3 Ekim 2026 04:00 UTC
        let note = ReadingNote(text: "x", createdAt: Date(timeIntervalSince1970: 1_791_000_000))
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))

        let turkish = DateNoteFormatter(locale: Locale(identifier: "tr_TR"), timeZone: utc).detail(for: note)
        let english = DateNoteFormatter(locale: Locale(identifier: "en_US"), timeZone: utc).detail(for: note)
        let turkishInTokyo = DateNoteFormatter(locale: Locale(identifier: "tr_TR"), timeZone: tokyo).detail(for: note)

        XCTAssertTrue(turkish.contains("Eki"), turkish)
        XCTAssertTrue(english.contains("Oct"), english)
        XCTAssertNotEqual(turkish, turkishInTokyo, "Saat dilimi çıktıyı değiştirmeli (UTC 04:00 = Tokyo 13:00)")
    }

    func testExporterOutputChangesWithInjectedStrategy() {
        let notes = DependencyDemoSamples.notes

        let byLength = NotesPlainTextExporter.export(notes, using: LengthNoteFormatter())
        let byDate = NotesPlainTextExporter.export(notes, using: DateNoteFormatter())

        // Her not "• " ile başlar. (Satır sayısı nottan fazla olabilir: ikinci örnek notun kendisi iki satır.)
        XCTAssertEqual(byLength.split(separator: "\n").filter { $0.hasPrefix("• ") }.count, notes.count)
        XCTAssertTrue(byLength.hasPrefix("• Tutunamayanlar"), byLength)
        XCTAssertTrue(byLength.contains("karakter · 1 satır)"), byLength)
        XCTAssertTrue(byLength.contains("karakter · 2 satır)"), byLength)
        XCTAssertFalse(byDate.contains("karakter"), byDate)
        XCTAssertNotEqual(byLength, byDate)
    }
}
