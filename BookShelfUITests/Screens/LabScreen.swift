import XCTest

/// "Laboratuvar" sekmesi (`ConcurrencyLabView`, SwiftUI `Form`).
///
/// Ekran uzun: Sıralı vs Paralel → Paylaşılan Durum → Reentrancy → İptal. `Form` tembel olduğu için alttaki
/// bölümler kaydırılana kadar ağaçta yoktur. Bu yüzden her bölümün eylemi önce o bölümü görünür hale getirir.
/// Test hangi bölümün ekranın neresinde olduğunu bilmek zorunda kalmaz; bu bilgi burada, tek yerde durur.
///
/// Sonuç metinleri deneylerin gerçekten çalıştığını gösterir, ama bir kısmı her çalıştırmada değişir
/// (ölçülen süreler, data race'te kaybolan artış sayısı). Testler bu yüzden değişmeyen kısımları doğrular.
@MainActor
struct LabScreen: Screen {
    private typealias ID = AccessibilityID.Lab

    let app: XCUIApplication

    var rootElement: XCUIElement { form }

    var form: XCUIElement { app.collectionViews[ID.form] }

    // MARK: Sıralı vs Paralel (ekranın en üstünde)

    var runSequentialButton: XCUIElement { app.buttons[ID.runSequentialButton] }
    var runTaskGroupButton: XCUIElement { app.buttons[ID.runTaskGroupButton] }
    var sequentialResult: XCUIElement { app.staticTexts[ID.sequentialResult] }
    var taskGroupResult: XCUIElement { app.staticTexts[ID.taskGroupResult] }
    var taskGroupArrivalOrder: XCUIElement { app.staticTexts[ID.taskGroupArrivalOrder] }

    // MARK: Paylaşılan durum

    var runCountersButton: XCUIElement { app.buttons[ID.runCountersButton] }
    var unsafeCounterResult: XCUIElement { app.staticTexts[ID.unsafeCounterResult] }
    var lockedCounterResult: XCUIElement { app.staticTexts[ID.lockedCounterResult] }
    var actorCounterResult: XCUIElement { app.staticTexts[ID.actorCounterResult] }

    // MARK: İptal (ekranın en altında)

    var longTaskStatus: XCUIElement { app.staticTexts[ID.longTaskStatus] }
    var startLongTaskButton: XCUIElement { app.buttons[ID.startLongTaskButton] }
    var cancelLongTaskButton: XCUIElement { app.buttons[ID.cancelLongTaskButton] }

    // MARK: Eylemler

    func runTaskGroup() {
        form.scrollUp(toReveal: runTaskGroupButton)
        runTaskGroupButton.tap()
    }

    /// Sayaç bölümünü görünür hale getirir. Hedef olarak bölümün SON satırını seçiyoruz: O görünüyorsa
    /// üstündeki düğme ve diğer sonuçlar da görünüyordur.
    func revealCounters() {
        form.scrollUp(toReveal: actorCounterResult)
    }

    func runCounters() {
        revealCounters()
        runCountersButton.tap()
    }

    /// İptal bölümünü görünür hale getirir (bölümün son düğmesi "İptal et").
    func revealLongTask() {
        form.scrollUp(toReveal: cancelLongTaskButton)
    }

    func startLongTask() {
        revealLongTask()
        startLongTaskButton.tap()
    }

    func cancelLongTask() {
        cancelLongTaskButton.tap()
    }
}
