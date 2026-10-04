import UIKit

/// Kurban ekranının görünüm kurulumu. Davranış (sızıntılar) ana dosyada; burada yalnızca view'lar ve Auto Layout var.
extension LeakVictimViewController {
    private typealias ID = AccessibilityID.MemoryLab.Victim

    func buildLayout() {
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = ID.root

        titleLabel.text = "\(scenario.title) · \(variant.title)"
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        closeButton.configuration?.title = "Kapat"
        closeButton.accessibilityIdentifier = ID.closeButton
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        // Burada da [weak self]: VC → view → düğme → UIAction → closure → VC döngüsü olurdu.
        // Laboratuvarın kendi kodu sızdırsaydı "düzeltilmiş" sürüm de sızmış görünürdü.
        closeButton.addAction(UIAction { [weak self] _ in self?.requestClose() }, for: .primaryActionTriggered)

        let header = UIStackView(arrangedSubviews: [titleLabel, closeButton])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 12

        let questionLabel = makeBodyLabel(
            "Ekranı kapat; laboratuvar deinit'in çalışıp çalışmadığını ölçecek.",
            color: .secondaryLabel
        )

        callbackCountLabel.font = .preferredFont(forTextStyle: .headline)
        callbackCountLabel.adjustsFontForContentSizeCategory = true
        callbackCountLabel.accessibilityIdentifier = ID.callbackCountLabel

        triggerButton.configuration?.title = "Callback'i tetikle"
        triggerButton.accessibilityIdentifier = ID.triggerButton
        triggerButton.isHidden = scenario.firesAutomatically
        triggerButton.addAction(UIAction { [weak self] _ in self?.trigger() }, for: .primaryActionTriggered)

        let autoFireLabel = makeBodyLabel("Her saniye kendiliğinden tetiklenir.", color: .secondaryLabel)
        autoFireLabel.isHidden = !scenario.firesAutomatically

        let codeView = CodeSnippetView()
        codeView.configure(
            title: variant == .leaking ? "Bu ekranın kodu (sızdıran)" : "Bu ekranın kodu (düzeltilmiş)",
            code: scenario.code(for: variant),
            tint: variant == .leaking ? .systemRed : .systemGreen
        )

        let chainLabel = makeBodyLabel("Sızdıran sürümdeki zincir: \(scenario.retainChain)", color: .secondaryLabel)

        let stack = UIStackView(arrangedSubviews: [
            header, questionLabel, callbackCountLabel, triggerButton, autoFireLabel, codeView, chainLabel,
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.setCustomSpacing(6, after: callbackCountLabel)

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -20),
        ])
    }

    func renderCallbackCount() {
        callbackCountLabel.text = "Callback sayısı: \(callbackCount)"
    }

    private func makeBodyLabel(_ text: String, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }
}
