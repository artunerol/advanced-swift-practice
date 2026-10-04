import XCTest

/// Kalıcılık demosu (`PersistenceDemoView`): üstte bölüm seçici (Ayar & Sır / Notlar / Karşılaştır).
///
/// Bölüm düğmeleri SwiftUI `Picker`'ın ürettiği segmentlerdir; kimlikleri yok, görünen etiketleriyle seçilir.
/// Not denetçisinin düğmeleri bir işlem sürerken devre dışıdır (`disabled`); eylemler önce düğmenin
/// etkinleşmesini bekler, yoksa devre dışı bir düğmeye yapılan dokunuş sessizce boşa giderdi.
@MainActor
struct PersistenceScreen: Screen {
    private typealias ID = AccessibilityID.Persistence

    let app: XCUIApplication

    var rootElement: XCUIElement { sectionPicker }

    var sectionPicker: XCUIElement { app.segmentedControls[ID.sectionPicker] }
    var list: XCUIElement { app.collectionViews[ID.list] }

    // MARK: Ayar & Sır

    var readingSpeedStepper: XCUIElement { app.steppers[ID.readingSpeedStepper] }
    var readingSpeedExample: XCUIElement { app.staticTexts[ID.readingSpeedExample] }
    var keychainSaveButton: XCUIElement { app.buttons[ID.keychainSaveButton] }
    var keychainReadButton: XCUIElement { app.buttons[ID.keychainReadButton] }
    var keychainDeleteButton: XCUIElement { app.buttons[ID.keychainDeleteButton] }
    var keychainStatus: XCUIElement { app.staticTexts[ID.keychainStatus] }
    var keychainMaskedToken: XCUIElement { app.staticTexts[ID.keychainMaskedToken] }

    // MARK: Notlar

    func kindRow(_ kindRawValue: String) -> XCUIElement { app.buttons[ID.kindRow(kindRawValue)] }
    var selectedCount: XCUIElement { app.staticTexts[ID.selectedCount] }
    var survivesRelaunch: XCUIElement { app.staticTexts[ID.selectedSurvivesRelaunch] }
    var addSampleButton: XCUIElement { app.buttons[ID.addSampleButton] }
    var reopenButton: XCUIElement { app.buttons[ID.reopenButton] }
    var message: XCUIElement { app.staticTexts[ID.notesMessage] }

    // MARK: Eylemler

    @discardableResult
    func showSettings() -> Self {
        sectionPicker.buttons[ID.settingsSegment].tap()
        return self
    }

    @discardableResult
    func showNotes() -> Self {
        sectionPicker.buttons[ID.notesSegment].tap()
        return self
    }

    func saveToken(file: StaticString = #filePath, line: UInt = #line) {
        tapWhenEnabled(keychainSaveButton, file: file, line: line)
    }

    func readToken(file: StaticString = #filePath, line: UInt = #line) {
        tapWhenEnabled(keychainReadButton, file: file, line: line)
    }

    func deleteToken(file: StaticString = #filePath, line: UInt = #line) {
        tapWhenEnabled(keychainDeleteButton, file: file, line: line)
    }

    /// Stepper'ın "artır" düğmesine dokunur. Düğmelerin etiketi sistem diline göre değişir ("Increment"/"Artır");
    /// sıraları ise sabit: 0 = azalt, 1 = artır.
    func increaseReadingSpeed() {
        readingSpeedStepper.buttons.element(boundBy: 1).tap()
    }

    /// Depolama türünü seçer. `kindRawValue`: `AccessibilityID.Persistence.StorageKindRawValue` sabitlerinden biri.
    func selectKind(_ kindRawValue: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = kindRow(kindRawValue)
        tapWhenEnabled(row, likelyAbove: true, file: file, line: line)
        XCTAssertTrue(row.waitForValue("Seçili"), "'\(kindRawValue)' seçilemedi.", file: file, line: line)
    }

    func addSample(file: StaticString = #filePath, line: UInt = #line) {
        tapWhenEnabled(addSampleButton, file: file, line: line)
    }

    func reopen(file: StaticString = #filePath, line: UInt = #line) {
        tapWhenEnabled(reopenButton, file: file, line: line)
    }

    /// Öğe ekranda görünür ve dokunulabilir olana kadar listeyi kaydırır.
    ///
    /// Liste tembel (lazy): Ekranın dışına çıkan satırlar erişilebilirlik ağacından da çıkar, yani "öğe nerede?"
    /// sorusunu her zaman ağaca bakarak cevaplayamayız. Bu yüzden önce TAHMİN edilen yöne kaydırırız
    /// (`likelyAbove`: tür satırları listenin üstünde, düğmeler altında), bulamazsak ters yöne. Ayrıca iOS 26'nın
    /// yüzen sekme çubuğu listenin altını örter; `isHittable` dokunuşun gerçekten öğeye düşüp düşmediğini söyler.
    func reveal(
        _ element: XCUIElement,
        likelyAbove: Bool = false,
        maxSwipes: Int = 6,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        func isVisible() -> Bool { element.exists && element.isHittable }
        // İkinci tur, birincinin kaydırdığı kadar geri gelip öbür tarafa da bakabilsin diye iki kat uzun.
        for (towardTop, limit) in [(likelyAbove, maxSwipes), (!likelyAbove, maxSwipes * 2)] {
            var swipes = 0
            while !isVisible(), swipes < limit {
                if towardTop {
                    list.swipeDown(velocity: .slow)
                } else {
                    list.swipeUp(velocity: .slow)
                }
                swipes += 1
            }
            if isVisible() { break }
        }
        XCTAssertTrue(isVisible(), "\(element) ekranda bulunamadı.", file: file, line: line)
    }

    /// Öğeyi görünür hale getirir, etkinleşmesini bekler ve dokunur.
    private func tapWhenEnabled(_ element: XCUIElement, likelyAbove: Bool = false, file: StaticString, line: UInt) {
        reveal(element, likelyAbove: likelyAbove, file: file, line: line)
        XCTAssertTrue(element.waitUntilEnabled(), "\(element) etkinleşmedi.", file: file, line: line)
        element.tap()
    }
}
