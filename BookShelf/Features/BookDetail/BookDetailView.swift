import SwiftUI

/// Kitap detay ekranı.
///
/// Sözleşme: Kendi `NavigationStack`'ini İÇERMEZ. İki farklı yerden push edilir:
/// - SwiftUI: `BookListView`'deki `NavigationStack` → `.navigationDestination(for: Book.self)`
/// - UIKit: Favoriler ekranı bu view'i bir `UIHostingController`'a sarıp `UINavigationController`'a push eder.
/// İçeride ikinci bir `NavigationStack` olsaydı iç içe iki navigasyon çubuğu oluşurdu.
///
/// Dikkat: `.navigationTitle` ve `.toolbar`, SwiftUI'ın `NavigationStack`'inde navigasyon çubuğuna yansır.
/// UIKit'in `UINavigationController`'ına push edilen `UIHostingController`'da ise bu projede SwiftUI ne başlığı ne de
/// araç çubuğu düğmesini UIKit çubuğuna aktarıyor (iOS 26.2 simülatöründe XCUITest ile doğrulandı: kalp düğmesi
/// erişilebilirlik ağacında hiç yoktu). Bu yüzden UIKit tarafı başlığı `title` ile kendisi verir, kalp düğmesi de
/// `FavoriteButtonPlacement.header` ile içeriğe taşınır.
struct BookDetailView: View {
    /// Favori (kalp) düğmesinin ekrandaki yeri.
    ///
    /// Tip `BookDetailView`'in içinde (iç içe tip): Tüm ekranlar aynı modülde derlendiği için bu ad başka bir
    /// ekranın tipiyle çakışmaz ve kullanım yerinde `BookDetailView.FavoriteButtonPlacement` diye kendini açıklar.
    enum FavoriteButtonPlacement {
        /// Navigasyon çubuğunda (`.toolbar`). SwiftUI `NavigationStack`'inden push edildiğinde.
        case navigationBar
        /// İçerikte, başlık bölümünün altında ayrı bir satır. UIKit'ten (`UIHostingController`) push edildiğinde.
        case header
    }

    /// Neden `@State`? `BookListView`'deki açıklamanın aynısı: SwiftUI bu view yaşadığı sürece aynı view model
    /// örneğini saklar. Ekran kapanınca (pop) view model de serbest kalır.
    @State private var viewModel: BookDetailViewModel

    /// Kalp düğmesinin yeri. Ekran yaşadığı sürece değişmez; bu yüzden `@State` değil, düz bir `let`.
    private let favoriteButtonPlacement: FavoriteButtonPlacement

    /// - Parameter favoriteButtonPlacement: Varsayılan `.navigationBar` (SwiftUI). UIKit'ten açan ekran `.header` verir.
    init(book: Book, dependencies: AppDependencies, favoriteButtonPlacement: FavoriteButtonPlacement = .navigationBar) {
        _viewModel = State(initialValue: BookDetailViewModel(
            book: book,
            service: dependencies.bookService,
            favorites: dependencies.favorites
        ))
        self.favoriteButtonPlacement = favoriteButtonPlacement
    }

    private var book: Book { viewModel.book }

    var body: some View {
        List {
            headerSection
            infoSection
            summarySection
            extrasSections
        }
        // UI testleri kaydırmayı bu kaba (container) uygular: alttaki yorumlar ve yazar bölümü `List` tembel
        // (lazy) olduğu için ekrana gelene kadar erişilebilirlik ağacında yoktur.
        .accessibilityIdentifier(AccessibilityID.BookDetail.list)
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // `ToolbarContentBuilder` iOS 16'dan beri `if` destekler. Düğme yalnızca çubukta gösterilecekse eklenir;
            // böylece aynı kimliğe sahip iki düğme hiçbir zaman aynı anda ekranda olmaz.
            if favoriteButtonPlacement == .navigationBar {
                ToolbarItem(placement: .topBarTrailing) {
                    favoriteButton
                }
            }
        }
        // Ekran açılınca yükle; geri dönülünce (pop) SwiftUI görevi iptal eder. İptal, `async let` ile başlayan
        // alt görevlere de yayılır, yani yarıda kalan istekler boşuna çalışmaya devam etmez.
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Bölümler

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.title2.bold())
                    .accessibilityIdentifier(AccessibilityID.BookDetail.title)
                Text(book.author)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.BookDetail.author)
                // `String(...)`: yılın "1.972" diye binlik ayırıcıyla yazılmasını önler (BookListRow'daki nota bak).
                Text("\(String(book.year)) · \(book.pageCount) sayfa")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            if favoriteButtonPlacement == .header {
                // Satırda tek bir `Button` olduğu için `List` bütün satırı dokunulabilir yapar.
                favoriteButton
            }
        }
    }

    private var infoSection: some View {
        Section {
            HStack {
                Text("ISBN")
                Spacer()
                Text(book.isbn)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Doğrulama")
                Spacer()
                BookDetailISBNBadge(isValid: viewModel.isISBNValid)
            }
            HStack {
                Text("Tahmini okuma süresi")
                Spacer()
                Text(viewModel.readingTimeText)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.BookDetail.readingTime)
            }
        } header: {
            Text("Kitap bilgileri")
        } footer: {
            Text("ISBN doğrulaması ve okuma süresi Objective-C sınıflarıyla (BKISBNValidator, BKReadingTimeEstimator) hesaplanıyor.")
        }
    }

    private var summarySection: some View {
        Section("Özet") {
            Text(book.summary)
        }
    }

    /// Yorumlar, yazar ve süre bölümleri: `extras` durumuna göre değişir.
    @ViewBuilder
    private var extrasSections: some View {
        switch viewModel.extras {
        case .idle, .loading:
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                        .accessibilityIdentifier(AccessibilityID.BookDetail.extrasLoading)
                    Text("Yorumlar ve yazar bilgisi yükleniyor…")
                        .foregroundStyle(.secondary)
                }
            }
        case .loaded(let extras):
            reviewsSection(extras.reviews)
            authorSection(extras.author)
            timingSection(extras.timing)
        case .failed(let message):
            Section {
                Text(message)
                    .accessibilityIdentifier(AccessibilityID.BookDetail.extrasError)
                Button("Tekrar Dene") {
                    Task { await viewModel.load() }
                }
                .accessibilityIdentifier(AccessibilityID.BookDetail.extrasRetryButton)
            } header: {
                Text("Yorumlar ve yazar")
            }
        }
    }

    private func reviewsSection(_ reviews: [Review]) -> some View {
        Section("Yorumlar") {
            if reviews.isEmpty {
                Text("Henüz yorum yok.")
                    .foregroundStyle(.secondary)
            }
            ForEach(reviews) { review in
                BookDetailReviewRow(review: review)
                    // `.combine`: satırdaki metinler VoiceOver için tek bir öğede birleşir ("Ayşe, 5 üzerinden 5, ...").
                    // Kimliği de bu birleşik öğeye veriyoruz.
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(AccessibilityID.BookDetail.review(id: review.id))
            }
        }
    }

    private func authorSection(_ author: AuthorProfile) -> some View {
        Section("Yazar") {
            VStack(alignment: .leading, spacing: 6) {
                Text(author.name)
                    .font(.headline)
                Text(author.bio)
                    .accessibilityIdentifier(AccessibilityID.BookDetail.authorBio)
                Text("Kitaplıkta bu yazarın \(author.bookCount) kitabı var.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    private func timingSection(_ timing: BookDetailViewModel.LoadTiming) -> some View {
        Section {
            Text(timing.totalText)
                .accessibilityIdentifier(AccessibilityID.BookDetail.loadDuration)
            Text(timing.breakdownText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Paralel yükleme (async let)")
        } footer: {
            Text("Yorumlar ve yazar profili aynı anda istendi. Toplam süre en yavaş isteğe yakındır; istekler sırayla yapılsaydı ikisinin toplamı kadar sürerdi.")
        }
    }

    private var favoriteButton: some View {
        let actionTitle = viewModel.isFavorite ? "Favorilerden çıkar" : "Favorilere ekle"
        let symbol = viewModel.isFavorite ? "heart.fill" : "heart"
        return Button {
            // Düğme aksiyonu senkron; actor'e `await` ile erişmek için kısa ömürlü bir `Task` açıyoruz.
            Task { await viewModel.toggleFavorite() }
        } label: {
            switch favoriteButtonPlacement {
            case .navigationBar:
                // Çubukta yer dar: yalnızca simge. Anlamını `accessibilityLabel` taşır.
                Image(systemName: symbol)
                    .foregroundStyle(.red)
            case .header:
                // İçerikte yer var: simge + metin, ne yapacağı ilk bakışta okunsun. Kalp, çubuktaki gibi kırmızı.
                Label {
                    Text(actionTitle)
                } icon: {
                    Image(systemName: symbol)
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityLabel(actionTitle)
        // UI testleri durumu `value` üzerinden doğrular: "Favori" / "Favori değil".
        .accessibilityValue(viewModel.isFavorite ? AccessibilityID.BookValue.favorite : AccessibilityID.BookValue.notFavorite)
        .accessibilityIdentifier(AccessibilityID.BookDetail.favoriteButton)
    }
}

// MARK: - Küçük yardımcı view'ler
// `private`: Sadece bu dosyada görünürler. Tüm ekranlar aynı modülde derlendiği için adlarına yine de
// `BookDetail` öneki verdik; başka bir dosyadaki aynı adlı tiple karışma ihtimali tamamen kalmasın.

/// Objective-C doğrulayıcısının sonucunu yeşil/kırmızı bir rozetle gösterir.
private struct BookDetailISBNBadge: View {
    let isValid: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                .accessibilityHidden(true)
            Text(isValid ? AccessibilityID.BookValue.isbnValid : AccessibilityID.BookValue.isbnInvalid)
                .accessibilityIdentifier(AccessibilityID.BookDetail.isbnStatus)
        }
        .font(.caption.bold())
        .foregroundStyle(isValid ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isValid ? Color.green : Color.red).opacity(0.15), in: Capsule())
    }
}

/// Tek bir okur yorumu: ad, yıldızlar ve yorum metni.
private struct BookDetailReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(review.reviewer)
                    .font(.subheadline.bold())
                Spacer()
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= review.rating ? "star.fill" : "star")
                    }
                }
                .font(.caption)
                .foregroundStyle(.orange)
                // Beş ayrı "yıldız" resmi yerine tek, anlamlı bir etiket okunsun.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("5 üzerinden \(review.rating) puan")
            }
            Text(review.comment)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        BookDetailView(
            book: Book(
                id: 1, title: "Tutunamayanlar", author: "Oğuz Atay", year: 1972,
                isbn: "978-605-000-001-6", pageCount: 724,
                summary: "Selim Işık'ın intiharıyla başlayan, çok katmanlı bir roman."
            ),
            dependencies: .preview
        )
    }
}
