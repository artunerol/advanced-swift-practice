import XCTest

/// "Struct vs Class" ekranı (`StructVsClassView`).
///
/// Ekranın üstünde bir bölüm seçici (segmented control) var. Bölüm düğmelerinin kimliği yok; SwiftUI `Picker`
/// onları kendisi oluşturur. Bu yüzden seçicinin KENDİSİNİ kimlikle, içindeki düğmeyi görünen etiketiyle buluruz:
/// `app.segmentedControls["...experimentPicker"].buttons["ARC"]`. Etiketler `Shared/` altındaki sabitlerden gelir.
@MainActor
struct StructVsClassScreen: Screen {
    private typealias ID = AccessibilityID.Fundamentals.StructVsClass

    let app: XCUIApplication

    var rootElement: XCUIElement { experimentPicker }

    var experimentPicker: XCUIElement { app.segmentedControls[ID.experimentPicker] }

    // MARK: Kopyalama deneyi

    var mutateCopyButton: XCUIElement { app.buttons[ID.mutateCopyButton] }
    var structOriginal: XCUIElement { app.staticTexts[ID.structOriginal] }
    var structCopy: XCUIElement { app.staticTexts[ID.structCopy] }
    var structEquality: XCUIElement { app.staticTexts[ID.structEquality] }
    var classOriginal: XCUIElement { app.staticTexts[ID.classOriginal] }
    var classCopy: XCUIElement { app.staticTexts[ID.classCopy] }
    var classIdentity: XCUIElement { app.staticTexts[ID.classIdentity] }

    // MARK: ARC deneyi

    var strongCycleButton: XCUIElement { app.buttons[ID.strongCycleButton] }
    var weakCycleButton: XCUIElement { app.buttons[ID.weakCycleButton] }
    var deinitCount: XCUIElement { app.staticTexts[ID.retainCycleDeinitCount] }
    var verdict: XCUIElement { app.staticTexts[ID.retainCycleVerdict] }

    // MARK: Bellek deneyi
    // Kararların metni: "Aynı adres mi? Evet|Hayır". Adreslerin kendisi her çalıştırmada değişir; onları doğrulamayız.

    /// Ekranın tamamını taşıyan liste; `MemoryLayout` tablosu aşağıda kaldığında kaydırmak için.
    var list: XCUIElement { app.collectionViews[ID.list] }
    var structCopiesVerdict: XCUIElement { app.staticTexts[ID.structCopiesVerdict] }
    var sharedReferenceVerdict: XCUIElement { app.staticTexts[ID.sharedReferenceVerdict] }
    var separateObjectsVerdict: XCUIElement { app.staticTexts[ID.separateObjectsVerdict] }

    /// `MemoryLayout` tablosundaki satırın boyut metni, ör. "size 8 · stride 8". `key`: "struct", "class", "existential"...
    func layoutRow(_ key: String) -> XCUIElement {
        app.staticTexts[ID.layoutRow(key)]
    }

    // MARK: Eylemler

    func mutateCopies() {
        mutateCopyButton.tap()
    }

    /// Bölüm seçicide bir deneyi seçer (ör. `AccessibilityID.Fundamentals.StructVsClass.arcSegment`).
    func selectExperiment(_ segmentLabel: String) {
        experimentPicker.buttons[segmentLabel].tap()
    }

    /// `MemoryLayout` tablosundaki satırı görünür hale getirir (liste tembel olduğu için alttaki satırlar
    /// kaydırılmadan ağaçta yoktur) ve döndürür.
    @discardableResult
    func revealLayoutRow(_ key: String) -> XCUIElement {
        let row = layoutRow(key)
        list.scrollUp(toReveal: row)
        return row
    }
}
