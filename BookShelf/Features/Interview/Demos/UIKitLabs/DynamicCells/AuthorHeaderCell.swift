import UIKit

/// Yazar satırı: Aynı tabloda ikinci bir hücre tipi (ayrı sınıf, ayrı reuse identifier).
///
/// Bilerek bölüm başlığı (`viewForHeaderInSection`) değil, bir HÜCRE: Amaç "tek tabloda birden çok hücre tipi"
/// kalıbını göstermek. Gerçek bir uygulamada yazara göre gruplamak için bölümler + başlıklar da doğru bir seçim olurdu.
///
/// Bu hücre de self-sizing: `UIListContentConfiguration` (iOS 14+) metni çok satırlı ve Auto Layout ile yerleştirir;
/// kendi constraint'imizi yazmamıza gerek kalmaz.
final class AuthorHeaderCell: UITableViewCell {
    static let reuseIdentifier = "AuthorHeaderCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .secondarySystemBackground
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AuthorHeaderCell kodla oluşturulur.")
    }

    func configure(authorName: String, bookCount: Int, index: Int) {
        var content = defaultContentConfiguration()
        content.image = UIImage(systemName: "person.crop.circle")
        content.text = authorName
        content.textProperties.font = .preferredFont(forTextStyle: .headline)
        content.secondaryText = "\(bookCount) kitap"
        contentConfiguration = content
        accessibilityIdentifier = AccessibilityID.UIKitLabs.DynamicCells.authorCell(index)
    }
}
