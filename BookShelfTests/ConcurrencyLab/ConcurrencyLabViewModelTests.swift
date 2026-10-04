import XCTest
@testable import BookShelf

/// `ConcurrencyLabViewModel`'in durum geçişlerinin testleri.
///
/// View model `@MainActor` olduğu için ona dokunan test metotları da `@MainActor`. Sınıfın tamamını `@MainActor`
/// yapmıyoruz: `XCTestCase`'in `setUp` gibi metotlarını override etmek o zaman sorun çıkarır.
final class ConcurrencyLabViewModelTests: XCTestCase {
    /// Birim testleri için çok kısa süreler.
    private static let fastSettings = ConcurrencyLab.Settings(
        jobs: ConcurrencyLab.JobTrio(.milliseconds(20), .milliseconds(5), .milliseconds(10)),
        counterChildTaskCount: 10,
        incrementsPerChild: 100,
        longTaskStepCount: 3,
        longTaskStepDuration: .milliseconds(5)
    )

    /// Uzun iş kendiliğinden bitmesin diye: 1000 adım × 1 sn.
    private static let slowLongTaskSettings: ConcurrencyLab.Settings = {
        var settings = fastSettings
        settings.longTaskStepCount = 1000
        settings.longTaskStepDuration = .seconds(1)
        return settings
    }()

    // MARK: - Başlangıç

    @MainActor
    func testInitialStateShowsPlaceholders() {
        let viewModel = ConcurrencyLabViewModel(settings: Self.fastSettings)

        XCTAssertEqual(viewModel.parallelismText(for: .sequential), "Sıralı: —")
        XCTAssertEqual(viewModel.parallelismText(for: .asyncLet), "async let: —")
        XCTAssertEqual(viewModel.parallelismText(for: .taskGroup), "TaskGroup: —")
        XCTAssertEqual(viewModel.actorCounterText, "Actor: —")
        XCTAssertEqual(viewModel.longTaskState, .idle)
        XCTAssertEqual(viewModel.longTaskProgress, 0)
        XCTAssertFalse(viewModel.isParallelismRunning)
        XCTAssertFalse(viewModel.isLongTaskRunning)
    }

    // MARK: - Sıralı vs paralel

    @MainActor
    func testRunParallelismStoresReportAndFormattedText() async {
        let viewModel = ConcurrencyLabViewModel(settings: Self.fastSettings)

        for strategy in ConcurrencyLab.ParallelismStrategy.allCases {
            await viewModel.runParallelism(strategy)

            XCTAssertNotNil(viewModel.parallelismReports[strategy])
            let text = viewModel.parallelismText(for: strategy)
            XCTAssertTrue(text.hasPrefix("\(strategy.title): "), text)
            XCTAssertTrue(text.hasSuffix(" sn"), text)
        }
        XCTAssertNil(viewModel.runningStrategy, "Deney bitince çalışıyor işareti kalkmalı.")
        XCTAssertTrue(viewModel.taskGroupArrivalText.contains("Sıraya dizildi: 1, 2, 3"), viewModel.taskGroupArrivalText)
    }

    /// Bir deney sürerken ikinci bir deney başlatılamaz.
    @MainActor
    func testParallelismIgnoresSecondStartWhileRunning() async {
        var settings = Self.fastSettings
        settings.jobs = ConcurrencyLab.JobTrio(.milliseconds(200), .milliseconds(200), .milliseconds(200))
        let viewModel = ConcurrencyLabViewModel(settings: settings)

        // Bu `Task` test metodunun izolasyonunu (@MainActor) miras alır.
        let first = Task { await viewModel.runParallelism(.sequential) }
        // İlk deney "çalışıyor" işaretini koyana kadar ana actor'ü bırak.
        while viewModel.runningStrategy == nil {
            await Task.yield()
        }
        XCTAssertEqual(viewModel.parallelismText(for: .sequential), "Sıralı: çalışıyor…")

        await viewModel.runParallelism(.asyncLet) // Hemen dönmeli, hiçbir şey yapmamalı.

        XCTAssertNil(viewModel.parallelismReports[.asyncLet])
        XCTAssertEqual(viewModel.runningStrategy, .sequential)

        await first.value
        XCTAssertNotNil(viewModel.parallelismReports[.sequential])
        XCTAssertNil(viewModel.runningStrategy)
    }

    // MARK: - Paylaşılan durum

    @MainActor
    func testRunCountersProducesExactActorAndLockResults() async {
        let viewModel = ConcurrencyLabViewModel(settings: Self.fastSettings)

        await viewModel.runCounters()

        XCTAssertEqual(viewModel.actorCounterText, "Actor: 1000 / 1000")
        XCTAssertEqual(viewModel.lockedCounterText, "Kilitli class: 1000 / 1000")
        XCTAssertTrue(viewModel.unsafeCounterText.hasPrefix("Kilitsiz class: "), viewModel.unsafeCounterText)
        XCTAssertTrue(viewModel.unsafeCounterText.contains("/ 1000"), viewModel.unsafeCounterText)
        XCTAssertFalse(viewModel.isRunningCounters)
    }

    @MainActor
    func testRunReentrancyShowsExactResultForAtomicVersion() async {
        let viewModel = ConcurrencyLabViewModel(settings: Self.fastSettings)

        await viewModel.runReentrancy()

        XCTAssertEqual(viewModel.reentrancyFixedText, "Arada await yok: 1000 / 1000")
        XCTAssertTrue(viewModel.reentrancyText.hasPrefix("Arada await var: "), viewModel.reentrancyText)
        let buggyValue = viewModel.reentrancyReport?.acrossSuspension.finalValue ?? .max
        XCTAssertLessThanOrEqual(buggyValue, 1000)
        XCTAssertFalse(viewModel.isRunningReentrancy)
    }

    // MARK: - İptal

    @MainActor
    func testLongTaskRunsToCompletion() async throws {
        let viewModel = ConcurrencyLabViewModel(settings: Self.fastSettings)

        viewModel.startLongTask()
        XCTAssertEqual(viewModel.longTaskState, .running(completedSteps: 0, totalSteps: 3))
        XCTAssertTrue(viewModel.isLongTaskRunning)

        let handle = try XCTUnwrap(viewModel.longTask)
        await handle.value

        XCTAssertEqual(viewModel.longTaskState, .completed(totalSteps: 3))
        XCTAssertTrue(viewModel.longTaskStatusText.contains("Tamamlandı"), viewModel.longTaskStatusText)
        XCTAssertEqual(viewModel.longTaskProgress, 1)
        XCTAssertFalse(viewModel.isLongTaskRunning)
    }

    /// Başlatıp hemen iptal: Task'ın gövdesi ana actor'de çalışacak ve biz de ana actor'deyiz; yani gövde ancak
    /// biz `await` edince başlayabilir. O ana kadar iptal bayrağı çoktan kalkmış olur → iş 0 adımda durur.
    @MainActor
    func testCancellingLongTaskReportsCancelled() async throws {
        let viewModel = ConcurrencyLabViewModel(settings: Self.slowLongTaskSettings)

        viewModel.startLongTask()
        let handle = try XCTUnwrap(viewModel.longTask)
        viewModel.cancelLongTask()
        await handle.value

        XCTAssertEqual(viewModel.longTaskState, .cancelled(completedSteps: 0, totalSteps: 1000))
        XCTAssertTrue(viewModel.longTaskStatusText.contains("İptal edildi"), viewModel.longTaskStatusText)
        XCTAssertFalse(viewModel.isLongTaskRunning)
    }

    @MainActor
    func testStartingLongTaskTwiceKeepsTheFirstTask() async throws {
        let viewModel = ConcurrencyLabViewModel(settings: Self.slowLongTaskSettings)

        viewModel.startLongTask()
        let firstHandle = try XCTUnwrap(viewModel.longTask)
        viewModel.startLongTask()

        XCTAssertEqual(viewModel.longTask, firstHandle, "İkinci başlatma yeni bir task oluşturmamalı.")

        viewModel.cancelLongTask()
        await firstHandle.value
    }

    @MainActor
    func testLongTaskCanBeRestartedAfterCancellation() async throws {
        let viewModel = ConcurrencyLabViewModel(settings: Self.slowLongTaskSettings)
        viewModel.startLongTask()
        let firstHandle = try XCTUnwrap(viewModel.longTask)
        viewModel.cancelLongTask()
        await firstHandle.value
        XCTAssertFalse(viewModel.isLongTaskRunning)

        viewModel.startLongTask()

        let secondHandle = try XCTUnwrap(viewModel.longTask)
        XCTAssertNotEqual(secondHandle, firstHandle, "Yeniden başlatma yeni bir task oluşturmalı.")
        XCTAssertEqual(viewModel.longTaskState, .running(completedSteps: 0, totalSteps: 1000))
        viewModel.cancelLongTask()
        await secondHandle.value
        XCTAssertTrue(viewModel.longTaskStatusText.contains("İptal edildi"), viewModel.longTaskStatusText)
    }
}
