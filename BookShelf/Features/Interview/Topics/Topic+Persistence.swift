import SwiftUI

// Mülakat sorusu: "iOS'ta veriyi nerede saklarsın?" Ders: docs/14-kalicilik.md
extension InterviewTopic {
    static let persistence = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.persistence,
        section: .data,
        question: "iOS'ta veri saklama yolları nelerdir? (UserDefaults, Keychain, dosya, Core Data, SwiftData)",
        shortAnswer: [
            "Seçimi verinin türü belirler. Küçük tercihler (tema, okuma hızı) → UserDefaults. Sırlar (token, parola) → Keychain; UserDefaults kendine ait şifrelemesi olmayan bir plist dosyasıdır.",
            "Belgeler, görseller ve basit Codable listeler → Application Support'ta dosya; atomik yazma ve dosya koruması (Data Protection) ile.",
            "Büyüyen, ilişkili, sorgulanan veri → Core Data ya da SwiftData (iOS 17+). SQL'e tam hakimiyet gerekirse SQLite (ör. GRDB).",
            "Yeniden üretilebilen veri → önbellek: bellekte NSCache, HTTP için URLCache, dosyalar için Caches klasörü (sistem silebilir, yedeğe girmez).",
            "Core Data'da her context bir kuyruğa bağlıdır: Her erişim perform içinde olur; thread'ler arasında NSManagedObject değil NSManagedObjectID ya da düz bir struct taşınır.",
            "Şema değişince migration gerekir: Basit değişikliklerde lightweight migration yeter. Bu projede hepsi tek bir NotesRepository protokolünün arkasında; depolama değişse de ekranlar değişmiyor.",
        ],
        followUps: [
            FollowUp(
                question: "Token'ı ya da büyüyen bir listeyi neden UserDefaults'a koymayız?",
                answer: "UserDefaults tek bir plist dosyasıdır: İlk erişimde tamamı belleğe alınır ve her değişiklikte tamamı yeniden yazılır; büyüdükçe bellek ve açılış maliyeti artar, sorgu da yoktur. Kendine ait şifrelemesi yoktur; şifresiz bir yedekten ya da jailbreak'li cihazdan okunabilir. Sırlar ayrı ve şifreli bir veritabanı olan Keychain'e yazılır; orada ne zaman okunabileceği (kSecAttrAccessible) ve Face ID şartı seçilebilir. (Thread güvenliği sorun değil: Apple UserDefaults'u thread-safe olarak belgeler, synchronize() artık gereksizdir; ama Xcode 26 SDK'sında Sendable değildir.)"
            ),
            FollowUp(
                question: "Core Data'da thread güvenliğini nasıl sağlarsın?",
                answer: "viewContext ana kuyruğa, newBackgroundContext() kendi özel kuyruğuna bağlıdır. Context'e ve getirdiği nesnelere yalnızca perform { } / performAndWait { } içinde dokunulur. NSManagedObject Sendable değildir; başka context'e NSManagedObjectID verilir ve orada existingObject(with:) ile yeniden alınır. Ana context'in arka plandaki kayıtları görmesi için automaticallyMergesChangesFromParent = true. Hataları yakalamak için -com.apple.CoreData.ConcurrencyDebug 1 başlatma argümanı kullanılır."
            ),
            FollowUp(
                question: "Lightweight migration nedir, ne zaman yetmez?",
                answer: "Modele yeni bir sürüm eklediğinde Core Data eski ve yeni şema arasındaki eşlemeyi kendisi çıkarır: entity/alan ekleme veya silme, alanı opsiyonel yapma, varsayılan değer vererek zorunlu yapma, renaming identifier ile yeniden adlandırma. NSPersistentContainer'da bu varsayılan olarak açıktır. Veriyi dönüştürmek gerekiyorsa (ör. tek alanı ikiye bölmek) özel bir mapping model ya da iOS 17+ staged migration gerekir. SwiftData'da karşılığı VersionedSchema + SchemaMigrationPlan."
            ),
            FollowUp(
                question: "SwiftData mı, Core Data mı?",
                answer: "SwiftData iOS 17+ ve çok daha az kod ister: @Model, #Predicate, SwiftUI'da @Query, arka plan için @ModelActor. Apple'a göre Core Data ile aynı kanıtlanmış depolama altyapısını kullanır ve ikisi aynı depoyu paylaşabilir. Core Data daha olgun: NSFetchedResultsController, batch istekleri, ayrıntılı migration, eski iOS desteği. Yeni ve iOS 17+ bir projede SwiftData, büyük ve eski bir kod tabanında Core Data mantıklı."
            ),
            FollowUp(
                question: "Uygulama silinince Keychain'deki veri de silinir mi?",
                answer: "Genellikle hayır: Keychain kayıtları uygulama silindikten sonra da cihazda kalır (Apple bunu garanti edilen bir davranış olarak belgelemez). Temiz başlangıç isteyen uygulamalar, uygulamayla birlikte silinen UserDefaults'ta bir \"ilk açılış\" bayrağı tutar ve bayrak yoksa Keychain'i temizler."
            ),
        ],
        pitfalls: [
            "NSManagedObject'i perform bloğunun dışına ya da başka bir thread'e taşımak. Derleyici her durumu yakalamaz: perform'a dışarıdan nesne sokmak (API @preconcurrency olduğu için) yalnızca uyarıdır, bloktan nesne döndürmek hiç uyarı vermez. Sonuç çalışma anında rastgele çökme ve bozuk veri. Sınırda struct'a çevir ya da NSManagedObjectID taşı.",
            "Token, parola gibi sırları UserDefaults'a ya da düz bir dosyaya yazmak.",
            "Büyüyen bir listeyi UserDefaults'ta tutmak: Her eklemede bütün dizi kodlanıp bütün plist yeniden yazılır.",
            "Dosyayı atomik yazmamak (yarıda kalan yazım dosyayı bozar), Application Support klasörünü oluşturmayı unutmak ve bozuk dosyayı \"boş\" sayıp üzerine yazmak.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Data/UserDefaultsNotesRepository.swift",
                symbol: "UserDefaultsNotesRepository",
                note: "Her save'de TÜM dizi kodlanıp yazılıyor: UserDefaults'un neden büyüyen veri için uygun olmadığını kodda gör."
            ),
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Data/FileNotesRepository.swift",
                symbol: "FileNotesRepository.write(_:)",
                note: "Klasörü oluştur, sonra .atomic + .completeFileProtection ile yaz; bozuk dosyayı boş saymak yerine hata fırlat."
            ),
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Data/CoreData/CoreDataNotesRepository.swift",
                symbol: "CoreDataNotesRepository",
                note: "Her erişim context.perform içinde; NoteEntity bloğun dışına çıkmıyor, ReadingNote'a çevriliyor. sharedModel neden tek?"
            ),
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Data/SwiftData/SwiftDataNotesRepository.swift",
                symbol: "SwiftDataNotesRepository",
                note: "@ModelActor: actor'ün executor'ı ModelContext'in seri kuyruğu, perform yazmaya gerek yok. @Model dışarı çıkmıyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/Persistence/KeychainStore.swift",
                symbol: "KeychainStore.save(_:account:)",
                note: "Önce SecItemUpdate, kayıt yoksa SecItemAdd; kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly seçiminin gerekçesi."
            ),
            CodePointer(
                file: "BookShelfTests/Persistence/NotesRepositoryContractTests.swift",
                symbol: "NotesRepositoryContractTests",
                note: "Aynı sözleşme testi beş uygulamada koşuyor: Liskov yerine geçme ilkesinin testi. Testler yalıtılmış konum kullanıyor."
            ),
        ],
        demo: { _ in AnyView(PersistenceDemoView()) }
    )
}
