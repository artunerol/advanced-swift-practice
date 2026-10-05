import UIKit

/// **VIPER → View.** Arama kutusu (`UISearchBar`) + sonuç tablosu. Karar vermez: olayları presenter'a iletir,
/// presenter'ın verdiği durumu (`BookSearchViewState`) çizer.
///
/// Neden `UISearchController` değil? `UISearchController` arama çubuğunu navigasyon çubuğuna (`navigationItem.searchController`)
/// yerleştirir. Bu ekran, kendi navigasyon çubuğu olan SwiftUI konu ekranının içinde duruyor; UIKit çubuğunu da
/// göstersek alt alta iki çubuk olurdu (bkz. `BookSearchVIPERContainer`). Düz bir `UISearchBar` aynı işi çubuksuz yapar.
///
/// Satır yükseklikleri içeriğe göre (self-sizing): `UIListContentConfiguration` + `numberOfLines = 0` + `automaticDimension`.
final class BookSearchViewController: UIViewController {
    private typealias ID = AccessibilityID.BookSearch

    enum Section: Hashable {
        case recent
        case results
    }

    /// Tablodaki bir öğe. Geçmişteki aramalar sırasıyla birlikte tutulur: diffable data source öğelerin benzersiz olmasını
    /// ister; aynı metin iki kez gelse bile (ör. bozuk bir kayıt) çökme olmasın.
    enum Item: Hashable {
        case recent(index: Int, query: String)
        case book(BookSearchRow)
    }

    /// Boş arama kutusunun altındaki ipucu (geçmiş de boşsa).
    static let idleHint = "Kitap adı ya da yazar ara (en az 2 harf). Son aramaların burada görünür."

    private static let cellReuseIdentifier = "BookSearchCell"

    /// **strong** + **constructor injection**: VC modülün sahibidir; presenter'ı (ve onun üzerinden interactor ile
    /// router'ı) VC hayatta tutar.
    let presenter: any BookSearchPresenterProtocol

    // Testlerin `@testable import` ile okuyabilmesi için `internal`.
    let searchBar = UISearchBar()
    let statusLabel = UILabel()
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    let loadingIndicator = UIActivityIndicatorView(style: .large)
    let messageLabel = UILabel()
    let retryButton = UIButton(configuration: .filled())
    private let statusStack = UIStackView()

    /// Son çizilen durum. Sadece `render(_:)` değiştirir.
    private(set) var state: BookSearchViewState = .idle(recentSearches: [])

    /// `static` fabrika: hücre closure'ı `self`'i yakalayamaz (VC → dataSource → closure → VC döngüsü olmaz).
    private lazy var dataSource = Self.makeDataSource(for: tableView)

    init(presenter: any BookSearchPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BookSearchViewController kodla oluşturulur; BookSearchRouter.build(...) kullan.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        configureSearchBar()
        configureTableView()
        configureStatusViews()
        configureLayout()
        render(state)
        presenter.viewDidLoad()
    }

    // MARK: - Kurulum

    private func configureSearchBar() {
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Kitap adı ya da yazar"
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .search
        searchBar.delegate = self
        // XCUITest arama alanını `searchFields` altında görür; kimliği iç metin alanına veriyoruz.
        searchBar.searchTextField.accessibilityIdentifier = ID.searchField

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
        statusLabel.accessibilityIdentifier = ID.statusLabel
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.accessibilityIdentifier = ID.table
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        // Listeyi kaydırmaya başlayınca klavye insin; sonuçlar klavyenin altında kalmasın.
        tableView.keyboardDismissMode = .onDrag
        tableView.delegate = self
        tableView.dataSource = dataSource
    }

    private func configureStatusViews() {
        loadingIndicator.accessibilityIdentifier = ID.loadingIndicator
        loadingIndicator.accessibilityLabel = "Aranıyor"

        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.accessibilityIdentifier = ID.messageLabel

        var retryConfiguration = UIButton.Configuration.filled()
        retryConfiguration.title = "Tekrar dene"
        retryConfiguration.image = UIImage(systemName: "arrow.clockwise")
        retryConfiguration.imagePadding = 6
        retryButton.configuration = retryConfiguration
        retryButton.accessibilityIdentifier = ID.retryButton
        // `UIAction` + `[weak self]`: düğme closure'ı saklar; closure VC'yi strong yakalasaydı döngü kurulurdu.
        retryButton.addAction(UIAction { [weak self] _ in
            self?.presenter.didTapRetry()
        }, for: .primaryActionTriggered)

        statusStack.axis = .vertical
        statusStack.alignment = .center
        statusStack.spacing = 16
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        for subview in [loadingIndicator, messageLabel, retryButton] {
            statusStack.addArrangedSubview(subview)
        }
    }

    private func configureLayout() {
        let header = UIStackView(arrangedSubviews: [searchBar, statusLabel])
        header.axis = .vertical
        header.spacing = 4
        header.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        view.addSubview(tableView)
        view.addSubview(statusStack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            header.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Durum yığını tablonun üstünde, ortasında. Tablo boşken görünür (bkz. `render`).
            statusStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            statusStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            statusStack.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 48),
            messageLabel.widthAnchor.constraint(equalTo: statusStack.widthAnchor),
        ])
    }

    // MARK: - Data source

    /// Bölüm başlıkları için küçük bir alt sınıf: başlık bir **data source** sorusudur (delegate değil).
    private final class DataSource: UITableViewDiffableDataSource<Section, Item> {
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            switch sectionIdentifier(for: section) {
            case .recent: "Son aramalar"
            case .results: "Sonuçlar"
            case nil: nil
            }
        }
    }

    private static func makeDataSource(for tableView: UITableView) -> DataSource {
        DataSource(tableView: tableView) { tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
            configure(cell, with: item)
            return cell
        }
    }

    /// Hücreyi her seferinde BAŞTAN yapılandırır (hücreler yeniden kullanılır; önceki satırın kimliği kalmasın).
    static func configure(_ cell: UITableViewCell, with item: Item) {
        switch item {
        case .recent(let index, let query):
            var content = UIListContentConfiguration.cell()
            content.text = query
            content.image = UIImage(systemName: "clock.arrow.circlepath")
            content.imageProperties.tintColor = .secondaryLabel
            cell.contentConfiguration = content
            cell.accessoryType = .none
            cell.accessibilityIdentifier = ID.recentCell(index)
        case .book(let row):
            var content = UIListContentConfiguration.subtitleCell()
            content.text = row.title
            content.secondaryText = row.detail
            content.textProperties.numberOfLines = 0
            content.secondaryTextProperties.numberOfLines = 0
            content.secondaryTextProperties.color = .secondaryLabel
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = ID.resultCell(bookID: row.id)
        }
    }

    // MARK: - Test desteği

    /// Tabloda şu an gösterilen öğeler (data source'un son snapshot'ı).
    var displayedItems: [Item] {
        dataSource.snapshot().itemIdentifiers
    }
}

// MARK: - Presenter → View

extension BookSearchViewController: BookSearchViewProtocol {
    /// Ekranı verilen duruma getiren TEK yer. Metinlerin hepsi presenter'dan hazır gelir; burada yalnızca "hangisi görünsün".
    func render(_ state: BookSearchViewState) {
        self.state = state

        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        var message: String?
        var showsRetry = false
        var isLoading = false

        switch state {
        case .idle(let recentSearches):
            statusLabel.isHidden = true
            if recentSearches.isEmpty {
                message = Self.idleHint
            } else {
                snapshot.appendSections([.recent])
                snapshot.appendItems(
                    recentSearches.enumerated().map { Item.recent(index: $0.offset, query: $0.element) },
                    toSection: .recent
                )
            }
        case .loading:
            statusLabel.isHidden = true
            isLoading = true
        case .results(let rows):
            snapshot.appendSections([.results])
            snapshot.appendItems(rows.map(Item.book), toSection: .results)
        case .empty(let text):
            message = text
        case .error(let text, let canRetry):
            message = text
            showsRetry = canRetry
        }

        dataSource.apply(snapshot, animatingDifferences: viewIfLoaded?.window != nil)

        if isLoading {
            loadingIndicator.startAnimating() // `hidesWhenStopped` varsayılan `true`: durunca gizlenir.
        } else {
            loadingIndicator.stopAnimating()
        }
        messageLabel.text = message
        messageLabel.isHidden = message == nil
        retryButton.isHidden = !showsRetry
        // Satırlar görünürken yığını tamamen gizle; aksi halde boş yığın dokunuşları yakalayabilirdi.
        statusStack.isHidden = !isLoading && message == nil
    }

    func showStatus(_ message: String) {
        statusLabel.text = message
        statusLabel.isHidden = false
        // VoiceOver kullanıcısı da duysun: görsel geri bildirimin sesli karşılığı.
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    func showError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.view.accessibilityIdentifier = ID.errorAlert
        alert.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension BookSearchViewController: UISearchBarDelegate {
    /// Her harfte. VC karar vermez: "metin değişti" der; debounce ve iptal interactor'da.
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        presenter.didChangeSearchText(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        presenter.didSubmitSearch(searchBar.text ?? "")
    }
}

// MARK: - UITableViewDelegate

extension BookSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .recent(_, let query):
            // Kutuyu doldurmak bir UI ayrıntısı. Kodla atanan metin `textDidChange`'i tetiklemez; ikinci arama olmaz.
            searchBar.text = query
            searchBar.resignFirstResponder()
            presenter.didSelectRecentSearch(query)
        case .book(let row):
            presenter.didSelectBook(id: row.id)
        }
    }

    /// Sola kaydırınca "Özet" ve "Favori". VC ne yapılacağını bilmez; presenter'a kitabın kimliğini iletir.
    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard case .book(let row) = dataSource.itemIdentifier(for: indexPath) else { return nil }

        let insights = UIContextualAction(style: .normal, title: ID.insightsActionTitle) { [weak self] _, _, completion in
            self?.presenter.didRequestInsights(forBookID: row.id)
            completion(true)
        }
        insights.image = UIImage(systemName: "chart.bar.doc.horizontal")
        insights.backgroundColor = .systemIndigo

        let favorite = UIContextualAction(style: .normal, title: ID.favoriteActionTitle) { [weak self] _, _, completion in
            self?.presenter.didRequestFavoriteToggle(forBookID: row.id)
            completion(true)
        }
        favorite.image = UIImage(systemName: "heart")
        favorite.backgroundColor = .systemPink

        let configuration = UISwipeActionsConfiguration(actions: [insights, favorite])
        // Tam kaydırma ilk eylemi (Özet) kendiliğinden tetiklemesin; kullanıcı seçsin.
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}
