import XCTest
@testable import BookShelf

/// `NS_SWIFT_SENDABLE`'ın etkisini gösteren test.
///
/// Bu dosyanın asıl "testi" **derlenebilmesi**dir. `BKReadingTimeEstimator.h`'deki `NS_SWIFT_SENDABLE` satırını
/// silersen, Swift 6 dil modunda (tam concurrency denetimi) bu dosya DERLENMEZ:
/// - `objcInteropRequireSendable(estimator)`: "type 'ReadingTimeEstimator' does not conform to the 'Sendable' protocol"
/// - `group.addTask { ... estimator ... }`: Aynı Sendable olmayan nesne birden çok eşzamanlı task'a yakalatıldığı
///   için "passing closure as a 'sending' parameter risks causing data races" hatası.
/// - `Task.detached { ... }` sonrasında `estimator`'ı tekrar kullanmak da aynı nedenle hata olur
///   ("sending value of non-Sendable type ... risks causing data races").
/// Not: Derleyici önce tip denetimi hatasını (ilk madde) gösterir. `sending` hataları daha sonraki bir derleme
/// aşamasında (bölge/region analizi) üretildiği için ancak o satırı silince görünür. Üçü de denenip doğrulandı.
///
/// Varsayılan olarak Swift, ObjC sınıflarını `Sendable` saymaz; çünkü ObjC kodunun thread-safe olup olmadığını
/// denetleyemez. `NS_SWIFT_SENDABLE` ile "bu sınıf değişmez, güvenle paylaşılabilir" diye söz veriyoruz ve
/// Swift sınıfı `@unchecked Sendable` olarak içe aktarıyor. Söz yanlışsa (sınıf aslında değişkense) derleyici
/// bizi korumaz; data race'ler geri gelir.
final class ObjCSendableInteropTests: XCTestCase {
    func testReadingTimeEstimatorCanBeSharedAcrossConcurrentTasks() async {
        let estimator = ReadingTimeEstimator(pagesPerHour: 40)

        // 1) En açık derleme anı kanıtı: `Sendable` şartı olan generic bir fonksiyona verebiliyoruz.
        objcInteropRequireSendable(estimator)

        // 2) AYNI nesneyi üç eşzamanlı child task paylaşıyor.
        let results = await withTaskGroup(of: (Int, String).self) { group in
            for pageCount in [30, 220, 320] {
                group.addTask { (pageCount, estimator.formattedEstimate(forPageCount: pageCount)) }
            }
            var collected: [Int: String] = [:]
            for await (pageCount, text) in group {
                collected[pageCount] = text
            }
            return collected
        }
        XCTAssertEqual(results, [30: "45 dk", 220: "5 sa 30 dk", 320: "8 sa"])

        // 3) Nesneyi ayrı (detached) bir task'a verip bu task'ta da kullanmaya devam ediyoruz.
        let detached = Task.detached { estimator.estimatedSeconds(forPageCount: 320) }
        XCTAssertEqual(estimator.pagesPerHour, 40)
        let seconds = await detached.value
        XCTAssertEqual(seconds, 28_800, accuracy: 0.001)
    }
}

/// Yalnızca derleme anında `T: Sendable` şartını denetler; çalışma anında hiçbir şey yapmaz.
/// (Tüm testler tek modülde derlendiği için adı özelliğe özgü ve `private`.)
private func objcInteropRequireSendable<T: Sendable>(_ value: T) {}
