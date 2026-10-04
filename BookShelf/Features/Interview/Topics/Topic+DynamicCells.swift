import SwiftUI

extension InterviewTopic {
    static let dynamicCells = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.dynamicCells,
        section: .uikit,
        question: "UITableView'da dinamik yükseklikli (self-sizing) hücre nasıl yapılır?",
        shortAnswer: [
            "Tabloda rowHeight = UITableView.automaticDimension ve gerçeğe yakın bir estimatedRowHeight (iOS 11'den beri ikisi de varsayılan olarak automatic; açıkça yazmak niyeti belli eder).",
            "Hücrede alt view'ları contentView'a ekle ve constraint'leri yukarıdan aşağı KESİNTİSİZ bağla: üst kenar → label'lar → alt kenar. Yüksekliği Auto Layout bu zincirden hesaplar.",
            "Çok satırlı label'da numberOfLines = 0; Dynamic Type için preferredFont(forTextStyle:) + adjustsFontForContentSizeCategory.",
            "Hücreyi register et, cellForRowAt içinde dequeueReusableCell(withIdentifier:for:) ile al ve her özelliğini baştan ayarla; prepareForReuse yalnızca geçici durumu sıfırlar.",
            "Yükseklik çalışırken değişirse (aç/kapa): görünen hücreyi güncelle, sonra tableView.performBatchUpdates(nil) (eski yöntem beginUpdates/endUpdates; SDK başlığı yerine bunu öneriyor). Hücre yeniden yüklenmeden yükseklik animasyonla yeniden hesaplanır.",
        ],
        followUps: [
            FollowUp(
                question: "Tek tabloda farklı tipte hücreleri nasıl gösterirsin?",
                answer: "Satırları ilişkili değerli bir enum ile modelle (case author(...), case book(Book)). Her hücre sınıfını kendi reuse identifier'ıyla register et; cellForRowAt içinde enum'a göre switch edip doğru tipi dequeue et."
            ),
            FollowUp(
                question: "reloadRows(at:with:) ile performBatchUpdates(nil) farkı nedir?",
                answer: "reloadRows satırı yeniden yapılandırır (cellForRowAt tekrar çağrılır, çapraz geçiş animasyonu olur, hücrenin geçici durumu kaybolur). Boş batch update ise veriye dokunmaz; tablo yalnızca yükseklikleri yeniden sorar. İçerik değiştiyse reloadRows ya da diffable'da reconfigureItems doğru seçimdir."
            ),
            FollowUp(
                question: "estimatedRowHeight neden var?",
                answer: "Tablo, ekrandaki satırlar dışındakileri ölçmeden içerik boyutunu ve kaydırma çubuğunu tahminle hesaplar; gerçek yükseklik hücre ekrana gelirken ölçülür. Tahmin gerçek ortalamaya ne kadar yakınsa kaydırma çubuğu o kadar az zıplar. 0 vermek tahmini kapatır; Apple'ın self-sizing tarifi ise automaticDimension'ın yanında sıfırdan farklı bir tahmin ister."
            ),
            FollowUp(
                question: "Konsolda UIView-Encapsulated-Layout-Height çakışması görürsen?",
                answer: "Tablonun hücreye ölçmeden önce verdiği geçici yükseklik, senin zorunlu (1000) dikey zincirinle çakışıyor. Zincirdeki bir constraint'in önceliğini 999 yapmak (genellikle alttaki) çakışmayı giderir; hücre yine içeriğine göre boyutlanır."
            ),
            FollowUp(
                question: "Modern alternatif ne?",
                answer: "Diffable data source + UIListContentConfiguration (bu projede Favoriler ekranı). Self-sizing aynı kurallarla çalışır; içerik değişince snapshot'ta reconfigureItems. UICollectionView list configuration'da hücreler zaten self-sizing'dir."
            ),
        ],
        pitfalls: [
            "Dikey constraint zincirini eksik bırakmak (ör. alt kenara bağlanmamak): hücre tahmini yükseklikte kalır ya da içerik üst üste biner.",
            "Alt view'ları contentView yerine doğrudan hücreye eklemek: self-sizing, düzenleme modu ve kaydırma eylemlerinde yerleşim bozulur.",
            "heightForRowAt'te sabit bir değer döndürmek: o satırlar için automaticDimension devre dışı kalır.",
            "Açık/kapalı gibi durumu hücrede saklamak: hücre yeniden kullanılınca durum başka satıra geçer. Durum VC'de (ör. Set<Book.ID>) tutulmalı.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/DynamicCells/DynamicCellsViewController.swift",
                symbol: "tableView(_:cellForRowAt:)",
                note: "Enum satır modeli, iki reuse identifier ve dequeueReusableCell(withIdentifier:for:)."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/DynamicCells/DynamicCellsViewController.swift",
                symbol: "toggleBook(at:)",
                note: "Durum VC'de (expandedBookIDs); hücre yerinde güncelleniyor ve performBatchUpdates(nil) yüksekliği animasyonla yeniden hesaplatıyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/DynamicCells/DynamicCellsViewController.swift",
                symbol: "configureTableView()",
                note: "register, rowHeight = automaticDimension, estimatedRowHeight."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/DynamicCells/BookSummaryCell.swift",
                symbol: "configureLayout()",
                note: "contentView'a üstten alta bağlı zincir; alt constraint'in önceliği 999."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/DynamicCells/BookSummaryCell.swift",
                symbol: "prepareForReuse()",
                note: "Yalnızca geçici durumu sıfırlıyor; içerik her seferinde configure(with:isExpanded:) ile veriliyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Favorites/FavoritesViewController.swift",
                symbol: "makeDataSource(for:)",
                note: "Aynı tablo işinin modern hali: diffable data source + UIListContentConfiguration."
            ),
        ],
        demo: { dependencies in
            AnyView(UIKitLabBooksLoader(bookService: dependencies.bookService) { books in
                UIKitLabHost { DynamicCellsViewController(books: books) }
            })
        }
    )
}
