import OSLog
import UIKit

/// Kurban ekranı "Kapat"a basıldığını bildirir. Kapatma işini ekranı **açan** (sahibi) yapar.
///
/// Apple'ın önerdiği modal kalıbı: Sunulan (presented) ekran kendini kapatmaz, sunan (presenting) ekrana
/// "işim bitti" der. Sahip = laboratuvar = delegate. Kurban onu `weak` tutar, yani bu bağ ölçümü etkilemez.
@MainActor
protocol LeakVictimViewControllerDelegate: AnyObject {
    func leakVictimDidRequestClose(_ victim: LeakVictimViewController)
}

/// Sızıntı laboratuvarının açıp kapattığı küçük ekran. Beş klasik sızıntının her birini sızdıran ya da
/// düzeltilmiş haliyle **gerçekten** kurar; laboratuvar da kapanıştan sonra `deinit`'in çalışıp çalışmadığına bakar.
///
/// Okuma sırası: önce yaşam döngüsü (neyi nerede kuruyoruz), sonra `MARK`'lı beş senaryo. Görünüm kurulumu
/// ayrı dosyada (`LeakVictimViewController+Layout.swift`), çünkü ders orada değil burada.
///
/// Kalıp: **Kur ↔ durdur simetrisi.** `viewWillAppear`'da başlayan bir şey `viewDidDisappear`'da durmalı.
/// Sızdıran sürümler temizliği `deinit`'e bırakıyor; ama nesneyi tutan şey zaten o temizlenmemiş kaynak
/// olduğu için `deinit` hiç gelmiyor. Bu, mülakatlarda en sık anlatılan tuzaktır.
final class LeakVictimViewController: UIViewController {
    let scenario: LeakScenario
    let variant: LeakVariant
    /// `weak`: Kurban sahibini (laboratuvarı) tutmaz. Delegate kuralının ta kendisi.
    weak var delegate: (any LeakVictimViewControllerDelegate)?

    /// Mekanizmanın gerçekten çalıştığını gösterir: düzeltilmiş sürüm de callback'leri almaya devam eder.
    private(set) var callbackCount = 0

    // MARK: Senaryoların sakladığı kaynaklar (her kurban yalnızca kendi senaryosununkini kullanır)

    private var onUpdate: (@MainActor () -> Void)?
    private var timer: Timer?
    private var reporter: LeakLabReporter?
    private var notificationToken: (any NSObjectProtocol)?
    /// `Task` tipi `Sendable` olduğu için nonisolated `deinit` içinden de iptal edilebilir.
    private(set) var tickTask: Task<Void, Never>?

    // MARK: Görünümler (kurulumu +Layout dosyasında)

    let titleLabel = UILabel()
    let callbackCountLabel = UILabel()
    let triggerButton = UIButton(configuration: .gray())
    let closeButton = UIButton(configuration: .filled())

    /// `deinit` nonisolated olduğu için logger'a ana actor dışından erişebilmeliyiz. `Logger` `Sendable` olduğundan
    /// `nonisolated static let` güvenli.
    nonisolated private static let logger = Logger(subsystem: "BookShelf", category: "MemoryLab")

    init(scenario: LeakScenario, variant: LeakVariant) {
        self.scenario = scenario
        self.variant = variant
        super.init(nibName: nil, bundle: nil)
        // Aşağı kaydırarak kapatmayı kapatıyoruz: tek çıkış "Kapat" düğmesi, böylece ölçüm hep aynı yoldan başlar.
        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LeakVictimViewController kodla oluşturulur.")
    }

    /// "deinit logging": Sızıntı ararken en basit araç. Bu satır konsolda (ve Console.app'te) görünmüyorsa nesne yaşıyordur.
    /// Sızdıran sürümlerde bu gövde HİÇ çalışmaz; bu yüzden içindeki `cancel()` onları kurtaramaz.
    deinit {
        tickTask?.cancel()
        Self.logger.debug("deinit: \(self.scenario.rawValue, privacy: .public) / \(self.variant.rawValue, privacy: .public)")
    }

    // MARK: - Yaşam döngüsü

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        // Yapısal bağlar: ekran yaşadıkça duran şeyler (bir closure, bir yardımcı nesne).
        switch scenario {
        case .closure: installUpdateClosure()
        case .delegate: installReporter()
        case .timer, .notification, .task: break
        }
        renderCallbackCount()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Çalışan işler: yalnızca ekran görünürken çalışsın.
        switch scenario {
        case .timer: startTimer()
        case .notification: startObservingPings()
        case .task: startTickTask()
        case .closure, .delegate: break
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Düzeltilmiş sürüm burada durdurur. Sızdıran sürüm "deinit'te temizlerim" diye düşündü; deinit gelmeyecek.
        if variant == .fixed {
            stopRunningWork()
        }
    }

    /// Ortak callback: her senaryo sonunda bunu çağırır.
    func refresh() {
        callbackCount += 1
        renderCallbackCount()
    }

    /// Elle tetiklenen senaryolar için tek bir olay üretir. Timer ve Task kendiliğinden tetikler.
    func trigger() {
        switch scenario {
        case .closure: onUpdate?()
        case .delegate: reporter?.report()
        case .notification: NotificationCenter.default.post(name: .leakLabPing, object: nil)
        case .timer, .task: break
        }
    }

    func requestClose() {
        if let delegate {
            delegate.leakVictimDidRequestClose(self)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - (a) Saklanan closure

    private func installUpdateClosure() {
        switch variant {
        case .leaking:
            // VC → onUpdate → closure → self (VC). Closure'lar referans tipidir ve yakaladıklarını güçlü tutar.
            onUpdate = { self.refresh() }
        case .fixed:
            // Yakalama listesi: self zayıf yakalanır. VC ölünce self nil olur, çağrı sessizce atlanır.
            onUpdate = { [weak self] in self?.refresh() }
        }
    }

    // MARK: - (b) Timer

    /// İki sürümde de AYNI kurulum. Fark yalnızca durdurmada (`viewDidDisappear` → `stopRunningWork()`).
    /// RunLoop zamanlanmış timer'ı güçlü tutar; timer da target'ını invalidate edilene kadar güçlü tutar.
    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func timerFired() {
        refresh()
    }

    // MARK: - (c) Delegate

    /// VC reporter'ın sahibidir (strong). Sızdıran sürümde reporter da VC'yi strong tutar → döngü.
    private func installReporter() {
        reporter = LeakLabReporter(delegate: self, holdsDelegateStrongly: variant == .leaking)
    }

    // MARK: - (d) NotificationCenter

    /// Block tabanlı gözlemciyi NotificationCenter, `removeObserver` çağrılana kadar tutar.
    ///
    /// Block'un tipi SDK'da `@Sendable`. `queue: .main` block'u ana thread'de çalıştırır; derleyici bunu bilemediği için
    /// `MainActor.assumeIsolated` ile söylüyoruz (yanılırsak sessizce yarışmak yerine çöker).
    private func startObservingPings() {
        guard notificationToken == nil else { return }
        let center = NotificationCenter.default
        switch variant {
        case .leaking:
            notificationToken = center.addObserver(forName: .leakLabPing, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { self.refresh() }
            }
        case .fixed:
            notificationToken = center.addObserver(forName: .leakLabPing, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    // MARK: - (e) Hiç bitmeyen Task

    /// `Task { }` ana actor'ü miras alır (VC `@MainActor`), yani `refresh()` ana thread'de çalışır.
    /// Task, closure'ını bitene kadar tutar; sonsuz döngü kimse iptal etmedikçe bitmez.
    private func startTickTask() {
        guard tickTask == nil else { return }
        switch variant {
        case .leaking:
            tickTask = Task {
                while !Task.isCancelled {
                    self.refresh()
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        case .fixed:
            // [weak self] VC'nin ölmesine izin verir; viewDidDisappear'daki cancel() döngüyü bitirir.
            // Dikkat: Döngüden ÖNCE `guard let self` yazsaydık self döngü boyunca güçlü kalırdı (bkz. FavoritesViewController).
            tickTask = Task { [weak self] in
                while !Task.isCancelled {
                    self?.refresh()
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }

    // MARK: - Durdurma ve temizlik

    /// Çalışan işleri durdurur: timer'ı RunLoop'tan çıkarır, gözlemciyi siler, task'ı iptal eder.
    private func stopRunningWork() {
        timer?.invalidate()
        timer = nil
        if let notificationToken {
            NotificationCenter.default.removeObserver(notificationToken)
        }
        notificationToken = nil
        tickTask?.cancel()
        tickTask = nil
    }

    /// "Sızıntıları temizle" için: hangi sürüm olursa olsun nesneyi tutan tüm okları koparır.
    /// Gerçek kodda böyle bir metoda ihtiyaç olmamalı; burada yalnızca laboratuvarın çöp biriktirmemesi için var.
    func breakRetainCycles() {
        stopRunningWork()
        onUpdate = nil
        reporter?.detachDelegate()
        reporter = nil
    }
}

extension LeakVictimViewController: LeakLabReporterDelegate {
    func reporterDidProduceUpdate(_ reporter: LeakLabReporter) {
        refresh()
    }
}
