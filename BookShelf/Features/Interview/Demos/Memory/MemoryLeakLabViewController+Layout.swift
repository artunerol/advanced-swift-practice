import UIKit

/// Laboratuvar ekranının görünüm kurulumu (Auto Layout, kodla). Davranış ana dosyada.
///
/// Sıra bilinçli: Seçici, düğmeler ve sonuç en üstte. Böylece küçük ekranlarda bile kaydırmadan kullanılır;
/// kod parçaları ve açıklama aşağıda, okumak isteyen kaydırır.
extension MemoryLeakLabViewController {
    private typealias ID = AccessibilityID.MemoryLab

    func buildLayout() {
        view.backgroundColor = .systemBackground

        scenarioControl.accessibilityIdentifier = ID.scenarioPicker
        // UIControl'ün kendisi UIAction'ı güçlü tutar → closure'da [weak self] (aksi halde VC → kontrol → closure → VC).
        scenarioControl.addAction(UIAction { [weak self] _ in self?.scenarioControlChanged() }, for: .valueChanged)

        configureBodyLabel(chainLabel, style: .footnote, color: .secondaryLabel)

        configureOpenButton(openLeakingButton, title: "Sızdıranı aç", tint: .systemRed, identifier: ID.openLeakingButton)
        openLeakingButton.addAction(UIAction { [weak self] _ in self?.openVictim(.leaking) }, for: .primaryActionTriggered)
        configureOpenButton(openFixedButton, title: "Düzeltilmişi aç", tint: .systemGreen, identifier: ID.openFixedButton)
        openFixedButton.addAction(UIAction { [weak self] _ in self?.openVictim(.fixed) }, for: .primaryActionTriggered)
        let buttonRow = UIStackView(arrangedSubviews: [openLeakingButton, openFixedButton])
        buttonRow.axis = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 12

        let lessonTitle = UILabel()
        configureBodyLabel(lessonTitle, style: .headline, color: .label)
        lessonTitle.text = "Neden düzeltiyor?"
        configureBodyLabel(lessonLabel, style: .subheadline, color: .label)

        let toolsLabel = UILabel()
        configureBodyLabel(toolsLabel, style: .footnote, color: .secondaryLabel)
        toolsLabel.text = """
        Sızıntıyı nasıl bulursun? deinit'e log koy. Uygulama çalışırken Xcode'daki Debug Memory Graph her tipin \
        canlı örneklerini listeler (kapattığın ekran hâlâ orada mı?) ve ulaşılamayan döngüleri mor ünlemle işaretler. \
        Instruments'ta Leaks ulaşılamayan döngüleri, Allocations (Mark Generation) birikmeyi gösterir. \
        Testte weak referansla nesnenin serbest kaldığını doğrula.
        """

        let stack = UIStackView(arrangedSubviews: [
            scenarioControl, chainLabel, buttonRow, makeResultCard(),
            leakingCodeView, fixedCodeView, lessonTitle, lessonLabel, toolsLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(6, after: lessonTitle)
        embedInScrollView(stack)
    }

    private func scenarioControlChanged() {
        let index = scenarioControl.selectedSegmentIndex
        guard LeakScenario.allCases.indices.contains(index) else { return }
        selectScenario(LeakScenario.allCases[index])
    }

    /// Sonuç kartı: karar, açıklama, bellekte kalan kurban sayısı ve temizlik düğmesi.
    private func makeResultCard() -> UIView {
        verdictLabel.accessibilityIdentifier = ID.verdictLabel
        configureBodyLabel(verdictLabel, style: .title3, color: .secondaryLabel)

        verdictDetailLabel.accessibilityIdentifier = ID.verdictDetailLabel
        configureBodyLabel(verdictDetailLabel, style: .footnote, color: .secondaryLabel)

        leakCountLabel.accessibilityIdentifier = ID.leakCountLabel
        configureBodyLabel(leakCountLabel, style: .subheadline, color: .secondaryLabel)

        cleanUpButton.configuration?.title = "Sızıntıları temizle"
        cleanUpButton.accessibilityIdentifier = ID.cleanUpButton
        cleanUpButton.setContentHuggingPriority(.required, for: .horizontal)
        cleanUpButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        cleanUpButton.addAction(UIAction { [weak self] _ in self?.cleanUpLeaks() }, for: .primaryActionTriggered)

        let countRow = UIStackView(arrangedSubviews: [leakCountLabel, cleanUpButton])
        countRow.axis = .horizontal
        countRow.alignment = .center
        countRow.spacing = 8

        // Senaryo değiştirilince son ölçüm ekranda kalır; açıklama satırı hangi senaryoya ait olduğunu söyler.
        let cardTitle = UILabel()
        configureBodyLabel(cardTitle, style: .caption1, color: .secondaryLabel)
        cardTitle.text = "Son ölçüm"

        let cardStack = UIStackView(arrangedSubviews: [cardTitle, verdictLabel, verdictDetailLabel, countRow])
        cardStack.axis = .vertical
        cardStack.spacing = 6
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])
        return card
    }

    private func configureOpenButton(_ button: UIButton, title: String, tint: UIColor, identifier: String) {
        button.configuration?.title = title
        button.tintColor = tint
        button.accessibilityIdentifier = identifier
    }

    private func configureBodyLabel(_ label: UILabel, style: UIFont.TextStyle, color: UIColor) {
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
    }

    private func embedInScrollView(_ stack: UIStackView) {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            // Genişliği kaydırma alanının görünen çerçevesine bağlıyoruz: yatay kaydırma olmasın.
            stack.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -16),
        ])
    }
}
