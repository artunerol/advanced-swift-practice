import SwiftUI

// Sahibi: swift-basics. Ders notu: docs/02-struct-vs-class.md
extension InterviewTopic {
    static let structVsClass = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.structVsClass,
        section: .swift,
        question: "Struct ile class arasındaki fark nedir? Stack ve heap ile ilişkisi ne?",
        shortAnswer: [
            "Struct değer tipidir: Atama ve parametre geçişinde bağımsız bir kopya oluşur. Class referans tipidir: Kopyalanan şey nesnenin adresidir; iki değişken aynı nesneyi paylaşır.",
            "Class'ta olup struct'ta olmayanlar: kalıtım, kimlik (===), ARC ile referans sayma ve deinit (kopyalanamayan ~Copyable struct'lar hariç). Struct'ta: otomatik memberwise init, kendi alanını değiştiren metotlar için mutating ve let ile tam değişmezlik.",
            "Stack/heap: Struct değeri BULUNDUĞU YERDE satır içi saklanır. Yerel değişkense genelde stack'te ya da register'da; bir class'ın alanıysa o nesneyle birlikte heap'te, bir dizinin elemanıysa dizinin heap'teki deposunda. Class örnekleri heap'te ayrılır ve referans sayılır.",
            "Bu yüzden class daha pahalıdır: heap ayırma, atomik retain/release, dolaylı erişim ve (final değilse) dinamik dispatch. Ama \"struct her zaman stack'te\" demek yanlış; Swift'in garantisi depolama yeri değil, semantiktir.",
            "Seçim: Apple'ın önerisiyle varsayılan struct. Kimlik, paylaşılan değiştirilebilir durum, kalıtım ya da Objective-C/UIKit gerekiyorsa class. Paylaşılan durum thread'ler arasında kullanılacaksa Swift 6'da çoğu zaman actor.",
        ],
        followUps: [
            FollowUp(
                question: "Struct'lar her zaman stack'te mi durur?",
                answer: "Hayır. Struct satır içi saklanır, yani nerede durduğu onu kimin tuttuğuna bağlı: Class'ın alanıysa heap'teki nesnenin içinde, Array elemanıysa dizinin heap deposunda. Kaçan (escaping) bir closure'ın yakaladığı var heap'te bir kutuya taşınır; any P kutusunun 3 kelimelik tamponuna sığmayan değer de heap'e konur. Tersine, optimize edici fonksiyondan kaçmayan bazı class nesnelerini stack'e alabilir."
            ),
            FollowUp(
                question: "Struct her atamada kopyalanıyorsa büyük bir Array'i fonksiyona vermek pahalı değil mi?",
                answer: "Değil: Array, String, Dictionary ve Set copy-on-write kullanır. Kopyalamak yalnızca heap'teki depo referansını kopyalar (MemoryLayout<[Int]>.size == 8); biri değiştirilmek istendiğinde isKnownUniquelyReferenced ile depo paylaşılıyor mu diye bakılır ve gerekirse o anda kopyalanır. Kendi yazdığın struct otomatik olarak CoW değildir."
            ),
            FollowUp(
                question: "Struct'ın içinde bir class tutarsan ne olur?",
                answer: "Struct kopyalanır ama class alanı aynı nesneyi gösterir: Kopyalar o nesneyi paylaşır (sığ kopya) ve değer semantiği bozulur. Ayrıca her kopyada o referans için retain/release yapılır. Çözüm: class'ı değişmez yapmak ya da CoW uygulamak (PageHistory)."
            ),
            FollowUp(
                question: "MemoryLayout ile neyi görebilirsin?",
                answer: "Bir tipin satır içi boyutunu: Tek Int'lik struct 8, class referansı 8 (nesne ne kadar büyük olursa olsun), [Int] 8, any ReadingItem 40 bayt. size ile stride farkı hizalamadan gelir: Int + Bool → size 9, stride 16. Uygulamadaki \"Bellek\" deneyi bunları ve adres karşılaştırmasını gösterir."
            ),
            FollowUp(
                question: "Struct ile class thread güvenliği açısından nasıl farklı?",
                answer: "Kopyalanan bir değeri iki thread paylaşmaz; alanları Sendable olan struct, public değilse kendiliğinden Sendable olur (public tipte Sendable açıkça yazılır). Değiştirilebilir alanı olan bir class ise iki thread'den aynı anda değiştirilebilir; Swift 6 böyle bir nesneyi task'lar arasında paylaşmana derleme anında izin vermez. Paylaşılan değiştirilebilir durum için actor kullanılır."
            ),
        ],
        pitfalls: [
            "Yalnızca \"struct stack'te, class heap'te\" deyip semantik farkı (kopya vs paylaşım) hiç söylememek; üstelik bu cümle yarı yanlış.",
            "let ile tutulan bir class örneğini değişmez sanmak: let yalnızca referansı sabitler, nesnenin var alanları değişebilir.",
            "Class alanı olan bir struct'ın tam değer semantiğine sahip olduğunu sanmak.",
            "Kalıtım gerekmediği halde class seçmek ve final yazmamak: Gereksiz dinamik dispatch ve ARC maliyeti.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/Fundamentals/StructVsClass/Bookmark.swift",
                symbol: "CopySemanticsDemo",
                note: "Aynı satır (var copy = original) struct'ta değeri, class'ta adresi kopyalıyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/StructVsClass/MemoryLayoutDemo.swift",
                symbol: "MemoryAddressDemo",
                note: "İki struct kopyası farklı adreste, aynı nesneyi gösteren iki referans aynı adreste. Dosyanın başındaki stack/heap notunu oku."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/StructVsClass/MemoryLayoutDemo.swift",
                symbol: "MemoryLayoutDemo",
                note: "Class referansı 8 bayt, [Int] 8 bayt, any ReadingItem 40 bayt; size ile stride farkı."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/StructVsClass/PageHistory.swift",
                symbol: "PageHistory.record(_:)",
                note: "Elle copy-on-write: isKnownUniquelyReferenced ile depo yalnızca paylaşılıyorsa kopyalanıyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/StructVsClass/RetainCycleDemo.swift",
                symbol: "RetainCycleDemo.run(_:)",
                note: "ARC: Döngü varken deinit hiç çalışmıyor; weak/unowned ile ikisi de serbest bırakılıyor."
            ),
            CodePointer(
                file: "BookShelf/Core/Stores/FavoritesStore.swift",
                symbol: "FavoritesStore",
                note: "Paylaşılan değiştirilebilir durum için class + kilit yerine actor."
            ),
        ],
        demo: { _ in AnyView(StructVsClassView()) }
    )
}
