import UIKit

/// Aynı kitaplar, üç farklı biçimde: `UITableView`, list configuration'lı `UICollectionView` ve compositional
/// layout'lu ızgara. Üçü de diffable data source kullanır; değişen tek şey **view ve yerleşim**.
///
/// Karar rehberi:
/// - Tek sütunlu, dikey bir liste ve hazır davranışlar (kaydırma eylemleri, düzenleme, bölüm başlıkları) → `UITableView`.
/// - Izgara, yatay kayan bölüm, farklı yerleşimli bölümler, ileride değişebilecek tasarım → `UICollectionView`.
/// - iOS 14+ list configuration ile collection view tabloya da dönüşebilir; tablo özelliklerinin büyük kısmı orada da var.
final class TableVsCollectionViewController: UIViewController {
    private typealias ID = AccessibilityID.UIKitLabs.TableVsCollection

    enum Mode: Int, CaseIterable {
        case table, list, grid

        var title: String {
            switch self {
            case .table: ID.tableSegment
            case .list: ID.listSegment
            case .grid: ID.gridSegment
            }
        }

        var caption: String {
            switch self {
            case .table: "UITableView + UITableViewDiffableDataSource: sabit yerleşim, tek sütun, dikey liste."
            case .list: "UICollectionView + UICollectionLayoutListConfiguration (iOS 14+): tablo gibi görünen collection view."
            case .grid: "UICollectionView + compositional layout: üstte yatay kayan bölüm, altta sütunlu ızgara."
            }
        }
    }

    /// Izgaranın bölümleri. Bölüm ve öğe kimlikleri `Hashable` olmalı (diffable data source şartı).
    enum GridSection: Int, CaseIterable, Hashable, Sendable {
        case featured, all
    }

    /// Izgaradaki bir öğenin kimliği. Neden yalnızca `Book.ID` değil? Bir kitap hem "öne çıkanlar"da hem "tüm
    /// kitaplar"da var. Snapshot'taki kimlikler **tüm snapshot'ta** benzersiz olmalı; aynı id iki kez eklenirse
    /// diffable data source çalışma anında hata verir. Bölümü kimliğe katarak ikisini ayırıyoruz.
    struct GridItem: Hashable, Sendable {
        let section: GridSection
        let bookID: Book.ID
    }

    /// Öne çıkanlar bölümünde gösterilecek kitap sayısı.
    static let featuredCount = 4

    let books: [Book]
    private(set) var mode: Mode = .table

    let modeControl = UISegmentedControl(items: Mode.allCases.map(\.title))
    let captionLabel = UILabel()
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    let listCollectionView = UICollectionView(frame: .zero, collectionViewLayout: TableVsCollectionLayouts.list())
    let gridCollectionView = UICollectionView(frame: .zero, collectionViewLayout: TableVsCollectionLayouts.grid())

    // Data source'lar `lazy`: view'lara ihtiyaç duyar; ilk erişim `viewDidLoad`'da olur.
    // Fabrikalar `static`: kapanışlar `self`'i yakalayamasın (VC → dataSource → kapanış → VC döngüsü olmasın).
    private(set) lazy var tableDataSource = Self.makeTableDataSource(tableView, books: booksByID)
    private(set) lazy var listDataSource = Self.makeListDataSource(listCollectionView, books: booksByID)
    private(set) lazy var gridDataSource = Self.makeGridDataSource(gridCollectionView, books: booksByID)

    private let booksByID: [Book.ID: Book]

    init(books: [Book]) {
        self.books = books
        booksByID = Dictionary(books.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("TableVsCollectionViewController kodla oluşturulur.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        configureViews()
        applySnapshots()
        select(.table)
    }

    /// Seçili modu gösterir. Üç view da hiyerarşide; yalnızca biri görünür.
    func select(_ newMode: Mode) {
        mode = newMode
        modeControl.selectedSegmentIndex = newMode.rawValue
        captionLabel.text = newMode.caption
        tableView.isHidden = newMode != .table
        listCollectionView.isHidden = newMode != .list
        gridCollectionView.isHidden = newMode != .grid
    }

    // MARK: - Snapshot'lar

    private func applySnapshots() {
        let ids = books.map(\.id)

        var tableSnapshot = NSDiffableDataSourceSnapshot<Int, Book.ID>()
        tableSnapshot.appendSections([0])
        tableSnapshot.appendItems(ids)
        tableDataSource.apply(tableSnapshot, animatingDifferences: false)

        var listSnapshot = NSDiffableDataSourceSnapshot<Int, Book.ID>()
        listSnapshot.appendSections([0])
        listSnapshot.appendItems(ids)
        listDataSource.apply(listSnapshot, animatingDifferences: false)

        var gridSnapshot = NSDiffableDataSourceSnapshot<GridSection, GridItem>()
        gridSnapshot.appendSections(GridSection.allCases)
        gridSnapshot.appendItems(ids.prefix(Self.featuredCount).map { GridItem(section: .featured, bookID: $0) }, toSection: .featured)
        gridSnapshot.appendItems(ids.map { GridItem(section: .all, bookID: $0) }, toSection: .all)
        gridDataSource.apply(gridSnapshot, animatingDifferences: false)
    }

    // MARK: - Data source fabrikaları
    //
    // Öğe kimliği olarak `Book` değil `Book.ID` kullanıyoruz (Apple'ın önerisi): Snapshot küçük kalır, içerik
    // değişirse `reconfigureItems` ile güncellenir. Kitabın kendisini hücre kurulurken sözlükten buluruz.

    private static func makeTableDataSource(
        _ tableView: UITableView,
        books: [Book.ID: Book]
    ) -> UITableViewDiffableDataSource<Int, Book.ID> {
        let reuseIdentifier = "TableVsCollectionBookCell"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        return UITableViewDiffableDataSource(tableView: tableView) { tableView, indexPath, bookID in
            // Tabloda kimlik bir string: kaydederken ve alırken aynı metni yazmak bize kalmış.
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = books[bookID]?.title
            content.secondaryText = books[bookID]?.author
            cell.contentConfiguration = content
            cell.accessibilityIdentifier = ID.tableCell(bookID)
            return cell
        }
    }

    private static func makeListDataSource(
        _ collectionView: UICollectionView,
        books: [Book.ID: Book]
    ) -> UICollectionViewDiffableDataSource<Int, Book.ID> {
        // `CellRegistration` (iOS 14+): Hücre tipi ve öğe tipi generic parametre → string kimlik ve `as!` cast yok.
        // Kayıt, cell provider kapanışının DIŞINDA bir kez oluşturulur. İçinde oluşturmak hücre yeniden kullanımını
        // engeller ve iOS 15+ çalışma anında istisna fırlatır.
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Book.ID> { cell, _, bookID in
            var content = cell.defaultContentConfiguration()
            content.text = books[bookID]?.title
            content.secondaryText = books[bookID]?.author
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
            cell.accessibilityIdentifier = ID.listCell(bookID)
        }
        return UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, bookID in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: bookID)
        }
    }

    private static func makeGridDataSource(
        _ collectionView: UICollectionView,
        books: [Book.ID: Book]
    ) -> UICollectionViewDiffableDataSource<GridSection, GridItem> {
        let registration = UICollectionView.CellRegistration<BookTileCell, GridItem> { cell, _, item in
            guard let book = books[item.bookID] else { return }
            let isFeatured = item.section == .featured
            cell.configure(with: book, featured: isFeatured)
            cell.accessibilityIdentifier = isFeatured ? ID.featuredCell(book.id) : ID.gridCell(book.id)
        }
        let headerRegistration = UICollectionView.SupplementaryRegistration<GridHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { header, _, indexPath in
            header.titleLabel.text = GridSection(rawValue: indexPath.section) == .featured
                ? "Öne çıkanlar (yana kaydır)"
                : "Tüm kitaplar"
        }

        let dataSource = UICollectionViewDiffableDataSource<GridSection, GridItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
        return dataSource
    }

    // MARK: - Görünüm kurulumu

    private func configureViews() {
        modeControl.accessibilityIdentifier = ID.modePicker
        modeControl.addAction(UIAction { [weak self] action in
            guard let control = action.sender as? UISegmentedControl,
                  let mode = Mode(rawValue: control.selectedSegmentIndex) else { return }
            self?.select(mode)
        }, for: .valueChanged)

        captionLabel.font = .preferredFont(forTextStyle: .footnote)
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.textColor = .secondaryLabel
        captionLabel.numberOfLines = 0
        captionLabel.accessibilityIdentifier = ID.caption

        tableView.accessibilityIdentifier = ID.table
        listCollectionView.accessibilityIdentifier = ID.listCollection
        gridCollectionView.accessibilityIdentifier = ID.gridCollection
        gridCollectionView.backgroundColor = .systemGroupedBackground

        let header = UIStackView(arrangedSubviews: [modeControl, captionLabel])
        header.axis = .vertical
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        var constraints = [
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ]
        // Üç view aynı alanı paylaşır (üst üste); `select(_:)` hangisinin görüneceğine karar verir.
        for content in [tableView, listCollectionView, gridCollectionView] as [UIView] {
            content.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(content)
            constraints += [
                content.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
                content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }
}
