import Foundation

// Sahibi: Mimari demoları (Okuma Notları: Clean Architecture + VIPER + MVVM) ve DIP vs DI demosu.
// Mülakat merkezinde "Clean Architecture, VIPER ve MVVM" ile "Dependency Inversion vs Injection" konularında görünür.
//
// Notlar UUID kimlikli olduğu için satırların kimliği yok; UI testleri satırı **görünen metniyle** bulur
// (testte yazdığımız metni zaten biliyoruz): `app.tables[VIPER.table].staticTexts["Benim notum"]`.
extension AccessibilityID {
    enum ReadingNotes {
        // MARK: Demo üst kısmı

        /// "VIPER · UIKit" | "MVVM · SwiftUI" | "Kıyas" seçicisi. Bölümler görünen etiketleriyle seçilir:
        /// `app.segmentedControls[ReadingNotes.presentationPicker].buttons[ReadingNotes.viperSegment].tap()`
        static let presentationPicker = "readingNotes.presentationPicker"
        static let viperSegment = "VIPER · UIKit"
        static let mvvmSegment = "MVVM · SwiftUI"
        static let comparisonSegment = "Kıyas"
        /// Depolama türü seçicisi (menü biçimli `Picker`; XCUITest'te bir `button`).
        static let storagePicker = "readingNotes.storagePicker"
        /// "MVC vs MVVM vs VIPER" karşılaştırma listesi.
        static let comparisonList = "readingNotes.comparisonList"
        /// Satırı sola kaydırınca çıkan "Sil" eyleminin **görünen başlığı** (iki arayüzde de aynı).
        /// UIKit'teki `UIContextualAction` bir view değildir, kimlik alamaz; XCUITest onu etiketiyle bulur:
        /// `cell.swipeLeft(); app.buttons[ReadingNotes.deleteActionTitle].tap()`.
        static let deleteActionTitle = "Sil"

        // MARK: VIPER (UIKit)

        enum VIPER {
            static let table = "readingNotes.viper.table"
            static let addButton = "readingNotes.viper.add"
            /// "2 not · en yeni en üstte"
            static let summary = "readingNotes.viper.summary"
            static let emptyState = "readingNotes.viper.empty"
            static let loadingIndicator = "readingNotes.viper.loading"

            /// Not yazma penceresi (`UIAlertController`): `app.alerts[editorAlert]`.
            /// iOS 26'da alert düğmeleri ağaçta iki kez görünür; düğmelere `.firstMatch` ile dokun.
            static let editorAlert = "readingNotes.viper.editor"
            static let editorTextField = "readingNotes.viper.editor.text"
            static let editorSaveButton = "readingNotes.viper.editor.save"
            static let editorCancelButton = "readingNotes.viper.editor.cancel"

            /// Doğrulama/depolama hatası penceresi. Mesaj, domain'deki `NoteValidationError`'dan gelir.
            static let errorAlert = "readingNotes.viper.error"
            static let errorOKButton = "readingNotes.viper.error.ok"
        }

        // MARK: MVVM (SwiftUI)

        enum MVVM {
            /// SwiftUI `List` → XCUITest'te `collectionViews`.
            static let list = "readingNotes.mvvm.list"
            static let addButton = "readingNotes.mvvm.add"
            static let emptyState = "readingNotes.mvvm.empty"

            /// Not ekleme sayfası (sheet).
            static let editorTextField = "readingNotes.mvvm.editor.text"
            static let editorSaveButton = "readingNotes.mvvm.editor.save"
            static let editorCancelButton = "readingNotes.mvvm.editor.cancel"
            /// "12/280"
            static let editorCharacterCount = "readingNotes.mvvm.editor.count"
            /// Doğrulama hatası (sayfanın içinde, kırmızı metin). VIPER'daki alert ile AYNI mesaj.
            static let editorValidationMessage = "readingNotes.mvvm.editor.validation"
        }

        // MARK: DIP vs DI demosu

        enum DependencyDemo {
            /// Demonun `List`'i (XCUITest'te `collectionViews`). Alttaki bölümlere kaydırmak için.
            static let list = "dependencyDemo.list"
            /// Enjekte edilen depo seçicisi: "Dolu depo" | "Boş depo".
            static let repositoryPicker = "dependencyDemo.repositoryPicker"
            static let filledRepositorySegment = "Dolu depo"
            static let emptyRepositorySegment = "Boş depo"
            /// Sayaç sonuçları, ör. "3 not".
            static let tightlyCoupledCount = "dependencyDemo.tightCount"
            static let concreteInjectedCount = "dependencyDemo.concreteCount"
            static let injectedCount = "dependencyDemo.injectedCount"

            /// Biçimlendirici stratejisi seçicisi: "Tarih" | "Uzunluk".
            static let formatterPicker = "dependencyDemo.formatterPicker"
            static let dateFormatterSegment = "Tarih"
            static let lengthFormatterSegment = "Uzunluk"
            /// Seçilen stratejiyle üretilen dışa aktarma metni (çok satırlı tek bir `Text`).
            static let formatterOutput = "dependencyDemo.formatterOutput"
        }
    }
}
