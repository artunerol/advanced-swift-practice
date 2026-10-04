import UIKit
import XCTest
@testable import BookShelf

/// frame ve bounds'un mülakatta sorulan davranışları; önce çıplak UIView'larla, sonra lab ekranıyla.
///
/// Not: UIView.h "dönüşmüş (transform'lu) view'da frame'i kullanma" der; Apple'ın dokümantasyonu bu durumda frame'i
/// "tanımsız" sayar. Burada frame'i yalnızca OKUYORUZ ve pratikteki davranışı belgeliyoruz: UIKit onu dönüşmüş
/// view'ı saran eksen hizalı kutu olarak hesaplıyor. Gerçek kodda konum/boyut için bounds + center kullan.
final class FrameBoundsTests: XCTestCase {
    private typealias ID = AccessibilityID.UIKitLabs.FrameBounds

    // MARK: - transform

    @MainActor
    func testRotating45DegreesGrowsFrameButNotBounds() {
        let view = UIView()
        view.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        view.center = CGPoint(x: 200, y: 200)

        view.transform = CGAffineTransform(rotationAngle: .pi / 4)

        // 45° dönmüş kareyi saran kutu: kenar × √2 ≈ 141.42
        XCTAssertEqual(view.frame.width, 100 * 2.squareRoot(), accuracy: 0.01)
        XCTAssertEqual(view.frame.height, 100 * 2.squareRoot(), accuracy: 0.01)
        XCTAssertEqual(view.bounds, CGRect(x: 0, y: 0, width: 100, height: 100), "bounds transform'dan etkilenmez")
        XCTAssertEqual(view.center, CGPoint(x: 200, y: 200), "transform center etrafında uygulanır")
    }

    @MainActor
    func testRotating90DegreesSwapsFrameWidthAndHeight() {
        let view = UIView()
        view.bounds = CGRect(x: 0, y: 0, width: 120, height: 80)

        view.transform = CGAffineTransform(rotationAngle: .pi / 2)

        XCTAssertEqual(view.frame.width, 80, accuracy: 0.01)
        XCTAssertEqual(view.frame.height, 120, accuracy: 0.01)
        XCTAssertEqual(view.bounds.size, CGSize(width: 120, height: 80))
    }

    @MainActor
    func testScalingChangesFrameButNotBounds() {
        let view = UIView()
        view.bounds = CGRect(x: 0, y: 0, width: 120, height: 80)

        view.transform = CGAffineTransform(scaleX: 2, y: 2)

        XCTAssertEqual(view.frame.size, CGSize(width: 240, height: 160))
        XCTAssertEqual(view.bounds.size, CGSize(width: 120, height: 80))
    }

    // MARK: - bounds.origin ve UIScrollView

    /// Üst view'ın bounds.origin'i kayınca alt view ekranda kayar, ama kendi frame'i (üstün koordinatlarında) aynı kalır.
    @MainActor
    func testShiftingSuperviewBoundsOriginMovesSubviewOnScreenButKeepsItsFrame() {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let container = UIView(frame: CGRect(x: 50, y: 50, width: 200, height: 200))
        let child = UIView(frame: CGRect(x: 20, y: 30, width: 40, height: 40))
        root.addSubview(container)
        container.addSubview(child)
        XCTAssertEqual(child.convert(child.bounds, to: root).origin, CGPoint(x: 70, y: 80))

        container.bounds.origin = CGPoint(x: 0, y: 25)

        XCTAssertEqual(child.frame, CGRect(x: 20, y: 30, width: 40, height: 40), "frame değişmez")
        XCTAssertEqual(container.frame.origin, CGPoint(x: 50, y: 50), "kabın kendi yeri de değişmez")
        XCTAssertEqual(child.convert(child.bounds, to: root).origin, CGPoint(x: 70, y: 55), "ekranda 25 yukarı kaydı")
    }

    @MainActor
    func testScrollViewContentOffsetIsItsBoundsOrigin() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        scrollView.contentSize = CGSize(width: 300, height: 1_000)

        scrollView.contentOffset = CGPoint(x: 0, y: 120)
        XCTAssertEqual(scrollView.bounds.origin, CGPoint(x: 0, y: 120))

        scrollView.bounds.origin = CGPoint(x: 0, y: 300)
        XCTAssertEqual(scrollView.contentOffset, CGPoint(x: 0, y: 300))
    }

    // MARK: - Lab ekranı

    @MainActor
    func testRotationSettingUpdatesFrameReadoutButNotBoundsReadout() {
        let controller = makeController()
        let initialBounds = controller.childBoundsLabel.text

        controller.settings.rotationDegrees = 45

        // 120×80 dikdörtgen 45° → (120 + 80)·√2/2 ≈ 141.4 (iki kenar da)
        XCTAssertEqual(controller.childView.frame.width, 200 * 2.squareRoot() / 2, accuracy: 0.01)
        XCTAssertTrue(controller.childFrameLabel.text?.contains("w 141 · h 141") == true, "\(controller.childFrameLabel.text ?? "")")
        XCTAssertEqual(controller.childBoundsLabel.text, initialBounds)
        XCTAssertEqual(controller.childView.center, FrameBoundsViewController.childCenter)
    }

    @MainActor
    func testContainerOriginSettingShiftsBoundsButNotChildFrame() {
        let controller = makeController()
        let initialFrame = controller.childView.frame
        let initialOnScreen = controller.childView.convert(controller.childView.bounds, to: controller.view)

        controller.settings.containerOriginY = 40

        XCTAssertEqual(controller.containerView.bounds.origin.y, 40)
        XCTAssertEqual(controller.childView.frame, initialFrame)
        let onScreen = controller.childView.convert(controller.childView.bounds, to: controller.view)
        XCTAssertEqual(onScreen.minY, initialOnScreen.minY - 40, accuracy: 0.01)
        XCTAssertTrue(controller.containerBoundsLabel.text?.contains("y 40") == true)
    }

    @MainActor
    func testResetRestoresIdentityTransformAndOrigin() {
        let controller = makeController()
        controller.settings = .init(rotationDegrees: 90, scale: 1.5, containerOriginY: -30)

        controller.reset()

        XCTAssertEqual(controller.childView.transform, .identity)
        XCTAssertEqual(controller.containerView.bounds.origin, .zero)
        XCTAssertEqual(controller.rotationSlider.value, 0)
    }

    @MainActor
    func testGeometryTextRoundsAndAvoidsNegativeZero() {
        XCTAssertEqual(
            GeometryText.rect(CGRect(x: 49.3, y: -0.4, width: 141.42, height: 80)),
            "x 49 · y 0 · w 141 · h 80"
        )
        XCTAssertEqual(GeometryText.point(CGPoint(x: 130, y: 129.6)), "x 130 · y 130")
    }

    // MARK: - Yardımcılar (private)

    @MainActor
    private func makeController() -> FrameBoundsViewController {
        let controller = FrameBoundsViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        controller.view.layoutIfNeeded()
        return controller
    }
}
