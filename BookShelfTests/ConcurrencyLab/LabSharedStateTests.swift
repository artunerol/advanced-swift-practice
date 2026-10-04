import XCTest
@testable import BookShelf

/// Paylaşılan durum deneylerinin testleri: kilitsiz sınıf, kilitli sınıf, actor ve actor reentrancy.
///
/// Önemli: Kilitsiz sayaç ve reentrancy sayacı için ASLA `== N` ya da `!= N` doğrulaması yapmıyoruz.
/// Sonuçları zamanlamaya bağlıdır: bazen şans eseri tam N çıkabilir, bazen çıkmaz. Böyle bir test ara sıra
/// kırılır (*flaky test*). Kesin olarak bildiğimiz tek şey: artışlar kaybolabilir ama **fazladan** artış olamaz (≤ N).
final class LabSharedStateTests: XCTestCase {
    private let childTasks = 10
    private let incrementsPerChild = 100
    private var expected: Int { childTasks * incrementsPerChild }

    func testActorCounterIsAlwaysExact() async {
        let report = await ConcurrencyLab.runCounterExperiment(
            ConcurrencyLab.ActorCounter(), childTaskCount: childTasks, incrementsPerChild: incrementsPerChild
        )

        XCTAssertEqual(report.finalValue, expected)
        XCTAssertEqual(report.expectedValue, expected)
        XCTAssertTrue(report.isExact)
        XCTAssertEqual(report.lostUpdates, 0)
    }

    func testLockedCounterIsAlwaysExact() async {
        let report = await ConcurrencyLab.runCounterExperiment(
            ConcurrencyLab.LockedCounter(), childTaskCount: childTasks, incrementsPerChild: incrementsPerChild
        )

        XCTAssertEqual(report.finalValue, expected)
    }

    /// Kilitsiz sayaç: data race var. Sonuç N'i GEÇEMEZ, ama N'e eşit olup olmadığı şansa bağlı.
    func testUnsafeCounterNeverExceedsExpectedTotal() async {
        let report = await ConcurrencyLab.runCounterExperiment(
            ConcurrencyLab.UnsafeCounter(), childTaskCount: childTasks, incrementsPerChild: incrementsPerChild
        )

        XCTAssertLessThanOrEqual(report.finalValue, expected)
        XCTAssertEqual(report.expectedValue, expected)
    }

    /// Reentrancy: Actor içinde bile okuma ile yazma arasına `await` girince artışlar kaybolabilir.
    /// Aynı yükte `await`'siz sürüm her zaman tam N verir.
    func testReentrancyLosesUpdatesOnlyWhenAwaitingBetweenReadAndWrite() async {
        let report = await ConcurrencyLab.runReentrancyExperiment(
            childTaskCount: childTasks, incrementsPerChild: incrementsPerChild
        )

        XCTAssertLessThanOrEqual(report.acrossSuspension.finalValue, expected)
        XCTAssertEqual(report.atomic.finalValue, expected)
        XCTAssertTrue(report.atomic.isExact)
    }

    /// Protokol üzerinden (generic `some SharedCounter`) tek thread'de kullanım: her tip doğru sayar.
    func testEveryCounterCountsCorrectlyWithoutConcurrency() async {
        let counters: [any ConcurrencyLab.SharedCounter] = [
            ConcurrencyLab.UnsafeCounter(),
            ConcurrencyLab.LockedCounter(),
            ConcurrencyLab.ActorCounter(),
        ]

        for counter in counters {
            for _ in 0..<5 {
                await counter.increment()
            }
            let value = await counter.value
            XCTAssertEqual(value, 5, "\(type(of: counter)) tek başına yanlış saydı.")
        }
    }

    func testCounterReportComputesLostUpdates() {
        let report = ConcurrencyLab.CounterReport(finalValue: 912, expectedValue: 1000)

        XCTAssertEqual(report.lostUpdates, 88)
        XCTAssertFalse(report.isExact)
    }
}
