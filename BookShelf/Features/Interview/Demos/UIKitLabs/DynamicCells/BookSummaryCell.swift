import UIKit

/// Yüksekliği içeriğine göre hesaplanan (self-sizing) kitap hücresi. Dokununca özet açılır/kapanır.
///
/// Self-sizing'in üç şartı (bu sınıfta hepsi var):
/// 1. Alt view'lar `contentView`'a eklenir (hücrenin kendisine değil).
/// 2. Constraint'ler `contentView`'un **üstünden altına kesintisiz** bir zincir kurar. Auto Layout yüksekliği bu
///    zincirden hesaplar: üst boşluk + başlık + yazar + özet + ayrıntı + alt boşluk.
/// 3. Çok satırlı label'larda `numberOfLines = 0` (ya da sınırlı sayı). Tablo tarafında
///    `rowHeight = UITableView.automaticDimension` (bkz. `DynamicCellsViewController`).
final class BookSummaryCell: UITableViewCell {
    static let reuseIdentifier = "BookSummaryCell"
    /// Kapalıyken özetin en fazla kaç satır görüneceği.
    static let collapsedSummaryLineCount = 2

    let titleLabel = UILabel()
    let authorLabel = UILabel()
    let summaryLabel = UILabel()
    /// Yalnızca açıkken görünür. `UIStackView`, gizli elemanı yerleşimden tamamen çıkarır; yükseklik de kısalır.
    let detailsLabel = UILabel()
    private let chevronView = UIImageView()

    private(set) var isExpanded = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureLabels()
        configureLayout()
        setExpanded(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BookSummaryCell kodla oluşturulur.")
    }

    /// Hücreyi bir kitapla BAŞTAN yapılandırır. Yeniden kullanılan hücrede önceki kitaptan hiçbir şey kalmamalı;
    /// bu yüzden her özellik (kimlik ve açık/kapalı durumu dahil) burada her seferinde atanır.
    func configure(with book: Book, isExpanded: Bool) {
        titleLabel.text = book.title
        authorLabel.text = "\(book.author) · \(String(book.year))"
        summaryLabel.text = book.summary
        detailsLabel.text = "\(book.pageCount) sayfa · ISBN \(book.isbn)"
        accessibilityIdentifier = AccessibilityID.UIKitLabs.DynamicCells.bookCell(book.id)
        setExpanded(isExpanded)
    }

    /// Açık/kapalı görünümü uygular. Yüksekliği değiştirir ama tabloya haber VERMEZ; tablo
    /// `performBatchUpdates(nil)` çağrılınca yeni yüksekliği sorar (bkz. `DynamicCellsViewController.toggleBook(at:)`).
    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        summaryLabel.numberOfLines = expanded ? 0 : Self.collapsedSummaryLineCount
        detailsLabel.isHidden = !expanded
        chevronView.image = UIImage(systemName: expanded ? "chevron.up" : "chevron.down")
        accessibilityValue = expanded
            ? AccessibilityID.UIKitLabs.DynamicCells.expandedValue
            : AccessibilityID.UIKitLabs.DynamicCells.collapsedValue
    }

    /// Hücre kuyruktan (reuse queue) tekrar verilmeden hemen önce çağrılır.
    ///
    /// Burası yalnızca **geçici** durumu sıfırlamak içindir (ör. süren bir resim indirmesini iptal etmek, seçim/animasyon).
    /// İçerik yine `cellForRowAt` içinde `configure(with:isExpanded:)` ile her seferinde baştan verilir;
    /// prepareForReuse'a güvenip orada içerik ayarlamak yanlış olur.
    override func prepareForReuse() {
        super.prepareForReuse()
        setExpanded(false)
    }

    // MARK: - Kurulum

    private func configureLabels() {
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        authorLabel.font = .preferredFont(forTextStyle: .subheadline)
        authorLabel.textColor = .secondaryLabel
        summaryLabel.font = .preferredFont(forTextStyle: .body)
        detailsLabel.font = .preferredFont(forTextStyle: .footnote)
        detailsLabel.textColor = .tertiaryLabel

        for label in [titleLabel, authorLabel, summaryLabel, detailsLabel] {
            label.numberOfLines = 0
            // Dynamic Type: Kullanıcı yazı boyutunu büyütünce hücre de kendiliğinden uzar (self-sizing'in bedava kazancı).
            label.adjustsFontForContentSizeCategory = true
        }

        chevronView.tintColor = .tertiaryLabel
        chevronView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
        // Ok simgesi doğal genişliğinde kalsın; fazla genişliği metinler alsın.
        chevronView.setContentHuggingPriority(.required, for: .horizontal)
        chevronView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func configureLayout() {
        let textStack = UIStackView(arrangedSubviews: [titleLabel, authorLabel, summaryLabel, detailsLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [textStack, chevronView])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        // Alt constraint'in önceliği 999: Tablo, hücreyi ölçmeden önce ona geçici bir yükseklik verir
        // (`UIView-Encapsulated-Layout-Height`). Zincir "zorunlu" (1000) olsaydı bu geçici değerle çakışır ve konsola
        // "Unable to simultaneously satisfy constraints" yazılırdı. 999, zinciri neredeyse zorunlu bırakıp çakışmayı önler.
        let bottom = row.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        bottom.priority = .required - 1

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            bottom,
        ])
    }
}
