import UIKit

/// Lab'ın "Ana" ekranı: Günlüğe yazılan, başka ekranları **sunan / push eden / child olarak ekleyen** view controller.
///
/// Düğmeler:
/// - PageSheet / FullScreen: Aynı ekranı iki farklı stille sunar. Asıl ders: `.pageSheet`'te Ana'nın
///   `viewWillDisappear`/`viewDidDisappear`'ı ÇAĞRILMAZ (Ana'nın view'ı pencerede kalır, sheet üstünde durur);
///   `.fullScreen`'de çağrılır (sunum bitince Ana'nın view'ı pencereden çıkarılır). Kapanınca da aynı simetri:
///   yalnızca fullScreen'den dönüşte Ana'ya yeniden `viewWillAppear`/`viewDidAppear` gelir.
/// - Push: `UINavigationController` yığınına ekler. Ana kaybolur (disappear), Push görünür (appear).
/// - Child ekle/çıkar: Containment API sırası (aşağıda `toggleChild()`).
/// - setNeedsLayout + layoutIfNeeded: Yalnızca layout çiftini tetikler; `viewDidLoad` tekrar ÇALIŞMAZ.
final class LifecycleSubjectViewController: LoggingViewController {
    private typealias ID = AccessibilityID.UIKitLabs.Lifecycle

    /// Şu an eklenmiş child VC (yoksa `nil`). Güçlü referans: child'ı üst VC sahiplenir.
    private(set) var embeddedChild: LifecycleDetailViewController?

    /// Child'ın view'ının yerleştirileceği alan.
    private let childSlot = UIView()
    private lazy var toggleChildButton = makeButton(title: "Child ekle", id: ID.toggleChildButton) { [weak self] in
        self?.toggleChild()
    }

    init(logger: LifecycleLogger) {
        super.init(logName: ID.presenterName, logger: logger)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let pageSheetButton = makeButton(title: "PageSheet sun", id: ID.presentPageSheetButton) { [weak self] in
            self?.presentModal(style: .pageSheet)
        }
        let fullScreenButton = makeButton(title: "FullScreen sun", id: ID.presentFullScreenButton) { [weak self] in
            self?.presentModal(style: .fullScreen)
        }
        let pushButton = makeButton(title: "Push et", id: ID.pushButton) { [weak self] in
            self?.pushDetail()
        }
        let relayoutButton = makeButton(title: "setNeedsLayout + layoutIfNeeded", id: ID.relayoutButton) { [weak self] in
            self?.relayout()
        }

        let firstRow = makeRow([pageSheetButton, fullScreenButton])
        let secondRow = makeRow([pushButton, toggleChildButton])

        childSlot.layer.borderColor = UIColor.separator.cgColor
        childSlot.layer.borderWidth = 1
        childSlot.layer.cornerRadius = 8
        childSlot.clipsToBounds = true

        // Boş çerçeve ne işe yarıyor, ekranda söylesin. Child eklenince onun opak view'ı bu yazının üstünü örter.
        let slotHint = UILabel()
        slotHint.text = "Child view controller buraya eklenir"
        slotHint.font = .preferredFont(forTextStyle: .footnote)
        slotHint.adjustsFontForContentSizeCategory = true
        slotHint.textColor = .secondaryLabel
        slotHint.textAlignment = .center
        slotHint.translatesAutoresizingMaskIntoConstraints = false
        childSlot.addSubview(slotHint)
        NSLayoutConstraint.activate([
            slotHint.centerYAnchor.constraint(equalTo: childSlot.centerYAnchor),
            slotHint.leadingAnchor.constraint(equalTo: childSlot.leadingAnchor, constant: 8),
            slotHint.trailingAnchor.constraint(equalTo: childSlot.trailingAnchor, constant: -8),
        ])

        let stack = UIStackView(arrangedSubviews: [firstRow, secondRow, relayoutButton, childSlot])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.bottomAnchor),
            childSlot.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    // MARK: - Eylemler

    /// Sunulacak ekranı hazırlar. Sunum stili **sunulan** VC'ye verilir, sunana değil.
    /// (iOS 13'ten beri varsayılan `.automatic`; iPhone'da bir sheet olarak görünür.)
    func makeModal(style: UIModalPresentationStyle) -> LifecycleDetailViewController {
        let isFullScreen = style == .fullScreen
        let modal = LifecycleDetailViewController(
            logName: isFullScreen ? ID.fullScreenName : ID.pageSheetName,
            logger: logger,
            message: isFullScreen
                ? "Ana'nın view'ı pencereden çıktı: Ana viewWillDisappear + viewDidDisappear aldı."
                : "Ana'nın view'ı hâlâ pencerede (arkada). Ana kaybolma bildirimi ALMADI. Aşağı kaydırarak da kapatabilirsin.",
            closeStyle: .dismiss
        )
        modal.modalPresentationStyle = style
        return modal
    }

    func presentModal(style: UIModalPresentationStyle) {
        present(makeModal(style: style), animated: true)
    }

    func pushDetail() {
        let detail = LifecycleDetailViewController(
            logName: ID.pushedName,
            logger: logger,
            message: "Push: Ana kayboldu (disappear), bu ekran göründü (appear). Geri dönünce tersi olur.",
            closeStyle: .pop
        )
        navigationController?.pushViewController(detail, animated: true)
    }

    /// Child VC ekleme ve çıkarma (containment). Sıra önemlidir:
    ///
    /// Ekleme:  `addChild` (child'a otomatik `willMove(toParent:)`) → view'ı ekle + constraint → `didMove(toParent: self)`
    /// Çıkarma: `willMove(toParent: nil)` → view'ı kaldır → `removeFromParent` (otomatik `didMove(toParent: nil)`)
    ///
    /// Görünüş bildirimleri (`viewWillAppear` vb.) child'a kendiliğinden iletilir; view'ı pencerede olan bir
    /// hiyerarşiye eklendiği an child appear, çıkarıldığı an disappear alır.
    func toggleChild() {
        if let child = embeddedChild {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
            embeddedChild = nil   // Son güçlü referans gider → child'ın deinit'i günlüğe düşer.
        } else {
            let child = LifecycleDetailViewController(
                logName: ID.childName,
                logger: logger,
                message: "addChild → addSubview → didMove(toParent:)",
                closeStyle: .none
            )
            addChild(child)
            child.view.translatesAutoresizingMaskIntoConstraints = false
            childSlot.addSubview(child.view)
            NSLayoutConstraint.activate([
                child.view.topAnchor.constraint(equalTo: childSlot.topAnchor),
                child.view.bottomAnchor.constraint(equalTo: childSlot.bottomAnchor),
                child.view.leadingAnchor.constraint(equalTo: childSlot.leadingAnchor),
                child.view.trailingAnchor.constraint(equalTo: childSlot.trailingAnchor),
            ])
            child.didMove(toParent: self)
            embeddedChild = child
        }
        var configuration = toggleChildButton.configuration
        configuration?.title = embeddedChild == nil ? "Child ekle" : "Child çıkar"
        toggleChildButton.configuration = configuration
    }

    /// `setNeedsLayout`: "Bir sonraki çizimden önce yeniden yerleştir" diye işaretler (ucuz, hemen bir şey olmaz).
    /// `layoutIfNeeded`: İşaretliyse yerleşimi **hemen, senkron** yapar → `viewWillLayoutSubviews` + `viewDidLayoutSubviews`.
    /// `viewDidLoad` tekrar çalışmaz: view zaten yüklü; layout ile yükleme ayrı şeylerdir.
    func relayout() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    // MARK: - Görünüm yardımcıları

    private func makeButton(title: String, id: String, action: @escaping @MainActor () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.gray()
        configuration.title = title
        configuration.buttonSize = .small
        configuration.titleLineBreakMode = .byTruncatingTail
        let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
        button.accessibilityIdentifier = id
        return button
    }

    private func makeRow(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8
        return row
    }
}
