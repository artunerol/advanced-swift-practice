import Foundation

// Sahibi: Mülakat → "ARC ve retain cycle" (sızıntı laboratuvarı) ve "Delegate" (sahiplik) demoları.
// Uygulama ve UI testleri aynı sabitleri kullanır; görünen metinlerin bir kısmı da (sonuç etiketleri gibi)
// burada durur ki test ile ekran aynı cümleyi beklesin.
extension AccessibilityID {

    /// Sızıntı laboratuvarı (`MemoryLeakLabViewController`, UIKit).
    ///
    /// Akış: Üstteki seçiciden senaryo seçilir → "Sızdıranı aç" / "Düzeltilmişi aç" bir kurban ekranı açar →
    /// kurbandaki "Kapat" ekranı kapatır → laboratuvar nesnenin bellekten silinip silinmediğini `verdictLabel`'a yazar.
    enum MemoryLab {
        /// Senaryo seçici (UIKit `UISegmentedControl`). Bölümler görünen etiketleriyle seçilir:
        /// `app.segmentedControls[MemoryLab.scenarioPicker].buttons[MemoryLab.taskSegment].tap()`
        static let scenarioPicker = "memoryLab.scenarioPicker"
        static let closureSegment = "Closure"
        static let timerSegment = "Timer"
        static let delegateSegment = "Delegate"
        static let notificationSegment = "Bildirim"
        static let taskSegment = "Task"

        static let openLeakingButton = "memoryLab.openLeaking"
        static let openFixedButton = "memoryLab.openFixed"

        /// Son ölçümün sonucu. Metni aşağıdaki `verdict...` sabitlerinden biridir.
        static let verdictLabel = "memoryLab.verdict"
        /// Sonucun açıklaması, ör. "Closure · sızdıran sürüm: deinit çalışmadı. ..."
        static let verdictDetailLabel = "memoryLab.verdictDetail"
        /// "Bellekte kalan kurban: 2" (bkz. `leakCountText(_:)`).
        static let leakCountLabel = "memoryLab.leakCount"
        static let cleanUpButton = "memoryLab.cleanUp"

        static let verdictIdle = "Henüz ölçüm yok"
        static let verdictMeasuring = "Ölçülüyor…"
        static let verdictReleased = "Serbest bırakıldı ✓"
        static let verdictLeaked = "SIZINTI: hâlâ bellekte ✗"

        static func leakCountText(_ count: Int) -> String {
            "Bellekte kalan kurban: \(count)"
        }

        /// Laboratuvarın açtığı "kurban" ekranı (`LeakVictimViewController`).
        enum Victim {
            static let root = "memoryLab.victim.root"
            static let closeButton = "memoryLab.victim.close"
            /// Closure / delegate / bildirim senaryolarında callback'i elle tetikler. Timer ve Task kendiliğinden tetikler.
            static let triggerButton = "memoryLab.victim.trigger"
            /// "Callback sayısı: 3"
            static let callbackCountLabel = "memoryLab.victim.callbackCount"
        }
    }

    /// Delegate demosu (`DelegationDemoView`): canlı UIKit kontrolü, sahiplik şeması ve "hangisini seçmeli?" tablosu.
    enum Delegation {
        /// SwiftUI segmented `Picker`; bölümler görünen etiketleriyle seçilir.
        static let panePicker = "delegation.panePicker"
        static let liveSegment = "Canlı"
        static let ownershipSegment = "Sahiplik"
        static let choiceSegment = "Hangisi?"

        // MARK: Canlı demo (BookRatingViewController + StarRatingControl)

        static let ratingControl = "delegation.ratingControl"
        /// `n`. yıldızın düğmesi (1...5).
        static func starButton(_ number: Int) -> String { "delegation.star.\(number)" }
        /// Metin biçimleri: "Delegate: 4/5", "Closure: 4/5", "Target-action: 4/5"; henüz olay yoksa "...: —".
        static let delegateLabel = "delegation.delegateLabel"
        static let closureLabel = "delegation.closureLabel"
        static let targetActionLabel = "delegation.targetActionLabel"
        /// Açıkken delegate `shouldChangeRatingTo` sorusuna `false` döner ve değişiklik reddedilir.
        static let lockSwitch = "delegation.lockSwitch"
        /// Son olayın açıklaması (ör. reddedilen değişiklik).
        static let statusLabel = "delegation.status"

        // MARK: Sahiplik

        static let diagram = "delegation.diagram"
        static let ownershipList = "delegation.ownershipList"
        static let lifetimeExperimentButton = "delegation.lifetimeExperiment"
        /// Deney bitince: "Sahip serbest bırakıldı: Evet · control.delegate: nil"
        static let lifetimeResultLabel = "delegation.lifetimeResult"

        // MARK: Hangisi?

        static let choiceList = "delegation.choiceList"
    }
}
