import Foundation

/// Bir raf: **aynı türden** okunabilir şeyleri tutar.
///
/// `associatedtype Item`: Protocol'ün içindeki bir "yer tutucu tip". Hangi tip olduğuna protocol'e uyan tip
/// karar verir (`ReadingShelf<Novel>` için `Item == Novel`). Generic bir tipin protocol dünyasındaki karşılığıdır.
///
/// `protocol Shelf<Item>`: Köşeli parantezdeki `Item` bir **primary associated type**'tır (Swift 5.7+).
/// Sayesinde "Novel tutan herhangi bir raf" diyebiliriz:
/// - `some Shelf<Novel>`: Tek bir somut raf tipi, ama hangisi olduğu gizli (opaque).
/// - `any Shelf<Novel>`: Novel tutan herhangi bir raf kutusu (existential). `items` okunduğunda tip `[Novel]` olur.
///
/// Önemli kısıt: `any Shelf` (Item belirtilmeden) üzerinde `add(_:)` çağrılamaz, çünkü derleyici kutunun
/// içindeki rafın hangi tipi kabul ettiğini bilemez. `any Shelf<Novel>` ile ise bilir ve çağrılabilir.
protocol Shelf<Item> {
    associatedtype Item: ReadingItem

    var items: [Item] { get }

    /// Rafa ekler. Eklenmediyse (ör. zaten rafta) `false` döner.
    /// `mutating`: Protocol'ü struct'lar da uygulayabilsin diye. (Bir class uygularken `mutating` yazmaz.)
    @discardableResult
    mutating func add(_ item: Item) -> Bool
}

extension Shelf {
    /// Varsayılan davranış: Rafın toplam süresi. `items` homojen (`[Item]`) olduğu için **generic**
    /// `totalReadingMinutes(of:)` sürümü çağrılır; existential kutuya gerek yok.
    var totalMinutes: Int {
        totalReadingMinutes(of: items)
    }

    var isEmpty: Bool {
        items.isEmpty
    }
}

/// **Koşullu (constrained) extension**: Bu üye yalnızca `Item` `Comparable` ise vardır.
/// `ReadingShelf<Novel>`'da `sortedItems` kullanılabilir; `Comparable` olmayan `ReadingShelf<Book>`'ta derlenmez bile.
extension Shelf where Item: Comparable {
    var sortedItems: [Item] {
        items.sorted()
    }
}

/// `Shelf`'in generic bir struct ile uygulanması.
///
/// `Item: ReadingItem & Identifiable` bir **protocol birleşimi** (composition): `Item` hem okunabilir olmalı
/// hem de kimliği (`id`) olmalı. Kimliği aynı öğeyi ikinci kez eklememek için kullanıyoruz.
/// `&` ile istediğin kadar protocol birleştirebilirsin; yeni bir "birleşik protocol" tanımlamana gerek kalmaz.
///
/// Struct olduğu için değer semantiğine sahip: Bir rafı kopyalayıp kopyaya eklemek orijinal rafı değiştirmez.
struct ReadingShelf<Item: ReadingItem & Identifiable>: Shelf {
    /// `private(set)`: Dışarıdan okunabilir ama yalnızca `add(_:)` üzerinden değiştirilebilir.
    /// Böylece "aynı öğe iki kez" gibi geçersiz bir durum dışarıdan oluşturulamaz.
    private(set) var items: [Item]

    init(items: [Item] = []) {
        self.items = []
        for item in items {
            add(item)
        }
    }

    @discardableResult
    mutating func add(_ item: Item) -> Bool {
        guard !items.contains(where: { $0.id == item.id }) else { return false }
        items.append(item)
        return true
    }
}
