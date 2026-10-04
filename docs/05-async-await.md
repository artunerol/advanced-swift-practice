# async/await

## Neden önemli?

Bir uygulamanın zamanının büyük kısmı **beklemekle** geçer: ağ yanıtı, disk, veritabanı. Bu beklemeler ana thread'i bloklarsa arayüz donar. Eskiden çözüm **completion handler** idi:

```swift
service.fetchBooks { result in
    DispatchQueue.main.async {                 // Hangi thread'deyim? Unutursam UI'ı arka planda güncellerim.
        switch result {
        case .success(let books):
            service.fetchReviews(for: books[0].id) { reviewsResult in   // İç içe "piramit"
                // ...
            }
        case .failure(let error):
            // Bir dalda completion'ı çağırmayı unutursam çağıran sonsuza kadar bekler.
        }
    }
}
```

Bu kodun sorunları:

- İç içe closure'lar, yani "pyramid of doom".
- Completion'ı hiç çağırmamak ya da iki kez çağırmak derleyicinin yakalayamadığı hatalardır.
- Hata yönetimi `Result` ile elle yapılır; `try`/`catch` kullanılamaz.
- Sonucun hangi thread'de geldiği belirsizdir; `DispatchQueue.main.async` unutulabilir.
- İptal için ayrı bir mekanizma kurmak gerekir.

**async/await** ile aynı iş düz, yukarıdan aşağı okunan koda dönüşür:

```swift
let books = try await service.fetchBooks()
let reviews = try await service.fetchReviews(for: books[0].id)
```

Derleyici artık her yolun **tam olarak bir kez** döndüğünü garanti eder. Hatalar `throws` ile akar, iptal task ağacı boyunca yayılır. Swift 6'da da `Sendable` ve actor denetimleriyle birleşerek **data race'leri derleme anında** yakalar. Mülakatlarda neredeyse kesin sorulan bir konudur.

## Temel kavramlar

### 1. `async` fonksiyon ve `await`

```swift
func fetchBooks() async throws -> [Book]
```

- `async`: "Bu fonksiyon çalışırken **askıya alınabilir** (suspend)."
- `await`: Çağrı noktasında "burada askıya alınma **olabilir**" işaretidir. Bir `async` fonksiyonu sadece başka bir async bağlamdan (async fonksiyon, `Task`, `.task`) çağırabilirsin.

### 2. Askıya alma noktası (suspension point): `await` ne yapar?

`let books = try await service.fetchBooks()` satırında:

1. Fonksiyon durur ve **thread'i bırakır**. Thread boşta beklemez; başka işleri (ana thread ise dokunmaları, animasyonları) yürütür.
2. Beklenen iş bitince fonksiyon **kaldığı yerden** devam eder. Yerel değişkenler korunur.
3. Devam ettiği thread, başladığı thread **olmayabilir**. Ancak fonksiyon bir actor'e bağlıysa (ör. `@MainActor`) devam noktası o actor'dür. `@MainActor` için bu, ana thread demektir.

**`await` yeni bir thread açmak demek DEĞİLDİR.** Swift concurrency, kabaca CPU çekirdeği sayısı kadar thread'den oluşan bir **işbirlikçi thread havuzu** (cooperative thread pool) kullanır. Askıya alınan fonksiyon thread tutmaz. Binlerce eşzamanlı görev az sayıda thread üzerinde yürür. `await` "burada bekleyebilirim ve beklerken thread'i başkasına veririm" demektir.

Aynı nedenle `Task.sleep(for:)` thread'i **bloklamaz**, sadece görevi askıya alır. `Thread.sleep` ise thread'i kilitler. Havuzdaki az sayıdaki thread'den birini kilitlemek bütün sistemi yavaşlatır.

> **Dikkat:** `await`'ten önce ve sonra dünya değişmiş olabilir. Askıdayken başka kod (aynı actor'deki başka bir görev dahil) çalışabilir. `await`'ten sonra, öncesinde yaptığın varsayımları yeniden kontrol et.

### 3. Sıralı `await` ve `async let`

```swift
// SIRALI: ikinci istek, birincisi bitince başlar. Süre = 1x + 2x = 3x
let reviews = try await service.fetchReviews(for: book.id)
let author = try await service.fetchAuthorProfile(named: book.author)

// PARALEL: iki istek aynı anda yola çıkar. Süre ≈ max(1x, 2x) = 2x
async let reviews = service.fetchReviews(for: book.id)
async let author = service.fetchAuthorProfile(named: book.author)
let (loadedReviews, loadedAuthor) = try await (reviews, author)
```

`async let`, **yapılandırılmış (structured)** bir **alt görev** (child task) başlatır ve hemen bir sonraki satıra geçer. Kurallar:

- `try` ve `await` bildirim satırına değil, değeri **kullandığın** yere yazılır.
- Alt görev, parent'ın kapsamından (scope) **uzun yaşayamaz**. Değeri hiç `await` etmesen bile Swift kapsam sonunda o alt görevi **iptal eder ve bitmesini bekler**. "Başıboş" görev kalmaz.
- Bir alt görevin hatası, onu `await` ettiğin yerde fırlar. Parent hata ile kapsamdan çıkarken henüz bitmemiş kardeş görevler otomatik iptal edilir. Hata kardeşleri *anında* iptal etmez; iptal, parent kapsamdan çıkarken olur.
- Parent iptal edilirse iptal, tüm alt görevlere yayılır.
- Alt görev sayısı derleme anında bilinmiyorsa (ör. her kitap için bir istek) `withTaskGroup` / `withThrowingTaskGroup` kullanılır. Aynı yapılandırılmış kurallar geçerlidir.

Bu projedeki detay ekranı bunu canlı gösterir: "Yükleme süresi: 1,2 sn (paralel)" ve altında "Sırayla olsaydı ≈ 1,8 sn".

### 4. `Task`: yapılandırılmış ve yapılandırılmamış görevler

| Yöntem | Tür | İzolasyonu devralır mı? | Otomatik iptal? |
|---|---|---|---|
| `async let`, `withTaskGroup` | Yapılandırılmış | Alt görevler çocuk olarak parent'a bağlı | Parent iptal olunca ya da kapsamdan çıkınca |
| `.task { }` (SwiftUI) | SwiftUI yönetir | Evet (`@MainActor`) | View kaybolunca |
| `Task { }` | Yapılandırılmamış | **Evet**: actor izolasyonu, öncelik ve task-local değerler | **Hayır**; handle'ı saklayıp `cancel()` çağırmalısın |
| `Task.detached { }` | Yapılandırılmamış | **Hayır**: hiçbir şey devralmaz | Hayır |

- `Task { }`, senkron bir yerden (ör. `Button` aksiyonu) async kod çağırmanın yoludur: `Button("Tekrar Dene") { Task { await viewModel.load() } }`.
- `Task.detached` neredeyse hiç gerekmez. "Arka plana geçmek" için kullanılırsa önceliği ve iptal bağını kaybettirir. Doğru araç `nonisolated` async bir fonksiyon ya da (Swift 6.2) `@concurrent`'tir.
- Bir görevin sonucunu `let value = try await task.value` ile beklersin.

### 5. İşbirlikçi iptal (cooperative cancellation)

`task.cancel()` görevi **durdurmaz**, sadece "iptal edildin" bayrağını kaldırır. Görevin kendisi bu bayrağı kontrol edip erken çıkmalıdır:

```swift
try Task.checkCancellation()        // iptal edildiyse CancellationError fırlatır
if Task.isCancelled { return }      // fırlatmadan kontrol
```

- Pek çok sistem API'si bayrağı kendisi kontrol eder: `Task.sleep` hemen `CancellationError` fırlatır. `URLSession` ise `URLError(.cancelled)` fırlatır. İkisini de "kullanıcıya gösterilecek hata" sayma.
- İptal edilen bir görev **yarım kalmış bir durum** bırakmamalıdır. Bu projede `BookListViewModel.load()` iptalde `state`'i önceki haline döndürür. Yoksa `.loading`'de takılıp kalır ve view tekrar göründüğünde yükleme hiç başlamaz.
- Askıda beklenen bir işe (ör. bir callback'e) iptali iletmek için `withTaskCancellationHandler` kullanılır.

### 6. `throws` + `async`

```swift
func fetchBooks() async throws -> [Book]      // bildirimde sıra: async throws

do {
    let books = try await service.fetchBooks()  // çağrıda sıra: try await
    state = .loaded(books)
} catch is CancellationError {
    // iptal: sessizce toparlan
} catch {
    state = .failed(message: error.localizedDescription)
}
```

- `catch is CancellationError` genel `catch`'ten **önce** gelmelidir. `catch` blokları yukarıdan aşağı denenir.
- `BookServiceError` `LocalizedError` olduğu için `localizedDescription` kullanıcıya gösterilebilecek Türkçe mesajı verir.

### 7. Actor'ler arası geçişler (main actor hop) ve bu projenin ayarları

`BookListViewModel` `@MainActor`'dür. `load()` içinde `await service.fetchBooks()` dediğinde ne olur?

- Swift 6 dil modunda, **"Approachable Concurrency" kapalıyken** (bu projenin ayarı), `nonisolated` bir async fonksiyon her zaman **global concurrent executor**'de, yani arka plan havuzunda çalışır. `LocalBookService.fetchBooks()` hiçbir actor'e bağlı değildir. Çağrı ana actor'den **ayrılır**, JSON çözümleme arka planda yapılır, dönüşte ana actor'e **geri atlanır** (hop). Bu atlamaları sen yazmazsın; derleyici fonksiyonların izolasyonuna bakarak ekler.
- Xcode 26'nın yeni proje şablonları iki ayarı açar: **Default Actor Isolation = MainActor** (işaretsiz her şey ana actor'e bağlanır) ve **Approachable Concurrency**. İkincisi Swift 6.2'deki `NonisolatedNonsendingByDefault` özelliğini de açar. O modda `nonisolated` async fonksiyonlar **çağıranın actor'ünde** çalışır. Arka plana açıkça geçmek için fonksiyonu `@concurrent` işaretlersin. Bu projede bu iki ayarı **bilerek kapalı** tuttuk: hangi kodun nerede çalıştığı açıkça yazılı olsun ve öğrenilebilsin.
- `@MainActor` kod içinde `DispatchQueue.main.async` yazmana gerek yoktur. Zaten ana actor'desin ve her `await` sonrası oraya geri dönülür. Tek bir bloğu ana actor'de çalıştırmak için `await MainActor.run { ... }` vardır. Ama genelde fonksiyonu ya da tipi `@MainActor` yapmak daha temizdir.
- Actor sınırını geçen değerler `Sendable` olmalıdır. `Book` ve `Review` gibi tüm alanları `Sendable` olan struct'lar bunu kendiliğinden sağlar.

### 8. `LocalBookService` ağı nasıl taklit ediyor?

```swift
private func simulateNetworkRoundTrip(_ delay: Duration) async throws {
    if delay > .zero {
        try await Task.sleep(for: delay)   // thread'i bloklamadan bekler; iptalde hemen fırlatır
    }
    try Task.checkCancellation()           // gecikme sıfır olsa bile iptal edilmiş görev devam etmesin
    if simulatesFailure {
        throw BookServiceError.networkUnavailable
    }
}
```

- `latency` varsayılan olarak 600 ms'dir. Yazar profili bilerek 2 kat yavaştır, böylece `async let` farkı gözle görülür.
- UI testlerinde `-ui-testing` argümanı gecikmeyi sıfırlar; `-simulate-network-error` her isteği hata fırlatır hale getirir.
- Kullanıcı yükleme sırasında ekrandan çıkarsa: SwiftUI `.task`'ı iptal eder → `Task.sleep` `CancellationError` fırlatır → view model bunu hata saymaz.

### 9. Eski callback API'lerini köprülemek: `withCheckedThrowingContinuation`

Elinde completion handler'lı eski bir API varsa onu async bir fonksiyona sarabilirsin:

```swift
struct LegacyBookAPI {
    func fetchBooks(completion: @escaping @Sendable (Result<[Book], Error>) -> Void) {
        // ... eski kod, bir noktada completion'ı çağırır
    }
}

extension LegacyBookAPI {
    func fetchBooks() async throws -> [Book] {
        try await withCheckedThrowingContinuation { continuation in
            fetchBooks { result in
                continuation.resume(with: result)   // TAM OLARAK BİR KEZ
            }
        }
    }
}
```

- **Altın kural: her yolda tam olarak bir kez `resume`.**
  - Hiç `resume` etmezsen çağıran görev **sonsuza kadar** askıda kalır. "Checked" sürüm, continuation hiç devam ettirilmeden yok olursa konsola `SWIFT TASK CONTINUATION MISUSE ... leaked its continuation` uyarısı basar.
  - İki kez `resume` edersen "checked" sürüm programı **çökertir**. `withUnsafeThrowingContinuation` bu denetimleri yapmaz; ancak ölçülmüş bir performans sorunu varsa tercih edilir.
- Continuation iptali kendiliğinden **iletmez**. Eski API'nin bir `cancel()` metodu varsa `withTaskCancellationHandler` ile bağla.
- Objective-C'de son parametresi completion block olan metotlar, Swift'e **otomatik olarak** async sürümleriyle de aktarılır. Örneğin `- (void)fetchWithCompletion:(void (^)(NSArray *, NSError *))completion`, Swift'te `func fetch() async throws -> [Any]` olarak da görünür.

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Ne gösteriyor? |
|---|---|---|
| [BookListViewModel.swift](../BookShelf/Features/BookList/BookListViewModel.swift) | `BookListViewModel.load()` | `await` askıya alma noktası, ana actor dışında çalışan servis çağrısı, `CancellationError`'ı ayrı ele almak, eşzamanlı yüklemeye karşı koruma |
| [BookListViewModel.swift](../BookShelf/Features/BookList/BookListViewModel.swift) | `BookListViewModel.refresh()` | İçeriği koruyarak yenileme, `defer` ile her çıkış yolunda temizlik |
| [BookDetailViewModel.swift](../BookShelf/Features/BookDetail/BookDetailViewModel.swift) | `loadExtrasIfNeeded()` | `async let` ile paralel yükleme, `ContinuousClock` ile süre ölçümü, alt görevlere `self` yerine `Sendable` değerler vermek |
| [BookDetailViewModel.swift](../BookShelf/Features/BookDetail/BookDetailViewModel.swift) | `measure(_:)` | `nonisolated` statik yardımcı; async closure alan generic fonksiyon |
| [BookDetailViewModel.swift](../BookShelf/Features/BookDetail/BookDetailViewModel.swift) | `load()`, `toggleFavorite()` | Actor'e dışarıdan `await` ile erişmek |
| [BookListView.swift](../BookShelf/Features/BookList/BookListView.swift) | `.task`, `.refreshable`, `observeFavorites()` | SwiftUI'ın yönettiği görevler, `Button` içinde `Task { }`, `AsyncStream` + `for await` |
| [LocalBookService.swift](../BookShelf/Core/Services/LocalBookService.swift) | `simulateNetworkRoundTrip(_:)` | `Task.sleep`, `Task.checkCancellation()`, taklit hata |
| [FavoritesStore.swift](../BookShelf/Core/Stores/FavoritesStore.swift) | `changes()` | `AsyncStream.makeStream`, `onTermination` ile temizlik |
| [BookDetailViewModelTests.swift](../BookShelfTests/BookList/BookDetailViewModelTests.swift) | `testReviewsAndAuthorLoadConcurrently` | Paralelliği göreli bir karşılaştırmayla test etmek |
| [BookListViewModelTests.swift](../BookShelfTests/BookList/BookListViewModelTests.swift) | `testCancelledLoadIsNotTreatedAsErrorAndCanStartAgain`, `testConcurrentLoadsCallServiceOnlyOnce` | İptali ve eşzamanlı çağrıları deterministik biçimde test etmek |
| [LocalBookServiceTests.swift](../BookShelfTests/Core/LocalBookServiceTests.swift) | `testCancellationThrowsCancellationErrorPromptly` | İptal edilen görevin 10 sn beklemeden bitmesi |

## Sık yapılan hatalar

**1. Bağımsız işleri sırayla beklemek**

```swift
// YANLIŞ: 1x + 2x = 3x sürer.
let reviews = try await service.fetchReviews(for: id)
let author = try await service.fetchAuthorProfile(named: name)

// DOĞRU: ≈ 2x sürer.
async let reviews = service.fetchReviews(for: id)
async let author = service.fetchAuthorProfile(named: name)
let (r, a) = try await (reviews, author)
```

**2. Durumu `await`'ten SONRA işaretlemek**

```swift
// YANLIŞ: İki çağrı da guard'ı geçer, çünkü bayrak ancak await bittikten sonra kalkıyor.
guard !isLoading else { return }
let books = try await service.fetchBooks()
isLoading = true

// DOĞRU: Bayrağı askıya alma noktasından ÖNCE kaldır.
guard state != .loading else { return }
state = .loading
let books = try await service.fetchBooks()
```

**3. Async sonucu bloklayarak beklemek**

```swift
// YANLIŞ: Thread'i kilitler. Ana thread'de yapılırsa ve görev ana thread'e ihtiyaç duyarsa kilitlenme (deadlock).
let semaphore = DispatchSemaphore(value: 0)
Task { books = try await service.fetchBooks(); semaphore.signal() }
semaphore.wait()

// DOĞRU: Çağıranı da async yap ve await et.
let books = try await service.fetchBooks()
```

**4. Continuation'ı bir dalda unutmak ya da iki kez çağırmak**

```swift
// YANLIŞ: data da error da nil gelirse resume edilmez; çağıran sonsuza kadar bekler.
try await withCheckedThrowingContinuation { continuation in
    legacyFetch { data, error in
        if let error { continuation.resume(throwing: error) }
        if let data { continuation.resume(returning: data) }
    }
}

// DOĞRU: Her yol tam olarak bir kez resume eder.
try await withCheckedThrowingContinuation { continuation in
    legacyFetch { data, error in
        if let data {
            continuation.resume(returning: data)
        } else {
            continuation.resume(throwing: error ?? BookServiceError.decodingFailed)
        }
    }
}
```

**5. "Arka plana geçmek" için `Task.detached` kullanmak**

```swift
// YANLIŞ: Öncelik ve iptal bağı kopar; sonucu UI'a yazmak için yine ana actor'e dönmek gerekir.
Task.detached { let books = try await service.fetchBooks() ... }

// DOĞRU: Ağır işi nonisolated bir async fonksiyona (Swift 6.2 + Approachable Concurrency'de @concurrent)
// koy ve normal şekilde await et. Bu projede servis zaten nonisolated.
let books = try await service.fetchBooks()
```

**6. `@MainActor` kodda gereksiz `DispatchQueue.main.async`**

```swift
// YANLIŞ: Zaten ana actor'desin; bu satır işi bir sonraki turda çalıştırarak sıralamayı bozar.
@MainActor func apply(_ books: [Book]) {
    DispatchQueue.main.async { self.state = .loaded(books) }
}

// DOĞRU
@MainActor func apply(_ books: [Book]) {
    state = .loaded(books)
}
```

## Mülakatta sorulabilecekler

1. **`await` thread'i bloklar mı? Yeni bir thread açar mı?**
   Hayır, ikisini de yapmaz. `await` olası bir askıya alma noktasıdır. Fonksiyon askıya alınırsa thread serbest kalır ve başka işler yürütür. İş bitince fonksiyon devam eder, muhtemelen başka bir thread'de; actor'e bağlıysa o actor'ün executor'ünde. Swift concurrency çekirdek sayısı kadar thread'li işbirlikçi bir havuz kullanır.

2. **`async let`, `TaskGroup` ve `Task { }` farkı nedir?**
   `async let`: sayısı derleme anında bilinen yapılandırılmış alt görevler. `TaskGroup`: sayısı dinamik olan yapılandırılmış alt görevler. `Task { }`: yapılandırılmamış bir kök görev. Actor izolasyonunu, önceliği ve task-local değerleri devralır ama parent kapsamına bağlı değildir ve kendiliğinden iptal edilmez.

3. **Swift'te iptal nasıl çalışır?**
   İşbirlikçidir. `cancel()` bir bayrak kaldırır. Kod `Task.isCancelled` ya da `try Task.checkCancellation()` ile kontrol eder. `Task.sleep` gibi API'ler `CancellationError` fırlatır. İptal yapılandırılmış görev ağacında aşağıya, alt görevlere yayılır. SwiftUI'da `.task` view kaybolunca iptal edilir.

4. **`async let` ile başlattığım iki görevden biri hata fırlatırsa ne olur?**
   Hata, o değeri `await` ettiğin yerde fırlar. Kapsamdan hata ile çıkılırken henüz bitmemiş diğer alt görev otomatik iptal edilir ve bitmesi beklenir. Parent, alt görevleri bitmeden asla kapsamdan çıkmaz.

5. **`Task.detached` ne zaman kullanılır?**
   Çok nadiren: gerçekten mevcut actor'den, öncelikten ve task-local değerlerden bağımsız bir iş gerektiğinde. Çoğu durumda `nonisolated` async fonksiyon (Swift 6.2'de gerekirse `@concurrent`) daha doğrudur.

6. **Bir continuation'ı iki kez resume edersem ne olur? Hiç etmezsem?**
   `CheckedContinuation` ikinci resume'da programı çökertir. Hiç resume edilmezse çağıran görev sonsuza kadar askıda kalır ve continuation yok olurken konsola "leaked its continuation" uyarısı düşer. `Unsafe` sürümler bu denetimleri yapmaz.

7. **Swift 6.2'de `nonisolated` bir async fonksiyon hangi thread'de çalışır?**
   Ayarlara bağlıdır. `NonisolatedNonsendingByDefault` kapalıyken (bu proje) global concurrent executor'de, yani arka planda çalışır. Açıkken (Xcode 26 yeni projelerindeki "Approachable Concurrency") çağıranın actor'ünde çalışır; arka plana geçmek için `@concurrent` gerekir.

8. **`@MainActor` bir fonksiyon içinde `await` sonrası hâlâ ana thread'de miyim?**
   Evet. İzole bir fonksiyon her askıya alma noktasından sonra kendi actor'üne geri döner. Ama arada başka ana actor işleri çalışmış olabilir; durumu yeniden kontrol et (reentrancy).

## Alıştırmalar

1. **Sıralı sürümü ölç.** `BookDetailViewModel.loadExtrasIfNeeded()` içindeki iki `async let`'i geçici olarak iki sıralı `try await` ile değiştir. Uygulamada detay ekranındaki süreye bak, sonra birim testlerini çalıştır.
   *İpucu:* Ekranda toplam süre ≈ 1,8 sn olmalı (600 ms + 1200 ms). `testReviewsAndAuthorLoadConcurrently` testi kırılmalı, çünkü toplam artık iki sürenin toplamından kısa değil. Denedikten sonra `async let`'e geri dön.

2. **Kısmi sonuç göster.** Yazar profili yüklenemese bile yorumlar görünsün; yazar bölümünde "Yazar bilgisi alınamadı" yazsın.
   *İpucu:* Yazar isteğini kendi `do/catch`'i olan küçük bir async fonksiyona taşı ve `AuthorProfile?` döndür: `async let author = loadAuthorOrNil(...)`. `CancellationError`'ı yutma, yeniden fırlat ki iptal yine iptal olarak kalsın. `Extras.author`'ı `Optional` yap ve `StubBookService(author: .failure(...))` ile bir test yaz.

3. **Callback köprüsü yaz.** `LocalBookService`'i saran, completion handler'lı bir `LegacyBookFetcher` yaz (`func fetchBooks(completion: @escaping @Sendable (Result<[Book], Error>) -> Void)`; içinde `Task { }` açıp servisi çağırsın). Ardından onu `withCheckedThrowingContinuation` ile tekrar `async throws` bir fonksiyona çevir ve birim testi ekle.
   *İpucu:* `continuation.resume(with: result)` tek satırda hem başarıyı hem hatayı karşılar. Testte `LocalBookService(latency: .zero)` kullan ve 8 kitap geldiğini doğrula. Bilerek iki kez `resume` etmeyi dene ve çöküş mesajını oku.
