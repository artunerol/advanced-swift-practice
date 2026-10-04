import SwiftUI

// Sahibi: memory-delegate. Demo: Demos/Memory/ (UIKit sızıntı laboratuvarı). Ders: docs/12-arc-ve-delegate.md
extension InterviewTopic {
    static let arcRetainCycle = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.arcRetainCycle,
        section: .swift,
        question: "ARC nasıl çalışır? Retain cycle nedir, nasıl kırılır?",
        shortAnswer: [
            "ARC class örneklerinin (closure bağlamları ve actor'ler dahil) güçlü referanslarını sayar; retain/release çağrılarını derleyici ekler. Sayaç 0 olduğu anda deinit senkron çalışır ve nesne yok edilir; arka planda dolaşan bir çöp toplayıcı (GC) yoktur. Dikkat: Derleyici son referansı süslü parantezde değil son kullanımda bırakabilir; deinit'in tam zamanına mantık bağlamam.",
            "Retain cycle: nesneler birbirini güçlü tutar, ör. VC → closure → VC. Dışarıdan kimse ulaşamasa da sayaç 0'a inmez; deinit çalışmaz, bellek sızar. ARC döngüyü kendisi bulamaz.",
            "Kırmak için geri dönen oku zayıflatırım. weak sayacı artırmaz, nesne ölünce otomatik nil olur, bu yüzden Optional'dır. unowned da artırmaz ama nil olmaz; ölmüş nesneye erişim çöker, sadece ömür garantiliyse kullanırım.",
            "UIKit'teki tipik kaynaklar: saklanan closure'da self, strong delegate, Timer'ın target'ı, NotificationCenter block observer'ı ve hiç bitmeyen Task. Çözüm: [weak self], weak delegate ve invalidate / removeObserver / cancel'ı deinit'e değil viewDidDisappear'a koymak.",
            "Bulmak için deinit'e log koyarım, Xcode'un Debug Memory Graph'ına ve Instruments'ın Leaks/Allocations araçlarına bakarım; testte weak referansla nesnenin serbest kaldığını doğrularım.",
        ],
        followUps: [
            FollowUp(
                question: "weak, unowned ve unowned(unsafe) arasındaki fark ne?",
                answer: "Üçü de sayacı artırmaz. weak Optional'dır, nesne ölünce otomatik nil olur (zeroing); Swift 6.2'ye kadar yalnızca var olabiliyordu, artık weak let de var. unowned nil olmaz (Optional olmak zorunda da değil); ölmüş nesneye erişim kontrollü bir çökmedir (nesne deinit olur ama unowned referanslar bitene kadar belleği tamamen bırakılmaz, çalışma zamanı ölü olduğunu bu yüzden anlayabilir). unowned(unsafe) hiç kontrol yapmaz; erişim tanımsız davranıştır. Karşı taraf senden önce ölebiliyorsa weak, en az senin kadar yaşayacağı kesinse unowned."
            ),
            FollowUp(
                question: "[weak self], [self] ve [x] yakalama listeleri arasındaki fark ne?",
                answer: "[weak self] self'i zayıf yakalar; closure içinde Optional'dır. [self] self'i açıkça güçlü yakalar: davranış örtük yakalamayla aynıdır, sadece niyeti gösterir ve gövdede self. yazmayı gereksiz kılar. [x], x'in closure oluşturulduğu andaki değerini yakalar: değer tipiyse kopyası, class ise o nesneye güçlü referans. Sonradan dıştaki x değişse closure eski değeri görür; yakalama listesi olmadan closure değişkenin güncel değerini görür."
            ),
            FollowUp(
                question: "Her closure'da [weak self] gerekir mi?",
                answer: "Hayır. Döngü ancak closure, self'in doğrudan ya da dolaylı tuttuğu bir yerde saklanırsa oluşur. Kaçmayan (non-escaping) closure'lar (map, filter, sorted) fonksiyon bitince yok olur, döngü kuramaz. Tek seferlik kaçan closure'lar (bir completion handler, UIView.animate) self'in ömrünü yalnızca iş bitene kadar uzatır. Saklanan closure'larda (onUpdate, UIAction, cell provider) ve uzun ya da sonsuz Task'larda gerekir."
            ),
            FollowUp(
                question: "SwiftUI'da retain cycle olur mu?",
                answer: "View'lar struct olduğu için view'un kendisi döngü kuramaz; struct'a weak referans bile alınamaz. Ama @Observable ya da ObservableObject view model'ler class'tır: kendi sakladığı bir closure'da, bir Combine sink'inde ya da bitmeyen bir Task'ta self'i güçlü tutarlarsa sızarlar. .task modifier'ı view kaybolunca task'ı kendisi iptal ettiği için elle Task { } açmaya tercih edilir."
            ),
            FollowUp(
                question: "Struct'lar ARC'ye tabi mi?",
                answer: "Struct'ın kendisi referans sayılmaz ve deinit'i yoktur (kopyalanamayan ~Copyable tipler hariç). Ama içindeki class referansları ve Array/String gibi tiplerin heap'teki depoları sayılır; bir struct'ı kopyalamak, içindeki her referans için bir retain demektir."
            ),
        ],
        pitfalls: [
            "Temizliği deinit'e koymak: timer.invalidate(), removeObserver(token) ya da task.cancel() deinit'teyse ve o kaynak self'i güçlü tutuyorsa deinit hiç gelmez. Durdurmayı viewDidDisappear'a ya da açık bir stop() metoduna koy.",
            "Task içinde guard let self'i döngüden ÖNCE yazmak: self döngü boyunca güçlü kalır, [weak self] boşa gider. Açmayı her turun içinde yap ve task'ı iptal et.",
            "[weak self] yazınca işin bittiğini sanmak: VC kurtulur ama sonsuz Timer, Task ya da gözlemci boşuna çalışmaya devam eder. invalidate / cancel / removeObserver yine şart.",
            "Ömrü garanti olmayan bir referansı unowned yapmak: nesne öldükten sonraki ilk erişim çöker. Emin değilsen weak.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/Memory/LeakVictimViewController.swift",
                symbol: "LeakVictimViewController.startTickTask()",
                note: "Sızdıran sürümde Task self'i güçlü yakalar ve hiç bitmez; deinit'teki cancel() bu yüzden hiç çalışmaz. Düzeltilmişte [weak self] + viewDidDisappear'da cancel."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/Memory/LeakVictimViewController.swift",
                symbol: "LeakVictimViewController.startTimer()",
                note: "İki sürümde kurulum aynı, fark durdurmada: RunLoop → Timer → target zinciri ancak invalidate() ile kopar."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/Memory/DeallocationProbe.swift",
                symbol: "DeallocationProbe.waitForRelease(timeout:)",
                note: "Sızıntıyı ölçmenin yolu: weak referans tut, son güçlü referansı bırak, nil olmasını bekle. weak sayacı artırmadığı için ölçüm sonucu bozmaz."
            ),
            CodePointer(
                file: "BookShelf/Features/Fundamentals/StructVsClass/RetainCycleDemo.swift",
                symbol: "LibraryCard",
                note: "strong, weak ve unowned geri referans yan yana; unowned'ın neden ancak ömür garantisiyle güvenli olduğu."
            ),
            CodePointer(
                file: "BookShelf/Features/Favorites/FavoritesViewController.swift",
                symbol: "FavoritesViewController.startObservingFavorites()",
                note: "Gerçek ekranda doğru kalıp: [weak self], guard let self döngünün İÇİNDE, task viewDidDisappear'da iptal, deinit'te güvenlik ağı."
            ),
            CodePointer(
                file: "BookShelfTests/MemoryDelegate/MemoryLabVictimTests.swift",
                symbol: "MemoryLabVictimTests",
                note: "Her sızıntının testte yakalanışı: weak referans + kısa bekleme; sızanlar testin sonunda breakRetainCycles() ile temizlenir."
            ),
        ],
        demo: { _ in AnyView(MemoryLeakLabView()) }
    )
}
