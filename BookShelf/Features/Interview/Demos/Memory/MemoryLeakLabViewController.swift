import UIKit

/// Sızıntı laboratuvarı (UIKit): Bir "kurban" ekranı açar, kapatır ve nesnenin bellekten silinip silinmediğini ölçer.
///
/// Ölçüm yöntemi, birim testlerde kullandığımızın aynısı: Kapanmadan hemen önce kurbana **zayıf** bir referans
/// (`DeallocationProbe`) al, ekranı kapat, kısa bir süre bekle. Zayıf referans `nil` olduysa `deinit` çalışmıştır.
///
/// Sahiplik (delegate konusunun canlı örneği):
/// ```
/// MemoryLeakLabViewController ──present──▶ LeakVictimViewController     (sunulan ekranı UIKit tutar)
///            ▲                                       │
///            └──────────── weak delegate ────────────┘  "Kapat'a basıldı"
/// ```
/// Kurban laboratuvarı tutmaz; laboratuvar da kurbanı (zayıf probe dışında) tutmaz. Böylece ölçümü biz bozmayız.
final class MemoryLeakLabViewController: UIViewController {

    /// Ekranın durumu. Tek bir `enum`, "kurban açık ama ölçüm de sürüyor" gibi imkânsız birleşimleri yazılamaz yapar.
    enum Status: Equatable {
        case idle
        case victimOnScreen
        case measuring
        case measured(LeakMeasurement)
        case cleaning
        case cleaned(released: Int, total: Int)

        /// Kurban açıkken ya da beklerken yeni bir kurban açılmasın, temizlik başlamasın.
        var isBusy: Bool {
            switch self {
            case .victimOnScreen, .measuring, .cleaning: true
            case .idle, .measured, .cleaned: false
            }
        }
    }

    private let registry: LeakRegistry
    private(set) var selectedScenario: LeakScenario = .closure
    private(set) var status: Status = .idle
    private var measurementTask: Task<Void, Never>?

    // MARK: Görünümler (kurulumu +Layout dosyasında)

    let scenarioControl = UISegmentedControl(items: LeakScenario.allCases.map(\.segmentTitle))
    let chainLabel = UILabel()
    let openLeakingButton = UIButton(configuration: .tinted())
    let openFixedButton = UIButton(configuration: .tinted())
    let verdictLabel = UILabel()
    let verdictDetailLabel = UILabel()
    let leakCountLabel = UILabel()
    let cleanUpButton = UIButton(configuration: .bordered())
    let leakingCodeView = CodeSnippetView()
    let fixedCodeView = CodeSnippetView()
    let lessonLabel = UILabel()

    init(registry: LeakRegistry = .shared) {
        self.registry = registry
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("MemoryLeakLabViewController kodla oluşturulur.")
    }

    deinit {
        measurementTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        render()
    }

    /// Konuya geri dönüldüğünde önceki ziyaretten kalan sızıntılar da sayılsın.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    // MARK: - Eylemler

    func selectScenario(_ scenario: LeakScenario) {
        selectedScenario = scenario
        render()
    }

    /// Seçili senaryonun kurbanını modal olarak açar.
    func openVictim(_ variant: LeakVariant) {
        guard !status.isBusy else { return }
        let victim = LeakVictimViewController(scenario: selectedScenario, variant: variant)
        victim.delegate = self
        victim.modalPresentationStyle = .pageSheet
        status = .victimOnScreen
        render()
        present(victim, animated: true)
    }

    /// Yaşayan tüm kurbanların döngüsünü kırar ve serbest kalmalarını bekler.
    func cleanUpLeaks() {
        guard !status.isBusy else { return }
        let probes = registry.breakAllCycles()
        guard !probes.isEmpty else { return }
        status = .cleaning
        render()
        measurementTask = Task { [weak self] in
            var releasedCount = 0
            for probe in probes {
                if await probe.waitForRelease() {
                    releasedCount += 1
                }
            }
            guard let self, !Task.isCancelled else { return }
            status = .cleaned(released: releasedCount, total: probes.count)
            render()
        }
    }

    // MARK: - Ölçüm

    private func measureRelease(
        of probe: DeallocationProbe<LeakVictimViewController>,
        scenario: LeakScenario,
        variant: LeakVariant
    ) {
        status = .measuring
        render()
        measurementTask = Task { [weak self] in
            let released = await probe.waitForRelease()
            guard let self, !Task.isCancelled else { return }
            status = .measured(LeakMeasurement(scenario: scenario, variant: variant, released: released))
            render()
        }
    }

    // MARK: - Durumu ekrana yansıtma

    private func render() {
        guard isViewLoaded else { return }
        typealias ID = AccessibilityID.MemoryLab

        scenarioControl.selectedSegmentIndex = LeakScenario.allCases.firstIndex(of: selectedScenario) ?? 0
        chainLabel.text = "Sızdıran sürümdeki zincir: \(selectedScenario.retainChain)"
        leakingCodeView.configure(title: "Sızdıran", code: selectedScenario.code(for: .leaking), tint: .systemRed)
        fixedCodeView.configure(title: "Düzeltilmiş", code: selectedScenario.code(for: .fixed), tint: .systemGreen)
        lessonLabel.text = selectedScenario.lesson

        switch status {
        case .idle:
            show(ID.verdictIdle, detail: "Bir sürümü aç, sonra kurban ekranını kapat.", color: .secondaryLabel)
        case .victimOnScreen:
            show("Kurban açık", detail: "Kapatınca deinit'in çalışıp çalışmadığı ölçülecek.", color: .secondaryLabel)
        case .measuring:
            show(ID.verdictMeasuring, detail: "Zayıf referansın nil olması bekleniyor…", color: .secondaryLabel)
        case .measured(let measurement):
            show(measurement.verdict, detail: measurement.detail, color: measurement.released ? .systemGreen : .systemRed)
        case .cleaning:
            show(ID.verdictMeasuring, detail: "Döngüler kırılıyor…", color: .secondaryLabel)
        case .cleaned(let released, let total):
            show(
                "Temizlendi: \(released)/\(total)",
                detail: "\(total) kurbanın döngüsü kırıldı; \(released) tanesinin deinit'i çalıştı.",
                color: released == total ? .systemGreen : .systemRed
            )
        }

        let survivors = registry.survivorCount
        leakCountLabel.text = ID.leakCountText(survivors)
        leakCountLabel.textColor = survivors > 0 ? .systemRed : .secondaryLabel

        openLeakingButton.isEnabled = !status.isBusy
        openFixedButton.isEnabled = !status.isBusy
        cleanUpButton.isEnabled = !status.isBusy && survivors > 0
    }

    private func show(_ verdict: String, detail: String, color: UIColor) {
        verdictLabel.text = verdict
        verdictLabel.textColor = color
        verdictDetailLabel.text = detail
    }
}

// MARK: - LeakVictimViewControllerDelegate

extension MemoryLeakLabViewController: LeakVictimViewControllerDelegate {
    func leakVictimDidRequestClose(_ victim: LeakVictimViewController) {
        // Kapatmadan ÖNCE zayıf referansı al. Bu metottan çıkınca elimizde kurbana güçlü referans kalmaz;
        // completion closure'ı da yalnızca probe'u ve zayıf self'i yakalar, kurbanı değil.
        let probe = registry.track(victim)
        let scenario = victim.scenario
        let variant = victim.variant

        // Sunulan ekranı sunan taraf kapatır; `victim.dismiss` isteği ekranı sunan VC'ye iletir.
        victim.dismiss(animated: true) { [weak self] in
            self?.measureRelease(of: probe, scenario: scenario, variant: variant)
        }
    }
}
