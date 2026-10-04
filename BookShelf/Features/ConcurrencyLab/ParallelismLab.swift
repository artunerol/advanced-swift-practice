import Foundation

// MARK: - Modeller

extension ConcurrencyLab {
    /// Taklit edilen bir iş. Gerçekte sadece `duration` kadar bekler; bir ağ isteği gibi düşünebilirsin.
    struct SimulatedJob: Identifiable, Hashable, Sendable {
        let id: Int
        let duration: Duration

        /// İşi çalıştırır.
        ///
        /// - `Task.sleep` thread'i BLOKLAMAZ (`Thread.sleep`'in aksine): task askıya alınır (suspend),
        ///   thread havuzdaki başka bir işe döner. Üç iş aynı anda "uyuyabilir"; paralellik kazancı buradan gelir.
        /// - `throws`: Task iptal edilirse `Task.sleep` hemen `CancellationError` fırlatır.
        func run() async throws -> JobResult {
            try await Task.sleep(for: duration)
            return JobResult(jobID: id, duration: duration)
        }
    }

    /// Bir işin küçük sonucu. Child task'lardan geri döndüğü için `Sendable` olmak zorunda.
    struct JobResult: Hashable, Sendable {
        let jobID: SimulatedJob.ID
        let duration: Duration
    }

    /// Deneyde koşturulan üç iş (id'leri 1, 2, 3).
    ///
    /// Neden dizi değil de üç ayrı alan? `async let` ile başlatılan child task sayısı **derleme anında** bellidir;
    /// "dizideki her eleman için bir `async let`" yazamayız. Bu tip o kısıtı modelde de görünür kılar.
    /// Sayısı çalışma anında belli olan işler için `withTaskGroup` kullanılır (`runWithTaskGroup(_:)` dizi alır).
    struct JobTrio: Hashable, Sendable {
        let first: SimulatedJob
        let second: SimulatedJob
        let third: SimulatedJob

        init(_ firstDuration: Duration, _ secondDuration: Duration, _ thirdDuration: Duration) {
            first = SimulatedJob(id: 1, duration: firstDuration)
            second = SimulatedJob(id: 2, duration: secondDuration)
            third = SimulatedJob(id: 3, duration: thirdDuration)
        }

        var all: [SimulatedJob] { [first, second, third] }
    }

    /// Karşılaştırılan üç strateji.
    enum ParallelismStrategy: CaseIterable, Hashable, Sendable {
        case sequential
        case asyncLet
        case taskGroup

        var title: String {
            switch self {
            case .sequential: "Sıralı"
            case .asyncLet: "async let"
            case .taskGroup: "TaskGroup"
            }
        }
    }

    /// Bir deneyin ölçüm sonucu.
    struct ParallelismReport: Hashable, Sendable {
        let strategy: ParallelismStrategy
        /// `ContinuousClock` ile ölçülen toplam süre.
        let elapsed: Duration
        /// Sonuçlar, işlerin **gönderilme sırasıyla** (girdi dizisindeki sırayla).
        let results: [JobResult]
        /// Kodumuzun sonuçları **teslim aldığı** sıra (iş id'leri).
        /// Sıralı ve `async let`'te bu, bizim yazdığımız `await` sırasıdır; `TaskGroup`'ta ise işlerin bitiş sırası.
        let arrivalOrder: [SimulatedJob.ID]

        var jobCount: Int { results.count }
    }
}

// MARK: - Stratejiler

extension ConcurrencyLab {
    /// Seçilen stratejiyi çalıştırır. View model tek bir giriş noktası kullansın diye var.
    static func run(_ strategy: ParallelismStrategy, jobs: JobTrio) async throws -> ParallelismReport {
        switch strategy {
        case .sequential: try await runSequentially(jobs.all)
        case .asyncLet: try await runWithAsyncLet(jobs)
        case .taskGroup: try await runWithTaskGroup(jobs.all)
        }
    }

    /// 1) SIRALI: Her işi bir öncekinin bitmesini bekleyerek çalıştırır. Toplam süre ≈ sürelerin TOPLAMI.
    ///
    /// `await` "burada bekle ama thread'i bloklama" demektir. Fonksiyon her `await`'te askıya alınır ve iş bitmeden
    /// döngünün bir sonraki adımına geçmez. Yani `async` yazmak kendi başına hiçbir şeyi paralel yapmaz.
    static func runSequentially(_ jobs: [SimulatedJob]) async throws -> ParallelismReport {
        let clock = ContinuousClock()
        let start = clock.now

        var results: [JobResult] = []
        results.reserveCapacity(jobs.count)
        for job in jobs {
            results.append(try await job.run())
        }

        return ParallelismReport(
            strategy: .sequential,
            elapsed: start.duration(to: clock.now),
            results: results,
            arrivalOrder: results.map(\.jobID)
        )
    }

    /// 2) ASYNC LET: Sabit sayıda (burada 3) işi aynı anda başlatır. Toplam süre ≈ EN YAVAŞ işin süresi.
    ///
    /// - `async let x = f()` satırı bir **child task** başlatır ve beklemeden bir sonraki satıra geçer.
    /// - Sonuca ihtiyaç duyduğun yerde `await x` yazarsın. Üç iş o sırada zaten paralel çalışıyordur.
    /// - Sonuçları BİZİM yazdığımız sırayla alırız (önce `first`, sonra `second`...), işler hangi sırayla biterse bitsin.
    /// - Yapısal (structured) concurrency: child task'lar bu fonksiyonun kapsamını aşamaz. Bir tanesi hata fırlatırsa
    ///   ya da hiç `await` edilmeden kapsamdan çıkılırsa diğerleri otomatik iptal edilir ve bitmeleri beklenir.
    static func runWithAsyncLet(_ jobs: JobTrio) async throws -> ParallelismReport {
        let clock = ContinuousClock()
        let start = clock.now

        async let first = jobs.first.run()
        async let second = jobs.second.run()
        async let third = jobs.third.run()
        let results = try await [first, second, third]

        return ParallelismReport(
            strategy: .asyncLet,
            elapsed: start.duration(to: clock.now),
            results: results,
            arrivalOrder: results.map(\.jobID)
        )
    }

    /// 3) TASK GROUP: Sayısı çalışma anında belli olan N işi paralel çalıştırır. Toplam süre ≈ en yavaş iş.
    ///
    /// - `withThrowingTaskGroup`: child task'lar hata fırlatabildiği için "throwing" sürümü. (Hata yoksa `withTaskGroup`.)
    /// - `group.addTask { ... }` her iş için bir child task ekler. Closure `@Sendable`'dır: içine sadece `Sendable`
    ///   değerler (burada `job` ve `index`) yakalanabilir. Swift 6 bunu derleme anında denetler.
    /// - `for try await result in group` sonuçları **bitiş sırasıyla** verir; ekleme sırasıyla DEĞİL.
    ///   Bu yüzden her child sonucu kendi `index`'iyle birlikte döndürür ve biz sonucu dizideki yerine yazarak
    ///   orijinal sırayı geri kurarız. (Id'ye göre `sorted` da olurdu ama index her durumda doğrudur.)
    /// - Bir child hata fırlatırsa `for try await` o hatayı yeniden fırlatır; grup kapsamdan çıkarken kalan
    ///   child'ları iptal eder ve bitmelerini bekler. Dışarıdaki task iptal edilirse iptal tüm child'lara yayılır.
    static func runWithTaskGroup(_ jobs: [SimulatedJob]) async throws -> ParallelismReport {
        let clock = ContinuousClock()
        let start = clock.now

        let (ordered, arrivalOrder) = try await withThrowingTaskGroup(
            of: (index: Int, result: JobResult).self,
            returning: ([JobResult], [SimulatedJob.ID]).self
        ) { group in
            for (index, job) in jobs.enumerated() {
                group.addTask {
                    (index: index, result: try await job.run())
                }
            }

            var slots = [JobResult?](repeating: nil, count: jobs.count)
            var arrivalOrder: [SimulatedJob.ID] = []
            arrivalOrder.reserveCapacity(jobs.count)
            for try await (index, result) in group {
                arrivalOrder.append(result.jobID)
                slots[index] = result
            }
            // Döngü normal bittiyse her child sonucunu döndürmüştür; `compactMap` hiçbir şey atmaz.
            return (slots.compactMap { $0 }, arrivalOrder)
        }

        return ParallelismReport(
            strategy: .taskGroup,
            elapsed: start.duration(to: clock.now),
            results: ordered,
            arrivalOrder: arrivalOrder
        )
    }
}
