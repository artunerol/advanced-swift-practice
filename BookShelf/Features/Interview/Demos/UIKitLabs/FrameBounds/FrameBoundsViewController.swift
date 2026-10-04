import UIKit

/// frame ve bounds farkını canlı gösteren lab.
///
/// ```
/// container (gri kutu, 260×260)          child (mavi)
///   bounds.origin = (0, kaydırma)         bounds = (0, 0, 120, 80)   ← kendi koordinatları, transform'dan etkilenmez
///   └─ child                              center = (130, 130)        ← container'ın koordinatlarında
///                                         frame  = transform'dan sonra child'ı saran EKSEN HİZALI kutu (turuncu kesikli)
/// ```
/// - Döndür / ölçekle: `transform` değişir → `frame` büyür/küçülür, `bounds` ve `center` aynı kalır.
/// - container.bounds.origin'i kaydır: Alt view'lar ekranda kayar ama `frame`'leri DEĞİŞMEZ; çünkü frame
///   üst view'ın koordinat sisteminde tanımlı ve kayan şey koordinat sisteminin kendisi. `UIScrollView` tam olarak
///   böyle kaydırır: `contentOffset` == `bounds.origin` (sayfanın altındaki satır bunu canlı gösterir).
/// - Ekrandaki gerçek yer: `convert(_:to:)`.
final class FrameBoundsViewController: UIViewController {
    private typealias ID = AccessibilityID.UIKitLabs.FrameBounds

    /// Kontrollerin değerleri. Değişince ekran `apply()` ile güncellenir.
    struct Settings: Equatable {
        var rotationDegrees: Double = 0
        var scale: Double = 1
        var containerOriginY: Double = 0
    }

    static let containerSide: CGFloat = 260
    static let childBounds = CGRect(x: 0, y: 0, width: 120, height: 80)
    static let childCenter = CGPoint(x: 130, y: 130)

    var settings = Settings() {
        didSet { apply() }
    }

    let scrollView = UIScrollView()
    let containerView = UIView()
    let childView = UIView()
    /// child.frame'i çizen kesikli çerçeve. container'ın katmanında durur; yani o da container'ın koordinatlarında.
    private let frameOutline = CAShapeLayer()

    let rotationSlider = UISlider()
    let scaleSlider = UISlider()
    let originSlider = UISlider()
    private let rotationValueLabel = UILabel()
    private let scaleValueLabel = UILabel()
    private let originValueLabel = UILabel()

    let childFrameLabel = UILabel()
    let childBoundsLabel = UILabel()
    let childCenterLabel = UILabel()
    let containerBoundsLabel = UILabel()
    let convertedLabel = UILabel()
    let scrollInfoLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureGeometry()
        configureControls()
        configureLayout()
        apply()
    }

    /// Geometriye bağlı her şey burada güncellenir: Bu noktada Auto Layout container'ı yerleştirmiştir, yani
    /// `convert(_:to:)` doğru sonucu verir. `viewDidLoad`'da container henüz (0, 0, 0, 0) olabilirdi.
    /// Bu metot defalarca çağrılabilir; `updateReadouts()` ucuz ve tekrar çalıştırılabilir (aynı metni tekrar yazmaz).
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateReadouts()
    }

    func reset() {
        settings = Settings()
    }

    // MARK: - Durumu uygulama

    private func apply() {
        guard isViewLoaded else { return }
        let radians = settings.rotationDegrees * .pi / 180
        // Transform, child'ın `center`'ı (anchorPoint) etrafında uygulanır; `bounds` ve `center`'a dokunmaz.
        childView.transform = CGAffineTransform(rotationAngle: radians).scaledBy(x: settings.scale, y: settings.scale)
        // Yalnızca origin'i değiştiriyoruz; size Auto Layout'un verdiği gibi kalır.
        containerView.bounds.origin = CGPoint(x: 0, y: settings.containerOriginY)

        rotationSlider.value = Float(settings.rotationDegrees)
        scaleSlider.value = Float(settings.scale)
        originSlider.value = Float(settings.containerOriginY)
        rotationValueLabel.text = "Döndürme: \(Int(settings.rotationDegrees))°"
        scaleValueLabel.text = "Ölçek: \(settings.scale.formatted(.number.precision(.fractionLength(1))))×"
        originValueLabel.text = "container.bounds.origin.y: \(Int(settings.containerOriginY))"
        updateReadouts()
    }

    private func updateReadouts() {
        // Kesikli çerçeve = child.frame. Örtük (implicit) katman animasyonunu kapatıyoruz; çerçeve kaydırıcıyı anında izlesin.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frameOutline.path = UIBezierPath(rect: childView.frame).cgPath
        CATransaction.commit()

        setIfChanged(childFrameLabel, "child.frame      \(GeometryText.rect(childView.frame))")
        setIfChanged(childBoundsLabel, "child.bounds     \(GeometryText.rect(childView.bounds))")
        setIfChanged(childCenterLabel, "child.center     \(GeometryText.point(childView.center))")
        setIfChanged(containerBoundsLabel, "container.bounds \(GeometryText.rect(containerView.bounds))")
        // child'ın kendi bounds'unu sayfanın kök view'ının koordinatlarına çevir: "ekranda nerede?"
        let onScreen = childView.convert(childView.bounds, to: view)
        setIfChanged(convertedLabel, "convert → view   \(GeometryText.rect(onScreen))")
        let offset = GeometryText.number(scrollView.contentOffset.y)
        let origin = GeometryText.number(scrollView.bounds.origin.y)
        setIfChanged(scrollInfoLabel, "Bu sayfa da bir UIScrollView → contentOffset.y = \(offset) · bounds.origin.y = \(origin)")
    }

    /// Aynı metni tekrar atamamak, layout'u boşuna geçersiz kılmamak içindir (viewDidLayoutSubviews'tan çağrılıyor).
    private func setIfChanged(_ label: UILabel, _ text: String) {
        if label.text != text { label.text = text }
    }

    // MARK: - Kurulum

    private func configureGeometry() {
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.borderColor = UIColor.separator.cgColor
        containerView.layer.borderWidth = 1
        // Scroll view gibi: kaydırılan içerik kutunun dışına taşınca kırpılsın.
        containerView.clipsToBounds = true

        // child Auto Layout KULLANMIYOR: bounds + center ile konumlanıyor. Transform uygulanmış bir view'da frame
        // tanımsız sayılır (UIView.h: "do not use frame if view is transformed"); bounds + center her zaman güvenli.
        // Aşağıda frame'i yalnızca OKUYORUZ (pratikte saran kutuyu verir), hiç atamıyoruz.
        childView.bounds = Self.childBounds
        childView.center = Self.childCenter
        childView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.6)
        childView.layer.cornerRadius = 6

        let childLabel = UILabel(frame: Self.childBounds)
        childLabel.text = "child"
        childLabel.textAlignment = .center
        childLabel.textColor = .white
        childLabel.font = .preferredFont(forTextStyle: .headline)
        childView.addSubview(childLabel)
        containerView.addSubview(childView)

        frameOutline.strokeColor = UIColor.systemOrange.cgColor
        frameOutline.fillColor = nil
        frameOutline.lineWidth = 2
        frameOutline.lineDashPattern = [6, 4]
        containerView.layer.addSublayer(frameOutline)   // child'dan sonra eklendi → üstünde çizilir
    }

    private func configureControls() {
        configure(rotationSlider, range: 0...180, id: ID.rotationSlider) { [weak self] value in
            self?.settings.rotationDegrees = (value / 5).rounded() * 5      // 5°'lik adımlar
        }
        configure(scaleSlider, range: 0.5...1.5, id: ID.scaleSlider) { [weak self] value in
            self?.settings.scale = (value * 10).rounded() / 10
        }
        configure(originSlider, range: -80...80, id: ID.originSlider) { [weak self] value in
            self?.settings.containerOriginY = (value / 5).rounded() * 5
        }

        let ids = [ID.childFrameLabel, ID.childBoundsLabel, ID.childCenterLabel, ID.containerBoundsLabel, ID.convertedLabel]
        for (label, id) in zip(readoutLabels, ids) {
            label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.7
            label.accessibilityIdentifier = id
        }
        for label in [rotationValueLabel, scaleValueLabel, originValueLabel] {
            label.font = .preferredFont(forTextStyle: .subheadline)
        }

        scrollInfoLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        scrollInfoLabel.textColor = .secondaryLabel
        scrollInfoLabel.numberOfLines = 0
        scrollInfoLabel.accessibilityIdentifier = ID.scrollInfoLabel
        scrollView.delegate = self
    }

    private var readoutLabels: [UILabel] {
        [childFrameLabel, childBoundsLabel, childCenterLabel, containerBoundsLabel, convertedLabel]
    }

    private func configure(
        _ slider: UISlider,
        range: ClosedRange<Float>,
        id: String,
        onChange: @escaping @MainActor (Double) -> Void
    ) {
        slider.minimumValue = range.lowerBound
        slider.maximumValue = range.upperBound
        slider.accessibilityIdentifier = id
        slider.addAction(UIAction { action in
            guard let slider = action.sender as? UISlider else { return }
            onChange(Double(slider.value))
        }, for: .valueChanged)
    }

    private func configureLayout() {
        let explanation = UILabel()
        explanation.text = "Mavi: child. Turuncu kesikli: child.frame (container koordinatlarında, eksen hizalı kutu). "
            + "Döndürünce frame büyür, bounds aynı kalır. container.bounds.origin'i kaydırınca child kayar ama frame'i değişmez."
        explanation.font = .preferredFont(forTextStyle: .footnote)
        explanation.textColor = .secondaryLabel
        explanation.numberOfLines = 0

        // container'ı yatayda ortalamak için bir tutucu.
        let containerHolder = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerHolder.addSubview(containerView)

        var resetConfiguration = UIButton.Configuration.bordered()
        resetConfiguration.title = "Sıfırla"
        let resetButton = UIButton(configuration: resetConfiguration, primaryAction: UIAction { [weak self] _ in
            self?.reset()
        })
        resetButton.accessibilityIdentifier = ID.resetButton

        let stack = UIStackView(arrangedSubviews: [
            explanation, containerHolder,
            rotationValueLabel, rotationSlider, scaleValueLabel, scaleSlider, originValueLabel, originSlider,
        ] + readoutLabels + [resetButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(16, after: containerHolder)
        stack.setCustomSpacing(16, after: originSlider)
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        view.addSubview(scrollInfoLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: scrollInfoLabel.topAnchor, constant: -4),

            scrollInfoLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            scrollInfoLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            scrollInfoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),

            // İçerik yığını kaydırılabilir alanı (contentLayoutGuide) belirler; genişliği ise görünür alana (frameLayoutGuide)
            // eşitlenir ki yalnızca dikeyde kaysın.
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),

            containerView.widthAnchor.constraint(equalToConstant: Self.containerSide),
            containerView.heightAnchor.constraint(equalToConstant: Self.containerSide),
            containerView.centerXAnchor.constraint(equalTo: containerHolder.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: containerHolder.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: containerHolder.bottomAnchor),
        ])
    }
}

// MARK: - UIScrollViewDelegate

extension FrameBoundsViewController: UIScrollViewDelegate {
    /// Sayfa kaydıkça `contentOffset` değişir; bu aslında scroll view'ın `bounds.origin`'idir (iki değer hep eşit).
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateReadouts()
    }
}
