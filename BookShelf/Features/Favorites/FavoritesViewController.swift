import SwiftUI
import UIKit

/// "Favoriler" sekmesinin **UIKit** ile, storyboard kullanmadan (tamamen kodla) yazılmış ekranı.
///
/// SwiftUI'da "durum şu, arayüz şöyle görünsün" deriz ve farkları framework hesaplar (*declarative*).
/// UIKit'te ise view'ları kendimiz oluşturur, hiyerarşiye ekler ve her değişiklikte "şunu gizle, şunu göster,
/// tabloyu güncelle" diye tek tek komut veririz (*imperative*). Bu dosya o komutların hepsini tek bir
/// `render(_:)` metodunda toplayarak karmaşayı sınırlı tutuyor.
///
/// Veri akışı (tek doğruluk kaynağı = `FavoritesStore` actor'ü):
/// ```
/// FavoritesStore (actor) ──AsyncStream<Set<Book.ID>>──▶ observationTask ──render──▶ UITableView
///        ▲                                                                              │
///        └──────────────── Task { await favorites.remove(id) } ◀── "Kaldır" kaydırması ─┘
/// ```
/// Ekran tabloyu **kendisi** değiştirmez; sadece actor'e "şunu kaldır" der. Actor yeni kümeyi yayınlar,
/// dinleyen task tabloyu günceller. Böylece Kitaplar sekmesindeki kalp düğmesi, detay ekranı ve bu ekran
/// aynı veriyi görür ve hiçbir yerde "tablo başka, actor başka şey söylüyor" tutarsızlığı oluşmaz.
///
/// Neden `final`? Bu sınıftan türetilmesini (subclass) istemiyoruz. `final`, derleyicinin metot çağrılarını
/// dinamik yerine statik bağlamasına da izin verir.
///
/// İzolasyon: `UIViewController` SDK'da `@MainActor` olarak işaretlidir; ondan türeyen bu sınıf da, tüm
/// metotları ve özellikleriyle birlikte, otomatik olarak **ana actor**'e (main thread) bağlıdır.
final class FavoritesViewController: UIViewController {

    /// Diffable data source'un bölüm (section) tipi. Tek bölümümüz var.
    /// Bölüm ve öğe tipleri `Hashable` olmalıdır (güncel SDK'larda ayrıca `Sendable`); parametresiz bir `enum`
    /// ikisini de derleyiciden bedava alır. Öğe tipimiz ise doğrudan `Book` (o da `Hashable` + `Sendable`).
    enum Section: Hashable {
        case main
    }

    /// Uzun generic tip adlarına kısa takma adlar (typealias). Yeni bir tip OLUŞTURMAZLAR: Derleyici için `Snapshot`
    /// ile `NSDiffableDataSourceSnapshot<Section, Book>` birebir aynı tiptir. Bölüm ya da öğe tipi değişirse tek yerden güncellenir.
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Book>
    typealias DataSource = UITableViewDiffableDataSource<Section, Book>

    private static let cellReuseIdentifier = "FavoriteBookCell"

    // MARK: - Bağımlılıklar ve durum

    private let dependencies: AppDependencies

    /// Ekranın şu anki durumu. Yalnızca `render(_:)` değiştirir.
    private(set) var state: FavoritesState = .loading

    /// Favorileri dinleyen uzun ömürlü task. Ekran görünürken çalışır, kaybolunca iptal edilir.
    ///
    /// Referansını saklıyoruz çünkü `Task { }` ile oluşturulan (yapısal olmayan / *unstructured*) bir task'ın
    /// ömrü hiçbir kapsama (scope) bağlı değildir: onu biz iptal etmezsek, dinlediği akış bitene kadar
    /// (yani bu uygulamada **hiçbir zaman**) çalışmaya devam eder. `internal` okunabilir olması testler içindir.
    private(set) var observationTask: Task<Void, Never>?

    // MARK: - View'lar
    //
    // Bu view'lar `private` değil, `internal` (Swift'in varsayılanı): testler `@testable import BookShelf` ile
    // onlara erişip "boş durum mesajı görünüyor mu?" gibi sorular sorabilsin diye. Modül dışına açık değiller.

    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    let emptyStateLabel = UILabel()
    let errorLabel = UILabel()
    let retryButton = UIButton(configuration: .filled())
    let loadingIndicator = UIActivityIndicatorView(style: .large)

    /// Yükleniyor / boş / hata görünümlerini alt alta dizen yığın. `UIStackView`, gizlenen (`isHidden`)
    /// elemanlarını otomatik olarak yerleşimden çıkarır; bu yüzden hangisi görünürse ortada o durur.
    private let statusStack = UIStackView()

    /// Navigasyon çubuğundaki "Tümünü temizle" düğmesi.
    ///
    /// `UIAction` (iOS 14+), olayı bir closure ile karşılar. Klasik yöntem **target-action**'dır:
    /// `UIBarButtonItem(title:style:target:action:)` + `@objc` bir metot + `#selector(...)`.
    /// İkisini karşılaştırmak için `retryButton`'a bak; orada bilerek klasik yöntemi kullanıyoruz.
    ///
    /// `lazy`: `self`'e referans veren bir closure içerdiği için, `self` tamamen oluşmadan (init sırasında)
    /// kurulamaz; ilk erişimde (viewDidLoad'da) kurulur. Closure'daki `[weak self]`, VC → düğme → action →
    /// closure → VC şeklinde bir **retain cycle** (döngüsel güçlü referans) oluşmasını engeller.
    private(set) lazy var clearAllButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            title: "Tümünü temizle",
            primaryAction: UIAction { [weak self] _ in
                self?.presentClearAllConfirmation()
            }
        )
        item.accessibilityIdentifier = AccessibilityID.Favorites.clearAllButton
        return item
    }()

    /// Tabloya veriyi sağlayan diffable data source.
    ///
    /// Eski yöntemde (`UITableViewDataSource` + `reloadData()`) "kaç satır var?" ve "şu satırda ne var?"
    /// sorularına kendimiz cevap verir, veri değişince ya tabloyu komple yeniden yükler (`reloadData`, animasyonsuz)
    /// ya da `insertRows/deleteRows` çağrılarını elle hesaplardık. Bu hesabı yanlış yapmak meşhur
    /// "Invalid update: invalid number of rows" çökmesine yol açar.
    ///
    /// Diffable data source'ta ise tablonun **olması gereken halini** bir *snapshot* olarak veririz; neyin eklendiğini,
    /// silindiğini, yer değiştirdiğini kendisi hesaplar ve animasyonla uygular. Bunu yapabilmek için öğeleri
    /// `Hashable` ile ayırt eder: iki snapshot'taki `Book` değerleri eşitse (`==`) "aynı satır" sayılır.
    ///
    /// `lazy` çünkü `tableView`'a ihtiyaç duyuyor; ilk erişim `viewDidLoad` içinde olur.
    private lazy var dataSource = Self.makeDataSource(for: tableView)

    // MARK: - Yaşam döngüsü (lifecycle)

    /// Bağımlılıkları dışarıdan alıyoruz (*dependency injection*); testlerde sahte servis verebilmek için.
    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
    }

    /// Storyboard/XIB'den oluşturma için gereken başlatıcı. Biz ekranı kodla kurduğumuz için desteklemiyoruz.
    /// `@available(*, unavailable)`, onu Swift kodundan çağırmayı derleme hatası yapar.
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("FavoritesViewController storyboard'dan değil, kodla oluşturulur.")
    }

    /// Nesne bellekten silinirken çağrılır. Güvenlik ağı: ekran hiç "kaybolmadan" yok edilirse
    /// (ör. SwiftUI bu sekmeyi ağaçtan kaldırırsa) dinleyici task'ı burada durdururuz.
    ///
    /// Swift 6 notu: `deinit` varsayılan olarak **nonisolated**'dır; sınıf `@MainActor` olsa bile hangi thread'de
    /// çalışacağı garanti değildir (son güçlü referans hangi thread'de bırakıldıysa orada çalışır). Bu yüzden burada
    /// ana actor'e bağlı metotları (ör. `stopObservingFavorites()`) çağıramayız. `observationTask`'a erişebiliyoruz,
    /// çünkü `deinit` sırasında nesneye başka kimse erişemez ve `Task` tipi `Sendable`'dır;
    /// `Task.cancel()` da her thread'den çağrılabilen, thread-safe bir işlemdir.
    ///
    /// Alternatif: Swift 6.2 ile gelen `isolated deinit` (SE-0371), gövdeyi ana actor'de çalıştırır (gerekirse
    /// oraya zamanlar). Burada gerek yok; yaptığımız tek iş her thread'den güvenli olan `cancel()`.
    deinit {
        observationTask?.cancel()
    }

    /// View hiyerarşisi belleğe yüklendikten sonra **bir kez** çağrılır. Tek seferlik kurulum burada yapılır:
    /// view'ları oluşturmak, constraint'leri eklemek, delegate'leri bağlamak.
    /// Burada henüz ekranda değiliz ve boyutlar kesin değil; boyuta bağlı hesaplar için erken.
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Favoriler"
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = clearAllButton
        view.backgroundColor = .systemGroupedBackground

        configureTableView()
        configureStatusViews()
        configureLayout()
        render(state)
    }

    /// Ekran her görünür olmak üzereyken çağrılır (sekmeye her dönüşte, detaydan her geri gelişte).
    /// `viewDidLoad`'un aksine **birçok kez** çağrılabilir. Dinlemeyi burada başlatıyoruz ki
    /// ekran görünür görünmez güncel veri gelsin.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startObservingFavorites()
    }

    /// Ekran tamamen kaybolduktan sonra çağrılır (başka sekmeye geçildi ya da üstüne detay push edildi).
    ///
    /// Neden `viewWillDisappear` değil? "Kaybolacak" demek kesin değildir: kullanıcı detay ekranını parmağıyla
    /// geri kaydırmaya başlayıp vazgeçebilir (interaktif geçiş iptal edilir). `viewDidDisappear` ise geçişin
    /// gerçekten tamamlandığını bildirir. Görünmeyen bir ekranın tabloyu güncellemesi boşa iştir; dinlemeyi keseriz.
    /// Geri dönüldüğünde `viewWillAppear` yeni bir task başlatır ve akış güncel durumu hemen yayınlar.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopObservingFavorites()
    }

    // MARK: - Favorileri dinleme (async/await + actor + AsyncStream)

    /// Kataloğu bir kez yükleyen ve ardından favori değişikliklerini dinleyen TEK task'ı başlatır.
    private func startObservingFavorites() {
        // Zaten dinliyorsak ikinci bir task açma; yoksa iki task aynı tabloyu güncellemeye çalışırdı.
        guard observationTask == nil else { return }

        // Daha önce yüklenmiş bir liste varsa onu göstermeye devam et (ekran yanıp sönmesin);
        // yoksa (ilk açılış veya hata sonrası) yükleniyor göstergesini aç.
        if !state.isLoaded {
            render(.loading)
        }

        // Task'ın ihtiyaç duyduğu değerleri yerel sabitlere kopyalıyoruz. Böylece task, bunlara ulaşmak için
        // `self`'e muhtaç kalmaz. İkisi de `Sendable` (servis protokolü `Sendable`, actor her zaman `Sendable`).
        let bookService = dependencies.bookService
        let favorites = dependencies.favorites

        // `Task { }` onu oluşturan bağlamın actor'ünü **miras alır**. `UIViewController` `@MainActor` olduğu için
        // bu task'ın gövdesi de ana actor'de çalışır: `render` çağrısı güvenlidir, ekstra `MainActor.run` gerekmez.
        // `await` noktalarında ise task askıya alınır ve ana thread serbest kalır (UI donmaz).
        //
        // `[weak self]`: Task, closure'ını ve yakaladıklarını bitene kadar tutar. Bu task sonsuz bir
        // `for await` döngüsü içerdiğinden `self`'i güçlü (strong) yakalasaydı VC **hiç bellekten silinmezdi**
        // (deinit hiç çalışmaz, dolayısıyla task'ı iptal eden kod da hiç çalışmazdı).
        observationTask = Task { [weak self] in
            // 1) Kataloğu bir kez yükle. Gerçek servis (`LocalBookService`) nonisolated olduğu için JSON çözme
            //    ana thread'de değil, global concurrent executor'de (arka plan thread havuzu) çalışır.
            //    Biz beklerken ana thread serbesttir.
            let catalog: [Book]
            do {
                catalog = try await bookService.fetchBooks()
            } catch {
                // İptal bir hata değildir: ekran kayboldu, kullanıcıya hata gösterme.
                guard !Task.isCancelled else { return }
                self?.render(.failed(message: error.localizedDescription))
                return
            }

            // 2) Favori değişikliklerini dinle. Akış, abone olunduğu anda mevcut kümeyi hemen bir kez yayınlar,
            //    sonra her değişiklikte yenisini. Task iptal edilince `for await` döngüsü biter ve
            //    `FavoritesStore`'daki `onTermination` dinleyiciyi temizler.
            for await favoriteIDs in await favorites.changes() {
                // `self`'i yalnızca bu tur için güçlü hale getiriyoruz. Tur bitince güçlü referans bırakılır;
                // bir sonraki değeri beklerken (askıdayken) task VC'yi hayatta TUTMAZ.
                // Yanlış kalıp: döngüden ÖNCE `guard let self` yazmak; o zaman güçlü referans döngü boyunca,
                // yani sonsuza dek yaşar.
                //
                // `Task.isCancelled` kontrolü: İptal işbirlikçidir (cooperative); iptal sadece bir bayraktır.
                // `AsyncStream` iptalde bitse bile, tamponunda bekleyen son değeri yine de teslim edebilir.
                // İptal edilmiş bir task'ın görünmeyen tabloyu güncellemesini istemiyoruz.
                guard let self, !Task.isCancelled else { return }
                self.render(.from(catalog: catalog, favoriteIDs: favoriteIDs))
            }
        }
    }

    /// Dinleyici task'ı iptal eder. `cancel()` task'ı zorla durdurmaz, iptal bayrağını kaldırır;
    /// `for await` ise bu bayrağa tepki vererek döngüden çıkar.
    private func stopObservingFavorites() {
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - Durumu ekrana yansıtma

    /// Ekranı verilen duruma getiren TEK yer. UIKit'te görünümleri elle güncellediğimiz için
    /// bu işi tek bir metotta toplamak, "şu durumda şu label gizli kalmış" türü hataları önler.
    private func render(_ newState: FavoritesState) {
        state = newState

        // Snapshot: tablonun olması gereken hali. Her seferinde sıfırdan kurmak ucuzdur ve hatasızdır;
        // farkı (diff) data source hesaplar.
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(newState.books, toSection: .main)
        // Ekranda değilken (ör. testlerde veya ilk kurulumda) animasyona gerek yok.
        dataSource.apply(snapshot, animatingDifferences: viewIfLoaded?.window != nil)

        if newState.isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating() // `hidesWhenStopped` varsayılan olarak `true`: durunca gizlenir.
        }
        emptyStateLabel.isHidden = !newState.showsEmptyMessage
        errorLabel.text = newState.errorMessage
        errorLabel.isHidden = newState.errorMessage == nil
        retryButton.isHidden = newState.errorMessage == nil
        // Satırlar görünürken yığını tamamen gizliyoruz; aksi halde ortadaki (boş) yığın dokunuşları yakalayabilirdi.
        statusStack.isHidden = !newState.books.isEmpty
        clearAllButton.isEnabled = newState.canClearAll
    }

    // MARK: - Kullanıcı eylemleri

    /// Klasik **target-action**: "Olay olunca `target` nesnesinin `action` metodunu çağır."
    /// Metot adı çalışma anında Objective-C mesajı olarak gönderildiği için `@objc` olmak zorundadır
    /// ve `#selector(...)` ile derleme anında adı doğrulanır. `UIControl` hedefini (`target`) **zayıf** tutar;
    /// bu yüzden target-action'da retain cycle oluşmaz.
    @objc private func retryButtonTapped() {
        stopObservingFavorites()
        startObservingFavorites()
    }

    private func presentClearAllConfirmation() {
        present(makeClearAllConfirmation(), animated: true)
    }

    /// "Tümünü temizle" için onay penceresi. Geri alınamayan işlemlerden önce onay istemek iyi bir UX alışkanlığıdır.
    /// Oluşturma ayrı bir metotta, çünkü pencereyi göstermeden (pencere/window gerektirmeden) test edebilmek istiyoruz.
    func makeClearAllConfirmation() -> UIAlertController {
        let alert = UIAlertController(
            title: "Tüm favoriler kaldırılsın mı?",
            message: "Favori listendeki bütün kitaplar kaldırılacak. Kitapların kendisi silinmez.",
            preferredStyle: .alert
        )
        alert.view.accessibilityIdentifier = AccessibilityID.Favorites.clearAllAlert

        let cancel = UIAlertAction(title: "Vazgeç", style: .cancel)
        cancel.accessibilityIdentifier = AccessibilityID.Favorites.clearAllCancelButton

        let confirm = UIAlertAction(title: "Tümünü kaldır", style: .destructive) { [weak self] _ in
            self?.clearAllFavorites()
        }
        confirm.accessibilityIdentifier = AccessibilityID.Favorites.clearAllConfirmButton

        alert.addAction(cancel)
        alert.addAction(confirm)
        return alert
    }

    /// Tüm favorileri actor'den kaldırır. Tabloyu burada güncellemiyoruz: her `remove` sonrası actor yeni kümeyi
    /// yayınlar ve dinleyici task tabloyu günceller (tek doğruluk kaynağı).
    ///
    /// `FavoritesStore`'da toplu silme API'si yok; tek tek `remove` çağırıyoruz. Her çağrı ayrı bir `await`,
    /// yani aralarda başka işler (ör. başka bir ekrandan `add`) araya girebilir (*actor reentrancy*).
    /// Actor'e senkron bir `removeAll()` eklemek bunu tek, atomik bir işlem yapardı.
    ///
    /// Bu task'ı saklamıyor ve iptal etmiyoruz: kullanıcı "temizle" dedi, ekrandan çıksa bile işlem bitmeli.
    /// Kısa ömürlüdür ve `self`'i yakalamaz; sızıntı riski yok. Task'ı döndürmemizin tek sebebi,
    /// testlerin `await task.value` ile bitmesini bekleyebilmesi.
    @discardableResult
    func clearAllFavorites() -> Task<Void, Never> {
        let favorites = dependencies.favorites
        return Task {
            for bookID in await favorites.allIDs {
                await favorites.remove(bookID)
            }
        }
    }

    // MARK: - Kurulum

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.accessibilityIdentifier = AccessibilityID.Favorites.table
        // Hücre sınıfını bir "yeniden kullanım kimliği" ile kaydediyoruz; `dequeueReusableCell` bu kimlikle
        // ya ekrandan çıkmış eski bir hücreyi geri verir ya da yenisini oluşturur (bkz. `makeDataSource`).
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
        // Delegate kalıbı: tablo "bu satıra dokunuldu", "bu satırda hangi kaydırma eylemleri var?" gibi
        // soruları/olayları `delegate`'ine iletir. `delegate` özelliği `weak`'tir; retain cycle oluşmaz.
        tableView.delegate = self
        // Diffable data source kendi init'inde kendini zaten tablonun `dataSource`'u yapar; bu satır
        // ilişkiyi görünür kılmak ve lazy özelliği burada oluşturmak için.
        tableView.dataSource = dataSource
        view.addSubview(tableView)
    }

    private func configureStatusViews() {
        loadingIndicator.accessibilityIdentifier = AccessibilityID.Favorites.loadingIndicator
        loadingIndicator.accessibilityLabel = "Yükleniyor"

        emptyStateLabel.text = "Henüz favori kitabın yok. Kitaplar sekmesinde bir kitabın kalp simgesine dokun."
        emptyStateLabel.accessibilityIdentifier = AccessibilityID.Favorites.emptyState
        errorLabel.accessibilityIdentifier = AccessibilityID.Favorites.errorMessage
        for label in [emptyStateLabel, errorLabel] {
            label.font = .preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true // Dynamic Type: kullanıcının yazı boyutu ayarına uy.
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            label.numberOfLines = 0 // 0 = satır sınırı yok; metin sığmazsa alt satıra geçer.
        }

        var retryConfiguration = UIButton.Configuration.filled()
        retryConfiguration.title = "Tekrar dene"
        retryConfiguration.image = UIImage(systemName: "arrow.clockwise")
        retryConfiguration.imagePadding = 6
        retryButton.configuration = retryConfiguration
        retryButton.accessibilityIdentifier = AccessibilityID.Favorites.retryButton
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)

        statusStack.axis = .vertical
        statusStack.alignment = .center
        statusStack.spacing = 16
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        for subview in [loadingIndicator, emptyStateLabel, errorLabel, retryButton] {
            statusStack.addArrangedSubview(subview)
        }
        view.addSubview(statusStack)
    }

    /// Programatik Auto Layout.
    ///
    /// - `translatesAutoresizingMaskIntoConstraints = false`: Varsayılan (`true`) durumda UIKit, view'ın `frame`'ini
    ///   sabitleyen otomatik constraint'ler üretir; bizimkilerle çakışıp "Unable to simultaneously satisfy constraints"
    ///   uyarısına yol açar. Kodla constraint yazdığımız her view için `false` yaparız.
    ///   (`addArrangedSubview` ile yığına eklenen view'larda bunu `UIStackView` kendisi ayarlar.)
    /// - Anchor'lar (`topAnchor`, `leadingAnchor`, ...) tip güvenlidir: yatay bir anchor'ı dikey bir anchor'a
    ///   bağlamaya çalışmak derleme hatasıdır.
    /// - `NSLayoutConstraint.activate([...])`, constraint'leri toplu ve verimli şekilde etkinleştirir
    ///   (tek tek `isActive = true` yazmaktan daha okunaklı).
    /// - `leading/trailing` (baş/son), `left/right`'tan farklı olarak sağdan sola yazılan dillerde otomatik ters döner.
    private func configureLayout() {
        NSLayoutConstraint.activate([
            // Tablo tüm ekranı kaplar. Güvenli alanı (safe area: çentik, navigasyon ve sekme çubukları)
            // tablo kendisi `contentInset` ile hesaba katar; bu yüzden view'ın kenarlarına bağlıyoruz.
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Durum yığını, kenar boşluklarına (layout margins) yaslanmış ve güvenli alanın ortasında.
            statusStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            statusStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            statusStack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),

            // `.center` hizalı bir yığında label'lar kendi doğal genişliklerini alır; çok satıra
            // bölünebilmeleri için genişliklerini yığının genişliğine eşitliyoruz.
            emptyStateLabel.widthAnchor.constraint(equalTo: statusStack.widthAnchor),
            errorLabel.widthAnchor.constraint(equalTo: statusStack.widthAnchor),
        ])
    }

    /// Diffable data source'u oluşturur.
    ///
    /// Bilerek `static`: Closure içinde `self` kullanmak mümkün bile olmasın. Data source'u VC güçlü tutuyor;
    /// closure da VC'yi güçlü yakalasaydı VC → dataSource → closure → VC döngüsü (retain cycle) oluşurdu.
    private static func makeDataSource(for tableView: UITableView) -> DataSource {
        DataSource(tableView: tableView) { tableView, indexPath, book in
            // Hücre yeniden kullanımı (cell reuse): 1000 satırlık bir tablo için 1000 hücre oluşturulmaz.
            // Ekrana sığan kadar hücre oluşturulur; kaydırınca ekrandan çıkan hücre, yeni giren satır için
            // geri dönüştürülür. Bu yüzden hücreyi her seferinde BAŞTAN yapılandırırız: önceki kitabın
            // bilgisi (veya kimliği) üzerinde kalmasın.
            let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
            configure(cell, with: book)
            return cell
        }
    }

    /// Hücreyi `UIListContentConfiguration` ile yapılandırır (iOS 14+).
    ///
    /// Eski yöntemdeki `cell.textLabel?.text = ...` yerine, hücrenin içeriğini tarif eden bir **değer tipi**
    /// (struct) oluşturup hücreye veriyoruz. Yapılandırma bir değer olduğu için kopyalayıp değiştirmek güvenlidir
    /// ve hücre, seçili/vurgulu gibi durumlara göre görünümü kendisi ayarlar.
    static func configure(_ cell: UITableViewCell, with book: Book) {
        var content = cell.defaultContentConfiguration()
        content.text = book.title
        content.secondaryText = secondaryText(for: book)
        content.image = UIImage(systemName: "heart.fill")
        content.imageProperties.tintColor = .systemPink
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = AccessibilityID.Favorites.cell(bookID: book.id)
    }

    /// Hücrenin ikinci satırı, ör. "Oğuz Atay · 1972". (`String(book.year)` yazıyoruz; sayı biçimlendirici
    /// kullansaydık bazı dillerde "1.972" gibi binlik ayırıcı eklenebilirdi.)
    static func secondaryText(for book: Book) -> String {
        "\(book.author) · \(String(book.year))"
    }

    // MARK: - Test desteği

    /// Tabloda şu an gösterilen kitapların id'leri (data source'un son snapshot'ından okunur).
    var displayedBookIDs: [Book.ID] {
        dataSource.snapshot().itemIdentifiers.map(\.id)
    }
}

// MARK: - UITableViewDelegate

/// Delegate kalıbı (delegation): Bir nesne (tablo), bazı kararları ve olayları başka bir nesneye (delegate) devreder.
/// Tablo "bu satıra dokunuldu" der; ne yapılacağına VC karar verir. Protokolün metotları `optional`'dır
/// (Objective-C mirası), bu yüzden sadece ihtiyacımız olanları yazıyoruz.
/// Uyumu ayrı bir `extension`'da toplamak kodu okunur kılar ("bu kısım delegate işleri").
extension FavoritesViewController: UITableViewDelegate {

    /// Satıra dokunulunca detay ekranını açar: **UIKit içinde SwiftUI**.
    ///
    /// `UIHostingController`, bir SwiftUI view'ını saran sıradan bir `UIViewController`'dır; bu yüzden
    /// `pushViewController` ile navigasyon yığınına eklenebilir. Sonuç: SwiftUI (`TabView`) içinde UIKit
    /// (`UINavigationController`) içinde yine SwiftUI (`BookDetailView`).
    ///
    /// Köprünün bir sınırı: SwiftUI'ın `.navigationTitle` ve `.toolbar`'ı burada UIKit'in navigasyon çubuğuna
    /// taşınmıyor (iOS 26.2'de UI testiyle doğrulandı). Bu yüzden başlığı `title` ile biz veriyoruz ve detay ekranından
    /// kalp düğmesini araç çubuğu yerine içerikte (`.header`) göstermesini istiyoruz. Aksi halde Favoriler'den açılan
    /// detayda favoriden çıkarma düğmesi hiç görünmezdi.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let book = dataSource.itemIdentifier(for: indexPath) else { return }

        let detailViewController = UIHostingController(
            rootView: BookDetailView(book: book, dependencies: dependencies, favoriteButtonPlacement: .header)
        )
        detailViewController.title = book.title
        detailViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(detailViewController, animated: true)
    }

    /// Satırı sola kaydırınca çıkan eylemler.
    ///
    /// "Kaldır" tabloyu doğrudan değiştirmez; actor'e "kaldır" der. Actor yeni kümeyi yayınlayınca dinleyici task
    /// yeni snapshot'ı uygular ve satır animasyonla kaybolur. Tabloyu burada da elle değiştirseydik iki ayrı
    /// doğruluk kaynağı olurdu ve bir gün birbirlerinden ayrışırlardı.
    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let book = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let favorites = dependencies.favorites

        let removeAction = UIContextualAction(
            style: .destructive,
            title: AccessibilityID.Favorites.removeActionTitle
        ) { _, _, completion in
            // Bu handler senkron bir UIKit callback'i; `await` edemeyiz. Bu yüzden bir `Task` açıyoruz.
            // Task yalnızca actor'ü ve id'yi yakalıyor (ikisi de `Sendable`), `self`'i değil.
            Task { await favorites.remove(book.id) }
            completion(true) // UIKit'e "eylem yapıldı" de; kaydırma arayüzü kapansın.
        }
        removeAction.image = UIImage(systemName: "heart.slash")
        return UISwipeActionsConfiguration(actions: [removeAction])
    }
}
