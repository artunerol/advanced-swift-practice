import UIKit

/// Izgaradaki kitap kartı. `UICollectionViewCell`'in hazır bir içerik düzeni yoktur (tablo hücresinin `textLabel`'ı
/// gibi); her şey `contentView`'a eklenir. Constraint'ler üstten alta bağlı olduğu için kart, layout'taki
/// `.estimated` yükseklikle birlikte kendi boyunu hesaplar.
final class BookTileCell: UICollectionViewCell {
    let titleLabel = UILabel()
    let authorLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 0
        authorLabel.font = .preferredFont(forTextStyle: .caption1)
        authorLabel.numberOfLines = 0
        for label in [titleLabel, authorLabel] {
            label.adjustsFontForContentSizeCategory = true
        }

        let stack = UIStackView(arrangedSubviews: [titleLabel, authorLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BookTileCell kodla oluşturulur.")
    }

    /// Hücreyi baştan yapılandırır (yeniden kullanımda önceki kitaptan bir şey kalmasın).
    func configure(with book: Book, featured: Bool) {
        titleLabel.text = book.title
        authorLabel.text = "\(book.author) · \(String(book.year))"
        contentView.backgroundColor = featured ? .systemIndigo : .secondarySystemGroupedBackground
        titleLabel.textColor = featured ? .white : .label
        authorLabel.textColor = featured ? UIColor.white.withAlphaComponent(0.85) : .secondaryLabel
    }
}

/// Izgara bölümlerinin başlığı (supplementary view). Hücre değil: data source'un öğesi yoktur, layout ister.
final class GridHeaderView: UICollectionReusableView {
    let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("GridHeaderView kodla oluşturulur.")
    }
}
