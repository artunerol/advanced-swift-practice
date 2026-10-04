import XCTest

/// frame vs bounds lab'ı (`FrameBoundsViewController`).
///
/// Kaydırıcılar `adjust(toNormalizedSliderPosition:)` ile ayarlanır (0 = en sol, 1 = en sağ). Uygulama değeri 5'lik
/// adımlara yuvarladığı için kesin bir açı beklemiyoruz; testler "değişti / değişmedi" sorusunu sorar.
@MainActor
struct UIKitLabFrameBoundsScreen: Screen {
    private typealias ID = AccessibilityID.UIKitLabs.FrameBounds

    let app: XCUIApplication

    var rootElement: XCUIElement { rotationSlider }

    var rotationSlider: XCUIElement { app.sliders[ID.rotationSlider] }
    var originSlider: XCUIElement { app.sliders[ID.originSlider] }

    var childFrameLabel: XCUIElement { app.staticTexts[ID.childFrameLabel] }
    var childBoundsLabel: XCUIElement { app.staticTexts[ID.childBoundsLabel] }
    var containerBoundsLabel: XCUIElement { app.staticTexts[ID.containerBoundsLabel] }
    var convertedLabel: XCUIElement { app.staticTexts[ID.convertedLabel] }

    func rotate(toNormalizedPosition position: CGFloat) {
        rotationSlider.adjust(toNormalizedSliderPosition: position)
    }

    func shiftContainerOrigin(toNormalizedPosition position: CGFloat) {
        originSlider.adjust(toNormalizedSliderPosition: position)
    }
}
