import SwiftUI

/// "Kitaplar" sekmesinin kök ekranı: kitapları yükler, listeler ve detay ekranına geçişi yönetir.
///
/// SwiftUI'da bir `View` ekrandaki piksel değil, ekranın **tarifidir**: küçük, ucuz bir `struct`.
/// SwiftUI bu struct'ı istediği kadar yeniden oluşturabilir ve `body`'yi tekrar tekrar çağırabilir.
/// Bu yüzden kalıcı olması gereken her şey (view model, favori listesi) `@State` ile SwiftUI'ın
/// sakladığı depoda tutulur; struct'ın kendisinde değil.
struct BookListView: View {
    /// Detay ekranına ve favori deposuna aktarmak için saklıyoruz. `AppDependencies` değişmez bir
    /// `struct` olduğu için düz bir `let` yeterli; SwiftUI'ın bunu izlemesine gerek yok.
    private let dependencies: AppDependencies

    /// Neden bir referans tipi (`class`) için `@State`?
    /// `@Observable` nesnelerin değişimleri zaten izlenir; `@State`'in buradaki görevi **sahipliktir**.
    /// SwiftUI, view'in kimliği boyunca (ekranda kaldığı sürece) nesneyi saklar ve struct yeniden
    /// oluşturulsa bile AYNI örneği geri verir. Düz bir `let viewModel = ...` yazsaydık, üst view her
    /// yeniden çizildiğinde yeni bir view model oluşur ve yüklenmiş liste kaybolurdu.
    /// (Eski dünyadaki karşılığı: `ObservableObject` + `@StateObject`.)
    @State private var viewModel: BookListViewModel

    /// Favori kitap id'leri. `FavoritesStore` actor'ündeki AsyncStream'den beslenir (aşağıdaki ikinci `.task`).
    @State private var favoriteIDs: Set<Book.ID> = []

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        // `_viewModel` = property wrapper'ın kendisi (`State<BookListViewModel>`).
        // Dikkat: Bu init her çağrıldığında yeni bir `BookListViewModel` oluşur, ama SwiftUI sadece İLKİNİ
        // saklar; sonrakiler hemen atılır. Bu yüzden view model'in `init`'i ucuz ve yan etkisiz olmalı:
        // ağ isteği init'te değil, `.task` içinde başlar.
        _viewModel = State(initialValue: BookListViewModel(service: dependencies.bookService))
    }

    var body: some View {
        // Değer tabanlı (value-based) navigasyon: `NavigationLink(value:)` sadece bir `Book` değeri yayınlar,
        // hangi ekranın açılacağına `.navigationDestination(for: Book.self)` karar verir.
        // Hedef ekran (`BookDetailView`) ancak satıra dokunulunca oluşturulur; listedeki her satır için değil.
        NavigationStack {
            content
                .navigationTitle("Kitaplar")
                .navigationDestination(for: Book.self) { book in
                    BookDetailView(book: book, dependencies: dependencies)
                }
        }
        // `.task`, view ekrana gelmeden hemen önce bir async görev başlatır ve view ekrandan kalkınca
        // (ör. başka sekmeye geçince) o görevi OTOMATİK iptal eder. Elle `Task` tutup `cancel()` çağırmaya
        // gerek kalmaz. Görev ana actor'de başlar (View `@MainActor`), `load()` da `@MainActor` olduğu için
        // araya thread atlaması girmez.
        //
        // İkisini de `NavigationStack`'e bağladık, liste içeriğine değil: detay ekranı push edildiğinde
        // kök içerik "kaybolmuş" sayılır; `.task` orada olsaydı devam eden yükleme iptal olurdu.
        .task {
            await viewModel.load()
        }
        .task {
            await observeFavorites()
        }
    }

    // MARK: - Durumlara göre içerik

    /// `@ViewBuilder` sayesinde `switch`'in her kolu farklı tipte bir view döndürebilir.
    /// Durum bir enum olduğu için derleyici her durumu ele aldığımızı garanti eder.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Kitaplar yükleniyor…")
                .accessibilityIdentifier(AccessibilityID.BookList.loadingIndicator)
        case .loaded(let books):
            bookList(books)
        case .failed(let message):
            errorView(message: message)
        }
    }

    private func bookList(_ books: [Book]) -> some View {
        List {
            if let refreshErrorMessage = viewModel.refreshErrorMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .accessibilityHidden(true)
                        Text(refreshErrorMessage)
                            .accessibilityIdentifier(AccessibilityID.BookList.refreshErrorBanner)
                    }
                    .foregroundStyle(.orange)
                }
            }

            Section {
                // `ForEach(books)`: `Book` `Identifiable` olduğu için her satırın kimliği `book.id`'dir.
                // Kimlik sabit olduğu sürece SwiftUI hangi satırın eklendiğini/silindiğini/taşındığını doğru
                // anlar ve satır durumunu (animasyon, seçim) karıştırmaz.
                ForEach(books) { book in
                    let isFavorite = favoriteIDs.contains(book.id)
                    NavigationLink(value: book) {
                        BookListRow(book: book, isFavorite: isFavorite)
                    }
                    .accessibilityIdentifier(AccessibilityID.BookList.row(bookID: book.id))
                    .accessibilityValue(isFavorite ? AccessibilityID.BookValue.favorite : "")
                }
            } footer: {
                Text("\(books.count) kitap · Yenilemek için aşağı çekin")
            }
        }
        .overlay {
            if books.isEmpty {
                ContentUnavailableView("Henüz kitap yok", systemImage: "books.vertical")
            }
        }
        .accessibilityIdentifier(AccessibilityID.BookList.list)
        // `.refreshable` aşağı çekince async kapanışı çalıştırır; kapanış bitene kadar gösterge döner.
        .refreshable {
            await viewModel.refresh()
        }
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Kitaplar yüklenemedi", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
                .accessibilityIdentifier(AccessibilityID.BookList.errorMessage)
        } actions: {
            Button("Tekrar Dene") {
                // Düğme aksiyonları senkrondur; async bir fonksiyonu çağırmak için yapılandırılmamış
                // (unstructured) bir `Task` açıyoruz. Bu Task ana actor'ü devralır ama `.task`'ın aksine
                // view kaybolunca otomatik İPTAL EDİLMEZ; kısa bir istek için bu kabul edilebilir.
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(AccessibilityID.BookList.retryButton)
        }
        // `.contain`: Hata ekranı kimliği olan bir KAP (container) olur; içindeki metin ve düğme kendi
        // kimliklerini korur. Bunu yazmasaydık üstteki kimlik alt öğelere yayılıp onlarınkini ezebilirdi.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.BookList.errorView)
    }

    // MARK: - Favoriler (AsyncStream tüketimi)

    /// `FavoritesStore.changes()` bir `AsyncStream<Set<Book.ID>>` döndürür: abone olunca mevcut kümeyi,
    /// sonra her değişiklikte yeni kümeyi yayınlar.
    ///
    /// - `await dependencies.favorites.changes()`: `favorites` bir actor; dışarıdan her çağrı `await` ister.
    /// - `for await`: Akıştan yeni değer gelene kadar ASKIDA bekler (thread'i bloklamaz). Döngü biz
    ///   durdurmadıkça bitmez; bu yüzden ayrı bir `.task` içinde çalışıyor.
    /// - View ekrandan kalkınca `.task` iptal edilir → `for await` döngüsü biter → akışın `onTermination`'ı
    ///   çalışır ve actor bu dinleyiciyi listesinden siler. Sızıntı (leak) olmaz.
    /// - Döngü gövdesi ana actor'de çalışır, yani `@State`'e doğrudan yazabiliriz.
    private func observeFavorites() async {
        for await ids in await dependencies.favorites.changes() {
            favoriteIDs = ids
        }
    }
}

#Preview("Kitap listesi") {
    BookListView(dependencies: .preview)
}

#Preview("Hata durumu") {
    BookListView(dependencies: AppDependencies(bookService: LocalBookService(simulatesFailure: true)))
}
