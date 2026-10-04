import UIKit

/// Başlıklı, solunda renkli bir şerit olan, eş aralıklı (monospaced) yazıyla gösterilen kısa bir kod parçası.
/// Sızıntı laboratuvarı "sızdıran / düzeltilmiş" kodu alt alta göstermek için kullanır.
///
/// Renkler `UIColor`'ın dinamik sistem renkleri (`.systemRed`, `.secondarySystemBackground`...) olduğu için
/// açık/koyu temaya kendiliğinden uyar. (Bir `CALayer`'ın `CGColor`'ı ise dinamik değildir; o yüzden kenarlık yerine şerit.)
final class CodeSnippetView: UIView {
    private let accentStripe = UIView()
    private let titleLabel = UILabel()
    private let codeLabel = UILabel()

    init() {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 10
        layer.masksToBounds = true

        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.adjustsFontForContentSizeCategory = true

        // Kod için sabit genişlikli yazı tipi; UIFontMetrics onu kullanıcının yazı boyutu ayarına göre ölçekler.
        codeLabel.font = UIFontMetrics(forTextStyle: .footnote)
            .scaledFont(for: .monospacedSystemFont(ofSize: 12, weight: .regular))
        codeLabel.adjustsFontForContentSizeCategory = true
        codeLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, codeLabel])
        stack.axis = .vertical
        stack.spacing = 4

        for subview in [accentStripe, stack] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }
        NSLayoutConstraint.activate([
            accentStripe.leadingAnchor.constraint(equalTo: leadingAnchor),
            accentStripe.topAnchor.constraint(equalTo: topAnchor),
            accentStripe.bottomAnchor.constraint(equalTo: bottomAnchor),
            accentStripe.widthAnchor.constraint(equalToConstant: 4),

            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: accentStripe.trailingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("CodeSnippetView kodla oluşturulur.")
    }

    func configure(title: String, code: String, tint: UIColor) {
        titleLabel.text = title
        titleLabel.textColor = tint
        accentStripe.backgroundColor = tint
        codeLabel.text = code
    }
}
