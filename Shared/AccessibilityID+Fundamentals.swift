import Foundation

// Sahibi: Swift temelleri demoları (struct vs class, protocol'ler). Mülakat merkezinin konu ekranlarında gösterilir.
extension AccessibilityID {
    enum Fundamentals {
        /// "Struct vs Class" ekranı.
        ///
        /// Ekranın üstünde bir bölüm seçici (segmented control) var; her deney ayrı bir bölümde gösterilir.
        /// Böylece bir deneyin tüm öğeleri aynı anda ekranda olur ve UI testinin kaydırma yapması gerekmez.
        /// Bölümler **görünen etiketleriyle** seçilir:
        /// `app.segmentedControls[StructVsClass.experimentPicker].buttons[StructVsClass.arcSegment].tap()`
        enum StructVsClass {
            static let experimentPicker = "fundamentals.structVsClass.experimentPicker"
            /// Bölüm etiketleri (kimlik değil, görünen metin). Uygulama da aynı sabitleri kullanır.
            static let copyingSegment = "Kopyalama"
            static let copyOnWriteSegment = "CoW"
            static let arcSegment = "ARC"

            /// Gezinme çubuğundaki "Sıfırla" düğmesi: üç deneyi de başlangıç durumuna döndürür.
            static let resetButton = "fundamentals.structVsClass.reset"

            // MARK: Kopyalama deneyi
            // Metin biçimleri: "Orijinal: 10. sayfa", "Kopya: 20. sayfa",
            // "Eşit mi (==)? Evet|Hayır", "Aynı nesne mi (===)? Evet|Hayır"

            static let structOriginal = "fundamentals.structVsClass.structOriginal"
            static let structCopy = "fundamentals.structVsClass.structCopy"
            static let structEquality = "fundamentals.structVsClass.structEquality"
            static let classOriginal = "fundamentals.structVsClass.classOriginal"
            static let classCopy = "fundamentals.structVsClass.classCopy"
            static let classIdentity = "fundamentals.structVsClass.classIdentity"
            /// Her dokunuşta iki kopyayı da 10 sayfa ilerletir.
            static let mutateCopyButton = "fundamentals.structVsClass.mutateCopy"

            // MARK: Copy-on-write deneyi
            // Metin biçimleri: "Orijinal: [10]", "Kopya: [10, 20]", "Depo ortak mı? Evet|Hayır"

            static let cowOriginal = "fundamentals.structVsClass.cowOriginal"
            static let cowCopy = "fundamentals.structVsClass.cowCopy"
            static let cowSharedStorage = "fundamentals.structVsClass.cowSharedStorage"
            static let cowAppendButton = "fundamentals.structVsClass.cowAppend"

            // MARK: ARC / retain cycle deneyi
            // Metin biçimleri: "Serbest bırakılan: 0/2", "Sızıntı var" | "Sızıntı yok"
            // Günlük (log) tek bir çok satırlı metindir; her satır "1. ..." biçiminde numaralıdır.

            static let strongCycleButton = "fundamentals.structVsClass.strongCycle"
            static let weakCycleButton = "fundamentals.structVsClass.weakCycle"
            static let unownedCycleButton = "fundamentals.structVsClass.unownedCycle"
            static let retainCycleDeinitCount = "fundamentals.structVsClass.deinitCount"
            static let retainCycleVerdict = "fundamentals.structVsClass.verdict"
            static let retainCycleLog = "fundamentals.structVsClass.log"
        }

        /// "Protocol'ler" ekranı. Bu ekranda da üstte bir bölüm seçici var (Liste / Raf / Dispatch).
        enum Protocols {
            static let experimentPicker = "fundamentals.protocols.experimentPicker"
            static let listSegment = "Liste"
            static let shelfSegment = "Raf"
            static let dispatchSegment = "Dispatch"

            // MARK: Karışık liste ([any ReadingItem])

            /// Sıralama seçici (segmented). Seçenekler görünen etiketleriyle seçilir:
            /// `app.segmentedControls[Protocols.sortPicker].buttons[Protocols.sortByDurationLabel].tap()`
            static let sortPicker = "fundamentals.protocols.sortPicker"
            static let sortByTitleLabel = "Başlık"
            static let sortByDurationLabel = "Süre"
            /// Sıralanmış listedeki `index`. satırın başlığı (0'dan başlar). Sıralamayı doğrulamak için idealdir.
            static func rowTitle(index: Int) -> String { "fundamentals.protocols.rowTitle.\(index)" }
            /// Aynı satırın süre metni, ör. "4 sa 48 dk".
            static func rowDuration(index: Int) -> String { "fundamentals.protocols.rowDuration.\(index)" }
            /// "Toplam: 23 sa 36 dk"
            static let mixedTotal = "fundamentals.protocols.mixedTotal"

            // MARK: Raf (associatedtype + generic)

            static let shelfAddButton = "fundamentals.protocols.shelfAdd"
            /// "Raftaki roman: 2"
            static let shelfCount = "fundamentals.protocols.shelfCount"
            /// "Raf toplamı: 10 sa 48 dk"
            static let shelfTotal = "fundamentals.protocols.shelfTotal"
            /// "Eklendi: ..." veya "Zaten rafta, eklenmedi: ..."
            static let shelfMessage = "fundamentals.protocols.shelfMessage"
            /// Raftaki romanlar başlığa göre (Comparable) sıralı gösterilir.
            static func shelfRowTitle(index: Int) -> String { "fundamentals.protocols.shelfRowTitle.\(index)" }

            // MARK: Dispatch

            static let dispatchConcrete = "fundamentals.protocols.dispatchConcrete"
            static let dispatchExistential = "fundamentals.protocols.dispatchExistential"
            static let dispatchGeneric = "fundamentals.protocols.dispatchGeneric"
            static let dispatchRequirement = "fundamentals.protocols.dispatchRequirement"
        }
    }
}
