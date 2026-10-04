import Foundation
import SwiftData

/// **Data katmanı → SwiftData ile notlar** (iOS 17+).
///
/// SwiftData'nın parçaları Core Data'dakilere birebir karşılık gelir:
/// | SwiftData        | Core Data                                   |
/// |------------------|---------------------------------------------|
/// | `@Model` sınıfı  | `NSManagedObject` + `.xcdatamodeld` entity'si |
/// | `ModelContainer` | `NSPersistentContainer` (şema + depo)        |
/// | `ModelContext`   | `NSManagedObjectContext`                     |
/// | `FetchDescriptor` + `#Predicate` | `NSFetchRequest` + `NSPredicate` |
///
/// ## `@ModelActor` neden?
/// `ModelContext` Sendable değildir ve aynı anda tek bir yerden kullanılmalıdır. `@ModelActor` makrosu bu actor'e
/// kendi `ModelContext`'ini ve o context'in **seri executor'ını** verir: actor'ün izole metotları tam da o
/// context'in sırasında çalışır. Core Data'da `perform { }` ile elle yaptığımız şeyi burada dil yapıyor:
/// her metot zaten doğru "kuyrukta", `perform` yazmaya gerek yok.
///
/// Makronun ürettikleri: `modelContainer` ve `modelExecutor` özellikleri, `init(modelContainer:)` başlatıcısı ve
/// `ModelActor` protokolünden gelen `modelContext`.
///
/// Tasarım: `@Model` nesneleri (`NoteRecord`) bu actor'ün dışına hiç çıkmaz; her metot `ReadingNote` döndürür.
@ModelActor
actor SwiftDataNotesRepository: NotesRepository {
    func fetchAll() throws -> [ReadingNote] {
        // Sıralamayı veritabanı yapar. `SortDescriptor(\.createdAt)` anahtar yolu derleme anında denetlenir
        // (Core Data'daki "createdAt" metninden farklı olarak yazım hatası derlenmez).
        let descriptor = FetchDescriptor<NoteRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try storageCall { try modelContext.fetch(descriptor).map(\.readingNote) }
    }

    func save(_ note: ReadingNote) throws {
        try storageCall {
            if let existing = try record(id: note.id) {
                existing.update(from: note)
            } else {
                modelContext.insert(NoteRecord(note: note))
            }
            // `autosaveEnabled` açıkken SwiftData değişiklikleri belirli anlarda kendisi de kaydeder; ama NE ZAMAN
            // kaydedeceği garanti değil. "save döndü = depoda" sözleşmesi için her değişiklikten sonra açıkça kaydediyoruz.
            try modelContext.save()
        }
    }

    func delete(id: ReadingNote.ID) throws {
        try storageCall {
            guard let existing = try record(id: id) else { return } // idempotent
            modelContext.delete(existing)
            try modelContext.save()
        }
    }

    func deleteAll() throws {
        try storageCall {
            // Tek çağrıyla tüm `NoteRecord`'ları siler (koşul verilirse yalnızca uyanları).
            try modelContext.delete(model: NoteRecord.self)
            try modelContext.save()
        }
    }

    // MARK: - Yardımcılar

    private func record(id: UUID) throws -> NoteRecord? {
        // `#Predicate` makrosu Swift ifadesini veritabanı sorgusuna çevirir (derleme anında denetlenir).
        // `id` dışarıdan yakalanan bir sabit. İpucu: `note.id` gibi başka bir nesnenin özelliğini kullanacaksan
        // önce yerel bir sabite al; predicate'in içinde yalnızca modelin kendi anahtar yollarına güven.
        var descriptor = FetchDescriptor<NoteRecord>(predicate: #Predicate { $0.noteID == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// SwiftData hatalarını domain hatasına çevirir.
    private func storageCall<T>(_ work: () throws -> T) throws -> T {
        do {
            return try work()
        } catch {
            throw NotesRepositoryError.storageFailure(reason: error.localizedDescription)
        }
    }
}

extension SwiftDataNotesRepository {
    /// Depo nerede?
    enum Store: Sendable {
        /// Diskte (SQLite). `url`: depo dosyasının adresi.
        case file(URL)
        /// Bellekte. Testler ve önizlemeler için.
        case inMemory
    }

    /// Container'ı kurup repository'yi oluşturur. Depo açılamazsa hata fırlatır.
    ///
    /// Bu bir "delegating initializer": Container'ı kurduktan sonra işi makronun ürettiği `init(modelContainer:)`'a
    /// devrediyor (`self.init(...)`). Böylece kullanım Core Data'dakiyle aynı: `try SwiftDataNotesRepository(store: .inMemory)`.
    init(store: Store) throws {
        let configuration: ModelConfiguration
        switch store {
        case .file(let url):
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            configuration = ModelConfiguration(url: url)
        case .inMemory:
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        }
        do {
            // Şema `NoteRecord.self`'ten üretilir. İleride model değişirse `VersionedSchema` + `SchemaMigrationPlan`
            // ile sürümler ve geçiş adımları tanımlanır (`migrationPlan:` parametresi).
            let container = try ModelContainer(for: NoteRecord.self, configurations: configuration)
            self.init(modelContainer: container)
        } catch {
            throw NotesRepositoryError.storageFailure(reason: "SwiftData deposu açılamadı: \(error.localizedDescription)")
        }
    }
}
