import XCTest
@testable import BookShelf

/// Objective-C'deki `BKReadingTimeEstimator` ve onun kullandığı Swift sınıfı `ReadingPace` (ObjC adı `BKReadingPace`).
final class ObjCReadingTimeEstimatorTests: XCTestCase {
    // MARK: - Saniye hesabı

    func testEstimatedSecondsFollowsPagesPerHour() {
        let estimator = ReadingTimeEstimator(pagesPerHour: 40)
        XCTAssertEqual(estimator.estimatedSeconds(forPageCount: 320), 28_800, accuracy: 0.001)  // 8 saat
        XCTAssertEqual(estimator.estimatedSeconds(forPageCount: 1), 90, accuracy: 0.001)        // 1,5 dakika
        XCTAssertEqual(ReadingTimeEstimator(pagesPerHour: 60).estimatedSeconds(forPageCount: 30), 1_800, accuracy: 0.001)
    }

    func testEstimatedSecondsIsZeroForNonPositivePageCount() {
        let estimator = ReadingTimeEstimator(pagesPerHour: 40)
        XCTAssertEqual(estimator.estimatedSeconds(forPageCount: 0), 0)
        XCTAssertEqual(estimator.estimatedSeconds(forPageCount: -5), 0)
    }

    // MARK: - Biçimlendirme

    func testFormattedEstimateAtFortyPagesPerHour() {
        let estimator = ReadingTimeEstimator(pagesPerHour: 40)
        let cases: [(pageCount: Int, expected: String)] = [
            (320, "8 sa"),          // tam saat
            (220, "5 sa 30 dk"),    // saat + dakika
            (30, "45 dk"),          // bir saatten az
            (724, "18 sa 6 dk"),    // Tutunamayanlar: 18,1 saat
            (1, "2 dk"),            // 1,5 dk -> yarım yukarı yuvarlanır
            (5_000, "125 sa"),      // gün birimi yok
        ]
        for testCase in cases {
            XCTAssertEqual(estimator.formattedEstimate(forPageCount: testCase.pageCount), testCase.expected,
                           "\(testCase.pageCount) sayfa")
        }
    }

    func testFormattedEstimateBelowOneMinute() {
        let fastReader = ReadingTimeEstimator(pagesPerHour: 1_000)
        XCTAssertEqual(fastReader.formattedEstimate(forPageCount: 5), "1 dk'dan az")   // 18 sn -> 0 dk
        XCTAssertEqual(fastReader.formattedEstimate(forPageCount: 8), "1 dk'dan az")   // 28,8 sn -> 0 dk
        XCTAssertEqual(fastReader.formattedEstimate(forPageCount: 9), "1 dk")          // 32,4 sn -> 1 dk
    }

    /// 59,5 dakika yuvarlanınca 60 olur; sonuç "0 sa 60 dk" ya da "59 dk" değil, "1 sa" olmalı.
    func testRoundingCarriesIntoHours() {
        let estimator = ReadingTimeEstimator(pagesPerHour: 60.5)
        XCTAssertEqual(estimator.formattedEstimate(forPageCount: 60), "1 sa")
    }

    func testFormattedEstimateForNonPositivePageCount() {
        let estimator = ReadingTimeEstimator(pagesPerHour: 40)
        XCTAssertEqual(estimator.formattedEstimate(forPageCount: 0), "0 dk")
        XCTAssertEqual(estimator.formattedEstimate(forPageCount: -3), "0 dk")
    }

    // MARK: - Varsayılan hız: ObjC, Swift'teki ReadingPace'i kullanıyor

    func testInvalidPagesPerHourFallsBackToSwiftDefault() {
        for invalid in [0, -10, Double.nan, .infinity, -.infinity] {
            let estimator = ReadingTimeEstimator(pagesPerHour: invalid)
            XCTAssertEqual(estimator.pagesPerHour, ReadingPace.defaultPagesPerHour, "\(invalid)")
        }
        XCTAssertEqual(ReadingPace.defaultPagesPerHour, 40)
        XCTAssertEqual(ReadingTimeEstimator(pagesPerHour: 0).formattedEstimate(forPageCount: 320), "8 sa")
    }

    func testValidPagesPerHourIsKept() {
        XCTAssertEqual(ReadingTimeEstimator(pagesPerHour: 55).pagesPerHour, 55)
        XCTAssertEqual(ReadingPace.resolved(pagesPerHour: 55), 55)
        XCTAssertEqual(ReadingPace.resolved(pagesPerHour: -1), ReadingPace.defaultPagesPerHour)
        XCTAssertTrue(ReadingPace.typicalRange.contains(ReadingPace.defaultPagesPerHour))
    }

    // MARK: - Swift sınıfının ObjC çalışma zamanındaki (runtime) görünümü

    /// `@objc(BKReadingPace)` sayesinde ObjC çalışma zamanı sınıfı bu adla tanır.
    func testReadingPaceIsRegisteredWithObjCName() throws {
        XCTAssertEqual(NSStringFromClass(ReadingPace.self), "BKReadingPace")
        let runtimeClass: AnyClass = try XCTUnwrap(NSClassFromString("BKReadingPace"))
        XCTAssertTrue(runtimeClass == ReadingPace.self)
    }

    /// `@objc` üyeler ObjC çalışma zamanında seçici (selector) olarak vardır; `@objc` olmayanlar yoktur.
    func testOnlyObjCMembersAreVisibleToTheRuntime() {
        XCTAssertNotNil(class_getClassMethod(ReadingPace.self, NSSelectorFromString("defaultPagesPerHour")))
        XCTAssertNotNil(class_getClassMethod(ReadingPace.self, NSSelectorFromString("resolvedPagesPerHour:")))
        // `typicalRange` bir `ClosedRange<Double>`; ObjC'de temsil edilemez ve `@objc` değil.
        XCTAssertNil(class_getClassMethod(ReadingPace.self, NSSelectorFromString("typicalRange")))
    }
}
