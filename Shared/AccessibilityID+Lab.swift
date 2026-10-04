import Foundation

// Sahibi: Laboratuvar sekmesi (Concurrency). Yeni kimlik gerekirse buraya ekle.
extension AccessibilityID {
    enum Lab {
        /// Ekranın `Form`'u. Tür: collectionView. `Form` tembeldir (lazy): alttaki bölümler ekrana gelene kadar
        /// erişilebilirlik ağacında yoktur; UI testleri kaydırmayı bu kaba uygular.
        static let form = "lab.form"

        // Sıralı vs Paralel
        static let runSequentialButton = "lab.runSequential"
        static let runAsyncLetButton = "lab.runAsyncLet"
        static let runTaskGroupButton = "lab.runTaskGroup"
        /// Metin: "Sıralı: 1,20 sn" (çalışmadan önce "Sıralı: —").
        static let sequentialResult = "lab.sequentialResult"
        /// Metin: "async let: 0,50 sn".
        static let asyncLetResult = "lab.asyncLetResult"
        /// Metin: "TaskGroup: 0,50 sn".
        static let taskGroupResult = "lab.taskGroupResult"
        /// Metin: "Geliş sırası: İş 2 → İş 3 → İş 1 · Sıraya dizildi: 1, 2, 3".
        static let taskGroupArrivalOrder = "lab.taskGroupArrivalOrder"

        // Paylaşılan durum: data race vs kilit vs actor
        static let runCountersButton = "lab.runCounters"
        /// Metin: "Kilitsiz class: 912 / 1000 (88 artış kayboldu)" — değer her çalıştırmada değişebilir.
        static let unsafeCounterResult = "lab.unsafeCounterResult"
        /// Metin: "Kilitli class: 1000 / 1000".
        static let lockedCounterResult = "lab.lockedCounterResult"
        /// Metin: "Actor: 1000 / 1000".
        static let actorCounterResult = "lab.actorCounterResult"

        // Actor reentrancy
        static let runReentrancyButton = "lab.runReentrancy"
        /// Metin: "Arada await var: 131 / 1000 (869 artış kayboldu)" — değer her çalıştırmada değişebilir.
        static let reentrancyResult = "lab.reentrancyResult"
        /// Metin: "Arada await yok: 1000 / 1000".
        static let reentrancyFixedResult = "lab.reentrancyFixedResult"

        // İptal
        static let startLongTaskButton = "lab.startLongTask"
        static let cancelLongTaskButton = "lab.cancelLongTask"
        /// Metin: "Hazır: 20 adım" → "Çalışıyor: 7 / 20" → "Tamamlandı: 20 / 20" ya da "İptal edildi: 7 / 20 adımda durdu".
        /// `-ui-testing` ile adım sayısı 40'tır (`ConcurrencyLab.Settings.uiTesting`): "Hazır: 40 adım".
        static let longTaskStatus = "lab.longTaskStatus"
        static let longTaskProgress = "lab.longTaskProgress"
    }
}
