import XCTest
@testable import BookShelf

/// `LongRunningJob`'ın kooperatif iptal davranışının testleri.
final class LabCancellationTests: XCTestCase {
    func testJobCompletesAllStepsAndReportsProgressInOrder() async {
        let job = ConcurrencyLab.LongRunningJob(stepCount: 5, stepDuration: .milliseconds(5))
        let recorder = LabProgressRecorder()

        let outcome = await job.run { step in
            await recorder.record(step)
        }

        XCTAssertEqual(outcome, .completed(steps: 5))
        let steps = await recorder.steps
        XCTAssertEqual(steps, [1, 2, 3, 4, 5])
    }

    /// İptal edilen iş erken durur ve iptal edildiğini bildirir.
    ///
    /// Adımları bir `AsyncStream`'e akıtıp 2. adımı gördüğümüz anda iptal ediyoruz. Böylece "biraz bekle, sonra
    /// iptal et" gibi zamanlamaya bağlı (kırılgan) bir `sleep` kullanmamız gerekmiyor.
    func testCancelledJobStopsEarlyAndReportsCancellation() async {
        let job = ConcurrencyLab.LongRunningJob(stepCount: 100, stepDuration: .milliseconds(30))
        let (progress, continuation) = AsyncStream.makeStream(of: Int.self)
        let clock = ContinuousClock()
        let start = clock.now

        let task = Task {
            await job.run { step in
                continuation.yield(step)
            }
        }

        for await step in progress where step >= 2 {
            task.cancel()
            break
        }
        let outcome = await task.value
        continuation.finish()

        guard case .cancelled(let completedSteps) = outcome else {
            return XCTFail("İş iptal edilmiş olmalıydı, sonuç: \(outcome)")
        }
        XCTAssertGreaterThanOrEqual(completedSteps, 2)
        XCTAssertLessThan(completedSteps, 100, "İş sonuna kadar çalışmamalıydı.")
        XCTAssertLessThan(start.duration(to: clock.now), .seconds(3), "100 × 30 ms = 3 sn; iptal çok daha erken durdurmalı.")
    }

    /// Hemen iptal edilen iş hiçbir adımı tamamlamaz: ya ilk kontrolde (`Task.isCancelled`) ya da ilk
    /// `Task.sleep` sırasında durur. Hangisi olursa olsun sonuç aynıdır.
    func testJobCancelledImmediatelyCompletesNoSteps() async {
        let job = ConcurrencyLab.LongRunningJob(stepCount: 3, stepDuration: .seconds(30))

        let task = Task { await job.run() }
        task.cancel()
        let outcome = await task.value

        XCTAssertEqual(outcome, .cancelled(completedSteps: 0))
    }
}

/// Testte ilerleme adımlarını güvenle toplamak için küçük bir actor.
/// `onProgress` closure'ı `@Sendable` olduğu için içinden sıradan bir `var` diziye yazamayız; actor bu işi güvenle yapar.
private actor LabProgressRecorder {
    private(set) var steps: [Int] = []

    func record(_ step: Int) {
        steps.append(step)
    }
}
