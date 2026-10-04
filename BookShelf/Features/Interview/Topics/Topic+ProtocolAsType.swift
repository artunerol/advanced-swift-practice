import SwiftUI

// Sahibi: swift-basics. Ders notu: docs/03-protocoller.md ("Protocol tip olarak: olur mu, olmaz mı?")
// Demo: QuizSnippets/ altındaki örnekler; doğrulama: scripts/check-swift-quiz.sh
extension InterviewTopic {
    static let protocolAsType = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.protocolAsType,
        section: .swift,
        question: "Protocol'ü tip olarak kullanmak: hangisi derlenir, hangisi derlenmez? (any, some, generic)",
        shortAnswer: [
            "Bir protocol'ü üç şekilde \"tip\" gibi kullanırım: generic kısıt (<T: P> ya da parametrede some P), opaque dönüş tipi (-> some P) ve existential (any P).",
            "some P / generic: Derleme anında belli, TEK bir somut tip. Kutu yok; derleyici kodu o tipe özelleştirip (specialization) çağrıları statik yapabilir, associatedtype ilişkileri korunur. Parametrede some P'yi her çağrı farklı tiple yapabilir; dönüşte ise fonksiyon her yoldan AYNI tipi döndürmek zorunda.",
            "any P: İçinde herhangi bir uyan tip olabilen kutu. Heterojen dizi ([any P]) ya da çalışma anında değişen tip için gerekir. Bedeli: kutu (64-bit'te 3 kelimelik tampon + tip bilgisi + witness table; sığmayan değer heap'e), dinamik çağrı ve associatedtype'ın silinmesi.",
            "Kutunun kendisi protocol'e uymaz (bilinen istisna: any Error, Error'a uyar): [any P]'yi [T] where T: P bekleyen fonksiyona veremem, Set<any Hashable> kuramam (AnyHashable kullanılır), iki any Equatable'ı == ile karşılaştıramam. Tek bir any değer ise generic fonksiyona verilebilir; Swift 5.7'den beri kutu otomatik açılır.",
            "Swift 5.7'den beri associatedtype'lı protocol'ler de any Shelf olarak kullanılabilir, ama Item ALAN metotlar çağrılamaz; any Shelf<Novel> (primary associated type) ile çağrılabilir. Varsayılan tercihim some, gerekince any.",
        ],
        followUps: [
            FollowUp(
                question: "Neden iki any Equatable'ı == ile karşılaştıramıyorum?",
                answer: "== iki tarafın AYNI somut tip (Self) olmasını ister; iki kutuda farklı tipler (Int ve String) olabilir. Derleyici: \"binary operator '==' cannot be applied to two 'any Equatable' operands\". Çözüm: func isSame<T: Equatable>(_ a: T, _ b: T) gibi aynı tipi zorunlu kılan generic bir fonksiyon."
            ),
            FollowUp(
                question: "any yazmazsam ne olur? let x: ReadingItem derlenir mi?",
                answer: "Bu projenin derleyicisinde (Swift 6.2, Swift 6 modu): Self/associatedtype gereksinimi olmayan protocol için uyarısız derlenir. Equatable ya da Shelf gibi olanlarda derlenir ama \"must be written 'any Equatable'\" uyarısı verir. ExistentialAny ayarı açılırsa her protocol için aynı uyarı gelir. Uyarı metni, gelecekteki bir dil modunda bunun hata olacağını söylüyor."
            ),
            FollowUp(
                question: "MemoryLayout<any ReadingItem>.size kaç?",
                answer: "64-bit'te 40 bayt: 3 kelimelik değer tamponu (24) + tip bilgisi (8) + witness table (8). Her ek protocol bir witness table daha ekler (any P & Q: 48). Sendable gibi marker protocol'ler tablo eklemez. AnyObject'e bağlı bir protocol'ün existential'ı 16 bayttır: referans + witness table."
            ),
            FollowUp(
                question: "func f(_ x: some P) ile func f<T: P>(_ x: T) arasında fark var mı?",
                answer: "Anlam olarak aynı (SE-0341): Tipi çağıran seçer. Fark yazımda: some'ın gizli generic parametresine isim veremezsin, bu yüzden \"iki parametre aynı tip\" ya da \"aynı tipi döndür\" diyemezsin; bunun için <T> gerekir."
            ),
            FollowUp(
                question: "Neden [any ReadingItem]'ı generic fonksiyona veremiyorum ama tek bir any ReadingItem'ı verebiliyorum?",
                answer: "Tek değerde derleyici kutuyu açıp içindeki gerçek tipi T yapabilir (implicit opening, SE-0352). Dizide her kutu farklı tip taşıyabildiği için tek bir T bulunamaz ve kutunun kendisi protocol'e uymaz: \"type 'any ReadingItem' cannot conform to 'ReadingItem'\". Çözüm: items.map { describe($0) } ya da existential dizi alan ayrı bir fonksiyon."
            ),
        ],
        pitfalls: [
            "Her yerde any kullanmak: Gereksiz kutu ve dinamik çağrı, associatedtype ilişkileri kaybolur. Önce some/generic dene.",
            "\"associatedtype'lı protocol tip olarak hiç kullanılamaz\" demek: Swift 5.6 ve öncesi için doğruydu. Bugün any Shelf yazılabilir; kısıt, Item alan üyeleri çağırmakta.",
            "-> some P ile farklı yollardan farklı tipler döndürmeye çalışmak: \"do not have matching underlying types\".",
            "Quiz'deki cevapları ezberlemek: Derleyici sürümü değişebilir. Bu yüzden her cevap scripts/check-swift-quiz.sh ile gerçekten derlenerek doğrulanıyor.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/SwiftBasics/QuizSnippets/quiz-prelude.swift.txt",
                symbol: "Shelf",
                note: "Tüm quiz örneklerinin ortak tanımları; protocol Shelf<Item> satırındaki <Item> primary associated type."
            ),
            CodePointer(
                file: "scripts/check-swift-quiz.sh",
                symbol: "typecheck",
                note: "Her örneği prelude ile birleştirip gerçekten derliyor; beklenen sonuç ve mesaj tutmazsa CI kırmızı."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/Protocols/ReadingItem.swift",
                symbol: "totalReadingMinutes(ofMixed:)",
                note: "Generic sürüm [any ReadingItem] kabul etmediği için existential diziye ayrı bir fonksiyon gerekiyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/Protocols/ReadingItem.swift",
                symbol: "readingSummary(for:)",
                note: "Parametrede some; testte any ReadingItem ile çağrılıyor (implicit existential opening)."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/Protocols/ReadingItemTypes.swift",
                symbol: "ReadingSamples.featuredItem()",
                note: "Opaque dönüş tipi: Her zaman aynı somut tip (Novel), ama çağıran yalnızca some ReadingItem görür."
            ),
            CodePointer(
                file: "BookShelf/App/AppDependencies.swift",
                symbol: "AppDependencies",
                note: "any BookServiceProtocol: Çalışma anında farklı tip (gerçek servis ya da test dublörü) tutulacağı için existential."
            ),
        ],
        demo: { _ in AnyView(SwiftQuizView()) }
    )
}
