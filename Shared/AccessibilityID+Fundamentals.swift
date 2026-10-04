import Foundation

// Sahibi: Swift temelleri demoları (struct vs class, protocol'ler, protocol quiz'i, typealias).
// Bu ekranlar Mülakat merkezindeki konu ekranlarının "Demo" bölümünde gösterilir.
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
            /// Ekranın tamamını taşıyan `List` (XCUITest'te `collectionViews`). Aşağıdaki satırlara kaydırmak için.
            static let list = "fundamentals.structVsClass.list"
            /// Bölüm etiketleri (kimlik değil, görünen metin). Uygulama da aynı sabitleri kullanır.
            static let copyingSegment = "Kopyalama"
            static let copyOnWriteSegment = "CoW"
            static let arcSegment = "ARC"
            static let memorySegment = "Bellek"

            /// Gezinme çubuğundaki "Sıfırla" düğmesi: deneyleri başlangıç durumuna döndürür.
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

            // MARK: Bellek deneyi (MemoryLayout + adresler)
            // Adres kararlarının metin biçimi: "Aynı adres mi? Evet|Hayır".
            // Adreslerin kendisi her çalıştırmada değişir; testler yalnızca kararları doğrular.

            /// `MemoryLayout` tablosundaki bir satırın boyut metni, ör. "size 8 · stride 8".
            /// `key`, `MemoryLayoutDemo.Row.id` değeridir (ör. "struct", "class", "existential").
            static func layoutRow(_ key: String) -> String { "fundamentals.structVsClass.layout.\(key)" }
            /// İki struct kopyası (`var copy = original`): adresleri farklı olmalı.
            static let structCopiesVerdict = "fundamentals.structVsClass.structCopiesVerdict"
            /// Aynı nesneyi gösteren iki class referansı: adres aynı olmalı.
            static let sharedReferenceVerdict = "fundamentals.structVsClass.sharedReferenceVerdict"
            /// İçeriği aynı iki ayrı class nesnesi: adresleri farklı olmalı.
            static let separateObjectsVerdict = "fundamentals.structVsClass.separateObjectsVerdict"
            /// Adresleri yeniden ölçen düğme.
            static let remeasureButton = "fundamentals.structVsClass.remeasure"
        }

        /// "Protocol + extension" demosu (`ProtocolExtensionDemoView`). Üstte üç bölüm: Dispatch / Varsayılan / Koşullu.
        enum ProtocolExtension {
            static let sectionPicker = "fundamentals.protocolExtension.sectionPicker"
            static let dispatchSegment = "Dispatch"
            static let defaultsSegment = "Varsayılan"
            static let constrainedSegment = "Koşullu"

            // MARK: Dispatch
            /// Değişkenin derleme anındaki tipini seçen ikinci seçici. Etiketler `DispatchViewpoint.label`'dan gelir.
            static let viewpointPicker = "fundamentals.protocolExtension.viewpointPicker"
            /// Seçilen bakış açısının kod satırı, ör. "let item: any ReadingItem = magazine".
            static let viewpointDeclaration = "fundamentals.protocolExtension.viewpointDeclaration"
            /// "symbolName (gereksinim): newspaper"
            static let requirementResult = "fundamentals.protocolExtension.requirementResult"
            /// "shelfSection (yalnız extension): Süreli yayınlar" | "... Genel raf"
            static let extensionOnlyResult = "fundamentals.protocolExtension.extensionOnlyResult"

            // MARK: Varsayılan
            /// Bir tipin özet satırı; `typeName` "Novel", "Magazine", "AudioBook" ya da "Book".
            static func conformanceRow(_ typeName: String) -> String { "fundamentals.protocolExtension.row.\(typeName)" }

            // MARK: Koşullu
            /// "[Novel] → toplam 852 sayfa"
            static let novelPagesResult = "fundamentals.protocolExtension.novelPages"
            /// "Raftaki ilk roman (sıralı): Aylak Adam"
            static let sortedShelfResult = "fundamentals.protocolExtension.sortedShelf"
        }

        /// Protocol'ler ekranı (`ProtocolsView`): `[any ReadingItem]` listesi ve `associatedtype`'lı raf.
        /// "Protocol as a type" quiz'inin altındaki bağlantıyla açılır. Üstte bir bölüm seçici var (Liste / Raf).
        enum Protocols {
            static let experimentPicker = "fundamentals.protocols.experimentPicker"
            static let listSegment = "Liste"
            static let shelfSegment = "Raf"

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
        }

        /// "Olur mu, olmaz mı?" quiz'i (`SwiftQuizView`): protocol'ün tip olarak kullanımı.
        enum ProtocolQuiz {
            /// "Skor: 3/4" (doğru / cevaplanan)
            static let score = "fundamentals.quiz.score"
            /// "Soru 4/16"
            static let progress = "fundamentals.quiz.progress"
            static let snippetTitle = "fundamentals.quiz.title"
            static let code = "fundamentals.quiz.code"
            /// Örnek özel bir derleyici ayarıyla derleniyorsa gösterilir, ör. "-enable-upcoming-feature ExistentialAny".
            static let compilerFlags = "fundamentals.quiz.flags"

            /// Cevap düğmeleri. Cevaplandıktan sonra devre dışı kalırlar.
            static let compilesButton = "fundamentals.quiz.answer.compiles"
            static let failsButton = "fundamentals.quiz.answer.fails"
            static let previousButton = "fundamentals.quiz.previous"
            static let nextButton = "fundamentals.quiz.next"
            static let restartButton = "fundamentals.quiz.restart"

            // Cevap verildikten sonra görünenler.
            /// "Doğru ✓" | "Yanlış ✗"
            static let verdict = "fundamentals.quiz.verdict"
            /// "Derlenir" | "Derlenir, ama uyarı verir" | "Derlenmez"
            static let correctAnswer = "fundamentals.quiz.correctAnswer"
            /// Derleyicinin birebir mesajı, ör. "error: binary operator '==' cannot be applied ..."
            static let compilerMessage = "fundamentals.quiz.compilerMessage"
            static let explanation = "fundamentals.quiz.explanation"

            /// Örnekler paketten (bundle) okunamazsa gösterilen hata metni.
            static let loadError = "fundamentals.quiz.loadError"
            /// Quiz'in altındaki "Çalışan örnek: Liste ve Raf" bağlantısı (`ProtocolsView`'u açar).
            static let liveExampleLink = "fundamentals.quiz.liveExample"
        }

        /// typealias demosu (`TypealiasDemoView`).
        enum Typealias {
            static let list = "fundamentals.typealias.list"
            /// "BookID aslında: Int"
            static let bookIDUnderlyingType = "fundamentals.typealias.bookIDUnderlying"
            /// "BookID ile MemberID aynı tip mi? Evet"
            static let aliasesAreSameType = "fundamentals.typealias.aliasesSameType"
            /// "LibraryCardNumber ile Int aynı tip mi? Hayır"
            static let wrapperIsDistinctType = "fundamentals.typealias.wrapperDistinct"
            /// "BookMap<String> aslında: Dictionary<Int, String>"
            static let genericAliasType = "fundamentals.typealias.genericAlias"
            /// "ClassicsShelf.Item: Novel"
            static let associatedTypeResult = "fundamentals.typealias.associatedType"
            /// "Snapshot aslında: NSDiffableDataSourceSnapshot<Section, Book>"
            static let snapshotType = "fundamentals.typealias.snapshot"
            /// Kitap süzgeci (closure tipi) seçicisi ve sonucu.
            static let filterPicker = "fundamentals.typealias.filterPicker"
            static let filterResult = "fundamentals.typealias.filterResult"
        }
    }
}
