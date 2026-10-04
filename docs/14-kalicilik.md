# Kalıcılık: iOS'ta Veriyi Nerede Saklarsın?

## Neden önemli?

Hemen her uygulama bir şeyleri saklar: kullanıcının ayarlarını, oturum token'ını, indirilen görselleri, yazdığı notları. Yanlış yer seçmenin bedeli büyüktür:

- Token'ı UserDefaults'a yazarsan şifresiz bir yedekten okunabilir.
- Büyüyen bir listeyi UserDefaults'ta tutarsan her eklemede bütün dosya yeniden yazılır, uygulama yavaşlar.
- Core Data nesnesini yanlış thread'de kullanırsan nadiren tekrarlanan, bulması çok zor çökmeler yaşarsın.
- Dosyayı atomik yazmazsan yarıda kalan bir yazım kullanıcının bütün verisini bozar.

Mülakatta soru genelde "UserDefaults, Keychain, Core Data farkı ne?" diye başlar; ardından "Core Data'da thread güvenliği", "migration", "SwiftData mı Core Data mı?" gelir. Bu derste hepsini, bu projedeki **tek bir protokolün beş farklı uygulaması** üzerinden göreceğiz.

Uygulamada **Mülakat → "iOS'ta veri saklama yolları nelerdir?" → Demo** ekranı bu dersin canlı halidir: okuma hızı ayarı (UserDefaults), sahte bir token (Keychain), beş depoda not saklama ve bir karşılaştırma tablosu.

## Temel kavramlar

### 1. Karar: Önce verinin türüne bak

| Veri | Nereye? | Neden? |
|---|---|---|
| Küçük tercih, bayrak (tema, okuma hızı, "tanıtım görüldü") | **UserDefaults** | Basit anahtar-değer; SwiftUI'da `@AppStorage` |
| Sır (token, parola, şifreleme anahtarı) | **Keychain** | Ayrı, şifreli veritabanı; erişim koşulları seçilebilir |
| Belge, görsel, dışa aktarım, küçük-orta Codable liste | **Dosya** (Application Support / Documents) | Basit; "hepsini oku, hepsini yaz" |
| Büyüyen, ilişkili, sorgulanan veri | **Core Data / SwiftData** (ya da SQLite) | Sorgu, sıralama, faulting, migration |
| Yeniden üretilebilen veri | **NSCache**, **URLCache**, **Caches** klasörü | Sistem gerekirse siler; yedeğe girmez |
| Cihazlar arası eşitleme | **NSUbiquitousKeyValueStore**, **CloudKit** | iCloud hesabı üzerinden |

Akılda tutulacak cümle: *"Önce verinin türü (tercih mi, sır mı, belge mi, sorgulanan bir grafik mi, önbellek mi), sonra boyutu."*

### 2. Uygulamanın klasörleri (sandbox)

Her iOS uygulaması kendi klasöründe (sandbox) çalışır. İçindeki klasörlerin davranışı farklıdır:

| Klasör | Ne için? | Yedeğe girer mi? | Sistem silebilir mi? |
|---|---|---|---|
| `Documents/` | Kullanıcının belgeleri (Dosyalar uygulamasında gösterilebilir) | Evet | Hayır |
| `Library/Application Support/` | Uygulamanın kendi verisi (veritabanı, JSON) | Evet | Hayır |
| `Library/Caches/` | Yeniden indirilebilen/üretilebilen dosyalar | Hayır | Evet, disk azalınca |
| `Library/Preferences/` | UserDefaults'un plist dosyası (elle dokunma) | Evet | Hayır |
| `tmp/` | Kısa ömürlü dosyalar | Hayır | Evet |

Swift'te adresleri `URL.applicationSupportDirectory`, `URL.documentsDirectory`, `URL.cachesDirectory`, `URL.temporaryDirectory` ile alınır (iOS 16+). Application Support klasörünün var olacağı garanti değildir; yazmadan önce `createDirectory(withIntermediateDirectories: true)` çağrılır. Yedekten hariç tutmak istediğin büyük bir dosya varsa `URLResourceValues.isExcludedFromBackup = true`.

### 3. UserDefaults ve `@AppStorage`

UserDefaults bir **plist dosyasıdır** (`Library/Preferences/<bundle-id>.plist`). Uygulama içinde önbelleğe alınır, bu yüzden okumak ucuzdur. Ama:

- Değer değişince plist **bütünüyle** yeniden yazılır.
- Sorgu yoktur; yalnızca anahtar → değer.
- Kendine ait bir şifrelemesi yoktur. Dosya yalnızca diğer uygulama dosyaları gibi cihazın Data Protection'ıyla korunur; şifresiz bir bilgisayar yedeğinden düz metin olarak okunabilir.

SwiftUI'da `@AppStorage` bir anahtarı durum (state) gibi kullanmayı sağlar:

```swift
@AppStorage(BookDetailViewModel.readingSpeedKey) private var pagesPerHour: Double = 40
```

Varsayılan değer (40) yalnızca anahtar hiç yazılmamışsa kullanılır; UserDefaults'a **yazılmaz**. Bu yüzden aynı ayarı okuyan başka bir yer de aynı varsayılanı bilmelidir. Bu projede o yer `BookDetailViewModel.readingSpeed(in:)`: kayıt yoksa `double(forKey:)` 0 döner ve `ReadingPace.resolved` onu 40'a çevirir.

Bilinmesi gerekenler:

- `UserDefaults(suiteName:)` ayrı bir alan açar. App Group ile (`"group.com.ornek"`) uygulama ve eklentileri aynı ayarları paylaşır; testlerde ise her test kendi suite'ini kullanıp sonunda `removePersistentDomain(forName:)` ile siler.
- `register(defaults:)` varsayılanları **diske yazmadan** kaydeder; her açılışta yeniden çağrılır.
- Apple'ın belgesine göre UserDefaults thread-safe'tir ama Xcode 26 SDK'sında `Sendable` olarak işaretli değil. Swift 6'da bir örneği actor'e verip dışarıda kullanmaya devam edersen derleyici "sending ... risks causing data races" der. Bu projede çözüm: `PersistenceLocation` örneği değil suite **adını** saklar ve her ihtiyaçta yeni bir örnek açar.

### 4. Keychain

Keychain, uygulama dosyalarından ayrı, **şifreli** bir veritabanıdır; anahtarları cihaz parolası ve Secure Enclave ile korunur. C tarzı API'si sözlüklerle çalışır: "sınıf + service + account" bir kaydı tanımlar.

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "dev.learning.BookShelf",
    kSecAttrAccount as String: "demo-access-token",
]
// Güncelle; kayıt yoksa (errSecItemNotFound) ekle.
var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
if status == errSecItemNotFound {
    var attributes = query
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    status = SecItemAdd(attributes as CFDictionary, nil)
}
```

**Ne zaman okunabilir?** (`kSecAttrAccessible`)

| Değer | Anlamı |
|---|---|
| `kSecAttrAccessibleWhenUnlocked` (varsayılan) | Yalnızca cihaz açıkken |
| `kSecAttrAccessibleAfterFirstUnlock` | Yeniden başlatmadan sonraki ilk kilit açılışından itibaren, kilitliyken de. Arka planda yenilenen token'lar için |
| `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` | Yalnızca cihazda parola varsa; parola kaldırılırsa kayıt silinir |
| `...ThisDeviceOnly` eki | Kayıt yedekten başka bir cihaza taşınmaz |

Face ID / parola şartı için `SecAccessControlCreateWithFlags` ile bir `kSecAttrAccessControl` verilir.

Sık karşılaşılan durum kodları: `errSecItemNotFound` (-25300), `errSecDuplicateItem` (-25299), `errSecMissingEntitlement` (-34018, süreçte Keychain yetkisi yok; imzasız test host'larında görülebilir). `SecCopyErrorMessageString` kodu okunur metne çevirir.

İki önemli ayrıntı:

- SecItem fonksiyonları thread-safe ama **senkron ve bloklayıcıdır** (sistem servisine süreçler arası çağrı yaparlar). Sık çağrılan bir yolda değeri bellekte tut.
- Keychain kayıtları uygulama silinse bile genellikle cihazda **kalır** (Apple bunu garanti edilen bir davranış olarak belgelemez). Temiz başlangıç isteyen uygulamalar UserDefaults'ta bir "ilk açılış" bayrağı tutar; bayrak yoksa Keychain'i temizler.

### 5. Dosyalar ve Codable

Küçük-orta veri için en basit kalıcılık: `Codable` → JSON → dosya.

```swift
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
try JSONEncoder().encode(notes).write(to: fileURL, options: [.atomic, .completeFileProtection])
```

- **`.atomic`**: Veri önce geçici bir dosyaya yazılır, sonra tek adımda asıl dosyanın yerine taşınır. Yazma yarıda kesilirse eski dosya sağlam kalır.
- **Dosya koruması (Data Protection)**: `.complete` cihaz kilitliyken dosyayı okunamaz yapar (arka plandaki kod da okuyamaz). Uygulama dosyalarının varsayılanı `completeUntilFirstUserAuthentication`'dır: yeniden başlatmadan sonraki ilk kilit açılışından itibaren okunabilir.
- **Oku → değiştir → yaz** bir işlemdir. İki çağrı aynı anda çalışırsa ikisi de eski listeyi okur ve biri diğerinin değişikliğini ezer (*lost update*). Bu projede `FileNotesRepository` bir **actor**: adımlar sıraya girer.
- Bozuk dosyayı "boş liste" sayma: Sonraki kayıt kullanıcının bütün verisini siler. Hatayı yukarı bildir.

### 6. Core Data

Core Data bir veritabanı değil, bir **nesne grafiği ve kalıcılık çerçevesidir**; genelde altında SQLite vardır.

| Parça | Görevi |
|---|---|
| `NSManagedObjectModel` | Şema: entity'ler ve alanları (`.xcdatamodeld` → derlenince `.momd`) |
| `NSPersistentStoreCoordinator` | Modeli diskteki depoya bağlar |
| `NSManagedObjectContext` | Nesnelerle çalıştığın "karalama defteri"; `save()` deyince depoya gider |
| `NSPersistentContainer` | Bu üçünü kurar; `viewContext` ve `newBackgroundContext()` verir |

**Concurrency kuralları** (mülakatın asıl sorusu):

1. Her context bir **kuyruğa bağlıdır**: `viewContext` ana kuyruğa, `newBackgroundContext()` kendi özel kuyruğuna.
2. Context'e ve getirdiği nesnelere yalnızca `perform { }` / `performAndWait { }` içinde dokunulur.
3. `NSManagedObject` thread'ler arasında taşınmaz. `NSManagedObjectID` taşınır ve diğer context'te `existingObject(with:)` ile yeniden alınır. Daha da basiti: Nesneyi `perform` içinde düz bir struct'a çevirip struct'ı döndürmek.
4. `viewContext.automaticallyMergesChangesFromParent = true`: Arka plandaki kayıtlar ana context'e otomatik yansır.
5. `-com.apple.CoreData.ConcurrencyDebug 1` başlatma argümanı kural ihlalinde uygulamayı hemen durdurur.

```swift
func fetchAll() async throws -> [ReadingNote] {
    let context = self.context
    return try await context.perform {
        let request = NoteEntity.typedFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(NoteEntity.createdAt), ascending: false)]
        return try context.fetch(request).map(\.readingNote)   // dışarı yalnızca struct çıkıyor
    }
}
```

**Swift 6 ile Sendable durumu (Xcode 26 SDK'sında doğrulandı):** `NSPersistentContainer`, `NSManagedObjectContext` ve `NSManagedObjectID` `NS_SWIFT_SENDABLE`; `NSManagedObject` `NS_SWIFT_NONSENDABLE`. Yani context'in **referansını** başka thread'e vermek güvenlidir, çünkü `perform` her yerden çağrılabilir ve işi context'in kendi kuyruğuna koyar. `perform`'un kapanışı `@Sendable`'dır; içine dışarıdan bir `NSManagedObject` sokarsan derleyici uyarır (API `@preconcurrency` olduğu için hata değil **uyarı**; ama hatanın kendisi gerçektir). Ters yön daha da sinsidir: `perform`'un dönüş tipi `Sendable` istemediği için bloktan bir `NSManagedObject` **döndürmek** hiç uyarı vermez (Swift 6.2.4 ile denendi). Derleyici burada seni korumaz; kural "bloktan yalnızca struct ya da `NSManagedObjectID` çıkar". Bu yüzden `CoreDataNotesRepository` bir actor değil, `final class`: Serileştirmeyi zaten context'in kuyruğu yapıyor.

Projede dikkat çeken iki karar:

- **Model süreç başına bir kez yüklenir** (`CoreDataNotesRepository.sharedModel`). Aynı `.momd`'den iki model yüklenirse iki entity açıklaması aynı `NoteEntity` sınıfını sahiplenir ve Core Data "Multiple NSEntityDescriptions claim the NSManagedObject subclass" uyarısı verir. `NSManagedObjectModel` Sendable olmadığı için `nonisolated(unsafe) static let` ile tutuluyor; gerekçe: Model bir coordinator tarafından kullanılmaya başlayınca değiştirilemez hale gelir.
- **Testlerde bellekteki depo** için adres `/dev/null` olan bir SQLite deposu: Diske hiçbir şey yazılmaz ama motor gerçek depoyla aynıdır.

**Migration:** Modeli değiştirince yeni bir **model sürümü** eklersin (Editor → Add Model Version). Basit değişiklikleri (alan ekleme/silme, opsiyonel yapma, varsayılan değerle zorunlu yapma, *renaming identifier* ile yeniden adlandırma) Core Data **lightweight migration** ile kendisi çevirir; `NSPersistentContainer`'da bu varsayılan olarak açıktır (`shouldMigrateStoreAutomatically`, `shouldInferMappingModelAutomatically`). Veriyi dönüştürmek gerekiyorsa özel bir mapping model ya da iOS 17+ **staged migration** (`NSStagedMigrationManager`) gerekir.

Büyük veri için: `NSBatchDeleteRequest` / `NSBatchInsertRequest` doğrudan SQLite üzerinde çalışır ve nesneleri belleğe almaz; ama context'i atladıkları için açık context'lere değişikliği ayrıca bildirmen gerekir. UIKit listeleri için `NSFetchedResultsController` sonuçları izler ve değişiklikleri bildirir.

### 7. SwiftData (iOS 17+)

SwiftData aynı işleri Swift'e özgü bir API ile yapar. Apple'a göre Core Data ile aynı kanıtlanmış depolama altyapısını kullanır ve ikisi aynı depoyu paylaşabilir.

| SwiftData | Core Data karşılığı |
|---|---|
| `@Model final class NoteRecord` | `NSManagedObject` alt sınıfı + `.xcdatamodeld` entity'si |
| `ModelContainer(for: NoteRecord.self, configurations: ...)` | `NSPersistentContainer` |
| `ModelContext` | `NSManagedObjectContext` |
| `FetchDescriptor` + `#Predicate { $0.noteID == id }` | `NSFetchRequest` + `NSPredicate` (metin) |
| `@Query` (SwiftUI) | `@FetchRequest` / `NSFetchedResultsController` |
| `@ModelActor` | arka plan context'i + `perform` |
| `VersionedSchema` + `SchemaMigrationPlan` | model sürümleri + mapping |

- `@Model` yalnızca class'lara uygulanır: Bir context aynı kaydı tek bir nesneyle temsil eder; kimlik gerekir. Makro sınıfı `PersistentModel` ve `Observable` yapar.
- `ModelContext` ve `@Model` nesneleri **Sendable değildir**. Arka plan işi için **`@ModelActor`**: Makro actor'e kendi `ModelContext`'ini ve o context'in **seri executor'ını** verir; actor'ün metotları zaten doğru "kuyrukta" çalışır, `perform` yazmaya gerek kalmaz. Actor'ler arasında nesne değil `persistentModelID` (`PersistentIdentifier`, Sendable) taşınır.
- `@Attribute(.unique)`: Aynı değerle ikinci kayıt eklenirse SwiftData yenisini eklemek yerine mevcut kaydı günceller (upsert).
- `ModelContext`'in `autosaveEnabled` özelliği açıkken SwiftData değişiklikleri belirli anlarda kendisi de kaydeder, ama ne zaman kaydedeceği garanti değildir. "Kaydet döndü = depoda" sözleşmesi istiyorsan `try modelContext.save()` çağır.
- Bellekte depo: `ModelConfiguration(isStoredInMemoryOnly: true)`.

```swift
@ModelActor
actor SwiftDataNotesRepository: NotesRepository {
    func fetchAll() throws -> [ReadingNote] {
        let descriptor = FetchDescriptor<NoteRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.readingNote)
    }
}
```

**Hangisi?** Yeni ve iOS 17+ bir projede SwiftData çok daha az kod ister. Core Data daha olgundur: `NSFetchedResultsController`, batch istekleri, ayrıntılı migration seçenekleri, iOS 16 ve öncesi. Büyük ve eski bir kod tabanında Core Data'dan çıkmak için bir neden yoksa kalmak mantıklıdır. Bu projede `NotesStorageKind.appDefault = .swiftData`; gerekçesi `NotesRepositoryFactory.swift`'te yazıyor.

### 8. Önbellekler ve iCloud

- **`NSCache`**: Bellekte anahtar-değer önbelleği. Thread-safe; bellek azalınca öğeleri kendisi atar (`countLimit`/`totalCostLimit` kesin sınır değildir). Anahtarları kopyalamaz.
- **`URLCache`**: HTTP yanıtlarını bellek ve diskte tutar; `URLSession` kullanır ve `Cache-Control` başlıklarına uyar.
- **Caches klasörü**: Yeniden indirilebilen dosyalar; yedeğe girmez ve sistem silebilir.
- **`NSUbiquitousKeyValueStore`**: Küçük ayarları kullanıcının cihazları arasında eşitler (toplam 1 MB, en fazla 1024 anahtar).
- **CloudKit**: Kullanıcının iCloud'unda kayıtlar. Core Data `NSPersistentCloudKitContainer`, SwiftData `ModelConfiguration(cloudKitDatabase:)` ile eşitlenir. Şema üretime gönderildikten sonra yalnızca eklenebilir: alan silinmez, yeniden adlandırılmaz.

### 9. Hepsini bir protokolün arkasına saklamak

Bu projede beş depolama türü de aynı sözleşmeye uyar:

```swift
protocol NotesRepository: Sendable {
    func fetchAll() async throws -> [ReadingNote]     // en yeni en başta
    func save(_ note: ReadingNote) async throws       // upsert
    func delete(id: ReadingNote.ID) async throws      // idempotent
    func deleteAll() async throws
}
```

- Kayıt tipleri (`NoteEntity`, `NoteRecord`) Data katmanından hiç çıkmaz; sınırda `ReadingNote` struct'ına çevrilir (*mapping*). Üst katmanlar Core Data'yı ya da SwiftData'yı bilmez.
- `NotesRepositoryFactory.make(_:location:)` hangi sınıfın, hangi konumla oluşturulacağına karar verir. Depo açılamazsa çökmek ya da sessizce belleğe geçmek yerine hatayı taşıyan `UnavailableNotesRepository` döner.
- **Sözleşme testi** (`NotesRepositoryContractTests`): Aynı test rutini yedi kurulumda koşar (bellek, UserDefaults, dosya, Core Data bellek/SQLite, SwiftData bellek/dosya). Bu, **Liskov yerine geçme ilkesinin** testidir: Protokolün belgesinde yazan ama derleyicinin denetleyemediği kuralları ("en yeni en başta", "upsert", "silmek idempotent", "yeni örnek eski veriyi görür") her uygulama için doğrular.
- **`PersistenceLocation`**: Verinin nereye yazılacağı (klasör, UserDefaults suite'i, Keychain service'i) dışarıdan verilir. Birim testleri her test için geçici bir konum kullanır; UI testleri (`-ui-testing`) her açılışta silinen ayrı bir konum kullanır. Böylece bir UI testinde değiştirilen okuma hızı, "okuma süresi 18 sa 6 dk" bekleyen başka bir testi bozmaz.

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Gösterdiği kavram |
|---|---|---|
| [NotesRepository.swift](../BookShelf/Features/ReadingNotes/Domain/Repositories/NotesRepository.swift) | `NotesRepository` | Tek sözleşme; Dependency Inversion |
| [NotesRepositoryFactory.swift](../BookShelf/Features/ReadingNotes/Data/NotesRepositoryFactory.swift) | `NotesStorageKind.appDefault`, `NotesRepositoryFactory.make(_:location:)` | Factory, varsayılan depo kararı, hata durumunda yedek |
| [PersistenceLocation.swift](../BookShelf/Features/ReadingNotes/Data/PersistenceLocation.swift) | `PersistenceLocation.current`, `isolated(name:)` | Konumu enjekte etmek; UI testlerinde açılışta bir kez sıfırlama |
| [UserDefaultsNotesRepository.swift](../BookShelf/Features/ReadingNotes/Data/UserDefaultsNotesRepository.swift) | `UserDefaultsNotesRepository` | UserDefaults neden büyüyen veri için uygun değil; actor ile lost update'i önlemek |
| [FileNotesRepository.swift](../BookShelf/Features/ReadingNotes/Data/FileNotesRepository.swift) | `FileNotesRepository.write(_:)` | Klasör oluşturma, `.atomic`, `.completeFileProtection` |
| [NotesModel.xcdatamodeld](../BookShelf/Features/ReadingNotes/Data/CoreData/NotesModel.xcdatamodeld) | `NoteEntity` entity'si | Model dosyası, fetch index |
| [NoteEntity.swift](../BookShelf/Features/ReadingNotes/Data/CoreData/NoteEntity.swift) | `NoteEntity` | `@NSManaged`, `@objc(...)`, `NSNumber?` ile opsiyonel sayı |
| [CoreDataNotesRepository.swift](../BookShelf/Features/ReadingNotes/Data/CoreData/CoreDataNotesRepository.swift) | `CoreDataNotesRepository`, `sharedModel` | `perform`, mapping, `/dev/null` deposu, lightweight migration seçenekleri |
| [NoteRecord.swift](../BookShelf/Features/ReadingNotes/Data/SwiftData/NoteRecord.swift) | `NoteRecord` | `@Model`, `@Attribute(.unique)` |
| [SwiftDataNotesRepository.swift](../BookShelf/Features/ReadingNotes/Data/SwiftData/SwiftDataNotesRepository.swift) | `SwiftDataNotesRepository` | `@ModelActor`, `#Predicate`, delegating initializer |
| [UnavailableNotesRepository.swift](../BookShelf/Features/ReadingNotes/Data/UnavailableNotesRepository.swift) | `UnavailableNotesRepository` | Depo açılamazsa hatayı ekrana kadar taşımak |
| [KeychainStore.swift](../BookShelf/Features/Interview/Demos/Persistence/KeychainStore.swift) | `KeychainStore` | SecItem API, `kSecAttrAccessible` seçimi |
| [PersistenceSettingsSections.swift](../BookShelf/Features/Interview/Demos/Persistence/PersistenceSettingsSections.swift) | `PersistenceSettingsSections`, `DemoToken` | `@AppStorage(store:)`, Keychain demosu, sırrı maskelemek |
| [BookDetailViewModel.swift](../BookShelf/Features/BookDetail/BookDetailViewModel.swift) | `readingSpeedKey`, `readingSpeed(in:)` | Ayarı okuyan taraf; view model'e değer olarak enjekte edilir |
| [NotesStorageInspector.swift](../BookShelf/Features/Interview/Demos/Persistence/NotesStorageInspector.swift) | `NotesStorageInspector` | Beş depoyu aynı arayüzle kullanmak; "yeni örnekle yeniden aç" |
| [StorageComparison.swift](../BookShelf/Features/Interview/Demos/Persistence/StorageComparison.swift) | `StorageComparisonItem.all` | Karşılaştırma tablosu |
| [NotesRepositoryContractTests.swift](../BookShelfTests/Persistence/NotesRepositoryContractTests.swift) | `assertHonorsContract(...)` | Tek test rutini, yedi kurulum: Liskov |
| [PersistenceFailureTests.swift](../BookShelfTests/Persistence/PersistenceFailureTests.swift) | `PersistenceFailureTests` | Bozuk veri sessizce "boş" sayılmıyor |
| [KeychainStoreTests.swift](../BookShelfTests/Persistence/KeychainStoreTests.swift) | `KeychainStoreTests` | Gerçek Keychain'e karşı test; `XCTSkip` ile ortam sorunu |
| [PersistenceUITests.swift](../BookShelfUITests/PersistenceUITests.swift) | `PersistenceUITests` | Kalıcılığı UI'dan doğrulamak; UI testlerinde durum bağımsızlığı |

## Sık yapılan hatalar

**1. Sırrı UserDefaults'a yazmak.**

```swift
// YANLIŞ: Düz bir plist; şifresiz bir yedekten okunabilir.
UserDefaults.standard.set(token, forKey: "accessToken")

// DOĞRU
try KeychainStore(service: Bundle.main.bundleIdentifier!).save(token, account: "accessToken")
```

**2. Büyüyen listeyi UserDefaults'ta tutmak.**

```swift
// YANLIŞ: Her eklemede bütün dizi kodlanır ve bütün plist yeniden yazılır.
var notes = try JSONDecoder().decode([ReadingNote].self, from: defaults.data(forKey: "notes") ?? Data("[]".utf8))
notes.append(newNote)
defaults.set(try JSONEncoder().encode(notes), forKey: "notes")

// DOĞRU: Veritabanı (Core Data / SwiftData) ya da en azından ayrı bir dosya.
try await repository.save(newNote)
```

**3. `NSManagedObject`'i `perform`'un dışına taşımak.**

```swift
// YANLIŞ: Nesne arka plan context'inin; ana thread'de okumak tanımsız davranış.
let entities = try await context.perform { try context.fetch(request) }
titleLabel.text = entities.first?.text

// DOĞRU: perform içinde struct'a çevir.
let notes = try await context.perform { try context.fetch(request).map(\.readingNote) }
titleLabel.text = notes.first?.text
```

**4. Atomik yazmamak ve bozuk dosyayı "boş" saymak.**

```swift
// YANLIŞ: Yarıda kalan yazım dosyayı bozar; bozuk dosya boş sayılır, sonraki kayıt her şeyi siler.
try data.write(to: url)
let notes = (try? JSONDecoder().decode([ReadingNote].self, from: Data(contentsOf: url))) ?? []

// DOĞRU
try data.write(to: url, options: [.atomic, .completeFileProtection])
do { notes = try JSONDecoder().decode([ReadingNote].self, from: Data(contentsOf: url)) }
catch { throw NotesRepositoryError.storageFailure(reason: error.localizedDescription) }
```

**5. Testlerde gerçek depoyu kullanmak.**

```swift
// YANLIŞ: Testler UserDefaults.standard'a yazar, birbirini ve geliştiricinin ayarlarını kirletir.
let repository = UserDefaultsNotesRepository(defaults: .standard)

// DOĞRU: Her test kendi yalıtılmış konumunu kullanır ve sonunda siler.
let location = PersistenceLocation.isolated(name: "Test-\(UUID().uuidString)")
let repository = UserDefaultsNotesRepository(defaults: location.defaults)
// tearDown: location.erase()
```

**6. Aynı Core Data modelini her container için yeniden yüklemek.**

```swift
// YANLIŞ: Her çağrıda yeni bir NSManagedObjectModel → "Multiple NSEntityDescriptions claim..." uyarısı.
let container = NSPersistentContainer(name: "NotesModel")

// DOĞRU: Modeli bir kez yükle, her container'a aynısını ver.
let container = NSPersistentContainer(name: "NotesModel", managedObjectModel: CoreDataNotesRepository.sharedModel)
```

## Mülakatta sorulabilecekler

**1. iOS'ta veri saklama yolları nelerdir, hangisini ne zaman seçersin?**
Küçük tercihler UserDefaults'a, sırlar Keychain'e, belgeler ve basit Codable listeler Application Support'taki dosyalara, büyüyen/ilişkili/sorgulanan veri Core Data ya da SwiftData'ya (SQL gerekirse SQLite/GRDB), yeniden üretilebilen veri NSCache, URLCache ya da Caches klasörüne. Önce verinin türüne, sonra boyutuna bakarım.

**2. UserDefaults'a neden token ya da büyük veri koymayız?**
Tek bir plist dosyasıdır: bütünüyle önbelleğe alınır ve değişince bütünüyle yeniden yazılır; sorgu yoktur. Kendine ait şifrelemesi yoktur, şifresiz bir yedekten okunabilir. Sırlar Keychain'e gider: ayrı, şifreli bir veritabanı; ne zaman okunabileceği ve Face ID şartı seçilebilir.

**3. Keychain'de `kSecAttrAccessible` neyi belirler?**
Kaydın hangi durumda okunabileceğini: `WhenUnlocked` (varsayılan) yalnızca cihaz açıkken, `AfterFirstUnlock` yeniden başlatmadan sonraki ilk kilit açılışından itibaren (arka plan işleri için). `ThisDeviceOnly` eki kaydın yedekle başka cihaza taşınmasını engeller.

**4. Core Data'da thread güvenliği nasıl sağlanır?**
Her context bir kuyruğa bağlıdır; ona ve nesnelerine yalnızca `perform` içinde dokunulur. `NSManagedObject` taşınmaz; `NSManagedObjectID` taşınır ya da nesne struct'a çevrilir. Ana context'in arka plandaki kayıtları görmesi için `automaticallyMergesChangesFromParent`. İhlalleri yakalamak için `-com.apple.CoreData.ConcurrencyDebug 1`.

**5. Lightweight migration nedir?**
Yeni model sürümünde Core Data'nın eşlemeyi kendisinin çıkardığı otomatik dönüşüm: alan ekleme/silme, opsiyonel yapma, varsayılan değerle zorunlu yapma, renaming identifier ile yeniden adlandırma. Veri dönüştürmek gerekiyorsa mapping model ya da staged migration (iOS 17+). SwiftData'da `VersionedSchema` + `SchemaMigrationPlan`.

**6. SwiftData mı Core Data mı?**
iOS 17+ yeni projede SwiftData: `@Model`, `#Predicate`, `@Query`, `@ModelActor` ile çok daha az kod. Core Data daha olgun ve esnek: `NSFetchedResultsController`, batch istekleri, ayrıntılı migration, eski iOS. İkisi aynı depoyu paylaşabildiği için kademeli geçiş mümkün.

**7. `@ModelActor` ne işe yarar?**
Actor'e kendi `ModelContext`'ini ve o context'in seri executor'ını verir. `ModelContext` Sendable değildir; bu sayede arka planda, doğru sırada ve derleyici denetimiyle kullanılır. Actor'ler arasında `@Model` nesnesi değil `PersistentIdentifier` taşınır.

**8. Kalıcılık kodunu nasıl test edersin?**
Depoyu bir protokolün arkasına alırım ve konumu (suite adı, klasör) enjekte ederim. Her test kendi geçici konumunu kullanır, sonunda siler. Bütün uygulamalar aynı sözleşme testinden geçer (Liskov). Core Data için `/dev/null` deposu, SwiftData için `isStoredInMemoryOnly`. UI testlerinde uygulama bir başlatma argümanıyla açılışta sıfırlanan ayrı bir konuma yazar.

**9. Uygulama silinince Keychain'deki veri de silinir mi?**
Genellikle hayır; kayıtlar cihazda kalır (Apple garanti edilen bir davranış olarak belgelemez). Temiz başlangıç için UserDefaults'ta "ilk açılış" bayrağı tutulur, bayrak yoksa Keychain temizlenir.

## Alıştırmalar

**1. Kitaba göre notlar.**
`NotesRepository`'ye `fetchAll(bookID: Book.ID) async throws -> [ReadingNote]` ekle ve beş uygulamada da yaz. Core Data'da `NSPredicate`, SwiftData'da `#Predicate` kullan; UserDefaults ve dosyada bellekte filtrele. Sözleşme testine bu kuralı da ekle.
*İpucu:* Core Data'da `bookID` `NSNumber?` olarak saklanıyor: `NSPredicate(format: "%K == %@", #keyPath(NoteEntity.bookID), NSNumber(value: bookID))`. Yeni gereksinimi protokole ekleyince derleyici hangi uygulamaların eksik olduğunu tek tek gösterecek.

**2. İlk Core Data migration'ın.**
`NotesModel.xcdatamodeld`'ye yeni bir sürüm ekle (Editor → Add Model Version), yeni sürümü güncel (current) yap ve `NoteEntity`'ye opsiyonel `pageNumber` (Integer 64) alanı ekle. Eski sürümle bir SQLite deposu oluşturup yeni modelle açan bir test yaz.
*İpucu:* Opsiyonel alan eklemek lightweight migration'ın otomatik çevirdiği bir değişikliktir; `shouldInferMappingModelAutomatically` zaten açık. Testte eski depoyu üretmek için o sürümün `.mom` dosyasını `.momd` paketinin içinden yükleyebilirsin.

**3. Keychain'e Face ID şartı.**
`KeychainStore.save`'e isteğe bağlı bir `requiresBiometry: Bool` parametresi ekle; `true` ise `SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, nil)` ile oluşturulan değeri `kSecAttrAccessControl` olarak ver. Simülatörde Features → Face ID → Enrolled ile dene.
*İpucu:* `kSecAttrAccessControl` ile `kSecAttrAccessible` aynı sorguda birlikte verilmez; erişilebilirlik sınıfı zaten access control'ün içinde. Okurken sistem kimlik doğrulama penceresini kendisi gösterir. Face ID için Info.plist'te `NSFaceIDUsageDescription` gerekir (bu projede build ayarı: `INFOPLIST_KEY_NSFaceIDUsageDescription`).
