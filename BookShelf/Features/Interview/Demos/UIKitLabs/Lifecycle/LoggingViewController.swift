import UIKit

/// Yaşam döngüsü çağrılarının HER birini `LifecycleLogger`'a yazan view controller.
///
/// Lab'daki tüm ekranlar (Ana, PageSheet, FullScreen, Push, Child) bundan türer. Override'ların hepsi aynı kalıpta:
/// önce `super`, sonra günlüğe yaz. (`super`'i çağırmamak UIKit'in o anda yaptığı işi atlar; ör. `viewWillAppear`'da
/// child VC'lere görünüş bildirimi iletilmez.)
///
/// Nereye ne konur? (mülakatın asıl sorusu)
/// - `init`: Bağımlılıkları al. View'a DOKUNMA; `view`'a erişmek onu hemen yükler.
/// - `loadView`: Kök view'ı kendin oluşturacaksan. `super` çağrılmaz, `view = ...` atanır.
/// - `viewDidLoad`: BİR kez. Alt view'lar, constraint'ler, delegate'ler. Boyutlar henüz kesin değil.
/// - `viewWillAppear` / `viewIsAppearing`: Her görünüşte. `viewIsAppearing`'de trait'ler ve geometri artık geçerli
///   (iOS 17 SDK'sıyla geldi, iOS 13'e kadar geriye dönük çalışır); görünüşe bağlı UI güncellemesi için tercih edilen yer.
/// - `viewWillLayoutSubviews` / `viewDidLayoutSubviews`: Kök view her yerleştiğinde (kaç kez olacağı belli değil).
///   `viewDidLayoutSubviews`'ta alt view'ların frame'leri kesindir; buraya ucuz ve tekrar çalıştırılabilir
///   (idempotent) geometri işleri konur. Bkz. `FrameBoundsViewController.viewDidLayoutSubviews()`.
/// - `viewDidAppear`: Görünüş animasyonu bitti: analitik, kullanıcıya dönük animasyon başlatma.
/// - `viewWillDisappear` / `viewDidDisappear`: Dinleyicileri, zamanlayıcıları durdur. `viewWillDisappear` iptal
///   edilebilir (yarım bırakılan geri kaydırma); kesin bilgi `viewDidDisappear`'da.
/// - `deinit`: Son temizlik. Burada çalışıyorsa nesne sızmıyor demektir.
class LoggingViewController: UIViewController {
    /// Günlükte görünen ad, ör. "Ana".
    let logName: String
    let logger: LifecycleLogger

    init(logName: String, logger: LifecycleLogger) {
        self.logName = logName
        self.logger = logger
        super.init(nibName: nil, bundle: nil)
        log(.initialized)

        // iOS 17+: Trait değişimlerini kaydolarak dinlemek (`traitCollectionDidChange` iOS 17'de deprecated oldu).
        // Kapanış `self`'i YAKALAMAZ; UIKit onu ilk parametre olarak verir. Bu yüzden retain cycle riski yok ve
        // kayıt nesneyle birlikte kendiliğinden silinir.
        let observedTraits: [UITrait] = [
            UITraitUserInterfaceStyle.self,
            UITraitHorizontalSizeClass.self,
            UITraitVerticalSizeClass.self,
            UITraitPreferredContentSizeCategory.self,
        ]
        registerForTraitChanges(observedTraits) { (self: Self, previous: UITraitCollection) in
            self.log(.traitsChanged(Self.describeChange(from: previous, to: self.traitCollection)))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LoggingViewController storyboard'dan değil, kodla oluşturulur.")
    }

    /// `deinit` **nonisolated**'dır: Sınıf `@MainActor` olsa bile hangi thread'de çalışacağı garanti değildir
    /// (son güçlü referans nerede bırakıldıysa orada). Bu yüzden ana actor'deki günlüğe burada senkron yazamayız.
    ///
    /// Çözüm: Gereken iki `Sendable` değeri (günlük ve ad) yerel sabitlere kopyalayıp ana actor'de bir `Task` açmak.
    /// `self`'i yakalamıyoruz; nesne zaten yok oluyor. Bedeli: "deinit" satırı günlüğe birkaç an sonra düşer.
    ///
    /// Neden Swift 6.2'nin `isolated deinit`'i değil? Daha temiz olurdu (gövde ana actor'de, senkron), ama Xcode 26.3
    /// derleyicisi (Swift 6.2.4) bu projede derlemeyi kırdı: Alt sınıf, üst sınıftan ÖNCEKİ bir dosyada derlenince
    /// emit-module adımı "'@preconcurrency' attribute cannot be applied to this declaration" hatası veriyor
    /// (dosya sırasına bağlı bir derleyici hatası; küçük bir örnekle doğrulandı).
    deinit {
        let logger = logger
        let logName = logName
        Task { @MainActor in
            logger.record(.deinitialized, from: logName)
        }
    }

    // MARK: - Yükleme

    /// Kök view'ı kendimiz oluşturuyoruz; bu yüzden `super.loadView()` çağrılmaz.
    /// (Storyboard/XIB yoksa varsayılan uygulama boş bir `UIView` oluşturur; burada da aynısını açıkça yapıyoruz.)
    override func loadView() {
        log(.loadView)
        view = UIView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        log(.viewDidLoad)
    }

    // MARK: - Görünme / kaybolma

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        log(.viewWillAppear)
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        log(.viewIsAppearing)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        log(.viewDidAppear)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        log(.viewWillDisappear)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        log(.viewDidDisappear)
    }

    // MARK: - Yerleşim (layout)

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        log(.viewWillLayoutSubviews)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        log(.viewDidLayoutSubviews)
    }

    /// Döndürme ya da pencere boyutu değişimi (iPad'de Split View). `coordinator` ile geçiş animasyonuna eşlik edilebilir.
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        log(.viewWillTransition(width: Int(size.width.rounded()), height: Int(size.height.rounded())))
    }

    // MARK: - Containment (child VC)

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        log(.willMoveToParent(parent.map(Self.displayName(of:))))
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        log(.didMoveToParent(parent.map(Self.displayName(of:))))
    }

    // MARK: - Yardımcılar

    func log(_ event: LifecycleEvent) {
        logger.record(event, from: logName)
    }

    /// Günlükte üst VC'yi okunur göstermek için: lab ekranlarının adı, UIKit'inkilerin tip adı.
    private static func displayName(of controller: UIViewController) -> String {
        (controller as? LoggingViewController)?.logName ?? String(describing: type(of: controller))
    }

    private static func describeChange(from previous: UITraitCollection, to current: UITraitCollection) -> String {
        var changes: [String] = []
        if previous.userInterfaceStyle != current.userInterfaceStyle {
            changes.append(current.userInterfaceStyle == .dark ? "koyu mod" : "açık mod")
        }
        if previous.horizontalSizeClass != current.horizontalSizeClass || previous.verticalSizeClass != current.verticalSizeClass {
            changes.append("size class")
        }
        if previous.preferredContentSizeCategory != current.preferredContentSizeCategory {
            changes.append("yazı boyutu")
        }
        return changes.isEmpty ? "diğer" : changes.joined(separator: ", ")
    }
}
