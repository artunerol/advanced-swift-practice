import UIKit

/// Collection view yerleşimleri. `UICollectionView`'ın kendisi yerleşim bilmez; neyin nerede duracağına bu
/// layout nesneleri karar verir. Tablo ile en büyük fark budur: UITableView'ın yerleşimi sabittir (tek sütun, dikey).
///
/// Compositional layout'un yapı taşları (içten dışa):
/// `NSCollectionLayoutItem` (bir hücre) → `NSCollectionLayoutGroup` (item'ları yan yana/alt alta dizer)
/// → `NSCollectionLayoutSection` (grup tekrar eder; kendi kaydırma davranışı olabilir) → `UICollectionViewCompositionalLayout`.
/// Boyutlar üç türlü verilir: `.fractionalWidth/Height` (kaba oranla), `.absolute` (sabit nokta), `.estimated` (tahmin;
/// gerçek boyutu hücre Auto Layout ile hesaplar → self-sizing).
@MainActor
enum TableVsCollectionLayouts {
    /// Tablo gibi görünen collection view (iOS 14+). Ayırıcılar, inset grouped görünüm, kaydırma eylemleri
    /// (`trailingSwipeActionsConfigurationProvider`) list configuration ile hazır gelir.
    static func list() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    /// İki farklı bölümlü ızgara: üstte yatay kayan "öne çıkanlar", altta sütunlu "tüm kitaplar".
    /// Bölüm sağlayıcı (section provider) her bölüm için ayrı bir yerleşim döndürebilir; ekran genişliğine
    /// (`environment.container`) göre sütun sayısı da burada seçilir.
    static func grid() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, environment in
            switch TableVsCollectionViewController.GridSection(rawValue: sectionIndex) {
            case .featured:
                return featuredSection()
            case .all, nil:
                let columnCount = environment.container.effectiveContentSize.width > 600 ? 4 : 2
                return gridSection(columnCount: columnCount)
            }
        }
    }

    /// Dikey kayan bir sayfanın içinde YATAY kayan bölüm: `orthogonalScrollingBehavior`.
    /// UITableView ile bunu yapmak için hücrenin içine ayrı bir collection view gömmek gerekirdi.
    static func featuredSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        ))
        // Grubun genişliği ekranın %75'i: sonraki kart kenardan görünür, kullanıcı yana kaydırılabildiğini anlar.
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.75), heightDimension: .absolute(120)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPaging
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 20, trailing: 16)
        section.boundarySupplementaryItems = [header()]
        return section
    }

    /// `columnCount` sütunlu ızgara. Yükseklik `.estimated`: kart, içindeki metne göre uzar (self-sizing).
    static func gridSection(columnCount: Int) -> NSCollectionLayoutSection {
        // Genişliği biz bölüyoruz: `repeatingSubitem:count:` (iOS 16+) item'ı `count` kez tekrarlar ama genişliğini
        // ZORLAMAZ; "count tekrarın gruba sığması çağıranın sorumluluğu" (SDK başlık dosyası). `.fractionalWidth(1)`
        // verseydik her kart satırın tamamını kaplar, ikinci sütun ekrandan taşardı.
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1 / CGFloat(columnCount)),
            heightDimension: .estimated(110)
        ))
        // Kartlar arası boşluk item'ın içinden: Kesirli genişlikler toplamı zaten 1; `interItemSpacing` eklemek taşırırdı.
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(110)),
            repeatingSubitem: item,
            count: columnCount
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 20, trailing: 10)
        // Başlık da bölümün kenar boşluğunu izler; kartların iç boşluğu kadar içeri alıp hizalıyoruz.
        let sectionHeader = header()
        sectionHeader.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
        section.boundarySupplementaryItems = [sectionHeader]
        return section
    }

    private static func header() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(32)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }
}
