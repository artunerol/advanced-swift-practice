import Foundation

// Sahibi: UIKit laboratuvarları (Mülakat → UIKit bölümündeki dört demo). Uygulama ve UI testleri aynı sabitleri kullanır.
//
// Hepsi UIKit ile yazıldı; kimlikler `accessibilityIdentifier` özelliğiyle verilir. XCUITest açısından SwiftUI'dan farkı yok:
// `UITableView` → `app.tables`, `UICollectionView` → `app.collectionViews`, `UITextView` → `app.textViews`,
// `UISlider` → `app.sliders`, `UISegmentedControl` → `app.segmentedControls`.
extension AccessibilityID {
    enum UIKitLabs {
        /// View controller yaşam döngüsü laboratuvarı.
        enum Lifecycle {
            /// Günlüğü gösteren `UITextView`. XCUITest'te metnin TAMAMI `value` olarak okunur; kaydırmaya gerek yok.
            /// Satır biçimi: "12. +452 ms  Ana · viewDidLoad"
            static let log = "uikitLabs.lifecycle.log"
            static let clearButton = "uikitLabs.lifecycle.clear"

            // "Ana" ekrandaki düğmeler.
            static let presentPageSheetButton = "uikitLabs.lifecycle.presentPageSheet"
            static let presentFullScreenButton = "uikitLabs.lifecycle.presentFullScreen"
            static let pushButton = "uikitLabs.lifecycle.push"
            static let toggleChildButton = "uikitLabs.lifecycle.toggleChild"
            static let relayoutButton = "uikitLabs.lifecycle.relayout"

            /// Sunulan/push edilen ekrandaki "Kapat" ya da "Geri dön" düğmesi.
            static let closeButton = "uikitLabs.lifecycle.close"

            /// Günlükte görünen ekran adları. Testler "Ana · viewDidLoad" gibi satırları bu adlarla arar.
            static let presenterName = "Ana"
            static let pageSheetName = "PageSheet"
            static let fullScreenName = "FullScreen"
            static let pushedName = "Push"
            static let childName = "Child"
        }

        /// Dinamik yükseklikli (self-sizing) hücreler.
        enum DynamicCells {
            static let table = "uikitLabs.dynamicCells.table"
            static func bookCell(_ bookID: Int) -> String { "uikitLabs.dynamicCells.book.\(bookID)" }
            /// Yazar satırı (başlık benzeri ikinci hücre tipi). `index` 0'dan başlar, ekrandaki sırayı izler.
            static func authorCell(_ index: Int) -> String { "uikitLabs.dynamicCells.author.\(index)" }
            /// Kitap hücresinin `accessibilityValue`'su: özet açık mı kapalı mı?
            static let expandedValue = "Açık"
            static let collapsedValue = "Kapalı"
        }

        /// frame vs bounds laboratuvarı.
        enum FrameBounds {
            static let rotationSlider = "uikitLabs.frameBounds.rotation"
            static let scaleSlider = "uikitLabs.frameBounds.scale"
            static let originSlider = "uikitLabs.frameBounds.containerOrigin"
            static let resetButton = "uikitLabs.frameBounds.reset"

            /// Canlı değer etiketleri. Biçim: "child.frame  x 60 · y 70 · w 120 · h 80"
            static let childFrameLabel = "uikitLabs.frameBounds.childFrame"
            static let childBoundsLabel = "uikitLabs.frameBounds.childBounds"
            static let childCenterLabel = "uikitLabs.frameBounds.childCenter"
            static let containerBoundsLabel = "uikitLabs.frameBounds.containerBounds"
            static let convertedLabel = "uikitLabs.frameBounds.converted"
            /// Sayfanın kendi scroll view'ı: "contentOffset.y = 0 · bounds.origin.y = 0"
            static let scrollInfoLabel = "uikitLabs.frameBounds.scrollInfo"
        }

        /// UITableView vs UICollectionView laboratuvarı.
        enum TableVsCollection {
            /// Üstteki mod seçici. Bölümler görünen etiketleriyle seçilir:
            /// `app.segmentedControls[modePicker].buttons[TableVsCollection.listSegment].tap()`
            static let modePicker = "uikitLabs.tableVsCollection.mode"
            static let tableSegment = "Tablo"
            static let listSegment = "Liste"
            static let gridSegment = "Izgara"
            /// Seçili modun hangi API ile yapıldığını anlatan açıklama.
            static let caption = "uikitLabs.tableVsCollection.caption"

            static let table = "uikitLabs.tableVsCollection.table"
            static let listCollection = "uikitLabs.tableVsCollection.list"
            static let gridCollection = "uikitLabs.tableVsCollection.grid"

            static func tableCell(_ bookID: Int) -> String { "uikitLabs.tableVsCollection.tableCell.\(bookID)" }
            static func listCell(_ bookID: Int) -> String { "uikitLabs.tableVsCollection.listCell.\(bookID)" }
            /// Izgarada aynı kitap iki bölümde (öne çıkanlar + tümü) görünebilir; kimlik bölümü de içerir.
            static func featuredCell(_ bookID: Int) -> String { "uikitLabs.tableVsCollection.featuredCell.\(bookID)" }
            static func gridCell(_ bookID: Int) -> String { "uikitLabs.tableVsCollection.gridCell.\(bookID)" }
        }
    }
}
