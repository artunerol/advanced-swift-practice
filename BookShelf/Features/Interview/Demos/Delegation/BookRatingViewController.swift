import UIKit

/// Delegate demosunun **sahibi**: `StarRatingControl`'ü oluşturur, view hiyerarşisine ekler (güçlü sahiplik)
/// ve onun delegate'i olur. Aynı olayı closure ve target-action ile de dinleyerek üç yolu yan yana gösterir.
///
/// ```
/// BookRatingViewController ──strong (view → subview)──▶ StarRatingControl
///          ▲                                                   │
///          └──────────────── weak delegate ────────────────────┘
/// ```
/// Kural: Uzun yaşayan sahip delegate olur; sahip olunan kontrol protokolü tanımlar ve delegate'i `weak` tutar.
/// Aralarında kalıtım (superclass) ilişkisi yok: VC `UIViewController`'dan, kontrol `UIControl`'den türüyor;
/// birbirlerine yalnızca `StarRatingControlDelegate` protokolü üzerinden bağlılar.
final class BookRatingViewController: UIViewController {
    private typealias ID = AccessibilityID.Delegation

    let ratingControl = StarRatingControl()
    let delegateLabel = UILabel()
    let closureLabel = UILabel()
    let targetActionLabel = UILabel()
    let lockSwitch = UISwitch()
    let statusLabel = UILabel()

    /// Açıkken delegate, `shouldChangeRatingTo` sorusuna "hayır" der.
    var isRatingLocked: Bool {
        lockSwitch.isOn
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        connectRatingControl()
    }

    /// Üç kanalı bağlar. Hiçbiri VC'yi güçlü tutmaz; bu yüzden VC kapanınca kontrol ona tutunamaz.
    /// (Kanıtı: `DelegateLifetimeExperiment`.)
    private func connectRatingControl() {
        // 1) Delegate: `StarRatingControl.delegate` weak. Tek satır, sızıntı riski yok.
        ratingControl.delegate = self

        // 2) Closure: Kontrol closure'ı güçlü saklar. Closure da self'i güçlü yakalasaydı:
        //    VC → view → kontrol → closure → VC döngüsü. Bu yüzden [weak self].
        ratingControl.onRatingChange = { [weak self] rating in
            self?.closureLabel.text = Self.channelText("Closure", rating: rating)
        }

        // 3) Target-action: UIControl hedefini retain ETMEZ (UIControl.h: "the target is not retained").
        //    Selector tabanlı olduğu için metodun `@objc` olması gerekir.
        ratingControl.addTarget(self, action: #selector(ratingControlValueChanged(_:)), for: .valueChanged)
    }

    @objc private func ratingControlValueChanged(_ sender: StarRatingControl) {
        targetActionLabel.text = Self.channelText("Target-action", rating: sender.rating)
    }

    /// "Delegate: 4/5"; henüz olay yoksa "Delegate: —".
    static func channelText(_ channel: String, rating: Int?) -> String {
        guard let rating else { return "\(channel): —" }
        return "\(channel): \(rating)/\(StarRatingControl.maximumRating)"
    }
}

// MARK: - StarRatingControlDelegate

extension BookRatingViewController: StarRatingControlDelegate {
    /// Varsayılan cevabı (her zaman `true`) protokol extension'ı veriyor; biz kendi kuralımızla eziyoruz.
    func starRatingControl(_ control: StarRatingControl, shouldChangeRatingTo rating: Int) -> Bool {
        guard !isRatingLocked else {
            statusLabel.text = "Delegate reddetti: puan \(control.rating)/\(StarRatingControl.maximumRating) olarak kaldı."
            return false
        }
        return true
    }

    func starRatingControl(_ control: StarRatingControl, didChangeRating rating: Int) {
        delegateLabel.text = Self.channelText("Delegate", rating: rating)
        statusLabel.text = "Puan \(rating)/\(StarRatingControl.maximumRating) oldu: üç kanal da haber aldı."
    }
}

// MARK: - Görünüm

extension BookRatingViewController {
    private func buildLayout() {
        view.backgroundColor = .systemBackground

        let titleLabel = makeLabel(style: .headline, color: .label)
        titleLabel.text = "Kitabı puanla"

        ratingControl.accessibilityIdentifier = ID.ratingControl
        let ratingRow = UIStackView(arrangedSubviews: [ratingControl, UIView()])
        ratingRow.axis = .horizontal

        for (label, identifier, channel) in [
            (delegateLabel, ID.delegateLabel, "Delegate"),
            (closureLabel, ID.closureLabel, "Closure"),
            (targetActionLabel, ID.targetActionLabel, "Target-action"),
        ] {
            configure(label, style: .body, color: .label)
            label.accessibilityIdentifier = identifier
            label.text = Self.channelText(channel, rating: nil)
        }

        let lockLabel = makeLabel(style: .subheadline, color: .label)
        lockLabel.text = "Delegate değişikliği reddetsin"
        lockSwitch.accessibilityIdentifier = ID.lockSwitch
        lockSwitch.accessibilityLabel = lockLabel.text
        let lockRow = UIStackView(arrangedSubviews: [lockLabel, lockSwitch])
        lockRow.axis = .horizontal
        lockRow.alignment = .center
        lockRow.spacing = 12

        configure(statusLabel, style: .footnote, color: .secondaryLabel)
        statusLabel.accessibilityIdentifier = ID.statusLabel
        statusLabel.text = "Bir yıldıza dokun."

        let wiringLabel = makeLabel(style: .footnote, color: .secondaryLabel)
        wiringLabel.text = """
        Kim kimi tutuyor?
        • VC → view → StarRatingControl: strong (view hiyerarşisi)
        • control.delegate → VC: weak
        • control.onRatingChange → closure: strong; closure → VC: [weak self]
        • addTarget(self, …): UIControl hedefi hiç tutmaz
        """

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, ratingRow, delegateLabel, closureLabel, targetActionLabel, lockRow, statusLabel, wiringLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(20, after: ratingRow)
        stack.setCustomSpacing(20, after: targetActionLabel)
        stack.setCustomSpacing(20, after: statusLabel)

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
        ])
    }

    private func makeLabel(style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        configure(label, style: style, color: color)
        return label
    }

    private func configure(_ label: UILabel, style: UIFont.TextStyle, color: UIColor) {
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
    }
}
