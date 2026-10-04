# Concurrency, async/await ve Actor'ler

> Bu projenin çekirdek dersi. Kod örnekleri Swift 6 dil modu ve iOS 17+ içindir. Bu projede derleyici Swift 6.2'dir,
> ama **Approachable Concurrency** ve **Default Actor Isolation = MainActor** ayarları bilerek **kapalıdır**
> (neden kapalı olduğu ve açılsaydı ne değişeceği en sondaki bölümde).
> Anlatılanları uygulamanın **Laboratuvar** sekmesinde dokunarak deneyebilirsin.
> Önce [05 – async/await](05-async-await.md) dersini okuman önerilir; bu ders onun üzerine kurulur.

## Neden önemli?

- **Arayüz ana thread'de çizilir.** Ekran saniyede 60–120 kez yenilenir; ana thread'i birkaç yüz milisaniye meşgul
  eden bir dosya okuma ya da JSON çözümleme, uygulamanın "donması" demektir. İşi ana thread'den alıp sonucu güvenle
  geri getirmek her iOS uygulamasının temel ihtiyacıdır.
- **Data race'ler en sinsi hatalardır.** Çoğu zaman görünmezler, sonra bir gün müşterinin cihazında bozuk veri ya da
  çökme olarak ortaya çıkarlar. Swift 6 dil modu data race ihtimali olan kodu **derleme hatası** yapar; bu yüzden
  modern Swift yazmak için kuralları bilmek zorundasın.
- **Mülakatların favori konusudur.** `async let` vs `TaskGroup`, `Task` vs `Task.detached`, actor reentrancy,
  `Sendable`, `@MainActor`, iptal… Hepsi kısa sorularla ölçülebilen ve "gerçekten anlamış mı?" sorusuna cevap veren konular.

## Temel kavramlar

### 1. Thread ve Task

**Thread**, işletim sisteminin yönettiği bir yürütme hattıdır. Oluşturması ve thread'ler arasında geçiş yapması
(context switch) pahalıdır; her birinin kendi yığını (stack) vardır. GCD döneminde çok sayıda iş kuyruğa atıldığında
sistem yüzlerce thread açabiliyordu (*thread explosion*).

**Task** ise Swift çalışma zamanının (runtime) hafif iş birimidir. Task'lar, Swift'in **kooperatif thread havuzunda**
(cooperative thread pool) çalışır. Bu havuzda genellikle **CPU çekirdeği sayısı kadar** thread vardır:

- Bir task `await` noktasında **askıya alınır** (suspend). Kalan işi (continuation) bellekte saklanır ve thread
  hemen başka bir task'ı çalıştırmaya döner. Thread asla "boşta bekleyerek" tutulmaz.
- Task devam ettiğinde (resume) **başka bir thread'de** kalkabilir. (İstisna: ana actor'e bağlı kod her zaman ana
  thread'de çalışır.)
- "Kooperatif" demek, herkesin kurallara uyması demektir: **havuzdaki bir thread'i asla bloklama.**
  `DispatchSemaphore.wait()`, `Thread.sleep`, bir task'ın sonucunu senkron beklemek gibi işler az sayıdaki thread'i
  kilitler; tüm thread'ler bloklanırsa hiçbir task ilerleyemez.

```swift
// Thread'i 1 saniye BLOKLAR: bu sırada o thread başka hiçbir iş yapamaz.
Thread.sleep(forTimeInterval: 1)

// Task'ı 1 saniye ASKIYA ALIR: thread serbest kalır, başka task'lar çalışır.
try await Task.sleep(for: .seconds(1))
```

### 2. async / await

- `async` bir fonksiyon **askıya alınabilir**. `await` ise olası askıya alınma noktalarını işaretler: "Burada
  bekleyebilirim; bu sırada dünya değişebilir."
- `async` yazmak kendi başına **hiçbir şeyi paralel yapmaz**. Aşağıdaki döngü üç işi sırayla bekler; toplam süre
  sürelerin toplamıdır (Laboratuvar'daki "Sıralı" deneyi):

```swift
for job in jobs {
    results.append(try await job.run()) // bir sonraki işe ancak bu bitince geçilir
}
```

- Bir `async` fonksiyonun **nerede** çalıştığını izolasyonu belirler: bir actor'e izole ise o actor'de; hiçbir
  actor'e bağlı değilse (*nonisolated*) bu projenin ayarlarında **global concurrent executor**'de (arka plandaki
  havuzda). Swift 6.2'deki yeni seçenekleri 12. başlıkta göreceğiz.

### 3. Yapısal concurrency (structured concurrency)

Yapısal concurrency'de her task bir **ebeveyn-çocuk ağacının** parçasıdır; tıpkı değişkenlerin bir kapsamda
(scope) yaşaması gibi:

- Child task'lar ebeveynlerinin kapsamından **daha uzun yaşayamaz**; kapsamdan çıkmadan önce hepsi biter.
- **İptal aşağı doğru yayılır**: ebeveyn iptal edilirse tüm çocuklar da iptal edilir.
- **Hatalar yukarı doğru yayılır**: bir çocuğun hatası ebeveyne ulaşır, kardeşler iptal edilir.
- Öncelik (priority) ve task-local değerler çocuklara miras kalır.

**`async let`**: Sayısı derleme anında belli olan işler için.

```swift
async let first = jobs.first.run()   // child task HEMEN başlar, satır beklemez
async let second = jobs.second.run()
async let third = jobs.third.run()
let results = try await [first, second, third] // toplam süre ≈ en yavaş iş
```

Hiç `await` edilmeyen bir `async let` kapsam sonunda **otomatik iptal edilir ve beklenir**; "arka planda çalışmaya
devam eden unutulmuş iş" diye bir şey yoktur.

**Task group**: Sayısı çalışma anında belli olan işler için. Sonuçlar **bitiş sırasıyla** gelir; sıra önemliyse
her sonucu kendi indeksiyle döndürüp yerine koyarsın:

```swift
let ordered = try await withThrowingTaskGroup(of: (Int, JobResult).self) { group in
    for (index, job) in jobs.enumerated() {
        group.addTask { (index, try await job.run()) } // closure @Sendable: sadece Sendable değerler yakalanır
    }
    var slots = [JobResult?](repeating: nil, count: jobs.count)
    for try await (index, result) in group {           // bitiş sırasıyla gelir
        slots[index] = result
    }
    return slots.compactMap { $0 }                      // gönderilme sırasıyla
}
```

- Hata fırlatabilen çocuklar için `withThrowingTaskGroup`, fırlatmayanlar için `withTaskGroup`.
- Çocuklar sonuç döndürmüyorsa `withDiscardingTaskGroup` (iOS 17+): biten çocuğun kaynaklarını hemen bırakır.
- Binlerce öğe için binlerce çocuk açmak yerine eşzamanlılığı sınırla: önce N çocuk başlat, her biri bittiğinde
  bir yenisini ekle (Alıştırma 2).

### 4. Yapısal olmayan task'lar: `Task { }` ve `Task.detached { }`

Senkron bir yerden (düğme aksiyonu, delegate callback) async bir iş başlatmak ya da işin ömrünü bir kapsamdan
bağımsız tutmak gerektiğinde yapısal olmayan (unstructured) task açılır.

| | `Task { }` | `Task.detached { }` |
|---|---|---|
| Actor izolasyonunu miras alır mı? | **Evet** (`@MainActor` bir yerden açılırsa closure ana actor'de çalışır) | Hayır |
| Önceliği miras alır mı? | Evet | Hayır |
| Task-local değerleri miras alır mı? | Evet | Hayır |
| Bir ebeveynin iptali ona yayılır mı? | Hayır (ebeveyni yok) | Hayır |

- İkisi de bir **handle** (`Task<Success, Failure>`) döndürür. `handle.cancel()` ile iptal, `await handle.value`
  ile sonuç alınır. Handle'ı bir kenara atmak task'ı **iptal etmez**.
- `Task.detached` nadiren gerekir. "Arka planda çalışsın" diye kullanmak yanlış bir refleks: ağır işi nonisolated
  (ya da Swift 6.2'de `@concurrent`) bir `async` fonksiyona koymak daha temizdir.
- SwiftUI'da `.task { }` modifier'ı, view ekrandan kalkınca task'ı **otomatik iptal eder**; ekrana bağlı yüklemeler
  için genellikle en doğru seçimdir.

### 5. `Sendable`

Farklı izolasyon alanları (task'lar, actor'ler, ana actor) arasında geçen her değer **`Sendable`** olmalıdır:
"Bu değeri başka bir eşzamanlı bağlama vermek data race yaratmaz." Swift 6 bunu **derleme anında** denetler.

- **Değer tipleri** (`struct`, `enum`): tüm alanları `Sendable` ise `Sendable` olabilir. Modül içi (public olmayan)
  tiplerde bu otomatik çıkarılır; `Book` gibi tiplerde açıkça yazmak niyeti belgeler.
- **Actor'ler** ve **`@MainActor` sınıflar** her zaman `Sendable`'dır; durumlarını izolasyon korur.
- **`final class`** ve tüm alanları `let` + `Sendable` ise derleyici `Sendable` uygunluğunu kendisi doğrular
  (`ConcurrencyLab.LockedCounter`: tek alanı bir kilit).
- **`@unchecked Sendable`**: "Denetleme, bana güven." Sadece durumu gerçekten koruyan (kilit, atomik) ama derleyicinin
  bunu göremediği tipler içindir. `ConcurrencyLab.UnsafeCounter` bunun **kötüye kullanımını** bilerek gösterir.
- **`@Sendable` closure**: eşzamanlı çalışabilecek closure'lar (ör. `group.addTask`) yalnızca `Sendable` değerleri
  yakalayabilir; değiştirilebilir yerel `var`'ları ise hiç yakalayamaz.
- Swift 6'nın **bölge tabanlı izolasyonu** (region-based isolation) ve `sending` anahtar kelimesi sayesinde,
  `Sendable` olmayan bir değer, gönderildikten sonra gönderen tarafta **bir daha kullanılmıyorsa** sınırı geçebilir.

### 6. Actor'ler ve izolasyon

**Actor**, kendi değiştirilebilir durumunu koruyan bir referans tipidir. Durumuna aynı anda **yalnızca bir** görev
erişebilir; içeride sırayla işlenen bir "posta kutusu" (serial executor) varmış gibi düşünebilirsin.

```swift
actor FavoritesStore {
    private var favoriteIDs: Set<Book.ID> = []

    func toggle(_ id: Book.ID) -> Bool {   // actor içinde: senkron, await yok
        if favoriteIDs.contains(id) { favoriteIDs.remove(id) } else { favoriteIDs.insert(id) }
        return favoriteIDs.contains(id)
    }
}

let isFavorite = await store.toggle(7)     // dışarıdan: await ("sıra bana gelene kadar bekleyebilirim")
```

- Actor içindeki kod kendi durumuna `await` olmadan erişir. Dışarıdan her erişim `await` ister.
- `nonisolated` işaretli bir actor üyesi izolasyon dışında çalışır: `await` gerektirmez ama değiştirilebilir izole
  duruma da erişemez (sabit `let` değerlerle ya da hesaplamalarla çalışabilir).
- Actor'ler **FIFO garantisi vermez**; bekleyen işleri önceliğe göre çalıştırabilir. Sıra önemliyse tek bir task
  içinde sırayla çalış ya da bir `AsyncStream` kullan.

### 7. `@MainActor` ve global actor'ler

**Global actor**, programın her yerinden erişilebilen tek bir actor örneğidir. En önemlisi **`@MainActor`**: ana
thread'i temsil eder. Bir tipi, fonksiyonu ya da closure'ı `@MainActor` ile işaretlemek "bu kod ana thread'de
çalışır" demektir ve derleyici bunu **denetler**.

```swift
@MainActor @Observable
final class ConcurrencyLabViewModel {
    private(set) var parallelismReports: [ConcurrencyLab.ParallelismStrategy: ConcurrencyLab.ParallelismReport] = [:]

    func runParallelism(_ strategy: ConcurrencyLab.ParallelismStrategy) async {
        // Ana actor'den ÇIKILIR: nonisolated async fonksiyon global havuzda çalışır, ana thread serbesttir.
        let report = try? await ConcurrencyLab.run(strategy, jobs: settings.jobs)
        // İş bitince OTOMATİK olarak ana actor'e dönülür; durumu burada güvenle değiştiririz.
        parallelismReports[strategy] = report
    }
}
```

- `DispatchQueue.main.async { }` ile farkı: GCD'de "ana thread'de miyim?" sorusu senin sorumluluğundu; `@MainActor`
  ile yanlış yerden dokunmak **derleme hatasıdır**.
- İzolasyonsuz bir yerden ana actor'e geçmek için: `await MainActor.run { ... }` ya da `@MainActor` bir fonksiyonu
  `await` ile çağırmak.
- Zaten ana thread'de olduğundan emin olduğun (ama derleyicinin bilmediği) eski callback API'lerinde:
  `MainActor.assumeIsolated { ... }`. Yanılıyorsan sessizce yarışmak yerine **çöker**; bu iyi bir şeydir.
- Kendi global actor'ünü de tanımlayabilirsin:

```swift
@globalActor
actor DatabaseActor {
    static let shared = DatabaseActor()
}

@DatabaseActor
final class Database { /* tüm durum DatabaseActor'e izole */ }
```

### 8. Data race ve race condition aynı şey değil

| | Data race | Race condition (mantıksal yarış) |
|---|---|---|
| Tanım | Aynı belleğe, en az biri yazma olan, **senkronize edilmemiş** eşzamanlı erişim | Sonucun işlemlerin **zamanlamasına/sırasına** bağlı olması |
| Swift 6 yakalar mı? | **Evet**, derleme anında (`@unchecked` ile susturmadıysan) | **Hayır**, bu bir mantık hatasıdır |
| Sonuç | Tanımsız davranış (undefined behavior): kayıp güncelleme, bozuk veri, çökme | Tutarlı ama yanlış sonuç |
| Laboratuvar'da | `ConcurrencyLab.UnsafeCounter` | `ConcurrencyLab.ReentrantCounter.incrementAcrossSuspension()` |

Actor'ler ve kilitler data race'i önler; race condition'ları ise ancak doğru tasarım önler.

### 9. Actor reentrancy (yeniden girilebilirlik)

Bir actor metodu `await` ile askıya alındığında actor **kilitli kalmaz**; bekleme sırasında aynı actor'e gelen
başka çağrılar çalışabilir. Bu, deadlock'ları önler ama şu kuralı doğurur:

> **`await`'ten önce okuduğun actor durumu, `await`'ten sonra geçerli olmayabilir.**

```swift
actor ReentrantCounter {
    private(set) var value = 0

    func incrementAcrossSuspension() async {  // ❌
        let snapshot = value
        await Task.yield()        // askıya alınma noktası: başka çağrılar araya girer
        value = snapshot + 1      // eski anlık görüntüyle yazar, araya girenlerin artışını siler
    }

    func increment() {             // ✅ oku-yaz arasında await yok
        value += 1
    }
}
```

Laboratuvar'da 1000 çağrıda hatalı sürüm tipik olarak 100–200 civarında kalır; data race yoktur, hata tamamen
mantıksaldır. Genel kurallar:

- Actor durumunu **senkron** kod içinde değiştir; bu senin "işlem sınırın" (transaction) olsun.
- `await` şartsa, `await`'ten sonra durumu **yeniden oku** ve varsayımlarını yeniden kontrol et.
- Klasik örnek: önbellekte yoksa indir → `await` → önbelleğe yaz. İki çağrı aynı anda gelirse ikisi de indirir.
  Çözüm: devam eden işi (`Task`) saklayıp ikinci çağrıya onu bekletmek:

```swift
actor ThumbnailCache {
    private var cache: [URL: Data] = [:]
    private var inFlight: [URL: Task<Data, any Error>] = [:]

    func data(for url: URL) async throws -> Data {
        if let cached = cache[url] { return cached }
        if let running = inFlight[url] { return try await running.value } // aynı işi ikinci kez başlatma

        let task = Task { try await URLSession.shared.data(from: url).0 }
        inFlight[url] = task
        defer { inFlight[url] = nil }

        let data = try await task.value
        cache[url] = data   // await'ten sonra yazıyoruz ama artık tek bir indirme var
        return data
    }
}
```

### 10. `AsyncStream`: zaman içinde gelen değerler

`async` bir fonksiyon **tek** bir değer döndürür. Zaman içinde **birden çok** değer üretmek için `AsyncSequence`
kullanılır; kendi akışını üretmenin en kolay yolu `AsyncStream`'dir. Projede `FavoritesStore.changes()`:

```swift
func changes() -> AsyncStream<Set<Book.ID>> {
    let (stream, continuation) = AsyncStream.makeStream(
        of: Set<Book.ID>.self,
        bufferingPolicy: .bufferingNewest(1)   // yavaş dinleyiciye sadece EN SON durum
    )
    let observerID = UUID()
    observers[observerID] = continuation
    continuation.yield(favoriteIDs)            // abone olunca mevcut durum hemen gelir
    continuation.onTermination = { [weak self] _ in
        Task { await self?.removeObserver(observerID) } // actor dışında çağrılır; actor'e await ile döneriz
    }
    return stream
}

// Tüketici:
for await ids in await store.changes() {
    favoriteIDs = ids
}
// Döngü, akış bitince ya da bu task iptal edilince sona erer.
```

- `yield` değeri akışa koyar, `finish()` akışı bitirir.
- Tüketen task iptal edilirse döngü biter ve `onTermination` çağrılır; kaynakları orada temizlersin.
  (Bu davranış `FavoritesStoreTests` içinde test ediliyor.)

### 11. Kooperatif (işbirlikçi) iptal (cooperative cancellation)

`task.cancel()` işi **zorla durdurmaz**. Sadece task'ın üzerine "iptal edildi" bayrağını koyar ve iptali tüm
çocuklarına yayar. İşin kendisi bayrağa bakıp **kendi isteğiyle** durmalıdır:

```swift
while completedSteps < stepCount {
    if Task.isCancelled { return .cancelled(completedSteps: completedSteps) } // 1) bayrağa bak (fırlatmaz)
    try await Task.sleep(for: stepDuration)  // 2) iptale duyarlı API: iptalde CancellationError fırlatır
    completedSteps += 1
}
```

- `Task.isCancelled`: `Bool` döndürür; kısmi sonuç döndürmek gibi kararları sana bırakır.
- `try Task.checkCancellation()`: iptal edildiyse `CancellationError` fırlatır.
- `Task.sleep`, `URLSession` gibi sistem API'leri iptale kendileri duyarlıdır.
- Askıda bekleyen (ör. eski bir callback API'sini bekleyen) bir işi iptalde uyandırmak için
  `withTaskCancellationHandler`:

```swift
let request = LegacyRequest()   // varsayımsal, iptal edilebilir eski API
let data = try await withTaskCancellationHandler {
    try await request.start()
} onCancel: {
    request.cancel()            // iptal ANINDA, operation ile eşzamanlı çağrılır → request thread-safe olmalı
}
```

- `CancellationError` bir "hata" değildir; kullanıcıya hata ekranı göstermek yerine sessizce çık.

### 12. Swift 6.2: Approachable Concurrency

**Bu projenin ayarları:** `SWIFT_VERSION = 6.0` (Swift 6 dil modu, tam eşzamanlılık denetimi), derleyici 6.2.
`SWIFT_DEFAULT_ACTOR_ISOLATION` ve `SWIFT_APPROACHABLE_CONCURRENCY` **ayarlanmadı**. Yani izolasyon her yerde açıkça
yazılı ve nonisolated bir `async` fonksiyon global havuzda çalışır. Öğrenirken "kod nerede çalışıyor?" sorusunun
cevabını koddan okuyabilmen için bu bilinçli bir seçim.

Xcode 26'nın **yeni proje şablonları** ise iki ayarı açar: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` ve
`SWIFT_APPROACHABLE_CONCURRENCY = YES`. İş yerinde karşılaşacağın projelerin çoğu bu şekilde olacak.

**a) `nonisolated(nonsending)` ve `@concurrent` (SE-0461)**

Swift 6.2 öncesinde nonisolated bir `async` fonksiyon, çağıran kim olursa olsun global havuza **geçerdi** (bu
projede hâlâ öyle). Bu yüzden ana actor'e ait, `Sendable` olmayan bir değeri (ör. view model'in bir özelliğini) böyle
bir fonksiyona vermek derleme hatasıydı: değer izolasyon sınırını geçiyordu. Swift 6.2 iki açık seçenek getirdi
(ikisi de bu projede ek ayar olmadan yazılabilir):

```swift
struct BookParser {
    // Çağıranın actor'ünde çalışır. Ana actor'den çağrılırsa ana thread'de kalır; argümanlar sınır geçmez.
    nonisolated(nonsending) func parse(_ data: Data) async throws -> [Book] { ... }

    // Her zaman global havuzda çalışır. Ağır CPU işini ana thread'den almak için.
    @concurrent func parseInBackground(_ data: Data) async throws -> [Book] { ... }
}
```

**Approachable Concurrency** ayarı (`SWIFT_APPROACHABLE_CONCURRENCY = YES`) bir grup "gelecek özelliği" (upcoming
feature) açar. Swift 6 dil modunda bunların çoğu zaten açıktır; fark yaratan ikisi:

- `NonisolatedNonsendingByDefault`: İşaretsiz nonisolated `async` fonksiyonlar artık **varsayılan olarak
  `nonisolated(nonsending)`** olur, yani çağıranın actor'ünde çalışır. Arka plana geçmek için `@concurrent` yazmak gerekir.
- `InferIsolatedConformances` (SE-0470): Ana actor'e bağlı bir tip, bir protokole **izole uygunluk** (isolated
  conformance) ile uyabilir; o uygunluk sadece ana actor'de kullanılabilir.

**b) Default Actor Isolation (SE-0466)**

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` ile modüldeki, izolasyonu açıkça belirtilmemiş bildirimler
**`@MainActor` kabul edilir**. Actor'ler kendi izolasyonlarını korur; `nonisolated` yazılan tipler ve üyeler bu
varsayılandan çıkar. Ayar **hedef (target) başınadır**; test hedefi kendi ayarını taşır. SwiftPM karşılığı:
`swiftSettings: [.defaultIsolation(MainActor.self)]`.

**c) Bu projede bu ayarlar açılsaydı ne değişirdi?**

| Yer | Bugün | Ayarlar açık olsaydı | Ne yapmamız gerekirdi |
|---|---|---|---|
| `LocalBookService.fetchBooks()` vb. | nonisolated → global havuzda çalışır | *Approachable*: view model'den çağrılınca **ana actor'de** çalışır. *Default MainActor*: tip zaten `@MainActor` olur. İki durumda da `Task.sleep` ana thread'i bloklamaz ama `loadBooksFromBundle()` (dosya okuma + `JSONDecoder`) **ana thread'de** çalışır. Dosyadaki "gövde ana thread'de değil…" açıklaması geçersizleşir. | Ağır fonksiyonları `@concurrent` yapmak; tipi `nonisolated struct LocalBookService` olarak işaretlemek |
| `ConcurrencyLab.UnsafeCounter` | nonisolated; child task'lar `increment()`'i paralel çağırır → data race görünür | *Default MainActor*: sınıf `@MainActor` olur. Child task'lar `increment()`'e ulaşmak için ana actor'de **sıraya girer**; artışlar sıralanır ve deney her seferinde `1000 / 1000` gösterir. Hata "düzelmiş" gibi görünür ama sebebi tesadüftür ve bedeli her artışta ana thread'e geçiştir. | Deneyi korumak için `nonisolated final class UnsafeCounter` (aynısı `LockedCounter` için de) |
| `ConcurrencyLab.run…` fonksiyonları, `LongRunningJob.run` | Global havuzda çalışır | *Approachable*: çağıran `@MainActor` view model olduğu için ana actor'de başlar. Ölçülen süreler değişmez, çünkü işler `Task.sleep` ile bekliyor ve bekleme hiçbir actor'ü meşgul etmez. Gerçek CPU işi olsaydı ana thread'i tutardı. | CPU işi içeren fonksiyonları `@concurrent` yapmak |
| `Book`, `Review`, `AuthorProfile` | nonisolated değer tipleri | *Default MainActor*: `@MainActor` olurlar. Bugünkü hâlleriyle sorun çıkmaz: `Sendable` tipteki saklanan `let` alanlar her yerden okunabilir ve `JSONDecoder` ile çözümleme `@concurrent` bir fonksiyonda da derlenir (Swift 6.2.4 ile denendi). Ama modele hesaplanmış bir özellik ya da metot eklersen (ör. `var displayTitle: String`) o **ana actor'e bağlanır**; arka plan kodundan erişmek "main actor-isolated property … can not be referenced from a nonisolated context" hatası verir. | Saf veri tiplerini `nonisolated struct Book` olarak işaretlemek |
| `ConcurrencyLabViewModel` ve diğer view model'ler | Açıkça `@MainActor` | *Default MainActor*: `@MainActor` yazmaya gerek kalmaz (yazmak zararsızdır) | — |
| `FavoritesStore`, `ConcurrencyLab.ActorCounter`, `ConcurrencyLab.ReentrantCounter`, `StubBookService` | Actor | **Değişmez**: actor'ler kendi izolasyonlarını taşır | — |

Kısaca: bu ayarlar **UI katmanı** için harikadır (daha az işaretleme, daha az "sınır geçişi" hatası), ama arka planda
çalışması gereken kodu **açıkça** `nonisolated` / `@concurrent` işaretlemeni gerektirir. Bu projede tersini
yaptık: varsayılan nonisolated, UI tipleri açıkça `@MainActor`.

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Gösterdiği kavram |
|---|---|---|
| [ConcurrencyLab.swift](../BookShelf/Features/ConcurrencyLab/ConcurrencyLab.swift) | `ConcurrencyLab`, `ConcurrencyLab.Settings` | Namespace olarak `enum`; süreleri enjekte ederek test edilebilirlik |
| [ParallelismLab.swift](../BookShelf/Features/ConcurrencyLab/ParallelismLab.swift) | `runSequentially(_:)` | Sıralı `await`: süreler toplanır |
| [ParallelismLab.swift](../BookShelf/Features/ConcurrencyLab/ParallelismLab.swift) | `runWithAsyncLet(_:)`, `JobTrio` | `async let`, sabit sayıda child task |
| [ParallelismLab.swift](../BookShelf/Features/ConcurrencyLab/ParallelismLab.swift) | `runWithTaskGroup(_:)` | `withThrowingTaskGroup`, bitiş sırası ve sırayı geri kurma |
| [LabCounters.swift](../BookShelf/Features/ConcurrencyLab/LabCounters.swift) | `UnsafeCounter` | Data race, `@unchecked Sendable`'ın kötüye kullanımı |
| [LabCounters.swift](../BookShelf/Features/ConcurrencyLab/LabCounters.swift) | `LockedCounter` | `OSAllocatedUnfairLock`, derleyicinin doğruladığı `Sendable` |
| [LabCounters.swift](../BookShelf/Features/ConcurrencyLab/LabCounters.swift) | `ActorCounter`, `SharedCounter` | Actor izolasyonu; senkron metodun `async` protokol gereksinimini karşılaması |
| [LabCounters.swift](../BookShelf/Features/ConcurrencyLab/LabCounters.swift) | `ReentrantCounter`, `runReentrancyExperiment(...)` | Actor reentrancy, race condition |
| [LabCounters.swift](../BookShelf/Features/ConcurrencyLab/LabCounters.swift) | `hammer(...)` | `withDiscardingTaskGroup`, `@Sendable` closure |
| [LongRunningJob.swift](../BookShelf/Features/ConcurrencyLab/LongRunningJob.swift) | `LongRunningJob.run(onProgress:)` | Kooperatif iptal, `Task.isCancelled`, iptale duyarlı `Task.sleep` |
| [ConcurrencyLabViewModel.swift](../BookShelf/Features/ConcurrencyLab/ConcurrencyLabViewModel.swift) | `ConcurrencyLabViewModel` | `@MainActor @Observable`, ana actor'e geri dönüş, çift başlatma koruması |
| [ConcurrencyLabViewModel.swift](../BookShelf/Features/ConcurrencyLab/ConcurrencyLabViewModel.swift) | `startLongTask()`, `cancelLongTask()` | `Task { }` vs `Task.detached`, handle saklayıp iptal etme |
| [ConcurrencyLabView.swift](../BookShelf/Features/ConcurrencyLab/ConcurrencyLabView.swift) | `ConcurrencyLabView` | Senkron düğme aksiyonundan `Task { await ... }` |
| [FavoritesStore.swift](../BookShelf/Core/Stores/FavoritesStore.swift) | `FavoritesStore`, `changes()` | Gerçek bir actor, `AsyncStream`, `onTermination` |
| [LocalBookService.swift](../BookShelf/Core/Services/LocalBookService.swift) | `LocalBookService` | Nonisolated async servis, `Task.checkCancellation()` |
| [BookServiceProtocol.swift](../BookShelf/Core/Services/BookServiceProtocol.swift) | `BookServiceProtocol: Sendable` | `Sendable` protokol, `async throws` gereksinimler |
| [StubBookService.swift](../BookShelfTests/Support/StubBookService.swift) | `StubBookService` | Değiştirilebilir durumlu test dublörü için actor |
| [LabParallelismTests.swift](../BookShelfTests/ConcurrencyLab/LabParallelismTests.swift) | `testCancellingParentCancelsTaskGroupChildren` | İptalin child task'lara yayılması |
| [LabSharedStateTests.swift](../BookShelfTests/ConcurrencyLab/LabSharedStateTests.swift) | `testUnsafeCounterNeverExceedsExpectedTotal` | Yarışa bağlı sonucu kırılgan olmadan test etmek |
| [LabCancellationTests.swift](../BookShelfTests/ConcurrencyLab/LabCancellationTests.swift) | `testCancelledJobStopsEarlyAndReportsCancellation` | `sleep` kullanmadan, `AsyncStream` ile iptal zamanlamak |
| [ConcurrencyLabViewModelTests.swift](../BookShelfTests/ConcurrencyLab/ConcurrencyLabViewModelTests.swift) | `ConcurrencyLabViewModelTests` | `@MainActor` test metotları, `await handle.value` |
| [FavoritesStoreTests.swift](../BookShelfTests/Core/FavoritesStoreTests.swift) | `FavoritesStoreTests` | Actor'e 1000 eşzamanlı yazma, `AsyncStream` aboneliği ve iptal |

## Sık yapılan hatalar

**1. `async` yazınca işlerin paralel çalıştığını sanmak**

```swift
// ❌ Sıralı: toplam süre = a + b
let reviews = try await service.fetchReviews(for: id)
let author = try await service.fetchAuthorProfile(named: name)

// ✅ Paralel: toplam süre ≈ max(a, b)
async let reviews = service.fetchReviews(for: id)
async let author = service.fetchAuthorProfile(named: name)
let (loadedReviews, loadedAuthor) = try await (reviews, author)
```

**2. Async kodu senkron beklemek (thread'i bloklamak)**

```swift
// ❌ Havuzun thread'ini bloklar. Swift 6 bunu zaten derlemez: `result`'ı hem Task'a verip hem sonra kullanmak
//    "sending value ... risks causing data races" hatası verir.
func loadBooksBlocking() -> [Book] {
    let semaphore = DispatchSemaphore(value: 0)
    var result: [Book] = []
    Task {
        result = (try? await service.fetchBooks()) ?? []
        semaphore.signal()
    }
    semaphore.wait()
    return result
}

// ✅ Async kalsın; çağıran da await etsin.
func loadBooks() async throws -> [Book] {
    try await service.fetchBooks()
}
```

**3. Derleyici hatasını `@unchecked Sendable` ile susturmak**

```swift
// ❌ Hata kaybolmadı, sadece derleyicinin gözünden saklandı.
final class Cache: @unchecked Sendable {
    var items: [Int: String] = [:]
}

// ✅ Durumu gerçekten koru: actor (ya da kilit).
actor Cache {
    private var items: [Int: String] = [:]
    func set(_ value: String, for key: Int) { items[key] = value }
}
```

**4. Actor içinde `await`'ten önce okunan durumun hâlâ geçerli olduğunu varsaymak**

```swift
// ❌ Reentrancy: bekleme sırasında başka çağrılar `balance`'ı değiştirebilir.
func withdraw(_ amount: Int) async throws {
    guard balance >= amount else { throw BankError.insufficientFunds }
    await auditLog.record(amount)
    balance -= amount            // bakiye bu arada azalmış olabilir → eksi bakiye
}

// ✅ Kontrol ve değişiklik aynı senkron blokta; await sonra.
func withdraw(_ amount: Int) async throws {
    guard balance >= amount else { throw BankError.insufficientFunds }
    balance -= amount
    await auditLog.record(amount)
}
```

**5. "Arka planda çalışsın" diye `Task.detached` kullanmak**

```swift
// ❌ İzolasyon ve öncelik kaybolur; ana actor'deki özelliğe doğrudan yazmak derleme hatasıdır.
@MainActor func refresh() {
    Task.detached {
        let books = try await self.service.fetchBooks()
        self.books = books       // ❌ nonisolated bağlamdan ana actor'e izole özelliği değiştirme
    }
}

// ✅ Task { } ana actor'ü miras alır; ağır iş zaten nonisolated servis fonksiyonunda.
@MainActor func refresh() {
    Task {
        do {
            books = try await service.fetchBooks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

**6. İptali kontrol etmemek ya da `CancellationError`'ı hata gibi göstermek**

```swift
// ❌ İptal edilse de 10.000 öğenin hepsini işler; sonra kullanıcıya "hata" gösterir.
for item in items { process(item) }

// ✅ Pahalı adımlardan önce kontrol et; iptali sessizce karşıla.
do {
    for item in items {
        try Task.checkCancellation()
        process(item)
    }
} catch is CancellationError {
    return
}
```

**7. Kilidi `await` boyunca tutmak**

```swift
// ❌ Kilidi tutarken askıya alınmak: task başka bir thread'de devam edebilir, kilidi bekleyenler takılır.
// (Swift 6 SDK'sında `NSLock.lock()` "unavailable from asynchronous contexts" olarak işaretli; derleyici bunu reddeder.
//  `withLock { }` closure'ı ise senkrondur, içine hiç `await` yazılamaz.)
lock.lock()
let value = await fetchValue()
lock.unlock()

// ✅ Önce await et, sonra kısa ve senkron bir kritik bölgede yaz.
let value = await fetchValue()
state.withLock { $0 = value }
```

**8. Task handle'ını saklamamak / çift başlatmayı engellememek**

```swift
// ❌ Her dokunuşta yeni bir iş başlar; hiçbiri iptal edilemez.
Button("Başlat") { Task { await viewModel.runLongJob() } }

// ✅ Handle'ı sakla, çalışırken yenisini başlatma, gerektiğinde iptal et.
func startLongTask() {
    guard longTask == nil else { return }
    longTask = Task { ... ; longTask = nil }
}
func cancelLongTask() { longTask?.cancel() }
```

## Mülakatta sorulabilecekler

1. **Thread ile Task arasındaki fark nedir?**
   Thread işletim sisteminin pahalı bir kaynağıdır. Task ise Swift runtime'ın hafif iş birimidir ve çekirdek sayısı
   kadar thread'den oluşan kooperatif bir havuzda çalışır. Task `await`'te askıya alınır ve thread'i bırakır; sonra
   farklı bir thread'de devam edebilir. Binlerce task olabilir ama thread sayısı sabit kalır.

2. **`async let` ile `TaskGroup` arasındaki fark nedir? Hangisini ne zaman kullanırsın?**
   İkisi de yapısal concurrency'dir: child task'lar kapsamı aşamaz, iptal ve hatalar ağaç boyunca yayılır.
   `async let` derleme anında sayısı belli, farklı tipte sonuç döndürebilen işler içindir (ör. yorumlar + yazar
   profili). `TaskGroup` çalışma anında sayısı belli, aynı tipte sonuç döndüren işler içindir; sonuçlar bitiş
   sırasıyla gelir.

3. **`Task { }` ile `Task.detached { }` farkı nedir?**
   `Task { }` çağrıldığı yerin actor izolasyonunu, önceliğini ve task-local değerlerini miras alır.
   `Task.detached` hiçbirini almaz. İkisi de yapısal değildir, yani ebeveyn iptali onlara yayılmaz ve iptal senin
   sorumluluğundur. `Task.detached` nadiren gerekir.

4. **Actor nedir? Data race'i nasıl önler? Reentrancy nedir?**
   Actor, durumunu izole eden bir referans tipidir; durumuna aynı anda tek bir görev erişir ve dışarıdan erişim
   `await` ister. Reentrancy: actor bir `await`'te askıya alınınca başka çağrılar araya girebilir. Bu yüzden
   `await`'ten önce okunan durum sonra geçersiz olabilir. Çözüm: durumu senkron bloklarda değiştirmek,
   `await`'ten sonra yeniden kontrol etmek.

5. **Data race ile race condition arasındaki fark nedir?**
   Data race, aynı belleğe senkronize edilmemiş eşzamanlı erişimdir (en az biri yazma); tanımsız davranıştır ve
   Swift 6 onu derleme anında yakalar. Race condition ise sonucun zamanlamaya bağlı olmasıdır. Actor'ler data
   race'i önler ama race condition'ı önlemez (reentrancy örneği).

6. **`Sendable` nedir? `@unchecked Sendable` ne zaman kabul edilebilir?**
   Bir değerin izolasyon alanları arasında data race yaratmadan geçebileceğini belirtir. Swift 6 bunu derleme
   anında denetler. `@unchecked Sendable` ancak tip durumunu gerçekten bir kilit ya da atomik ile koruyor ama
   derleyici bunu göremiyorsa kabul edilebilir. Hatayı susturmak için kullanmak data race'i gizler.

7. **Task iptali nasıl çalışır? `cancel()` çağırınca ne olur?**
   Sadece bir bayrak kalkar ve iptal çocuk task'lara yayılır; iş zorla durdurulmaz. Kod `Task.isCancelled` /
   `Task.checkCancellation()` ile kontrol etmeli ya da `Task.sleep` gibi iptale duyarlı API'ler kullanmalıdır.
   Askıdaki işleri uyandırmak için `withTaskCancellationHandler` vardır.

8. **Swift 6.2'deki `nonisolated(nonsending)` ve `@concurrent` ne işe yarar?**
   `nonisolated(nonsending)` bir async fonksiyonun çağıranın actor'ünde çalışmasını sağlar; böylece `Sendable`
   olmayan argümanlar sınır geçmez. `@concurrent` ise fonksiyonu her zaman global havuzda çalıştırır; ağır işi ana
   thread'den almak için kullanılır. Approachable Concurrency açıkken işaretsiz nonisolated async fonksiyonlar
   varsayılan olarak `nonisolated(nonsending)` olur.

## Alıştırmalar

**1. Data race'i Thread Sanitizer ile yakala.**
Scheme > Edit Scheme > Run > Diagnostics'te **Thread Sanitizer**'ı aç, uygulamayı çalıştır ve Laboratuvar'da
"Üç sayacı çalıştır"a bas. TSan hangi satırı raporluyor? Sonra aynı deneyi `LockedCounter` ve `ActorCounter` için
düşün: neden onlar raporlanmıyor?
*İpucu:* Rapor `ConcurrencyLab.UnsafeCounter.increment()` içindeki `value += 1` satırını göstermeli. Denemeden
sonra TSan'ı kapat; birim testleri de bilerek yarışan kodu çalıştırdığı için TSan açıkken raporlanır.

**2. Sınırlı eşzamanlılıkla TaskGroup.**
`ParallelismLab.swift` içine `runWithTaskGroup(_:maxConcurrent:)` ekle: 10 işi çalıştırsın ama aynı anda en fazla
3 tanesi çalışsın. Her iş 200 ms ise toplam süre yaklaşık kaç olmalı? `LabParallelismTests`'e cömert sınırlı bir
test ekle.
*İpucu:* Önce ilk 3 işi `addTask` ile ekle. `for try await` döngüsünde her sonuç geldiğinde, kalan iş varsa bir
tane daha ekle. Beklenen süre ≈ 4 × 200 ms (3 + 3 + 3 + 1).

**3. Reentrancy'yi `await`'i silmeden düzelt.**
`ConcurrencyLab.ReentrantCounter` içine `incrementAfterSuspension()` adında üçüncü bir metot ekle. `await
Task.yield()` satırı kalmalı ama sonuç her zaman tam 1000 olmalı. Sonra `runReentrancyExperiment` ve ekrana bu
sürümü de ekle.
*İpucu:* Sorun `await`'in kendisi değil, `await`'ten **önce** okunup **sonra** kullanılan değer. `await`'i okuma ve
yazmadan önceye taşı ya da değeri `await`'ten sonra yeniden oku; oku-yaz arasında askıya alınma noktası kalmasın.
