import Foundation
import Observation

/// Laboratuvar ekranının durumu ve davranışı.
///
/// - `@MainActor`: Tüm özellikleri ve metotları ana actor'e (ana thread'e) izole. SwiftUI bu özellikleri ana
///   thread'de okur; durumu da yalnızca ana thread'de değiştirirsek UI ile yarış (race) olmaz. Derleyici bunu
///   denetler: başka bir izolasyondan `viewModel.x = ...` yazmaya çalışmak derleme hatasıdır.
/// - `@Observable` (Observation çatısı, iOS 17+): View `body` içinde hangi özelliği okuduysa yalnızca o özellik
///   değişince yeniden çizilir. `ObservableObject` + `@Published`'ın modern karşılığı.
/// - `final class`: View model bir *kimliğe* sahiptir; ekran yaşadığı sürece aynı örnek kullanılır ve
///   task'lar bu örneği güncellemeye devam eder. Bu yüzden `struct` değil `class`.
///
/// Ağır işler burada değil, `ConcurrencyLab` içindeki nonisolated `async` fonksiyonlarda. View model onları
/// `await` ile çağırır: çağrı sürerken ana thread serbest kalır, sonuç gelince çalışma **otomatik olarak** ana
/// actor'e geri döner ve durumu orada güncelleriz. `DispatchQueue.main.async` yazmaya gerek kalmaz.
@MainActor
@Observable
final class ConcurrencyLabViewModel {
    /// Uzun işin ekranda gösterilen durumu.
    enum LongTaskState: Hashable, Sendable {
        case idle
        case running(completedSteps: Int, totalSteps: Int)
        case completed(totalSteps: Int)
        case cancelled(completedSteps: Int, totalSteps: Int)
    }

    let settings: ConcurrencyLab.Settings

    // MARK: Sıralı vs paralel

    /// Her stratejinin son ölçümü.
    private(set) var parallelismReports: [ConcurrencyLab.ParallelismStrategy: ConcurrencyLab.ParallelismReport] = [:]
    /// Şu an çalışan strateji. `nil` değilse yeni bir deney başlatılmaz (çift başlatma koruması).
    private(set) var runningStrategy: ConcurrencyLab.ParallelismStrategy?

    // MARK: Paylaşılan durum

    private(set) var unsafeCounterReport: ConcurrencyLab.CounterReport?
    private(set) var lockedCounterReport: ConcurrencyLab.CounterReport?
    private(set) var actorCounterReport: ConcurrencyLab.CounterReport?
    private(set) var isRunningCounters = false

    // MARK: Reentrancy

    private(set) var reentrancyReport: ConcurrencyLab.ReentrancyReport?
    private(set) var isRunningReentrancy = false

    // MARK: İptal

    private(set) var longTaskState: LongTaskState = .idle
    /// Uzun işi yürüten task. İptal edebilmek için referansını saklıyoruz.
    ///
    /// `@ObservationIgnored`: Bu özellik değişince SwiftUI'a haber VERİLMEZ. Bu yüzden view bunu ne doğrudan
    /// ne de dolaylı olarak (ondan hesaplanan bir özellik üzerinden) okumamalı; okursa ekran güncel kalmaz.
    /// Ekranın ihtiyaç duyduğu "çalışıyor mu?" bilgisi gözlemlenen `longTaskState`'ten gelir (`isLongTaskRunning`).
    @ObservationIgnored private(set) var longTask: Task<Void, Never>?

    init(settings: ConcurrencyLab.Settings = .standard) {
        self.settings = settings
    }

    // MARK: - Sıralı vs paralel

    var isParallelismRunning: Bool { runningStrategy != nil }

    /// Seçilen stratejiyi çalıştırır ve sonucu saklar.
    ///
    /// View bunu `Task { await viewModel.runParallelism(.sequential) }` ile çağırır. O `Task`, View'ın
    /// izolasyonunu (`@MainActor`) **miras alır**; bu fonksiyon da `@MainActor` olduğu için aynı actor üzerinde,
    /// ekstra geçiş olmadan başlar.
    func runParallelism(_ strategy: ConcurrencyLab.ParallelismStrategy) async {
        // Çift başlatma koruması: "kontrol et" ve "işaretle" adımları arasında `await` YOK.
        // Ana actor aynı anda tek bir iş yürüttüğü için bu ikili bölünmez; iki hızlı dokunuştan ikincisi
        // `runningStrategy`'yi dolu görür ve geri döner. (Actor reentrancy deneyindeki kuralın aynısı!)
        guard runningStrategy == nil else { return }
        runningStrategy = strategy
        defer { runningStrategy = nil }

        do {
            // `ConcurrencyLab.run` nonisolated ve async: bu satırda ana actor'den ÇIKILIR, iş global concurrent
            // executor'de yürür. Bu sırada ana thread boştadır (UI akıcı). İş bitince çalışma ana actor'e döner;
            // bir sonraki satır yine ana thread'de çalışır ve durumu güvenle değiştirebilir.
            let report = try await ConcurrencyLab.run(strategy, jobs: settings.jobs)
            parallelismReports[strategy] = report
        } catch {
            // Buraya yalnızca iptalle gelinebilir (`CancellationError`). Yarım kalan ölçüm yanıltmasın diye siliyoruz.
            parallelismReports[strategy] = nil
        }
    }

    /// Örn. "Sıralı: 1,20 sn".
    func parallelismText(for strategy: ConcurrencyLab.ParallelismStrategy) -> String {
        if runningStrategy == strategy {
            return "\(strategy.title): çalışıyor…"
        }
        guard let report = parallelismReports[strategy] else {
            return "\(strategy.title): —"
        }
        return "\(strategy.title): \(ConcurrencyLab.formattedSeconds(report.elapsed))"
    }

    /// Deneydeki işlerin süreleri. Örn. "İş 1: 0,50 sn · İş 2: 0,30 sn · İş 3: 0,40 sn".
    var jobsDescription: String {
        settings.jobs.all
            .map { "İş \($0.id): \(ConcurrencyLab.formattedSeconds($0.duration))" }
            .joined(separator: " · ")
    }

    /// TaskGroup sonuçlarının geliş sırası ve geri kurulan sıra.
    var taskGroupArrivalText: String {
        guard let report = parallelismReports[.taskGroup] else {
            return "Geliş sırası: —"
        }
        let arrival = report.arrivalOrder.map { "İş \($0)" }.joined(separator: " → ")
        let ordered = report.results.map { "\($0.jobID)" }.joined(separator: ", ")
        return "Geliş sırası: \(arrival) · Sıraya dizildi: \(ordered)"
    }

    // MARK: - Paylaşılan durum

    /// Üç sayacı sırayla aynı yük altında çalıştırır.
    ///
    /// Sayaçlar ana actor'de oluşturulup nonisolated fonksiyona veriliyor. Bu, ancak sayaç tipleri `Sendable`
    /// olduğu için derlenir: actor ve kilitli sınıf gerçekten güvenli; kilitsiz sınıf ise `@unchecked` ile
    /// derleyiciyi kandırıyor (bilerek).
    func runCounters() async {
        guard !isRunningCounters else { return }
        isRunningCounters = true
        defer { isRunningCounters = false }

        unsafeCounterReport = nil
        lockedCounterReport = nil
        actorCounterReport = nil

        let childTasks = settings.counterChildTaskCount
        let increments = settings.incrementsPerChild
        unsafeCounterReport = await ConcurrencyLab.runCounterExperiment(
            ConcurrencyLab.UnsafeCounter(), childTaskCount: childTasks, incrementsPerChild: increments
        )
        lockedCounterReport = await ConcurrencyLab.runCounterExperiment(
            ConcurrencyLab.LockedCounter(), childTaskCount: childTasks, incrementsPerChild: increments
        )
        actorCounterReport = await ConcurrencyLab.runCounterExperiment(
            ConcurrencyLab.ActorCounter(), childTaskCount: childTasks, incrementsPerChild: increments
        )
    }

    /// Örn. "Kilitsiz class: 912 / 1000 (88 artış kayboldu)".
    var unsafeCounterText: String {
        counterText(title: "Kilitsiz class", report: unsafeCounterReport, isRunning: isRunningCounters)
    }
    /// Örn. "Kilitli class: 1000 / 1000".
    var lockedCounterText: String {
        counterText(title: "Kilitli class", report: lockedCounterReport, isRunning: isRunningCounters)
    }
    /// Örn. "Actor: 1000 / 1000".
    var actorCounterText: String {
        counterText(title: "Actor", report: actorCounterReport, isRunning: isRunningCounters)
    }

    // MARK: - Reentrancy

    func runReentrancy() async {
        guard !isRunningReentrancy else { return }
        isRunningReentrancy = true
        defer { isRunningReentrancy = false }

        reentrancyReport = nil
        reentrancyReport = await ConcurrencyLab.runReentrancyExperiment(
            childTaskCount: settings.counterChildTaskCount,
            incrementsPerChild: settings.incrementsPerChild
        )
    }

    /// Örn. "Arada await var: 131 / 1000 (869 artış kayboldu)".
    var reentrancyText: String {
        counterText(title: "Arada await var", report: reentrancyReport?.acrossSuspension, isRunning: isRunningReentrancy)
    }

    /// Örn. "Arada await yok: 1000 / 1000".
    var reentrancyFixedText: String {
        counterText(title: "Arada await yok", report: reentrancyReport?.atomic, isRunning: isRunningReentrancy)
    }

    // MARK: - İptal

    /// "Başlat" ve "İptal et" düğmelerinin etkinliği buna bağlı.
    ///
    /// Bilerek `longTask != nil` DEĞİL: `longTask` `@ObservationIgnored` olduğu için view onu okuduğunda bağımlılık
    /// kaydedilmez ve düğmeler, ancak başka bir gözlemlenen özellik tesadüfen aynı anda değişirse yenilenirdi.
    /// Gözlemlenen `longTaskState`'ten türetmek bu kırılganlığı ortadan kaldırır. İki bilgi her zaman birlikte
    /// değişir: `startLongTask()` durumu `.running` yapıp task'ı saklar, `finishLongTask(with:)` durumu
    /// sonuçlandırıp task'ı bırakır.
    var isLongTaskRunning: Bool {
        if case .running = longTaskState { true } else { false }
    }

    /// Uzun işi **yapısal olmayan** (unstructured) bir `Task` içinde başlatır.
    ///
    /// Neden `Task { }`? Düğme aksiyonu senkron bir fonksiyondur ve işin ömrü bir kapsama (scope) sığmaz:
    /// kullanıcı başka bir düğmeyle (İptal) ona sonradan dokunabilmeli. Bu yüzden task'ın referansını saklıyoruz.
    ///
    /// `Task { }` vs `Task.detached { }`:
    /// - `Task { }` çağrıldığı yerin actor izolasyonunu (burada `@MainActor`), önceliğini ve task-local
    ///   değerlerini **miras alır**. Closure ana actor'de çalışır; `self`'in özelliklerine doğrudan erişebilir.
    ///   Ağır iş yine ana thread'i tutmaz, çünkü `job.run` nonisolated async bir fonksiyon: `await` edildiği
    ///   an iş arka plana geçer, bitince buraya (ana actor'e) geri dönülür.
    /// - `Task.detached { }` hiçbir şeyi miras almaz (ne actor, ne öncelik, ne task-local). Closure hiçbir actor'de
    ///   çalışmaz; durumu güncellemek için `await MainActor.run { }` gibi açık bir geçiş gerekir. Burada
    ///   ihtiyacımız yok; `Task.detached` nadiren gereken bir araçtır.
    ///
    /// Referans döngüsü notu: Task `self`'i güçlü tutar, `self` de task'ı. İş bitince `longTask = nil`
    /// yaptığımız için döngü kendiliğinden kırılır.
    func startLongTask() {
        // Çift başlatma koruması (kontrol ile atama arasında `await` yok).
        guard longTask == nil else { return }

        let job = ConcurrencyLab.LongRunningJob(
            stepCount: settings.longTaskStepCount,
            stepDuration: settings.longTaskStepDuration
        )
        longTaskState = .running(completedSteps: 0, totalSteps: job.stepCount)

        longTask = Task {
            let outcome = await job.run { completedSteps in
                // Bu closure `@Sendable` ve ana actor'e bağlı DEĞİL; iş arka planda çalışırken çağrılır.
                // `@MainActor` metoda ulaşmak için `await` ile ana actor'e geçiyoruz (actor hop).
                await self.didCompleteLongTaskStep(completedSteps)
            }
            // Buraya gelindiğinde yine ana actor'deyiz (Task'ın closure'ı `@MainActor` miras aldı).
            finishLongTask(with: outcome)
        }
    }

    /// Uzun işi iptal etmesini ister.
    ///
    /// `cancel()` işi zorla DURDURMAZ; sadece iptal bayrağını kaldırır. İş, bir sonraki kontrol noktasında
    /// (`Task.isCancelled` / `Task.sleep`) bunu fark edip kendisi durur. Durum da o an `.cancelled` olur.
    func cancelLongTask() {
        longTask?.cancel()
    }

    /// 0...1 arası ilerleme.
    var longTaskProgress: Double {
        switch longTaskState {
        case .idle: 0
        case .running(let completed, let total), .cancelled(let completed, let total):
            total > 0 ? Double(completed) / Double(total) : 0
        case .completed: 1
        }
    }

    /// Örn. "Çalışıyor: 7 / 20", "İptal edildi: 7 / 20 adımda durdu", "Tamamlandı: 20 / 20".
    var longTaskStatusText: String {
        switch longTaskState {
        case .idle:
            "Hazır: \(settings.longTaskStepCount) adım"
        case .running(let completed, let total):
            "Çalışıyor: \(completed) / \(total)"
        case .completed(let total):
            "Tamamlandı: \(total) / \(total)"
        case .cancelled(let completed, let total):
            "İptal edildi: \(completed) / \(total) adımda durdu"
        }
    }

    private func didCompleteLongTaskStep(_ completedSteps: Int) {
        guard case .running(_, let total) = longTaskState else { return }
        longTaskState = .running(completedSteps: completedSteps, totalSteps: total)
    }

    private func finishLongTask(with outcome: ConcurrencyLab.LongJobOutcome) {
        switch outcome {
        case .completed(let steps):
            longTaskState = .completed(totalSteps: steps)
        case .cancelled(let completedSteps):
            longTaskState = .cancelled(completedSteps: completedSteps, totalSteps: settings.longTaskStepCount)
        }
        longTask = nil
    }

    // MARK: - Yardımcılar

    private func counterText(title: String, report: ConcurrencyLab.CounterReport?, isRunning: Bool) -> String {
        if isRunning, report == nil {
            return "\(title): çalışıyor…"
        }
        guard let report else {
            return "\(title): —"
        }
        let fraction = "\(report.finalValue) / \(report.expectedValue)"
        return report.isExact ? "\(title): \(fraction)" : "\(title): \(fraction) (\(report.lostUpdates) artış kayboldu)"
    }
}
