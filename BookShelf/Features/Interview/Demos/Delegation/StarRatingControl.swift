import UIKit

/// Yıldız kontrolünün sahibine sorduğu soru ve verdiği haber.
///
/// Protokolü **sahip olunan** taraf (kontrol) tanımlar, **sahip** (view controller) uygular. Kontrol, sahibinin
/// hangi sınıf olduğunu bilmez; sadece "bu iki metodu cevaplayan biri" ister. Kalıtım yok, kompozisyon var.
///
/// - `AnyObject`: Yalnızca class'lar uygulayabilir. `weak var delegate` yazabilmenin şartı budur.
/// - `@MainActor`: UI olayları ana thread'de; sahibin metotları da ana actor'de çalışır.
/// - İlk parametre olarak kontrolün kendisi (`_ control:`) gönderilir. Cocoa geleneği: Aynı delegate birden çok
///   kontrolü yönetiyorsa (ör. bir ekranda iki yıldız satırı) hangisinden geldiğini ayırt edebilir.
@MainActor
protocol StarRatingControlDelegate: AnyObject {
    /// Soru: "Puanı şuna çevirebilir miyim?" Delegate'in bir **değer döndürebilmesi**, onu tek yönlü
    /// closure/bildirimden ayıran özelliktir (`UITableViewDelegate.tableView(_:shouldHighlightRowAt:)` gibi).
    func starRatingControl(_ control: StarRatingControl, shouldChangeRatingTo rating: Int) -> Bool

    /// Haber: "Puan değişti."
    func starRatingControl(_ control: StarRatingControl, didChangeRating rating: Int)
}

/// "İsteğe bağlı" delegate metodu: Swift protokollerinde `optional` yoktur (o yalnızca `@objc` protokollerde var).
/// Bunun yerine protokol extension'ı ile varsayılan bir cevap veririz; isteyen tip kendi cevabını yazar.
extension StarRatingControlDelegate {
    func starRatingControl(_ control: StarRatingControl, shouldChangeRatingTo rating: Int) -> Bool {
        true
    }
}

/// 1-5 arası puan veren küçük bir UIKit kontrolü. Olayı **üç kanaldan** birden duyurur, karşılaştırmak için:
///
/// | Kanal | Kontrol onu nasıl tutar? | Sahip tarafta ne gerekir? |
/// |---|---|---|
/// | `delegate` | `weak` | `control.delegate = self` |
/// | `onRatingChange` closure'ı | **güçlü** (closure'ı saklar) | Closure'da `[weak self]` |
/// | Target-action (`.valueChanged`) | Hiç tutmaz (UIControl hedefi retain etmez) | `addTarget(self, action:for:)` |
///
/// Gerçek bir kontrolde çoğu zaman bunlardan biri seçilir; burada üçünün de sahibi hayatta tutmadığını görmek için hepsi var.
final class StarRatingControl: UIControl {
    static let maximumRating = 5

    /// Kim kimi tutar? Sahip (VC) kontrolü view hiyerarşisi üzerinden güçlü tutar (VC → view → subviews).
    /// Kontrol de sahibini güçlü tutsaydı ikisi birbirini sonsuza dek yaşatırdı. Bu yüzden geri ok `weak`.
    weak var delegate: (any StarRatingControlDelegate)?

    /// Closure kanalı. Kontrol bu closure'ı **güçlü** saklar; closure `self`'i yakalarsa döngü kurulur.
    var onRatingChange: (@MainActor (Int) -> Void)?

    /// Güncel puan (0 = henüz puan yok).
    private(set) var rating: Int

    private(set) var starButtons: [UIButton] = []

    init(rating: Int = 0) {
        self.rating = min(max(rating, 0), Self.maximumRating)
        super.init(frame: .zero)
        buildStars()
        renderStars()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StarRatingControl kodla oluşturulur.")
    }

    /// Kullanıcının bir yıldıza dokunmasıyla aynı yolu izler (testler de bunu çağırır).
    ///
    /// Sıra önemli: Önce **sor** (delegate reddederse hiçbir şey değişmez), sonra **değiştir**, en son **haber ver**.
    func selectRating(_ newRating: Int) {
        let newRating = min(max(newRating, 0), Self.maximumRating)
        guard newRating != rating else { return }

        // `delegate?` → Optional chaining: delegate yoksa (atanmadı ya da çoktan yok oldu) soru sorulmaz, izin var sayılır.
        if let delegate, !delegate.starRatingControl(self, shouldChangeRatingTo: newRating) {
            return
        }

        rating = newRating
        renderStars()

        delegate?.starRatingControl(self, didChangeRating: newRating)
        onRatingChange?(newRating)
        // Target-action: `addTarget(_:action:for: .valueChanged)` ile kayıtlı herkese mesaj gönderir.
        sendActions(for: .valueChanged)
    }

    // MARK: - Görünüm

    private func buildStars() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        for number in 1...Self.maximumRating {
            let button = UIButton(type: .system)
            button.tintColor = .systemYellow
            button.accessibilityIdentifier = AccessibilityID.Delegation.starButton(number)
            button.accessibilityLabel = "\(number) yıldız"
            button.widthAnchor.constraint(equalToConstant: 44).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            // Kontrol → düğme → UIAction → closure. Closure kontrolü güçlü yakalasaydı döngü olurdu: [weak self].
            button.addAction(UIAction { [weak self] _ in self?.selectRating(number) }, for: .primaryActionTriggered)
            stack.addArrangedSubview(button)
            starButtons.append(button)
        }
    }

    private func renderStars() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        for (index, button) in starButtons.enumerated() {
            let isFilled = index < rating
            button.setImage(UIImage(systemName: isFilled ? "star.fill" : "star", withConfiguration: configuration), for: .normal)
            button.accessibilityTraits = isFilled ? [.button, .selected] : .button
        }
    }
}
