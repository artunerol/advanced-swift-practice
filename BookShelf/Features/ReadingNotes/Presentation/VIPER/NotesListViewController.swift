import UIKit

/// **VIPER → View.** Programatik `UITableView` ile not listesi. Karar vermez: olayları presenter'a iletir,
/// presenter'ın verdiği durumu (`NotesListViewState`) çizer.
///
/// Karşılaştır: Favoriler ekranı (`FavoritesViewController`) MVC'ye yakın; veri yükleme, dinleme ve navigasyon VC'nin
/// içinde. Burada VC'de iş mantığı yok, `if` bile neredeyse yok; test edilmesi gereken mantık presenter ve
/// interactor'da ve onlar UIKit'siz test ediliyor.
///
/// Satır yükseklikleri içeriğe göre hesaplanır (**self-sizing cells**), bkz. `configureTableView()`.
final class NotesListViewController: UIViewController {
    private typealias ID = AccessibilityID.ReadingNotes.VIPER

    enum Section: Hashable {
        case main
    }

    private static let cellReuseIdentifier = "NoteCell"

    /// **strong** + **constructor injection**: VC modülün sahibidir; presenter'ı (ve onun üzerinden interactor ile
    /// router'ı) VC hayatta tutar. VC ekrandan kalkıp serbest kalınca modülün tamamı onunla gider.
    let presenter: any NotesListPresenterProtocol

    // Testlerin `@testable import` ile durumu okuyabilmesi için `internal`.
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    let summaryLabel = UILabel()
    let addButton = UIButton(configuration: .filled())
    let emptyStateLabel = UILabel()
    let loadingIndicator = UIActivityIndicatorView(style: .medium)

    /// Son çizilen durum. Sadece `render(_:)` değiştirir.
    private(set) var state: NotesListViewState = .loading

    /// `static` fabrika: hücre closure'ı `self`'i yakalayamaz (VC → dataSource → closure → VC döngüsü olmaz).
    private lazy var dataSource = Self.makeDataSource(for: tableView)

    init(presenter: any NotesListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("NotesListViewController kodla oluşturulur; NotesListRouter.build(repository:) kullan.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        configureHeader()
        configureTableView()
        configureLayout()
        render(state)
        // View hazır; presenter'a haber ver. Ne yükleneceğine o karar verir.
        presenter.viewDidLoad()
    }

    // MARK: - Kurulum

    private func configureHeader() {
        summaryLabel.font = .preferredFont(forTextStyle: .subheadline)
        summaryLabel.adjustsFontForContentSizeCategory = true
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 0
        summaryLabel.accessibilityIdentifier = ID.summary

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Not ekle"
        configuration.image = UIImage(systemName: "plus")
        configuration.imagePadding = 6
        configuration.cornerStyle = .capsule
        addButton.configuration = configuration
        addButton.accessibilityIdentifier = ID.addButton
        // `UIAction` + `[weak self]`: düğme closure'ı saklar; closure VC'yi strong yakalasaydı döngü kurulurdu.
        addButton.addAction(UIAction { [weak self] _ in
            self?.presenter.didTapAddNote()
        }, for: .primaryActionTriggered)
        // Uzun özet metni düğmeyi ezmesin: düğme kendi doğal genişliğinde kalsın.
        addButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        addButton.setContentHuggingPriority(.required, for: .horizontal)

        emptyStateLabel.font = .preferredFont(forTextStyle: .body)
        emptyStateLabel.adjustsFontForContentSizeCategory = true
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.accessibilityIdentifier = ID.emptyState

        loadingIndicator.accessibilityIdentifier = ID.loadingIndicator
    }

    /// **Self-sizing cells (dinamik yükseklikli hücreler)** için üç şart:
    /// 1. `rowHeight = UITableView.automaticDimension`: "yüksekliği içerikten hesapla".
    /// 2. `estimatedRowHeight`: kaydırma çubuğu ve ilk yerleşim için tahmin. (1 ve 2, güncel SDK'da zaten varsayılan;
    ///    burada görünür olsun diye açıkça yazıyoruz.)
    /// 3. Hücre içeriğinin Auto Layout ile yukarıdan aşağıya tam bağlanması ve çok satırlı label (`numberOfLines = 0`).
    ///    `UIListContentConfiguration` bu şartı kendisi sağlar; kendi hücreni yazarsan constraint'leri `contentView`'a
    ///    bağlamak senin işin.
    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.accessibilityIdentifier = ID.table
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.delegate = self
        tableView.dataSource = dataSource
    }

    private func configureLayout() {
        let header = UIStackView(arrangedSubviews: [summaryLabel, addButton])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 12
        header.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private static func makeDataSource(for tableView: UITableView) -> UITableViewDiffableDataSource<Section, NoteRow> {
        UITableViewDiffableDataSource(tableView: tableView) { tableView, indexPath, row in
            let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
            var content = UIListContentConfiguration.subtitleCell()
            content.text = row.text
            content.secondaryText = row.detail
            content.textProperties.numberOfLines = 0 // satır sınırı yok → hücre metin kadar uzar
            content.secondaryTextProperties.color = .secondaryLabel
            cell.contentConfiguration = content
            cell.selectionStyle = .none
            return cell
        }
    }
}

// MARK: - Presenter → View

extension NotesListViewController: NotesListViewProtocol {
    func render(_ state: NotesListViewState) {
        self.state = state

        // Metinlerin hepsi presenter'dan hazır gelir; burada biçimlendirme yok, sadece "hangisi görünsün".
        // `backgroundView`: tablonun arkasında, satırların altında duran görünüm. Boş/yükleniyor durumu için ideal.
        let rows: [NoteRow]
        switch state {
        case .loading:
            rows = []
            summaryLabel.text = nil
            loadingIndicator.startAnimating()
            tableView.backgroundView = loadingIndicator
        case .empty(let message):
            rows = []
            summaryLabel.text = nil
            emptyStateLabel.text = message
            loadingIndicator.stopAnimating()
            tableView.backgroundView = emptyStateLabel
        case .notes(let summary, let newRows):
            rows = newRows
            summaryLabel.text = summary
            loadingIndicator.stopAnimating()
            tableView.backgroundView = nil
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, NoteRow>()
        snapshot.appendSections([.main])
        snapshot.appendItems(rows, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: viewIfLoaded?.window != nil)
    }

    func showError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.view.accessibilityIdentifier = ID.errorAlert
        let ok = UIAlertAction(title: "Tamam", style: .default)
        ok.accessibilityIdentifier = ID.errorOKButton
        alert.addAction(ok)
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate

extension NotesListViewController: UITableViewDelegate {
    /// Sola kaydırınca "Sil". VC silmez; presenter'a "kullanıcı bunu silmek istiyor" der.
    /// Satır, depo silindikten sonra gelen yeni durumla (render) kalkar: tek doğruluk kaynağı depo.
    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let row = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let delete = UIContextualAction(
            style: .destructive,
            title: AccessibilityID.ReadingNotes.deleteActionTitle
        ) { [weak self] _, _, completion in
            self?.presenter.didRequestDeleteNote(id: row.id)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
