import UIKit

/// Dinamik yükseklikli (self-sizing) hücreler: klasik `UITableViewDataSource` ile, bilerek.
///
/// Mülakatta beklenen kalıp tam olarak bu: `register` → `numberOfRowsInSection` → `cellForRowAt` içinde
/// `dequeueReusableCell(withIdentifier:for:)`. Modern alternatif olan diffable data source için
/// `FavoritesViewController.makeDataSource(for:)`'a bak; hücre tarafı (self-sizing) ikisinde de aynıdır.
///
/// Tabloda iki hücre tipi var: yazar satırı (`AuthorHeaderCell`) ve kitap satırı (`BookSummaryCell`).
/// Satırlar bir `enum` ile modellenir; `cellForRowAt` bu enum'a göre doğru tipi seçer.
final class DynamicCellsViewController: UIViewController {
    /// Tablonun bir satırı. Farklı hücre tiplerini tek dizide tutmanın en okunur yolu: ilişkili değerli enum.
    enum Row: Equatable {
        case author(name: String, bookCount: Int, index: Int)
        case book(Book)
    }

    let tableView = UITableView(frame: .zero, style: .plain)
    let rows: [Row]
    /// Açık (genişletilmiş) kitapların id'leri. Durum hücrede DEĞİL burada tutulur: hücreler yeniden kullanılır,
    /// ekrandan çıkan bir hücrenin üzerinde kalan "açık" bilgisi başka bir kitaba geçerdi.
    private(set) var expandedBookIDs: Set<Book.ID> = []

    init(books: [Book]) {
        rows = Self.makeRows(from: books)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("DynamicCellsViewController kodla oluşturulur.")
    }

    /// Kitapları yazara göre gruplar; yazarlar kitap listesindeki ilk görünme sırasıyla gelir.
    static func makeRows(from books: [Book]) -> [Row] {
        var authorOrder: [String] = []
        var booksByAuthor: [String: [Book]] = [:]
        for book in books {
            if booksByAuthor[book.author] == nil { authorOrder.append(book.author) }
            booksByAuthor[book.author, default: []].append(book)
        }
        return authorOrder.enumerated().flatMap { index, author -> [Row] in
            let authorBooks = booksByAuthor[author] ?? []
            return [.author(name: author, bookCount: authorBooks.count, index: index)] + authorBooks.map(Row.book)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureTableView()
    }

    private func configureTableView() {
        // Her hücre sınıfı kendi kimliğiyle kaydedilir; `dequeueReusableCell(withIdentifier:for:)` bu kimlikle
        // ya kuyruktaki eski bir hücreyi geri verir ya da kaydedilen sınıftan yenisini oluşturur.
        tableView.register(AuthorHeaderCell.self, forCellReuseIdentifier: AuthorHeaderCell.reuseIdentifier)
        tableView.register(BookSummaryCell.self, forCellReuseIdentifier: BookSummaryCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self

        // Self-sizing: Yüksekliği hücrenin Auto Layout zinciri belirlesin. (iOS 11'den beri ikisi de varsayılan olarak
        // `automaticDimension`; açıkça yazmak niyeti belli eder.) Tahmin, gerçek ortalamaya yakın olursa kaydırma
        // çubuğu ve içerik boyutu daha az "zıplar"; tablo tüm satırları önceden ölçmek zorunda kalmaz.
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120

        tableView.accessibilityIdentifier = AccessibilityID.UIKitLabs.DynamicCells.table
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    /// Kitap satırını açar/kapatır ve yükseklik değişimini animasyonla uygular.
    ///
    /// 1. Durumu güncelle (tek doğruluk kaynağı: `expandedBookIDs`).
    /// 2. Ekrandaki hücreyi **yerinde** güncelle. `reloadRows(at:with:)` da olurdu ama hücreyi yeniden yapılandırır
    ///    (çapraz geçiş animasyonu, hücrenin geçici durumu kaybolur). Ekranda değilse bir şey yapmaya gerek yok:
    ///    hücre ekrana girerken `cellForRowAt` zaten doğru durumu verecek.
    /// 3. `performBatchUpdates(nil)`: Veri değişikliği olmayan boş bir toplu güncelleme. Tablo görünen satırların
    ///    yüksekliklerini yeniden sorar ve farkı animasyonla uygular. Eski yazımı: `beginUpdates()` + `endUpdates()`
    ///    (Apple ileride deprecated olacağını söylüyor; `performBatchUpdates` iOS 11+).
    func toggleBook(at indexPath: IndexPath) {
        guard case .book(let book) = rows[indexPath.row] else { return }
        let isExpanded = !expandedBookIDs.contains(book.id)
        if isExpanded {
            expandedBookIDs.insert(book.id)
        } else {
            expandedBookIDs.remove(book.id)
        }
        (tableView.cellForRow(at: indexPath) as? BookSummaryCell)?.setExpanded(isExpanded)
        tableView.performBatchUpdates(nil)
    }
}

// MARK: - UITableViewDataSource

extension DynamicCellsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case let .author(name, bookCount, index):
            // `for: indexPath` sürümü kayıtlı sınıftan HER ZAMAN bir hücre döndürür (optional değil; kimlik kayıtlı
            // değilse çöker) ve index path'i hücreyi tablodaki konumuna göre hazırlamak için kullanır.
            // Eski `dequeueReusableCell(withIdentifier:)` ise `nil` dönebilir; yeni kodda bu sürümü kullan.
            let cell = tableView.dequeueReusableCell(withIdentifier: AuthorHeaderCell.reuseIdentifier, for: indexPath)
            (cell as? AuthorHeaderCell)?.configure(authorName: name, bookCount: bookCount, index: index)
            return cell
        case .book(let book):
            let cell = tableView.dequeueReusableCell(withIdentifier: BookSummaryCell.reuseIdentifier, for: indexPath)
            (cell as? BookSummaryCell)?.configure(with: book, isExpanded: expandedBookIDs.contains(book.id))
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension DynamicCellsViewController: UITableViewDelegate {
    /// Yazar satırları seçilemez; yalnızca kitap satırları açılıp kapanır.
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if case .book = rows[indexPath.row] { indexPath } else { nil }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        toggleBook(at: indexPath)
    }
}
