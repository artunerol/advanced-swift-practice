import SwiftUI

// Sahibi: swift-basics. Ders notu: docs/03-protocoller.md ("typealias" bölümü)
extension InterviewTopic {
    static let typealiasTopic = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.typealiasTopic,
        section: .swift,
        question: "typealias nedir, nerede işe yarar?",
        shortAnswer: [
            "typealias var olan bir tipe ikinci bir isim verir; yeni bir tip OLUŞTURMAZ. Derleyici için BookID ile Int birebir aynı tiptir, çalışma anında alias hiç yoktur.",
            "Uzun closure tiplerine isim veririm: typealias BookFilter = @Sendable (Book) -> Bool. Hem kısalır hem ne işe yaradığını anlatır.",
            "Protocol birleşimlerine isim veririm; Apple'ın kendi Codable tanımı da budur: typealias Codable = Decodable & Encodable.",
            "Uzun generic tipleri kısaltırım (Snapshot = NSDiffableDataSourceSnapshot<Section, Book>) ve generic alias yazabilirim (BookMap<Value> = [Book.ID: Value]). Uyan tipte typealias Item = Novel yazarak associatedtype'ı açıkça karşılayabilirim.",
            "Tuzak: typealias UserID = Int ile BookID = Int birbirine karışır, derleyici uyarmaz. Tip güvenliği istiyorsam tek alanlı bir sarmalayıcı struct yazarım.",
        ],
        followUps: [
            FollowUp(
                question: "typealias ile associatedtype farkı nedir?",
                answer: "associatedtype protocol içindeki bir yer tutucudur; gerçek tipi uyan tip belirler. typealias ise her zaman belli bir tipe takma addır. Uyan tipin içinde yazılan typealias Item = Novel, associatedtype'ı karşılamanın açık yoludur; çoğu zaman derleyici bunu metot imzalarından kendisi çıkarır."
            ),
            FollowUp(
                question: "typealias BookID = Int için extension BookID { ... } yazarsam ne olur?",
                answer: "Aslında Int'i genişletmiş olursun: Projedeki TÜM Int'ler o üyeyi alır. extension BookID { var isEvenID: Bool { self % 2 == 0 } } yazdıktan sonra 7.isEvenID de derlenir. Alias ayrı bir tip olmadığı için extension da ayrı bir tipe yazılmaz."
            ),
            FollowUp(
                question: "Swift'te başka dillerdeki \"newtype\" gibi bir şey var mı?",
                answer: "Yok; tek alanlı bir struct yazılır (çoğu zaman RawRepresentable, Hashable, Codable ile). Ayrı bir tiptir: Int beklenen yere verilemez, karıştırmak \"cannot convert value of type 'Int' to expected argument type ...\" hatasıdır. Bellekte içindeki Int kadar (8 bayt) yer kaplar."
            ),
            FollowUp(
                question: "typealias'ın erişim seviyesi nasıl çalışır?",
                answer: "Alias, gösterdiği tipten daha açık olamaz: internal bir tipe public typealias yazmak \"type alias cannot be declared public because its underlying type uses an internal type\" hatasıdır. Tersi serbest: private typealias ID = AccessibilityID.Fundamentals.StructVsClass gibi dosya içi kısaltmalar yaygın."
            ),
        ],
        pitfalls: [
            "typealias'ı tip güvenliği sanmak: UserID ve BookID karışır, derleme hatası almazsın.",
            "Her şeye alias vermek: Okuyan, gerçek tipi görmek için tanıma atlamak zorunda kalır. Yalnızca uzun ya da anlamlı bir isim kazandıran tiplere ver.",
            "Bir alias'a extension yazıp aslında alttaki tipi (ör. tüm Int'leri) genişlettiğini fark etmemek.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/Fundamentals/Typealias/TypealiasExamples.swift",
                symbol: "TypealiasExamples",
                note: "Altı kullanım bir arada; hepsi enum'un içinde (iç içe typealias), modülü kısa isimlerle kirletmemek için."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/Typealias/TypealiasExamples.swift",
                symbol: "TypealiasExamples.LibraryCardNumber",
                note: "BookID/MemberID alias'larının aksine ayrı bir tip: Int ile karıştırmak derleme hatası."
            ),
            CodePointer(
                file: "BookShelf/Features/Favorites/FavoritesViewController.swift",
                symbol: "FavoritesViewController.Snapshot",
                note: "Gerçek kullanım: render(_:) ve makeDataSource(for:) uzun diffable data source tiplerini kısaltılmış adla kullanıyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/StructVsClass/StructVsClassView.swift",
                symbol: "StructVsClassView",
                note: "private typealias ID = AccessibilityID.Fundamentals.StructVsClass: Uzun iç içe adı yalnızca bu dosyada kısaltıyor."
            ),
        ],
        demo: { _ in AnyView(TypealiasDemoView()) }
    )
}
