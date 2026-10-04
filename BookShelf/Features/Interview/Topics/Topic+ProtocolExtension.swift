import SwiftUI

// Sahibi: swift-basics. Ders notu: docs/03-protocoller.md
extension InterviewTopic {
    static let protocolExtension = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.protocolExtension,
        section: .swift,
        question: "Protocol ve extension birlikte nasıl kullanılır? Varsayılan uygulama nedir?",
        shortAnswer: [
            "Protocol bir sözleşmedir: Gereksinimleri (özellik, metot, init, static üye, associatedtype) tanımlar; struct, enum, class ve actor uyabilir.",
            "Protocol extension'ı, uyan TÜM tiplere ortak davranış ekler. Bir gereksinime extension'da gövde yazarsam bu onun varsayılan uygulaması olur; tip isterse kendi uygulamasını yazar.",
            "Kritik ayrım: Gereksinim dinamik dispatch ile (witness table üzerinden) çağrılır; tipin kendi uygulaması any ya da generic üzerinden de çalışır. Yalnızca extension'da olan üye statik dispatch'tir: Tipteki aynı isimli üye onu ezmez, gölgeler.",
            "Koşullu extension ile (extension Sequence where Element: PagedReadingItem) davranışı yalnızca şartı sağlayan tiplere eklerim. Var olan bir tipe, kaynağına dokunmadan uygunluk da ekleyebilirim (retroactive conformance).",
            "Extension computed property, metot, init, subscript, iç içe tip ve protocol uygunluğu ekleyebilir. Saklanan özellik (stored property) ekleyemez; bir class'a extension'la eklenen @objc olmayan metot da alt sınıfta override edilemez.",
        ],
        followUps: [
            FollowUp(
                question: "Swift protocol'lerinde \"optional\" gereksinim var mı?",
                answer: "Saf Swift protocol'lerinde yok; yalnızca @objc protocol'lerde @objc optional var (UIKit delegate'lerindeki optional metotlar bunlardır). Swift'teki karşılığı varsayılan uygulama: Tip yazmazsa extension'daki gövde çalışır."
            ),
            FollowUp(
                question: "Bir class protocol'e uyuyor ve varsayılanı kullanıyor. Alt sınıf aynı metodu yazarsa ne olur?",
                answer: "Uygunluk üst sınıfa aittir ve witness table'a varsayılan yazılmıştır. Alt sınıfın metodu (override değil, yeni bir metot) any P üzerinden çağrılmaz; varsayılan çalışır. Çözüm: Metodu üst sınıfın kendisinde yaz, alt sınıfta override et."
            ),
            FollowUp(
                question: "Extension neden saklanan özellik ekleyemez?",
                answer: "Bir tipin bellek düzeni (alanları, boyutu) tipin tanımında sabitlenir. Başka bir dosyadaki ya da modüldeki extension bu düzeni değiştiremez. Derleyici \"extensions must not contain stored properties\" hatası verir. Gerekirse protocol'e { get } gereksinimi konur, saklamayı uyan tip yapar."
            ),
            FollowUp(
                question: "Retroactive conformance nedir, @retroactive ne zaman gerekir?",
                answer: "Bir tipe, tanımlandığı yerin dışında bir extension ile uygunluk eklemektir (extension Book: PagedReadingItem). Hem tip hem protocol BAŞKA modüllerdense (extension Date: Identifiable) Swift 6 uyarır: O modüllerden biri aynı uygunluğu ileride eklerse çakışır. Bilerek yapıyorsan @retroactive yazarsın."
            ),
            FollowUp(
                question: "Protocol extension ile class kalıtımı arasında nasıl seçim yaparsın?",
                answer: "Kalıtım tek üst sınıf, yalnızca class ve saklanan özellikleriyle birlikte gelir. Protocol + extension ile davranışı küçük parçalar halinde struct'lara da verebilir, bir tipi birden çok protocol'e uydurabilirim. Ortak durum (stored state) ya da UIKit gibi bir class hiyerarşisi gerekiyorsa kalıtım; aksi halde protocol."
            ),
        ],
        pitfalls: [
            "Özelleştirilmesi beklenen bir üyeyi yalnızca extension'a yazmak: Tipin kendi uygulaması any ya da generic üzerinden hiç çağrılmaz (ProtocolDispatchDemo).",
            "Gereksinimin imzasını birebir tutturamamak (summary(short:) ya da yazım hatası summery()): Tipin metodu ayrı bir metot olur, gereksinimi varsayılan karşılar. Swift 6.2 bu örneklerde uyarı bile vermez.",
            "Alt sınıfta yazdığın metodun protocol varsayılanını ezdiğini sanmak (uygunluk üst sınıfa aitse ezmez).",
            "Her şey için protocol yazmak: Tek bir somut tip varken protocol + extension yalnızca dolaylılık ekler.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/Fundamentals/Protocols/ReadingItem.swift",
                symbol: "ReadingItem",
                note: "symbolName gereksinim + extension'da varsayılan; shelfSection ise yalnızca extension'da. İkisinin yorumlarını karşılaştır."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/Protocols/ProtocolExtensionExamples.swift",
                symbol: "ProtocolDispatchDemo.observe(from:)",
                note: "Üç dalda kod birebir aynı, yalnızca değişkenin tipi farklı; shelfSection sonucu yine de değişiyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/Protocols/ReadingItemTypes.swift",
                symbol: "extension Book: PagedReadingItem",
                note: "Retroactive conformance: Book'un kaynağına dokunulmadı; eksik olan tek gereksinim kindName."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/Protocols/ReadingItem.swift",
                symbol: "PagedReadingItem",
                note: "Protocol kalıtımı: Alt protocol'ün extension'ı, üst protocol'ün estimatedMinutes gereksinimini karşılıyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/Protocols/Shelf.swift",
                symbol: "Shelf.sortedItems",
                note: "Koşullu extension (where Item: Comparable): ReadingShelf<Novel>'da var, ReadingShelf<Book>'ta yok."
            ),
        ],
        demo: { _ in AnyView(ProtocolExtensionDemoView()) }
    )
}
