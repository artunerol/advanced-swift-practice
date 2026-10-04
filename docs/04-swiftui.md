# SwiftUI

## Neden önemli?

SwiftUI, Apple'ın **bildirimsel (declarative)** arayüz çatısıdır. UIKit'te "şu label'ın metnini değiştir, şu hücreyi yeniden yükle" diye ekranı adım adım *sen* güncellersin. SwiftUI'da ise "durum şu iken ekran böyle görünür" diye bir **tarif** yazarsın; durum değişince ekranı güncellemek SwiftUI'ın işidir.

Mülakatlarda SwiftUI soruları neredeyse hep aynı üç konuya çıkar:

1. **Durum sahipliği:** Veri kimde yaşıyor? `@State`, `@Binding`, `@Observable`, `@Environment` ne zaman kullanılır?
2. **Kimlik ve yaşam döngüsü:** Bir view ne zaman "aynı" view'dir, durumu ne zaman sıfırlanır, `.task` ne zaman başlar ve ne zaman iptal edilir?
3. **Veri akışı:** Veri yukarıdan aşağıya, olaylar aşağıdan yukarıya nasıl akar?

iOS 17 ile gelen `@Observable` makrosu önerilen kalıpları değiştirdi. Bu yüzden eski (`ObservableObject`) ve yeni yaklaşımı ayırt edebilmek de bekleniyor.

## Temel kavramlar

### 1. View bir değerdir, ekranın tarifidir

```swift
struct GreetingView: View {
    let name: String

    var body: some View {
        Text("Merhaba, \(name)!")
    }
}
```

- `View` bir protokoldür; genelde küçük bir `struct` ile uygulanır. Struct'ın kendisi ekrandaki piksel **değildir**, ekranın *tarifidir*. SwiftUI `body`'yi çağırır, çıkan tarifi bir öncekiyle karşılaştırır (diff) ve sadece değişen kısmı gerçek arayüzde günceller.
- View struct'ları **ucuzdur ve kısa ömürlüdür**. SwiftUI onları çok sık oluşturup atar. Bu yüzden `init` ve `body` içinde ağır iş yapılmaz (ağ isteği, dosya okuma vb.).
- `some View` bir **opak tiptir**: "Belirli bir `View` tipi döndürüyorum ama adını söylemiyorum." Gerçek tip `VStack<TupleView<(Text, Text)>>` gibi uzun bir şeydir, derleyici onu bilir.
- `body` bir `@ViewBuilder`'dır: içinde `if` / `switch` yazabilirsin, her kol farklı bir view döndürebilir.
- Xcode 16 SDK'sından (iOS 18) beri `View` protokolünün **tamamı** `@MainActor`'dür (öncesinde sadece `body` öyleydi). Yani view'in `init`'i, `body`'si ve metotları ana actor'de çalışır. Deployment target'ımız iOS 17 olsa da bu kural derleme zamanında SDK'dan geldiği için bizde de geçerli.

### 2. Kimlik (identity) ve yaşam süresi

SwiftUI iki view'in "aynı" olup olmadığına **kimlikle** karar verir. Durum (`@State`) kimliğe bağlıdır; kimlik değişirse durum sıfırlanır.

- **Yapısal kimlik (structural identity):** View ağacındaki konumu. `if` / `else` kolları farklı kimliklerdir. Koşul değişince eski koldaki view'in durumu atılır.
- **Açık kimlik (explicit identity):** `ForEach(books)` içindeki `id`'ler ya da `.id(değer)` modifier'ı. `.id(...)` değerini değiştirmek view'i "yepyeni" yapar ve durumunu sıfırlar.

Önemli ayrım: **View değerinin** ömrü çok kısadır (her `body` çağrısında yeniden oluşur); **view kimliğinin** ömrü ise view ekranda kaldığı sürecedir. `@State` ikincisine bağlıdır.

### 3. Durum sahipliği

| Araç | Veri kimde? | Ne zaman kullanılır? |
|---|---|---|
| `@State` | View'in kendisi (SwiftUI'ın deposunda) | View'e özel basit değerler (`Bool`, `String`), **veya** view'in sahip olduğu bir `@Observable` nesne |
| `@Binding` | Başka birinde; bu view sadece okur/yazar | Alt view'in üst view'deki bir değeri değiştirmesi |
| `@Observable` sınıf | Nesnenin kendisinde (referans tipi) | View model, paylaşılan model |
| `@Bindable` | Başka birinde | Bir `@Observable` nesnenin özelliklerine `$` ile binding üretmek |
| `@Environment` | Ağacın üst kısmında | Ağaç boyunca "enjekte edilen" değerler ve nesneler |

**`@State` ile basit değer:**

```swift
struct CounterView: View {
    @State private var count = 0   // private: bu durum sadece bu view'indir

    var body: some View {
        Stepper("Sayı: \(count)", value: $count)   // $count → Binding<Int>
    }
}
```

**`@Binding` ile alt view'e yazma yetkisi vermek:**

```swift
struct NotificationToggle: View {
    @Binding var isOn: Bool          // veri burada değil, üst view'de yaşıyor

    var body: some View {
        Toggle("Bildirimler", isOn: $isOn)
    }
}

// Üst view'de:
@State private var notificationsOn = true
NotificationToggle(isOn: $notificationsOn)
```

**`@Observable` (iOS 17+):**

```swift
@Observable
final class ProfileModel {
    var name = ""
    var bio = ""
}
```

`@Observable` bir makrodur: her `var` özelliğe erişim takibi ekler. SwiftUI `body` çalışırken hangi özelliklerin **okunduğunu** kaydeder ve sadece onlar değişince view'i yeniden çizer. Eski `ObservableObject`'te ise herhangi bir `@Published` değiştiğinde nesneyi izleyen bütün view'ler yeniden hesaplanırdı.

| Eski (`ObservableObject`) | Yeni (`@Observable`) |
|---|---|
| `class M: ObservableObject { @Published var x }` | `@Observable class M { var x }` |
| Sahip olan view: `@StateObject` | Sahip olan view: `@State` |
| Sahip olmayan view: `@ObservedObject` | Sahip olmayan view: düz `let` / `var` (binding lazımsa `@Bindable`) |
| `.environmentObject(m)` + `@EnvironmentObject` | `.environment(m)` + `@Environment(M.self)` |
| Nesne düzeyinde bildirim | Özellik düzeyinde takip |

**Neden bir sınıf için `@State`?** `@Observable` nesnenin *değişimlerini* izlemek için property wrapper'a gerek yoktur. `@State`'in buradaki görevi **sahipliktir**: SwiftUI nesneyi view'in kimliği boyunca saklar ve struct yeniden oluşturulsa bile aynı örneği geri verir. Düz `let model = ProfileModel()` yazsaydın, üst view her yeniden çizildiğinde yeni bir nesne oluşurdu ve içindeki veri kaybolurdu.

Apple'ın `State` dokümantasyonundaki önemli uyarı: `@State`'in başlangıç değeri, SwiftUI view'i **her** oluşturduğunda yeniden hesaplanır; sadece ilki saklanır, diğerleri atılır. Bu yüzden view model'in `init`'i ucuz ve yan etkisiz olmalı. Ağ isteği `init`'te değil, `.task` içinde başlar. (Nesnenin kendisi pahalıysa `@State private var model: Model?` tanımlayıp `.task` içinde oluşturmak da bir seçenektir.)

**`@Bindable` ile form alanı:**

```swift
struct ProfileEditor: View {
    @Bindable var profile: ProfileModel   // sahibi başkası, ama $ ile binding üretebiliriz

    var body: some View {
        TextField("Ad", text: $profile.name)
    }
}
```

`@State private var model = ProfileModel()` ile sahip olduğun bir nesnede `$model.name` zaten çalışır, `@Bindable`'a gerek yoktur.

**`@Environment`:**

```swift
// Ağacın tepesinde:
ContentView().environment(profile)

// Herhangi bir alt view'de:
@Environment(ProfileModel.self) private var profile
@Environment(\.dismiss) private var dismiss   // sistemin sağladığı değerler de böyle okunur
```

### 4. Veri akışı

- **Tek doğruluk kaynağı (single source of truth):** Her veri parçasının tek bir sahibi olur. Başkaları ona ya **kopya** (düz parametre) ya da **binding** ile erişir.
- **Veri aşağı, olaylar yukarı akar:** Üst view alt view'e değer verir; alt view bir şeyi değiştirmek isterse binding'e yazar ya da bir closure çağırır.
- Bu projede: `BookListView` view model'in sahibidir (`@State`). `BookListRow` ise sadece `Book` ve `isFavorite` değerlerini alır. Durumu yoktur, ne verilirse onu çizer. Bu tür "aptal" view'ler en kolay test edilen ve önizlenen parçalardır.

### 5. Değer tabanlı `NavigationStack`

```swift
NavigationStack {
    List(books) { book in
        NavigationLink(value: book) {          // sadece bir DEĞER yayınlar
            Text(book.title)
        }
    }
    .navigationDestination(for: Book.self) { book in   // değere göre hedef ekranı seçer
        BookDetailView(book: book, dependencies: dependencies)
    }
}
```

- `NavigationLink(value:)` hedef view'i değil, bir **değeri** taşır. Değer `Hashable` olmalıdır (`Book` öyle).
- Hedef view **tembel** oluşturulur: sadece satıra dokunulunca. Eski `NavigationLink(destination:)` ile ise liste çizilirken her satırın hedef view'inin `init`'i önceden çalışırdı (`body`'si değil). `init` içinde view model oluşturan ekranlarda bu, gereksiz nesneler demekti.
- Programatik navigasyon için yığını bir diziye bağlarsın:

  ```swift
  @State private var path: [Book] = []

  NavigationStack(path: $path) { ... }
  path.append(someBook)   // push
  path.removeLast()       // pop
  path.removeAll()        // köke dön
  ```

  Farklı tipte değerler için `NavigationPath` kullanılır.
- `.navigationDestination`'ı `List` / `LazyVStack` gibi **tembel kapların içine** koyma. O kaplar satırları sadece gerektiğinde oluşturur ve stack hedefi göremeyebilir. Kök içeriğe bağla.
- Push edilen bir ekran kendi `NavigationStack`'ini **içermemelidir**; aksi halde iç içe iki navigasyon çubuğu oluşur. `BookDetailView` bu yüzden stack içermez. Hem SwiftUI stack'inden hem de UIKit'te `UIHostingController` ile push edilebilir. (UIKit yolunda `.toolbar` UIKit'in navigasyon çubuğuna taşınmadığı için kalp düğmesi `favoriteButtonPlacement: .header` ile içeriğe alınır; bkz. [UIKit dersi](07-uikit.md).)

### 6. `.task` yaşam döngüsü

```swift
.task {
    await viewModel.load()
}
```

- View ekrana gelmeden önce bir async görev başlatır. View ekrandan kalktıktan sonra SwiftUI görevi **otomatik iptal eder**. Elle `Task` saklayıp `cancel()` çağırmana gerek kalmaz.
- "Ekrandan kalkmak" şunları da kapsar: başka sekmeye geçmek, `NavigationStack` içinde üstüne yeni ekran push edilmesi (kök içerik için). Geri gelindiğinde `.task` **yeniden** çalışır. Bu yüzden `load()` gibi fonksiyonlar **idempotent** tasarlanmalı: "zaten yüklüyse bir şey yapma".
- İptal **işbirlikçidir (cooperative)**: SwiftUI sadece "iptal edildin" bayrağını kaldırır. `Task.sleep` ve `URLSession` gibi API'ler bunu fark edip hata fırlatır. Sen de `CancellationError`'ı kullanıcıya hata olarak göstermemelisin.
- `.task(id: query) { ... }`: `id` değişince önceki görev iptal edilir ve yenisi başlar. Arama kutusu gibi senaryolar için idealdir.
- `onAppear { Task { await load() } }` **yapılandırılmamış** bir görev açar ve view kaybolunca iptal **edilmez**. `.task` neredeyse her zaman daha doğru seçimdir.
- Body içinde yazılan `.task` closure'ı view'in izolasyonunu, yani `@MainActor`'ü devralır. `@MainActor` bir view model'in metodunu çağırırken araya thread atlaması girmez.
- `.refreshable { await viewModel.refresh() }`: Aşağı çekince async closure'ı çalıştırır. Closure bitene kadar yenileme göstergesi döner.

### 7. `List`, `ForEach` ve kimlik

```swift
ForEach(books) { book in ... }   // Book: Identifiable → kimlik = book.id
```

- SwiftUI satırları kimlikleriyle eşleştirir. Kimlik **sabit ve benzersiz** olduğu sürece hangi satırın eklendiğini, silindiğini ya da taşındığını doğru anlar. Animasyonlar ve satır durumu da bozulmaz.
- Dizi indeksiyle (`ForEach(0..<books.count)`) çalışmak, eleman silinince kimliklerin kaymasına yol açar. Benzersiz olmayan bir alanla `id: \.self` kullanmak da aynı soruna yol açar.
- `List` **tembeldir**: sadece ekranda görünen satırları oluşturur. (UI testlerinde de önemli: ekran dışındaki satır erişilebilirlik ağacında yoktur, önce kaydırmak gerekir.)

### 8. Önizlemeler (Previews)

```swift
#Preview("Kitap listesi") {
    BookListView(dependencies: .preview)
}

#Preview("Hata durumu") {
    BookListView(dependencies: AppDependencies(bookService: LocalBookService(simulatesFailure: true)))
}
```

- `#Preview` bir makrodur. Xcode'un kanvasında gerçek kodunu çalıştırır.
- Bağımlılık enjeksiyonu (dependency injection) önizlemeyi kolaylaştırır: ekran bir protokole bağlı olduğu için önizlemeye hızlı ya da hata veren bir servis verebilirsin. Aynı ekranın farklı **durumlarını** yan yana görmek için birden çok `#Preview` yaz.
- Push edilen bir ekranı önizlerken başlık ve araç çubuğunu görmek için onu bir `NavigationStack` içine koy.

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Ne gösteriyor? |
|---|---|---|
| [BookListView.swift](../BookShelf/Features/BookList/BookListView.swift) | `BookListView` | `@State` ile view model sahipliği (`State(initialValue:)`), değer tabanlı `NavigationStack`, iki ayrı `.task`, `.refreshable`, durum enum'una göre `switch`, `ContentUnavailableView` |
| [BookListView.swift](../BookShelf/Features/BookList/BookListView.swift) | `observeFavorites()` | Actor'den gelen `AsyncStream`'i `.task` içinde `for await` ile tüketmek |
| [BookListRow.swift](../BookShelf/Features/BookList/BookListRow.swift) | `BookListRow` | Durumsuz (stateless) satır view'i; `Text` içinde sayı biçimlendirme tuzağı |
| [BookListViewModel.swift](../BookShelf/Features/BookList/BookListViewModel.swift) | `BookListViewModel`, `LoadState` | `@MainActor @Observable` view model, imkânsız durumları engelleyen enum |
| [BookDetailView.swift](../BookShelf/Features/BookDetail/BookDetailView.swift) | `BookDetailView` | Kendi stack'i olmayan push edilebilir ekran, `.toolbar`, `.task`, `@ViewBuilder` ile duruma göre bölümler |
| [BookDetailViewModel.swift](../BookShelf/Features/BookDetail/BookDetailViewModel.swift) | `BookDetailViewModel` | `@Observable` durumu, favori için actor erişimi |
| [RootTabView.swift](../BookShelf/App/RootTabView.swift) | `RootTabView` | `TabView`; her sekme kendi `NavigationStack`'ine sahip |
| [AccessibilityID+BookList.swift](../Shared/AccessibilityID+BookList.swift) | `AccessibilityID.BookList`, `.BookDetail`, `.BookValue` | UI testlerinin kullandığı erişilebilirlik kimlikleri ve sabit değerler |
| [BookListViewModelTests.swift](../BookShelfTests/BookList/BookListViewModelTests.swift) | `BookListViewModelTests` | View model'i SwiftUI açmadan test etmek |

## Sık yapılan hatalar

**1. Sahip olunan nesneyi `@State` olmadan tutmak**

```swift
// YANLIŞ: Üst view her yeniden çizildiğinde yeni bir view model oluşur, yüklenen veri kaybolur.
struct BookListView: View {
    let viewModel = BookListViewModel(service: LocalBookService())
    ...
}

// DOĞRU: SwiftUI nesneyi view'in kimliği boyunca saklar.
struct BookListView: View {
    @State private var viewModel: BookListViewModel
    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: BookListViewModel(service: dependencies.bookService))
    }
}
```

**2. `init` ya da `body` içinde iş başlatmak**

```swift
// YANLIŞ: init defalarca çağrılabilir; her seferinde yeni bir istek başlar ve hiçbiri iptal edilmez.
init(...) {
    Task { await viewModel.load() }
}

// DOĞRU: View görününce başlar, kaybolunca iptal edilir.
.task { await viewModel.load() }
```

**3. `onAppear` + `Task` ile iptali kaybetmek**

```swift
// YANLIŞ: Kullanıcı ekrandan çıksa bile istek sürer ve sonucu artık görünmeyen ekrana yazar.
.onAppear { Task { await viewModel.load() } }

// DOĞRU
.task { await viewModel.load() }
```

**4. İptali hata olarak göstermek**

```swift
// YANLIŞ: Sekme değiştirince kullanıcı bir anlığına "işlem iptal edildi" hatası görür.
do { books = try await service.fetchBooks() }
catch { errorMessage = error.localizedDescription }

// DOĞRU
do { books = try await service.fetchBooks() }
catch is CancellationError { /* sessizce önceki duruma dön */ }
catch { errorMessage = error.localizedDescription }
```

**5. Birden çok `Bool` ile durum modellemek**

```swift
// YANLIŞ: isLoading == true && errorMessage != nil gibi imkânsız bir durum yazılabilir.
var isLoading = false
var errorMessage: String?
var books: [Book] = []

// DOĞRU: Aynı anda tam olarak bir durum.
enum LoadState { case idle, loading, loaded([Book]), failed(message: String) }
```

**6. Push edilen ekrana `NavigationStack` koymak**

```swift
// YANLIŞ: İç içe iki navigasyon çubuğu, bozuk geri düğmesi.
struct BookDetailView: View {
    var body: some View { NavigationStack { List { ... } } }
}

// DOĞRU: Ekran stack'i üst taraftan devralır.
struct BookDetailView: View {
    var body: some View { List { ... }.navigationTitle(book.title) }
}
```

**7. `Text` içinde sayıyı yerelleştirilmiş biçimde basmak**

```swift
// YANLIŞ: Türkçe cihazda "1.972" görünür (binlik ayırıcı).
Text("\(book.year)")

// DOĞRU
Text(String(book.year))   // ya da Text(verbatim: "\(book.year)")
```

## Mülakatta sorulabilecekler

1. **SwiftUI'da view'ler neden `struct`?**
   View bir tarif olduğu için ucuz, kopyalanabilir bir değer tipi yeterlidir. SwiftUI onları sık sık oluşturup atar, diff'ler. Kalıcı durum struct'ta değil, SwiftUI'ın yönettiği depoda (`@State`) ya da dışarıdaki nesnelerde yaşar.

2. **`@State`, `@Binding`, `@Bindable`, `@Environment` farkı nedir?**
   `@State`: view verinin sahibidir. `@Binding`: veri başkasındadır, bu view okuyup yazar. `@Bindable`: başkasına ait bir `@Observable` nesnenin özelliklerine binding üretir. `@Environment`: ağacın yukarısından enjekte edilen değer ya da nesneyi okur.

3. **`@Observable` ile `ObservableObject` arasındaki fark nedir?**
   `@Observable` özellik düzeyinde takip yapar: sadece `body`'de okunan özellik değişince view güncellenir. `ObservableObject` ise nesne düzeyinde `objectWillChange` yayınlar ve izleyen tüm view'ler yeniden hesaplanır. `@Observable` ile `@Published`, `@StateObject` ve `@ObservedObject` gerekmez. iOS 17 ve üstünü gerektirir.

4. **`@Observable` bir sınıfı neden `@State` ile tutarız?**
   İzleme için değil, **sahiplik** için. `@State` nesneyi view'in kimliği boyunca saklar. Başlangıç değeri her `init`'te yeniden oluşturulur ama sadece ilki kullanılır. Bu yüzden `init` ucuz olmalı. `ObservableObject` dünyasındaki karşılığı `@StateObject`'tir.

5. **`.task` ile `onAppear { Task { } }` arasındaki fark nedir?**
   `.task` view kaybolunca görevi otomatik iptal eder; `.task(id:)` ile id değişince yeniden başlatır. `onAppear` içindeki `Task` yapılandırılmamıştır ve iptal edilmez.

6. **View kimliği nedir, `.id()` modifier'ı ne işe yarar?**
   Kimlik, SwiftUI'ın iki güncelleme arasında "bu aynı view mi?" kararıdır. Yapısal kimlik ağaçtaki konumdur. Açık kimlik `ForEach`'teki id'ler ya da `.id(x)` ile verilir. Kimlik değişince durum sıfırlanır ve `.task` yeniden başlar.

7. **`NavigationLink(value:)` + `navigationDestination` neden eski `NavigationLink(destination:)`'dan iyidir?**
   Hedef ekran tembel oluşturulur. Navigasyon durumu bir diziyle (`path`) temsil edildiği için programatik push/pop, derin bağlantı (deep link) ve durum geri yükleme kolaylaşır. Bağlantı ile hedef birbirinden ayrılır.

8. **`some View` ne demek?**
   Opak dönüş tipi. Fonksiyon belirli, tek bir somut tip döndürür ama çağırana adını gizler. Derleyici gerçek tipi bilir, bu yüzden `any View`'deki gibi bir kutulama (existential) maliyeti yoktur.

## Alıştırmalar

1. **Arama ekle.** `BookListView`'e `.searchable(text:)` ekle ve kitapları başlığa ya da yazara göre filtrele.
   *İpucu:* `BookListViewModel`'e `var query = ""` ve filtrelenmiş diziyi döndüren bir hesaplanmış özellik (`var visibleBooks: [Book]`) ekle. View'de `@State` ile tuttuğun view model için `$viewModel.query` doğrudan bir `Binding<String>` verir. Filtreyi büyük/küçük harf ve Türkçe karakterlere duyarsız yapmak için `localizedStandardContains` kullan. Bir de birim testi yaz.

2. **Programatik navigasyon.** Araç çubuğuna "Rastgele kitap" düğmesi ekle; dokununca rastgele bir kitabın detayı açılsın.
   *İpucu:* `@State private var path: [Book] = []` tanımla, `NavigationStack(path: $path)` kullan ve düğmede `path.append(books.randomElement()!)` yerine önce `if let` ile güvenli aç. Detay ekranı zaten `navigationDestination(for: Book.self)` ile tanımlı; ek bir şey gerekmez.

3. **Sıralama seçici.** Listeye "Ada göre / Yıla göre" sıralama seçeneği ekle.
   *İpucu:* `enum SortOrder: CaseIterable, Identifiable` tanımla ve toolbar'a bir `Picker` koy. Sıralamayı view'de değil view model'de bir hesaplanmış özellikte yap. Ardından `BookListViewModelTests`'e sıralamayı doğrulayan bir test ekle. Satırların `id`'si değişmediği için SwiftUI sıralama değişince satırları animasyonla taşıyacaktır; `.animation(.default, value: sortOrder)` ile dene.
