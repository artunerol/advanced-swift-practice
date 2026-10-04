import Foundation

/// Karşılaştırma tablosunun bir satırı: bir saklama seçeneği ve altı soruya kısa cevaplar.
/// Mülakatta "hangisini ne zaman?" sorusunu bu altı eksen üzerinden cevaplamak işe yarar.
struct StorageComparisonItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// Ne için?
    let useCase: String
    /// Ne kadar veri? Bellek/disk davranışı.
    let capacity: String
    /// Thread güvenliği.
    let threading: String
    /// Şifreleme.
    let encryption: String
    /// Sorgulama.
    let querying: String
    /// Şema/biçim değişince ne olur?
    let migration: String
}

extension StorageComparisonItem {
    /// Tablo, "basitten karmaşığa" sıralı. Üçüncü parti olanlar adında belirtiliyor.
    static let all: [StorageComparisonItem] = [
        StorageComparisonItem(
            id: "userDefaults",
            name: "UserDefaults",
            useCase: "Küçük tercihler ve bayraklar: tema, okuma hızı, \"tanıtım görüldü\".",
            capacity: "Küçük (KB'lar). Tek plist dosyası; ilk erişimde tamamı belleğe alınır, değişince tamamı yeniden yazılır.",
            threading: "Apple'a göre thread-safe; ama Swift 6'da Sendable olarak işaretli değil.",
            encryption: "Kendine ait şifreleme yok; yalnızca cihazın Data Protection'ı. Sır saklanmaz.",
            querying: "Yok: anahtar → değer.",
            migration: "Elle: anahtarı sürümle (ör. \"readingNotes.v1\") ve eski değeri yeni anahtara taşı."
        ),
        StorageComparisonItem(
            id: "keychain",
            name: "Keychain",
            useCase: "Sırlar: erişim token'ı, parola, şifreleme anahtarı.",
            capacity: "Küçük kayıtlar.",
            threading: "Thread-safe ama senkron ve bloklayıcı (sistem servisine süreçler arası çağrı).",
            encryption: "Var: ayrı, şifreli veritabanı. Erişim sınıfı (kSecAttrAccessible…) ve Face ID/parola şartı (SecAccessControl) seçilebilir.",
            querying: "Özniteliklerle (service, account) basit arama.",
            migration: "Yok. Kayıtlar uygulama silinse bile genellikle cihazda kalır; access group ile uygulamalar arasında paylaşılabilir."
        ),
        StorageComparisonItem(
            id: "file",
            name: "Dosya (Codable → JSON/plist)",
            useCase: "Belgeler, görseller, dışa aktarım; \"hepsini oku, hepsini yaz\" ile yetinen küçük-orta listeler.",
            capacity: "Disk kadar; ama tek dosyadaki liste her yazımda baştan yazılır. Application Support ve Documents yedeklenir.",
            threading: "FileManager.default çoğu işlemde thread-safe. \"Oku → değiştir → yaz\" adımlarını sen sıraya sokmalısın (ör. actor).",
            encryption: "Data Protection: .completeFileProtection vb. Varsayılan sınıf completeUntilFirstUserAuthentication.",
            querying: "Yok: belleğe al, filtrele.",
            migration: "Elle: Codable'da decodeIfPresent, varsayılan değerler ya da bir sürüm alanı."
        ),
        StorageComparisonItem(
            id: "caches",
            name: "Caches ve tmp klasörleri",
            useCase: "Yeniden indirilebilen ya da üretilebilen dosyalar (Caches), kısa ömürlü dosyalar (tmp).",
            capacity: "Disk kadar; ama sistem yer açmak için silebilir. Yedeğe girmez.",
            threading: "Dosyalarla aynı kurallar.",
            encryption: "Data Protection.",
            querying: "Yok.",
            migration: "Gerekmez: Her an silinebileceğini varsayarak yaz."
        ),
        StorageComparisonItem(
            id: "coreData",
            name: "Core Data",
            useCase: "Büyük, ilişkili, sorgulanan nesne grafiği; değişiklik takibi, undo, NSFetchedResultsController, CloudKit eşitleme.",
            capacity: "Büyük (genelde SQLite). Faulting: nesneler gerektiğinde belleğe alınır.",
            threading: "Her context bir kuyruğa bağlı; her erişim perform { } içinde. NSManagedObject taşınmaz, NSManagedObjectID taşınır.",
            encryption: "Kendi şifrelemesi yok; SQLite dosyası Data Protection ile korunur (NSPersistentStoreFileProtectionKey).",
            querying: "NSPredicate, sıralama, fetchLimit, sayma ve toplama, batch istekleri.",
            migration: "Model sürümleri + lightweight migration (otomatik çıkarım); karmaşık dönüşümde mapping model ya da staged migration (iOS 17+)."
        ),
        StorageComparisonItem(
            id: "swiftData",
            name: "SwiftData",
            useCase: "Core Data'nın işleri, Swift'e özgü API ile: @Model, #Predicate, SwiftUI'da @Query. iOS 17+.",
            capacity: "Büyük (varsayılan depo SQLite).",
            threading: "ModelContext ve @Model nesneleri Sendable değil. Arka plan işi @ModelActor ile; nesne yerine PersistentIdentifier taşınır.",
            encryption: "Kendi şifrelemesi yok; dosya Data Protection ile korunur.",
            querying: "FetchDescriptor + #Predicate: derleme anında denetlenen sorgular.",
            migration: "VersionedSchema + SchemaMigrationPlan (lightweight ve custom aşamalar)."
        ),
        StorageComparisonItem(
            id: "sqlite",
            name: "SQLite (GRDB · üçüncü parti)",
            useCase: "SQL'e tam hakimiyet, karmaşık sorgular, platformlar arası ortak şema.",
            capacity: "Büyük.",
            threading: "Kütüphaneye bağlı. GRDB: DatabaseQueue (seri) ya da DatabasePool (WAL ile eşzamanlı okuma).",
            encryption: "SQLCipher ile bütün veritabanı şifrelenebilir.",
            querying: "Tam SQL: JOIN, indeks, tam metin arama (FTS).",
            migration: "Sıralı, elle yazılan migration'lar (GRDB: DatabaseMigrator)."
        ),
        StorageComparisonItem(
            id: "realm",
            name: "Realm (üçüncü parti)",
            useCase: "Nesne veritabanı; canlı (live) nesneler ve değişiklik bildirimleri.",
            capacity: "Büyük.",
            threading: "Nesneler oluşturuldukları thread'e bağlı; başka thread'e ThreadSafeReference ya da frozen nesneyle aktarılır.",
            encryption: "Yerleşik şifreleme (64 baytlık anahtar).",
            querying: "Zengin sorgular (NSPredicate benzeri ve tip güvenli where).",
            migration: "schemaVersion artır + migration bloğu. MongoDB 2024'te Device Sync ve Device SDK'larını kullanımdan kaldırdı; yeni projede bakım geleceğini hesaba kat."
        ),
        StorageComparisonItem(
            id: "nsCache",
            name: "NSCache",
            useCase: "Bellekte, yeniden üretilebilen verinin önbelleği (ör. çözülmüş görseller).",
            capacity: "Bellek. countLimit/totalCostLimit; bellek azalınca sistem öğeleri kendisi atar.",
            threading: "Thread-safe: farklı thread'lerden kilitlemeden kullanılabilir.",
            encryption: "Yok (yalnızca bellek).",
            querying: "Yalnızca anahtarla. Anahtarları kopyalamaz (NSMutableDictionary'den farkı).",
            migration: "Gerekmez: uygulama kapanınca boşalır."
        ),
        StorageComparisonItem(
            id: "urlCache",
            name: "URLCache",
            useCase: "HTTP yanıt önbelleği. URLSession kullanır ve Cache-Control başlıklarına uyar.",
            capacity: "memoryCapacity + diskCapacity ayarlanabilir; disk kısmı Caches altında.",
            threading: "Thread-safe.",
            encryption: "Ayrıca yok; disk kısmı Data Protection kapsamında.",
            querying: "URLRequest ile.",
            migration: "Gerekmez: sistem disk dolunca silebilir."
        ),
        StorageComparisonItem(
            id: "iCloud",
            name: "iCloud (NSUbiquitousKeyValueStore, CloudKit)",
            useCase: "Key-value store: küçük ayarları cihazlar arası eşitler. CloudKit: kullanıcının iCloud'unda kayıtlar; Core Data/SwiftData eşitlemesi.",
            capacity: "Key-value store: toplam 1 MB, en fazla 1024 anahtar. CloudKit: özel veritabanı kullanıcının iCloud kotasını kullanır.",
            threading: "Ağ işi arka planda; dış değişiklikler bildirimle gelir (didChangeExternallyNotification). Çakışmayı uygulama düşünmeli.",
            encryption: "iCloud'da şifreli saklanır; CloudKit'te encryptedValues ile alan bazında uçtan uca şifreleme (iOS 15+).",
            querying: "Key-value: yok. CloudKit: CKQuery ile basit sorgular.",
            migration: "CloudKit şeması üretime gönderildikten sonra yalnızca eklenebilir: alan silinmez, yeniden adlandırılmaz."
        ),
    ]
}
