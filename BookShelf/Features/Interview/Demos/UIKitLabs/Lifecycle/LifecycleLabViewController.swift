import UIKit

/// Yaşam döngüsü lab'ının çerçevesi: üstte gözlenen "Ana" ekran, altta canlı günlük.
///
/// ```
/// LifecycleLabViewController (bu sınıf, günlüğe YAZMAZ)
///   ├─ UINavigationController (child VC, çubuğu gizli) ── push için yığın
///   │    └─ LifecycleSubjectViewController "Ana"  ← gözlenen ekran
///   └─ UITextView (günlük, en yeni satır altta) + "Temizle"
/// ```
/// Bu sınıf bilerek `LoggingViewController` DEĞİL: Günlüğü gösteren view'ın kendi yerleşimi de günlüğe düşseydi
/// her satır yeni bir layout'a, her layout yeni bir satıra yol açabilirdi (sonsuz döngü). Gözlenen ekran ile
/// gözleyen ekran ayrı.
final class LifecycleLabViewController: UIViewController {
    private typealias ID = AccessibilityID.UIKitLabs.Lifecycle

    /// Günlüğün sahibi bu VC (güçlü referans). Günlük ise bu VC'yi yalnızca `weak delegate` olarak tutar.
    let logger: LifecycleLogger
    let subject: LifecycleSubjectViewController
    private let subjectNavigation: UINavigationController

    let logTextView = UITextView()
    private let clearButton = UIButton(configuration: .plain())

    init() {
        // `super.init`'ten önce `self.logger`'ı okuyamayız (tüm alanlar dolmadan `self` kullanılamaz);
        // bu yüzden önce yerel bir sabite alıyoruz.
        let logger = LifecycleLogger()
        self.logger = logger
        subject = LifecycleSubjectViewController(logger: logger)
        subjectNavigation = UINavigationController(rootViewController: subject)
        super.init(nibName: nil, bundle: nil)
        logger.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LifecycleLabViewController storyboard'dan değil, kodla oluşturulur.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        embedSubject()
        configureLog()
        render()
    }

    /// Gözlenen ekranı child VC olarak yerleştirir. Navigasyon çubuğunu gizliyoruz: Konu ekranının SwiftUI çubuğu
    /// zaten üstte; ikinci bir çubuk kafa karıştırırdı. Push edilen ekranda geri dönmek için kendi düğmesi var.
    private func embedSubject() {
        subjectNavigation.setNavigationBarHidden(true, animated: false)
        addChild(subjectNavigation)
        subjectNavigation.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subjectNavigation.view)
        subjectNavigation.didMove(toParent: self)
    }

    private func configureLog() {
        let titleLabel = UILabel()
        titleLabel.text = "Günlük (en yeni satır altta)"
        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .secondaryLabel

        var clearConfiguration = UIButton.Configuration.plain()
        clearConfiguration.title = "Temizle"
        clearConfiguration.buttonSize = .small
        clearButton.configuration = clearConfiguration
        clearButton.accessibilityIdentifier = ID.clearButton
        clearButton.addAction(UIAction { [weak self] _ in self?.logger.clear() }, for: .primaryActionTriggered)

        let header = UIStackView(arrangedSubviews: [titleLabel, clearButton])
        header.axis = .horizontal
        header.alignment = .center

        logTextView.isEditable = false
        logTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logTextView.backgroundColor = .secondarySystemGroupedBackground
        logTextView.layer.cornerRadius = 8
        logTextView.accessibilityIdentifier = ID.log

        let logStack = UIStackView(arrangedSubviews: [header, logTextView])
        logStack.axis = .vertical
        logStack.spacing = 4
        logStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logStack)

        let subjectView: UIView = subjectNavigation.view
        NSLayoutConstraint.activate([
            subjectView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            subjectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            subjectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Ekranın ~%40'ı gözlenen ekran, geri kalanı günlük.
            subjectView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.4),

            logStack.topAnchor.constraint(equalTo: subjectView.bottomAnchor, constant: 4),
            logStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            logStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            logStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
    }

    /// Günlüğü ekrana yazar ve en alta kaydırır.
    private func render() {
        logTextView.text = logger.text
        let length = logTextView.text.utf16.count
        if length > 0 {
            logTextView.scrollRangeToVisible(NSRange(location: length - 1, length: 1))
        }
    }
}

extension LifecycleLabViewController: LifecycleLoggerDelegate {
    func lifecycleLoggerDidChange(_ logger: LifecycleLogger) {
        // `viewIfLoaded`: Günlük, bu VC'nin view'ı yüklenmeden önce de yazılır (Ana'nın init'i gibi).
        // `view`'a erişmek onu erkenden yüklerdi; yüklenmemişse viewDidLoad'daki render zaten hepsini gösterecek.
        guard viewIfLoaded != nil else { return }
        render()
    }
}
