import SwiftUI

extension InterviewTopic {
    static let tableVsCollection = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.tableVsCollection,
        section: .uikit,
        question: "UITableView mı UICollectionView mı? Hangisi ne zaman?",
        shortAnswer: [
            "UITableView: tek sütunlu, dikey listeler için. Yerleşimi sabittir; kaydırma eylemleri, düzenleme (silme/taşıma), bölüm başlık/altlıkları hazır gelir. Ayar ekranları, mesaj listeleri.",
            "UICollectionView: yerleşimi bir layout nesnesi belirler; ızgara, yatay kayan bölümler, kartlar, her bölümü farklı ekranlar. Compositional layout ile tek bir bölüm orthogonalScrollingBehavior ile yana kayabilir.",
            "iOS 14'ten beri UICollectionLayoutListConfiguration ile collection view tablo gibi davranabiliyor (list hücreleri, ayırıcılar, kaydırma eylemleri). Apple bunu WWDC20'de liste kurmanın modern yolu olarak tanıttı; UITableView ise deprecated değil.",
            "Modern veri tarafı ikisinde aynı: diffable data source + snapshot. Collection view'da CellRegistration ile string reuse identifier ve tip dönüşümü (cast) gerekmez.",
            "Karar: Sadece dikey bir liste ve mevcut tablo kodu varsa table; ızgara, yatay bölüm, karışık bölümler ya da değişmesi muhtemel bir tasarım varsa collection view.",
        ],
        followUps: [
            FollowUp(
                question: "Compositional layout'un parçaları nelerdir?",
                answer: "İçten dışa: item (bir hücre) → group (item'ları yatay/dikey dizer) → section (grup tekrarlanır, kendi kaydırma davranışı ve başlığı olabilir) → layout. Boyutlar .fractionalWidth/Height, .absolute ya da .estimated (self-sizing) ile verilir. Section provider kapanışı her bölüm için farklı yerleşim döndürebilir."
            ),
            FollowUp(
                question: "Aynı kitabı iki bölümde göstermek diffable data source'ta neden sorun?",
                answer: "Item kimlikleri TÜM snapshot'ta benzersiz olmalı; aynı kimlik ikinci kez eklenirse çalışma anında hata alırsın. Çözüm: bölümü de içeren bir kimlik tipi, ör. GridItem(section: .featured, bookID: 3)."
            ),
            FollowUp(
                question: "CellRegistration'ın avantajı ne, nerede oluşturulmalı?",
                answer: "Hücre ve öğe tipi generic parametredir: string reuse identifier ve as! dönüşümü yok, yapılandırma tek yerde. Kayıt, cell provider kapanışının DIŞINDA bir kez oluşturulmalı; içinde oluşturmak hücre yeniden kullanımını engeller ve iOS 15+ istisna fırlatır."
            ),
            FollowUp(
                question: "UICollectionViewFlowLayout ne zaman yeterli?",
                answer: "Tek tip hücrelerden oluşan basit bir ızgara ya da yatay şerit için hâlâ iş görür. Farklı yerleşimli bölümler, iç içe gruplar, yatay kayan bölüm gibi ihtiyaçlarda compositional layout daha esnek ve bildirimseldir."
            ),
            FollowUp(
                question: "SwiftUI'daki karşılıkları neler?",
                answer: "List ≈ table / list configuration; LazyVGrid / LazyHGrid ≈ ızgara; ScrollView(.horizontal) + LazyHStack ≈ yatay bölüm. SwiftUI'da bunlar tek bir ScrollView içinde iç içe kullanılabilir."
            ),
        ],
        pitfalls: [
            "CellRegistration'ı cell provider kapanışının içinde oluşturmak: her çağrıda yeni kayıt, yeniden kullanım yok, iOS 15+ istisna.",
            "Snapshot'ta aynı item kimliğini iki kez kullanmak (ör. aynı Book'u iki bölüme eklemek).",
            "Izgara ya da yatay şerit için tablo hücresine collection view gömmek; ya da tersine, basit bir ayar listesi için gereksiz özel layout yazmak.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/TableVsCollection/TableVsCollectionViewController.swift",
                symbol: "makeTableDataSource(_:books:)",
                note: "UITableView + diffable: string reuse identifier ile register/dequeue."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/TableVsCollection/TableVsCollectionViewController.swift",
                symbol: "makeListDataSource(_:books:)",
                note: "CellRegistration<UICollectionViewListCell, Book.ID>: kapanışın dışında bir kez oluşturuluyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/TableVsCollection/TableVsCollectionLayouts.swift",
                symbol: "list()",
                note: "UICollectionLayoutListConfiguration: collection view'ı tabloya dönüştüren tek satır."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/TableVsCollection/TableVsCollectionLayouts.swift",
                symbol: "featuredSection()",
                note: "orthogonalScrollingBehavior: dikey sayfanın içinde yatay kayan bölüm (tabloda yapılamaz)."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/TableVsCollection/TableVsCollectionViewController.swift",
                symbol: "GridItem",
                note: "Aynı kitap iki bölümde: kimliğe bölümü katarak snapshot'ta benzersiz kalıyor."
            ),
        ],
        demo: { dependencies in
            AnyView(UIKitLabBooksLoader(bookService: dependencies.bookService) { books in
                UIKitLabHost { TableVsCollectionViewController(books: books) }
            })
        }
    )
}
