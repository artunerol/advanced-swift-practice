import CoreData

/// **Data katmanı → Core Data ile notlar.**
///
/// Core Data "yığını" (stack) üç parçadır:
/// - `NSManagedObjectModel`: Şema (entity'ler ve alanları). `NotesModel.xcdatamodeld`'den gelir.
/// - `NSPersistentStoreCoordinator`: Modeli diskteki depoya (burada SQLite) bağlar.
/// - `NSManagedObjectContext`: Nesnelerle çalıştığımız "karalama defteri". Değişiklikler `save()` deyince depoya gider.
/// `NSPersistentContainer` bu üçünü bizim için kurar.
///
/// ## Concurrency kuralları (mülakatın asıl sorusu)
/// 1. Her context bir **kuyruğa bağlıdır**: `viewContext` ana kuyruğa, `newBackgroundContext()` kendi özel (private)
///    kuyruğuna. Context'e ve getirdiği nesnelere YALNIZCA o kuyrukta, yani `perform { }` / `performAndWait { }`
///    içinde dokunulur.
/// 2. `NSManagedObject` thread'ler arasında taşınmaz. Taşınması gerekiyorsa `NSManagedObjectID` (Sendable) taşınır
///    ve diğer context'te `existingObject(with:)` ile yeniden alınır. Biz daha da basitini yapıyoruz: Nesneyi
///    `perform` içinde `ReadingNote` struct'ına çevirip struct'ı döndürüyoruz.
/// 3. Hata ayıklarken `-com.apple.CoreData.ConcurrencyDebug 1` başlatma argümanı, kural ihlalinde uygulamayı
///    hemen durdurur.
///
/// ## Neden `actor` değil de `final class`?
/// Xcode 26 SDK'sında `NSPersistentContainer` ve `NSManagedObjectContext` `NS_SWIFT_SENDABLE` ile işaretli
/// (başlık dosyalarında görebilirsin): Context'in **referansını** başka thread'e vermek güvenlidir, çünkü
/// `perform` her yerden çağrılabilir ve işi context'in kendi seri kuyruğuna koyar. Yani serileştirmeyi zaten
/// context'in kuyruğu yapıyor; üstüne bir actor eklemek ikinci, gereksiz bir sıra olurdu. Her işlem (ör. upsert'te
/// "ara → güncelle ya da ekle → kaydet") TEK bir `perform` bloğunda; blok kuyrukta bölünmeden çalıştığı için iki
/// eşzamanlı `save` birbirinin değişikliğini ezemez (actor'deki "araya `await` girmesin" kuralının aynısı).
///
/// Sendable OLMAYAN şey `NSManagedObject`'tir ve `perform`'un kapanışı `@Sendable` olduğu için onu dışarıdan içeri
/// sokmak derleyici uyarısı verir. (Bu işaretleri taşımayan bir SDK'da yaygın çözüm, context'i bir actor'ün içinde
/// saklamaktır.)
final class CoreDataNotesRepository: NotesRepository {
    /// Depo nerede?
    enum Store: Sendable {
        /// Diskte SQLite dosyası. Uygulama kapanıp açılınca veri kalır.
        case sqlite(URL)
        /// Bellekte. Testler için: hızlı ve her seferinde boş.
        case inMemory
    }

    /// Modeli süreç boyunca BİR kez yükleyip tüm container'larda paylaşıyoruz.
    ///
    /// Neden? Aynı `.momd` dosyasından iki ayrı `NSManagedObjectModel` yüklenirse iki farklı entity açıklaması
    /// aynı `NoteEntity` sınıfını sahiplenir ve Core Data "Multiple NSEntityDescriptions claim the NSManagedObject
    /// subclass" uyarısı verir; `NoteEntity(context:)` hangi entity'yi kullanacağını şaşırabilir. Testler çok sayıda
    /// container oluşturduğu için bu gerçek bir sorun.
    ///
    /// `nonisolated(unsafe)`: `NSManagedObjectModel` Sendable değil, bu yüzden derleyici global bir `let`'e izin
    /// vermez. Elle verdiğimiz güvence: Model bir coordinator tarafından kullanılmaya başladığı an **değiştirilemez**
    /// hale gelir (SDK başlığındaki açıklama: "once a model is being used, it MUST NOT be changed") ve biz onu hiç
    /// değiştirmiyoruz. Değişmeyen bir nesneyi birden çok thread'in okuması güvenlidir. `static let`'in kendisi de
    /// tembel ve thread-safe biçimde bir kez başlatılır.
    nonisolated(unsafe) static let sharedModel: NSManagedObjectModel = {
        // Xcode, `.xcdatamodeld`'yi derleyip uygulama paketine `.momd` olarak koyar.
        // `Bundle(for:)`: Sınıfın bulunduğu paket. Testler uygulamanın içinde çalıştığı için yine uygulama paketi.
        guard let url = Bundle(for: NoteEntity.self).url(forResource: "NotesModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url)
        else {
            // Model dosyası pakette yoksa bu bir programcı hatasıdır (derleme ayarı bozuk); çalışmaya devam etmenin anlamı yok.
            fatalError("NotesModel.momd uygulama paketinde bulunamadı.")
        }
        return model
    }()

    private let container: NSPersistentContainer
    /// Tüm işlerin yapıldığı arka plan context'i. Kendi özel kuyruğu var; ana thread'i hiç meşgul etmez.
    private let context: NSManagedObjectContext

    /// Depoyu açar. Açılamazsa (disk dolu, dosya bozuk, model uyumsuz) hata fırlatır.
    init(store: Store) throws {
        container = NSPersistentContainer(name: "NotesModel", managedObjectModel: Self.sharedModel)

        let description: NSPersistentStoreDescription
        switch store {
        case .sqlite(let url):
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            description = NSPersistentStoreDescription(url: url)
            // Dosya koruması istenirse `NSPersistentStoreFileProtectionKey` seçeneğiyle verilir. Vermediğimiz için
            // uygulama dosyalarının varsayılanı (`completeUntilFirstUserAuthentication`) geçerli.
        case .inMemory:
            // Apple'ın önerdiği yol: SQLite deposu ama adres /dev/null → hiçbir şey diske yazılmaz.
            // (NSInMemoryStoreType da olurdu; ama SQLite'a özgü özellikler, ör. batch delete, onda çalışmaz.
            // /dev/null ile testler gerçek depoyla aynı motoru kullanır.)
            description = NSPersistentStoreDescription(url: URL(filePath: "/dev/null"))
        }
        // Lightweight migration: Model yeni bir sürüme geçtiğinde (alan ekleme, opsiyonel yapma, yeniden adlandırma...)
        // Core Data eski depoyu otomatik dönüştürür. İkisi de zaten varsayılan olarak açık; burada görünür olsunlar diye yazdık.
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        // `shouldAddStoreAsynchronously` varsayılan olarak false: Tamamlama bloğu bu çağrı dönmeden ÇALIŞIR.
        // Bu yüzden hatayı bir yerel değişkende toplayıp hemen kontrol edebiliyoruz.
        var loadError: (any Error)?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw NotesRepositoryError.storageFailure(reason: "Core Data deposu açılamadı: \(loadError.localizedDescription)")
        }

        context = container.newBackgroundContext()
        // Aynı kayıt iki yerden (ör. aynı dosyayı açmış başka bir container) değiştirilirse bu context'teki değerler
        // kazansın. Varsayılan politika (`NSErrorMergePolicy`) böyle bir çakışmada `save()`'i hatayla reddeder.
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    func fetchAll() async throws -> [ReadingNote] {
        let context = self.context
        return try await perform {
            let request = NoteEntity.typedFetchRequest()
            // Sıralamayı veritabanı yapar (SQL ORDER BY): bellekte sıralamaktan ucuzdur.
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(NoteEntity.createdAt), ascending: false)]
            // Nesneler `perform` bloğunun içinde struct'a çevriliyor; dışarı yalnızca Sendable `[ReadingNote]` çıkıyor.
            return try context.fetch(request).map(\.readingNote)
        }
    }

    func save(_ note: ReadingNote) async throws {
        let context = self.context
        try await perform {
            // Upsert: aynı id'li kayıt varsa güncelle, yoksa yeni kayıt ekle.
            let entity = try Self.existingEntity(id: note.id, in: context) ?? NoteEntity(context: context)
            entity.update(from: note)
            try context.save()
        }
    }

    func delete(id: ReadingNote.ID) async throws {
        let context = self.context
        try await perform {
            // Kayıt yoksa hiçbir şey yapmıyoruz: idempotent.
            guard let entity = try Self.existingEntity(id: id, in: context) else { return }
            context.delete(entity)
            try context.save()
        }
    }

    func deleteAll() async throws {
        let context = self.context
        try await perform {
            // Küçük veri için en basit yol: getir ve tek tek sil. Binlerce kayıt için `NSBatchDeleteRequest`
            // doğrudan SQLite üzerinde çalışır ve nesneleri belleğe almaz; ama context'i atladığı için açık
            // context'lerin değişikliği ayrıca öğrenmesi (`mergeChanges(fromRemoteContextSave:into:)`) gerekir.
            for entity in try context.fetch(NoteEntity.typedFetchRequest()) {
                context.delete(entity)
            }
            if context.hasChanges {
                try context.save()
            }
        }
    }

    // MARK: - Yardımcılar

    /// `context.perform`'u çağırır ve Core Data hatalarını domain hatasına çevirir. Üst katmanlar `NSError`'ın
    /// Core Data kodlarını (`NSValidationErrorKey`...) tanımak zorunda kalmaz.
    private func perform<T>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        do {
            // `perform` (iOS 15+ async sürümü): Bloğu context'in kuyruğunda çalıştırır ve bitmesini `await` ile bekler.
            return try await context.perform(work)
        } catch let error as NotesRepositoryError {
            throw error
        } catch {
            throw NotesRepositoryError.storageFailure(reason: error.localizedDescription)
        }
    }

    /// `id`'ye sahip kaydı getirir. `perform` bloğunun İÇİNDEN çağrılmalı.
    private static func existingEntity(id: UUID, in context: NSManagedObjectContext) throws -> NoteEntity? {
        let request = NoteEntity.typedFetchRequest()
        // `%K` anahtar adını, `%@` değeri güvenle yerleştirir. Model dosyasındaki `byNoteID` fetch index'i bu aramayı hızlandırır.
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(NoteEntity.noteID), id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
