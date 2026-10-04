import SwiftUI

extension InterviewTopic {
    /// Bonus: Swift Concurrency. Demo, Laboratuvar sekmesindeki deneylerin AYNISI (`ConcurrencyLabForm`);
    /// üstüne her deneyin hangi mülakat kavramını gösterdiğini söyleyen kısa bir özet eklenir.
    static let concurrency = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.concurrency,
        section: .bonus,
        question: "Swift Concurrency'yi anlatır mısın? async/await, actor, Sendable ve @MainActor ne işe yarar?",
        shortAnswer: [
            "async/await asenkron kodu callback'siz, yukarıdan aşağı okunur yazdırır. `await` olası bir askıya alma noktasıdır: Fonksiyon beklemek zorunda kalırsa thread'i bloklamaz, thread başka işlere döner.",
            "Yapılandırılmış concurrency: `async let` ve `TaskGroup` ile açılan alt görevler, üst görevin kapsamını aşamaz; hata ve iptal görev ağacı boyunca yayılır. `Task { }` yapılandırılmamıştır, ömrünü ve iptalini ben yönetirim.",
            "`actor`, değiştirilebilir durumunu izole eder: Durumuna aynı anda tek bir görev erişir, dışarıdan izole üyelerine erişim `await` ister. Böylece paylaşılan durumda data race olmaz.",
            "`@MainActor` ana thread'i temsil eden global actor'dür; UI kodu ve view model'ler orada çalışır. `Sendable` ise bir değerin izolasyon sınırını (görevden göreve, actor'den actor'e) güvenle geçebileceğini söyler.",
            "Swift 6 dil modunda derleyici bu kuralları denetler; data race'e yol açabilecek kod derlenmez (`@unchecked Sendable`, `nonisolated(unsafe)` gibi bilinçli kaçış kapıları hariç). Ama race condition (zamanlamaya bağlı mantık hatası) hâlâ mümkündür; örneğin actor reentrancy.",
        ],
        followUps: [
            FollowUp(
                question: "Data race ile race condition aynı şey mi?",
                answer: "Hayır. Data race: Aynı belleğe, en az biri yazma olan iki erişimin senkronizasyon olmadan aynı anda yapılması. Swift'te tanımsız davranıştır ve Swift 6 dil modu bunu derleme anında engeller. Race condition: Sonucun işlemlerin zamanlamasına bağlı olması; bir mantık hatasıdır ve data race olmadan da oluşur. Actor data race'i önler, race condition'ı önlemez."
            ),
            FollowUp(
                question: "Actor reentrancy nedir, nasıl korunursun?",
                answer: "Actor bir `await`'te askıya alınınca kilitli kalmaz; bekleme sırasında aynı actor'e gelen başka çağrılar çalışır. Bu deadlock'u önler, ama `await`'ten önce okuduğun durum sonra değişmiş olabilir. Korunma: Durumu arada `await` olmayan senkron metotlarda değiştir, `await`'ten sonra varsayımlarını yeniden kontrol et, aynı iş için devam eden görevi paylaş (ikinci kez başlatma)."
            ),
            FollowUp(
                question: "`async` bir fonksiyon arka planda mı çalışır?",
                answer: "`async` 'ayrı thread' demek değildir; nerede çalışacağını izolasyon belirler. `@MainActor` gibi bir actor'e bağlı fonksiyon o actor'de çalışır. Hiçbir actor'e bağlı olmayan (nonisolated) bir `async` fonksiyon, bu projenin ayarlarıyla (Swift 6 dil modu, Approachable Concurrency kapalı) global concurrent executor'de, yani arka plandaki thread havuzunda çalışır. Swift 6.2'de NonisolatedNonsendingByDefault açıksa aynı fonksiyon çağıranın actor'ünde çalışır; arka plana göndermek için `@concurrent` yazılır."
            ),
            FollowUp(
                question: "`Task { }` ile `Task.detached { }` farkı ne?",
                answer: "`Task { }` başlatıldığı yerin actor izolasyonunu, önceliğini ve task-local değerlerini miras alır; `@MainActor` bir view model'de açılan Task'ın gövdesi ana actor'de çalışır. `Task.detached` hiçbirini miras almaz. İkisi de yapılandırılmamıştır: Başlatan görev iptal edilse bile iptal onlara kendiliğinden geçmez. Detached nadiren gerekir."
            ),
            FollowUp(
                question: "GCD (DispatchQueue) varken neden Swift Concurrency?",
                answer: "GCD'de thread güvenliğini sen sağlarsın, derleyici denetlemez; callback'ler iç içe geçer, hata ve iptal elle taşınır, bloklanan işler yeni thread açtırıp 'thread explosion'a yol açabilir. Swift Concurrency'de görevler bloklamak yerine askıya alınır, kooperatif havuz kabaca çekirdek sayısı kadar thread kullanır; izolasyon ve Sendable derleme anında denetlenir, hata `throws` ile, iptal görev ağacıyla yayılır."
            ),
        ],
        pitfalls: [
            "Actor'ü bir kilit ya da transaction sanmak: oku → `await` → yaz kalıbında araya başka çağrılar girer ve güncellemeler kaybolur (reentrancy).",
            "Hatayı susturmak için `@unchecked Sendable` ya da `nonisolated(unsafe)` yazmak: Derleyici denetimi kapanır ama yarış sürer. Yalnızca içeride gerçekten bir kilit ya da atomik varsa kullan.",
            "Uzun yaşayan bir `Task` içinde `self`'i güçlü yakalamak: Task bitene kadar nesne yaşar; sonsuz bir `for await` döngüsünde `deinit` hiç çalışmaz. `[weak self]` kullan ve görevi `cancel()` et.",
            "`cancel()`'ın işi durdurduğunu sanmak: İptal yalnızca bir bayraktır. `Task.isCancelled`'a bakmayan bir döngü sonuna kadar çalışır.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Core/Stores/FavoritesStore.swift",
                symbol: "FavoritesStore",
                note: "Actor: `toggle` oku-karar ver-yaz adımlarını arada `await` olmadan yapar, bu yüzden atomik. Dışarıdan her çağrı `await` ister."
            ),
            CodePointer(
                file: "BookShelf/Features/BookDetail/BookDetailViewModel.swift",
                symbol: "loadExtrasIfNeeded()",
                note: "`async let` ile iki istek aynı anda yola çıkar; alt görevlere `self` yerine `Sendable` yerel kopyalar verilir."
            ),
            CodePointer(
                file: "BookShelf/Features/ConcurrencyLab/ParallelismLab.swift",
                symbol: "runWithTaskGroup(_:)",
                note: "TaskGroup sonuçları bitiş sırasıyla gelir; her sonuç kendi index'iyle döndüğü için ekleme sırası geri kurulur."
            ),
            CodePointer(
                file: "BookShelf/Features/ConcurrencyLab/LabCounters.swift",
                symbol: "ReentrantCounter",
                note: "Data race yok ama race condition var: `incrementAcrossSuspension` oku → await → yaz yüzünden artış kaybeder."
            ),
            CodePointer(
                file: "BookShelf/Features/ConcurrencyLab/LongRunningJob.swift",
                symbol: "LongRunningJob.run(onProgress:)",
                note: "Kooperatif iptal: Her adımdan önce `Task.isCancelled`, beklerken iptale duyarlı `Task.sleep`."
            ),
            CodePointer(
                file: "BookShelf/Features/Favorites/FavoritesViewController.swift",
                symbol: "startObservingFavorites()",
                note: "`Task { [weak self] in ... }` ana actor'ü miras alır; `for await` döngüsü VC'yi hayatta tutmaz ve `viewDidDisappear`'da iptal edilir."
            ),
        ],
        demo: { _ in AnyView(ConcurrencyTopicDemo()) }
    )
}

/// Konunun demosu: Laboratuvar deneyleri + her deneyin mülakattaki karşılığı.
///
/// Deneyler `ConcurrencyLabForm`'dan geliyor (Laboratuvar sekmesiyle aynı kod, ayrı durum). Bu view yalnızca
/// formun en üstüne bir "hangi deney neyi gösterir?" özeti ekler.
private struct ConcurrencyTopicDemo: View {
    var body: some View {
        ConcurrencyLabForm {
            Section {
                conceptRow(
                    "Sıralı vs Paralel",
                    "`async let` ve `TaskGroup` işleri aynı anda başlatır; toplam süre en yavaş iş kadardır."
                )
                conceptRow(
                    "Paylaşılan Durum",
                    "Korumasız class'ta artışlar kaybolur (data race). Kilit ve actor her seferinde tam sonucu verir."
                )
                conceptRow(
                    "Actor Reentrancy",
                    "Data race olmadan da yanlış sonuç: `await` sırasında araya giren çağrılar (race condition)."
                )
                conceptRow(
                    "İptal",
                    "`cancel()` bir bayrak kaldırır; iş her adımda bayrağa bakıp kendisi durur."
                )
            } header: {
                Text("Bu ekrandaki deneyler")
            } footer: {
                Text("Aynı deneyler Laboratuvar sekmesinde de var: aynı kod, ayrı durum. Data race deneyini Thread Sanitizer açıkken çalıştırırsan (Scheme > Run > Diagnostics) TSan yarışı raporlar.")
            }
        }
    }

    private func conceptRow(_ title: String, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            // `LocalizedStringKey`: Metindeki `async let` gibi ters tırnaklı kısımlar Markdown olarak kod biçiminde çizilir.
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
