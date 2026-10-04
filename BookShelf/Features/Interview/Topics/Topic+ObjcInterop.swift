import SwiftUI

extension InterviewTopic {
    /// Bonus: Objective-C ve Swift birlikte çalışma (interop). Demo, doğrulamayı Objective-C sınıfına yaptıran
    /// ISBN doğrulayıcı. Ayrıntılı ders: docs/08-objective-c.md.
    static let objcInterop = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.objcInterop,
        section: .bonus,
        question: "Objective-C ile Swift aynı projede nasıl birlikte çalışır?",
        shortAnswer: [
            "ObjC → Swift: Uygulama hedefinde ObjC header'ları köprü başlığına (bridging header) `#import` edilir. Swift bu API'leri `import` yazmadan, Swift'e çevrilmiş haliyle görür.",
            "Swift → ObjC: Xcode `<Modül>-Swift.h` header'ını üretir, .m dosyası onu import eder. ObjC yalnızca `@objc` ile açılan ve ObjC'de karşılığı olan şeyleri görür: NSObject'ten türeyen sınıflar, `@objc` protocol'ler, tamsayı ham değerli `@objc` enum'lar. Struct, generic ve ilişkili değerli enum görünmez.",
            "Header'daki işaretler Swift API'sini şekillendirir: `nullable`/`nonnull` Optional olup olmayacağını, `NS_SWIFT_NAME` Swift'teki adı, `NSArray<NSString *>` gibi generic'ler `[String]` olmasını belirler.",
            "Hatalar köprülenir: Son parametresi `NSError **` olan ve BOOL ya da nesne döndüren metot Swift'te `throws` olur. `NS_ERROR_ENUM` ile hata kodları Swift'te tipli olarak yakalanır.",
            "Concurrency de köprülenir: Son parametresi completion handler olan ve `void` dönen ObjC metotları Swift'e otomatik bir `async` karşılığıyla da gelir; `NS_SWIFT_SENDABLE` gibi işaretler Sendable bilgisini taşır.",
        ],
        followUps: [
            FollowUp(
                question: "Header'da nullability belirtilmezse ne olur?",
                answer: "Swift pointer'ı örtük açılan opsiyonel (`String!`) olarak alır. Değer nil gelir ve sen onu Optional olmayan bir tip gibi kullanırsan uygulama çöker. Çözüm: header'ı `NS_ASSUME_NONNULL_BEGIN`/`END` arasına almak ve nil olabilecekleri `nullable` diye işaretlemek."
            ),
            FollowUp(
                question: "Bir Swift struct'ını Objective-C'den kullanabilir misin?",
                answer: "Doğrudan hayır; ObjC struct'ları, generic'leri ve ilişkili değerli enum'ları göremez. NSObject'ten türeyen bir `@objc` sarmalayıcı (wrapper) sınıf yazarsın ya da API'yi ObjC'de karşılığı olan tiplerle sunarsın: `String` → `NSString`, `[String]` → `NSArray`, `Int` ham değerli `@objc enum`."
            ),
            FollowUp(
                question: "`@objc` ile `@objc dynamic` farkı ne?",
                answer: "`@objc` üyeyi ObjC çalışma zamanına açar (bir seçici üretir); ama Swift'ten yapılan çağrılar yine de doğrudan ya da vtable ile dağıtılabilir. `dynamic` eklenince her çağrı ObjC mesaj gönderimiyle (`objc_msgSend`) yapılır. KVO ve method swizzling, çalışma anında değiştirilen uygulamayı görebilmek için `@objc dynamic` ister."
            ),
            FollowUp(
                question: "Köprü başlığı ile `-Swift.h` neden birbirini import etmez?",
                answer: "Köprü başlığı Swift derlenmeden ÖNCE okunur, `-Swift.h` ise Swift derlendikten SONRA üretilir. Bir .h dosyasından `-Swift.h`'yi import etmek döngü yaratır. Kural: `-Swift.h` yalnızca .m dosyalarında import edilir; .h'de gerekirse `@class` ile ileri bildirim (forward declaration) yapılır."
            ),
            FollowUp(
                question: "ObjC'den gelen bir enum'u `switch`'lerken neden `@unknown default` gerekir?",
                answer: "`NS_ENUM` ile tanımlı C enum'ları 'donmamış' (non-frozen) sayılır: ObjC tarafı ileride yeni bir değer ekleyebilir. Swift 6 dil modunda `@unknown default` olmadan böyle bir `switch` derlenmez (Swift 5'te uyarıdır). `default` yerine `@unknown default` yazmanın faydası: Bilinen bir vakayı unutursan derleyici yine uyarır."
            ),
        ],
        pitfalls: [
            "Header'a nullability yazmamak: Swift `String!` görür; nil geldiğinde çökme riski doğar.",
            "`-Swift.h`'yi bir .h dosyasından import etmek: Derleme döngüsü. .h'de `@class` ileri bildirimi kullan.",
            "`@objc` yazınca her şeyin ObjC'ye açılacağını sanmak: Struct, generic, ilişkili değerli enum ve `Int?` gibi opsiyonel değer tipleri ObjC'de temsil edilemez; derleyici hata verir.",
            "ObjC exception'larını (`NSException`, ör. dizi sınırını aşmak) Swift'te `do/catch` ile yakalayabileceğini sanmak: Swift `catch` yalnızca `Error`'ları (NSError dahil) yakalar; NSException uygulamayı çökertir.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/ObjC/BookShelf-Bridging-Header.h",
                symbol: "#import \"BKISBNValidator.h\"",
                note: "ObjC → Swift yönü: Buraya import edilen header'lar uygulama hedefindeki tüm Swift dosyalarında görünür."
            ),
            CodePointer(
                file: "BookShelf/ObjC/BKISBNValidator.h",
                symbol: "+validateISBN13:error:",
                note: "`NSError **` + BOOL dönüş Swift'te `throws` olur. Aynı dosyada `NS_SWIFT_NAME(ISBNValidator)`, `NS_ERROR_ENUM` ve `nullable` dönüş (→ `String?`)."
            ),
            CodePointer(
                file: "BookShelf/Features/ISBNChecker/ISBNCheckOutcome.swift",
                symbol: "ISBNCheckOutcome.evaluate(_:)",
                note: "Swift tarafı: `try ISBNValidator.validateISBN13(...)`, `catch let error as BKISBNValidatorError` ve `hint(for:)` içindeki `@unknown default`."
            ),
            CodePointer(
                file: "BookShelf/ObjC/ReadingPace.swift",
                symbol: "ReadingPace",
                note: "Swift → ObjC: `NSObject` + `@objc(BKReadingPace)`. `typicalRange` (ClosedRange) ObjC'de karşılığı olmadığı için açılmaz."
            ),
            CodePointer(
                file: "BookShelf/ObjC/BKReadingTimeEstimator.m",
                symbol: "initWithPagesPerHour:",
                note: "`#import \"BookShelf-Swift.h\"` yalnızca .m'de; Swift sınıfı ObjC'den `[BKReadingPace resolvedPagesPerHour:]` diye çağrılıyor."
            ),
            CodePointer(
                file: "BookShelf/ObjC/BKReadingTimeEstimator.h",
                symbol: "NS_SWIFT_SENDABLE",
                note: "ObjC sınıfının Swift'e verdiği `Sendable` sözü (derleyici ObjC kodunu denetleyemez); `NS_UNAVAILABLE` ile parametresiz `init` kapatılmış."
            ),
        ],
        demo: { _ in AnyView(ISBNCheckerView()) }
    )
}
