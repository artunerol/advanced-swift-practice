import UIKit

/// Lab'da "Ana" ekranın açtığı ekran: sunulan (PageSheet / FullScreen), push edilen (Push) ya da gömülen (Child).
///
/// Tek sınıf, dört rol: Farkı yalnızca nasıl kapatıldığı (`CloseStyle`). Böylece günlükte görülen farklar ekranın
/// içeriğinden değil, **nasıl gösterildiğinden** gelir.
final class LifecycleDetailViewController: LoggingViewController {
    enum CloseStyle {
        /// `dismiss(animated:)`: modal sunumu kapatır.
        case dismiss
        /// `popViewController(animated:)`: navigasyon yığınından çıkar.
        case pop
        /// Child VC: kendini kapatmaz; ekleyen üst VC çıkarır.
        case none
    }

    private let message: String
    private let closeStyle: CloseStyle

    init(logName: String, logger: LifecycleLogger, message: String, closeStyle: CloseStyle) {
        self.message = message
        self.closeStyle = closeStyle
        super.init(logName: logName, logger: logger)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = closeStyle == .none ? .secondarySystemBackground : .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = logName
        titleLabel.font = .preferredFont(forTextStyle: closeStyle == .none ? .subheadline : .title2)
        titleLabel.adjustsFontForContentSizeCategory = true

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .footnote)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        stack.axis = .vertical
        stack.spacing = 8
        if let closeButton = makeCloseButton() {
            stack.addArrangedSubview(closeButton)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }

    private func makeCloseButton() -> UIButton? {
        let title: String
        switch closeStyle {
        case .dismiss: title = "Kapat (dismiss)"
        case .pop: title = "Geri dön (pop)"
        case .none: return nil
        }
        var configuration = UIButton.Configuration.borderedProminent()
        configuration.title = title
        // `[weak self]`: Düğme → action → closure → VC zinciri; VC de view hiyerarşisi üzerinden düğmeyi tutar.
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            self?.close()
        })
        button.accessibilityIdentifier = AccessibilityID.UIKitLabs.Lifecycle.closeButton
        return button
    }

    private func close() {
        switch closeStyle {
        case .dismiss: dismiss(animated: true)
        case .pop: navigationController?.popViewController(animated: true)
        case .none: break
        }
    }
}
