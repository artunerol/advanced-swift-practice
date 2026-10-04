import XCTest
@testable import BookShelf

/// Sıralı `await` vs `async let` vs `TaskGroup` deneylerinin testleri.
///
/// Zamanlama testleri yazarken kural: **dar duvar saati sınırları koyma.** CI makineleri yavaş ve yüklü olabilir.
/// Bu yüzden sadece kaba, cömert sınırlar kullanıyoruz: 3 × 200 ms sırayla en az 600 ms sürmek ZORUNDA (alt sınır
/// kesin), paralel sürümler ise ≈ 200 ms sürer; 500 ms üst sınırı ona 300 ms pay bırakır.
final class LabParallelismTests: XCTestCase {
    private let equalJobs = ConcurrencyLab.JobTrio(.milliseconds(200), .milliseconds(200), .milliseconds(200))

    func testSequentialTakesAtLeastTheSumOfDurations() async throws {
        let report = try await ConcurrencyLab.runSequentially(equalJobs.all)

        XCTAssertEqual(report.strategy, .sequential)
        XCTAssertGreaterThanOrEqual(report.elapsed, .milliseconds(600))
        XCTAssertEqual(report.results.map(\.jobID), [1, 2, 3])
        XCTAssertEqual(report.arrivalOrder, [1, 2, 3], "Sıralı çalışmada sonuçlar yazdığımız sırayla gelir.")
    }

    func testAsyncLetRunsJobsInParallel() async throws {
        let report = try await ConcurrencyLab.runWithAsyncLet(equalJobs)

        XCTAssertEqual(report.strategy, .asyncLet)
        XCTAssertGreaterThanOrEqual(report.elapsed, .milliseconds(200), "En yavaş işten kısa sürmesi imkânsız.")
        XCTAssertLessThan(report.elapsed, .milliseconds(500), "Paralel olsaydı ≈200 ms sürerdi; sıralı olsaydı ≥600 ms.")
        XCTAssertEqual(report.results.map(\.jobID), [1, 2, 3])
    }

    func testTaskGroupRunsJobsInParallel() async throws {
        let report = try await ConcurrencyLab.runWithTaskGroup(equalJobs.all)

        XCTAssertEqual(report.strategy, .taskGroup)
        XCTAssertLessThan(report.elapsed, .milliseconds(500))
        XCTAssertEqual(report.jobCount, 3)
    }

    /// TaskGroup, sayısı çalışma anında belli olan N işi çalıştırır ve hiçbir sonucu kaybetmez.
    func testTaskGroupReturnsAllResultsInSubmissionOrder() async throws {
        let jobs = (1...50).map { ConcurrencyLab.SimulatedJob(id: $0, duration: .milliseconds(10)) }

        let report = try await ConcurrencyLab.runWithTaskGroup(jobs)

        XCTAssertEqual(report.results.map(\.jobID), Array(1...50), "Sonuçlar gönderilme sırasına geri dizilmeli.")
        XCTAssertEqual(Set(report.arrivalOrder), Set(1...50), "Her iş tam bir kez gelmeli.")
        XCTAssertEqual(report.arrivalOrder.count, 50)
    }

    /// Sonuçlar bitiş sırasıyla gelir, ama rapor onları gönderilme sırasına geri dizer.
    /// Süreler arasında ≥140 ms fark var; bu, göreli bir karşılaştırma için yeterince cömert.
    func testTaskGroupDeliversInCompletionOrderAndRestoresSubmissionOrder() async throws {
        let jobs = ConcurrencyLab.JobTrio(.milliseconds(300), .milliseconds(10), .milliseconds(150))

        let report = try await ConcurrencyLab.runWithTaskGroup(jobs.all)

        XCTAssertEqual(report.arrivalOrder.first, 2, "En kısa iş (İş 2) ilk gelmeli.")
        XCTAssertEqual(report.arrivalOrder.last, 1, "En uzun iş (İş 1) son gelmeli.")
        XCTAssertEqual(report.results.map(\.jobID), [1, 2, 3])
        XCTAssertEqual(report.results.map(\.duration), [.milliseconds(300), .milliseconds(10), .milliseconds(150)])
    }

    /// `async let`'te sonuçları `await` ettiğimiz sırayla alırız; işlerin bitiş sırası bunu değiştirmez.
    func testAsyncLetDeliversInAwaitOrder() async throws {
        let jobs = ConcurrencyLab.JobTrio(.milliseconds(150), .milliseconds(10), .milliseconds(50))

        let report = try await ConcurrencyLab.runWithAsyncLet(jobs)

        XCTAssertEqual(report.arrivalOrder, [1, 2, 3])
    }

    /// Yapısal concurrency: Dıştaki task iptal edilince iptal child task'lara yayılır ve grup hızla biter.
    func testCancellingParentCancelsTaskGroupChildren() async {
        let slowJobs = (1...3).map { ConcurrencyLab.SimulatedJob(id: $0, duration: .seconds(30)) }
        let clock = ContinuousClock()
        let start = clock.now

        let task = Task { try await ConcurrencyLab.runWithTaskGroup(slowJobs) }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("İptal edilen deney sonuç döndürmemeli.")
        } catch {
            XCTAssertTrue(error is CancellationError, "Beklenen CancellationError, gelen: \(error)")
        }
        XCTAssertLessThan(start.duration(to: clock.now), .seconds(5), "Child'lar 30 sn beklemeden durmalıydı.")
    }

    func testRunDispatchesToTheRequestedStrategy() async throws {
        let quickJobs = ConcurrencyLab.JobTrio(.milliseconds(1), .milliseconds(1), .milliseconds(1))

        for strategy in ConcurrencyLab.ParallelismStrategy.allCases {
            let report = try await ConcurrencyLab.run(strategy, jobs: quickJobs)
            XCTAssertEqual(report.strategy, strategy)
            XCTAssertEqual(report.jobCount, 3)
        }
    }

    func testFormattedSecondsUsesTurkishDecimalComma() {
        XCTAssertEqual(ConcurrencyLab.formattedSeconds(.milliseconds(1510)), "1,51 sn")
        XCTAssertEqual(ConcurrencyLab.formattedSeconds(.zero), "0,00 sn")
    }

    func testUITestingSettingsAreShorterButNotZero() {
        let settings = ConcurrencyLab.Settings.forLaunch(arguments: ["BookShelf", LaunchArgument.uiTesting])

        XCTAssertEqual(settings, .uiTesting)
        XCTAssertEqual(ConcurrencyLab.Settings.forLaunch(arguments: ["BookShelf"]), .standard)
        for job in settings.jobs.all {
            XCTAssertGreaterThan(job.duration, .zero)
        }
        XCTAssertGreaterThan(settings.longTaskStepDuration, .zero)
        XCTAssertLessThan(settings.longTaskStepDuration, ConcurrencyLab.Settings.standard.longTaskStepDuration)
    }
}
