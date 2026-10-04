import SwiftData
import XCTest
@testable import BookShelf

/// **Öğrenme testi (learning test):** Kendi kodumuzu değil, güvendiğimiz bir çerçeve davranışını doğrular.
/// `NoteRecord`'daki yorum "`@Attribute(.unique)` ikinci eklemeyi güncellemeye (upsert) çevirir" diyor; bu test o
/// cümlenin bu SDK'da doğru olduğunu kanıtlar. Bir gün davranış değişirse yorumun da değişmesi gerektiğini buradan öğreniriz.
final class SwiftDataUniqueAttributeTests: XCTestCase {
    func testInsertingSameUniqueValueUpdatesExistingRecord() throws {
        let container = try ModelContainer(
            for: NoteRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let id = UUID()

        context.insert(NoteRecord(note: ReadingNote(id: id, text: "ilk")))
        try context.save()
        context.insert(NoteRecord(note: ReadingNote(id: id, text: "ikinci")))
        try context.save()

        let records = try context.fetch(FetchDescriptor<NoteRecord>())
        XCTAssertEqual(records.map(\.text), ["ikinci"], "Aynı noteID ile ikinci kayıt eklenmemeli, ilki güncellenmeli.")
    }
}
