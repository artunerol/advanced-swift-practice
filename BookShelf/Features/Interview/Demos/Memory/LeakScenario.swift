import Foundation

/// Sızıntı laboratuvarındaki beş klasik UIKit sızıntısı. Her birinin bir **sızdıran** ve bir **düzeltilmiş** sürümü var.
///
/// Bu dosya yalnızca ekranda gösterilen metinleri tutar (değer tipleri, `Sendable`). Asıl davranış
/// `LeakVictimViewController.swift` içinde (`installUpdateClosure()`, `startTimer()`, `installReporter()`,
/// `startObservingPings()`, `startTickTask()`); buradaki kod parçaları oradaki gerçek kodun kısaltılmış halidir.
enum LeakScenario: String, CaseIterable, Sendable {
    case closure
    case timer
    case delegate
    case notification
    case task

    /// Seçicideki kısa etiket. UI testleri aynı sabitle seçer.
    var segmentTitle: String {
        switch self {
        case .closure: AccessibilityID.MemoryLab.closureSegment
        case .timer: AccessibilityID.MemoryLab.timerSegment
        case .delegate: AccessibilityID.MemoryLab.delegateSegment
        case .notification: AccessibilityID.MemoryLab.notificationSegment
        case .task: AccessibilityID.MemoryLab.taskSegment
        }
    }

    var title: String {
        switch self {
        case .closure: "Saklanan closure"
        case .timer: "Timer'ın target'ı"
        case .delegate: "Strong delegate"
        case .notification: "NotificationCenter block observer'ı"
        case .task: "Hiç bitmeyen Task"
        }
    }

    /// Sızdıran sürümde nesneyi hayatta tutan referans zinciri. "→" = güçlü (strong) referans.
    var retainChain: String {
        switch self {
        case .closure: "VC → onUpdate (closure) → VC"
        case .timer: "RunLoop → Timer → target: VC"
        case .delegate: "VC → reporter → delegate: VC"
        case .notification: "NotificationCenter → observer → block → VC"
        case .task: "Çalışan Task → closure → VC"
        }
    }

    /// Timer ve Task kendiliğinden tetiklenir; diğerleri kurban ekranındaki düğmeyle.
    var firesAutomatically: Bool {
        switch self {
        case .timer, .task: true
        case .closure, .delegate, .notification: false
        }
    }

    /// Ekranda gösterilen kısa kod parçası. Satırlar telefonda kaymadan sığsın diye 2 boşluk girinti ve
    /// en fazla ~44 karakter. Gerçek kod `LeakVictimViewController.swift` içinde.
    func code(for variant: LeakVariant) -> String {
        switch (self, variant) {
        case (.closure, .leaking):
            """
            onUpdate = { self.refresh() }
            // VC → closure → VC: döngü
            """
        case (.closure, .fixed):
            """
            onUpdate = { [weak self] in self?.refresh() }
            """
        case (.timer, .leaking):
            """
            timer = Timer.scheduledTimer(
              timeInterval: 1, target: self,
              selector: #selector(tick),
              userInfo: nil, repeats: true)
            // deinit { timer?.invalidate() }
            // ↑ hiç çalışmaz: timer VC'yi tutuyor
            """
        case (.timer, .fixed):
            """
            // viewDidDisappear(_:) içinde:
            timer?.invalidate()  // VC'yi bırakır
            timer = nil
            """
        case (.delegate, .leaking):
            """
            // LeakLabReporter içinde:
            var delegate: LeakLabReporterDelegate?
            // strong (varsayılan) → VC ↔ reporter
            """
        case (.delegate, .fixed):
            """
            // LeakLabReporter içinde:
            weak var delegate: LeakLabReporterDelegate?
            // protokol: AnyObject (weak için şart)
            """
        case (.notification, .leaking):
            """
            token = center.addObserver(
              forName: .leakLabPing, object: nil,
              queue: .main) { _ in
              self.refresh()
            }
            // deinit { center.removeObserver(token) }
            // ↑ hiç çalışmaz: block VC'yi tutuyor
            """
        case (.notification, .fixed):
            """
            token = center.addObserver(
              forName: .leakLabPing, object: nil,
              queue: .main) { [weak self] _ in
              self?.refresh()
            }
            // viewDidDisappear(_:) içinde:
            center.removeObserver(token)
            """
        case (.task, .leaking):
            """
            task = Task {
              while !Task.isCancelled {
                self.refresh()
                try? await Task.sleep(for: .seconds(1))
              }
            }
            // deinit { task?.cancel() }
            // ↑ hiç çalışmaz: Task VC'yi tutuyor
            """
        case (.task, .fixed):
            """
            task = Task { [weak self] in
              while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(1))
              }
            }
            // viewDidDisappear(_:) içinde:
            task?.cancel()
            """
        }
    }

    /// Düzeltmenin neden işe yaradığı. Tek paragraf; laboratuvar ekranının altında gösterilir.
    var lesson: String {
        switch self {
        case .closure:
            "VC closure'ı saklıyor, closure da self'i güçlü yakalıyor: iki ok birbirine dönüyor. [weak self] geri oku zayıflatır; closure çağrıldığında VC yoksa self nil olur ve hiçbir şey yapılmaz."
        case .timer:
            "RunLoop zamanlanmış timer'ı, timer da target'ını invalidate edilene kadar güçlü tutar. Temizlik deinit'te olursa deinit hiç gelmez. Çözüm durdurmayı ekranın yaşam döngüsüne (viewDidDisappear) taşımak. Block tabanlı timer + [weak self] VC'yi kurtarır ama timer'ı durdurmaz; invalidate yine şart."
        case .delegate:
            "Sahip (VC) reporter'ı güçlü tutar; reporter da VC'yi güçlü tutarsa döngü olur. Sahip olunan taraf delegate'ini weak tutar; bu yüzden delegate protokolü AnyObject'e bağlıdır."
        case .notification:
            "Block tabanlı gözlemciyi NotificationCenter, removeObserver çağrılana kadar tutar; block da self'i yakalarsa VC hiç ölmez. [weak self] VC'yi kurtarır, removeObserver da block'u temizler. (Selector tabanlı addObserver(_:selector:...) için iOS 9'dan beri kaldırma zorunlu değildir.)"
        case .task:
            "Task, closure'ını ve yakaladıklarını bitene kadar tutar; sonsuz döngü hiç bitmez. [weak self] VC'nin ölmesine izin verir, cancel() da döngüyü bitirir. İkisi birlikte gerekir: yalnızca weak olursa task boşuna dönmeye devam eder."
        }
    }
}

/// Bir senaryonun hangi sürümü çalıştırılacak?
enum LeakVariant: String, CaseIterable, Sendable {
    case leaking
    case fixed

    var title: String {
        switch self {
        case .leaking: "sızdıran"
        case .fixed: "düzeltilmiş"
        }
    }
}

/// Bir kurban kapatıldıktan sonra yapılan ölçümün sonucu ve ekrandaki metinleri.
struct LeakMeasurement: Equatable, Sendable {
    let scenario: LeakScenario
    let variant: LeakVariant
    /// Kapanıştan sonraki kısa bekleme içinde `deinit` çalıştı mı?
    let released: Bool

    var verdict: String {
        released ? AccessibilityID.MemoryLab.verdictReleased : AccessibilityID.MemoryLab.verdictLeaked
    }

    var detail: String {
        let run = "\(scenario.title) · \(variant.title) sürüm"
        if released {
            return "\(run): deinit çalıştı, nesne bellekten silindi."
        }
        return "\(run): deinit çalışmadı. Tutan zincir: \(scenario.retainChain)"
    }

    /// Sızdıran sürüm sızmalı, düzeltilmiş sürüm serbest kalmalı. `false` ise demoda bir hata var demektir.
    var matchesExpectation: Bool {
        released == (variant == .fixed)
    }
}

extension Notification.Name {
    /// Bildirim senaryosunun kullandığı, yalnızca bu laboratuvara ait bildirim adı.
    static let leakLabPing = Notification.Name("BookShelf.leakLabPing")
}
