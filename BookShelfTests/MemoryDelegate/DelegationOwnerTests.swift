import UIKit
import XCTest
@testable import BookShelf

/// `BookRatingViewController`: kontrolün sahibi ve delegate'i. Üç kanalın bağlanması, etiketler, reddetme ve
/// sahibin kontrolden önce ölebilmesi (`DelegateLifetimeExperiment`).
final class DelegationOwnerTests: XCTestCase {

    @MainActor
    func testViewDidLoadWiresDelegateClosureAndTargetAction() throws {
        let viewController = makeLoadedOwner()
        let control = viewController.ratingControl

        XCTAssertTrue(control.delegate === viewController, "Sahip, kontrolün delegate'i olmalı")
        XCTAssertNotNil(control.onRatingChange)
        XCTAssertTrue(control.allTargets.contains(viewController))
        let actions = try XCTUnwrap(control.actions(forTarget: viewController, forControlEvent: .valueChanged))
        XCTAssertEqual(actions, ["ratingControlValueChanged:"])
        // Sahip kontrolü view hiyerarşisi üzerinden tutar.
        XCTAssertTrue(control.isDescendant(of: viewController.view))
    }

    @MainActor
    func testChannelLabelsStartEmptyAndAllUpdateOnChange() {
        let viewController = makeLoadedOwner()
        XCTAssertEqual(viewController.delegateLabel.text, "Delegate: —")

        viewController.ratingControl.selectRating(4)

        XCTAssertEqual(viewController.delegateLabel.text, "Delegate: 4/5")
        XCTAssertEqual(viewController.closureLabel.text, "Closure: 4/5")
        XCTAssertEqual(viewController.targetActionLabel.text, "Target-action: 4/5")
        XCTAssertEqual(viewController.statusLabel.text, "Puan 4/5 oldu: üç kanal da haber aldı.")
    }

    @MainActor
    func testLockedOwnerRejectsChangesThroughDelegate() {
        let viewController = makeLoadedOwner()
        viewController.ratingControl.selectRating(2)

        viewController.lockSwitch.isOn = true
        viewController.ratingControl.selectRating(5)

        XCTAssertEqual(viewController.ratingControl.rating, 2)
        XCTAssertEqual(viewController.delegateLabel.text, "Delegate: 2/5")
        XCTAssertEqual(viewController.closureLabel.text, "Closure: 2/5", "Reddedilen değişiklik closure'a da gitmemeli")
        XCTAssertEqual(viewController.statusLabel.text, "Delegate reddetti: puan 2/5 olarak kaldı.")
    }

    /// Sahip ölür, kontrol yaşar: Üç kanaldan hiçbiri sahibi tutmuyor, `weak` delegate `nil` oluyor, kontrol çökmüyor.
    @MainActor
    func testOwnerIsReleasedWhileControlLivesAndDelegateBecomesNil() async {
        let outcome = await DelegateLifetimeExperiment.run()

        XCTAssertTrue(outcome.ownerReleased, "Sahip serbest bırakılmalıydı; bir kanal onu güçlü tutuyor olabilir")
        XCTAssertTrue(outcome.delegateIsNil)
        XCTAssertTrue(outcome.controlStillWorks)
        XCTAssertEqual(outcome.summary, "Sahip serbest bırakıldı: Evet · control.delegate: nil")
    }

    @MainActor
    func testChannelTextFormat() {
        XCTAssertEqual(BookRatingViewController.channelText("Closure", rating: nil), "Closure: —")
        XCTAssertEqual(BookRatingViewController.channelText("Closure", rating: 3), "Closure: 3/5")
    }

    // MARK: - Yardımcılar

    @MainActor
    private func makeLoadedOwner() -> BookRatingViewController {
        let viewController = BookRatingViewController()
        viewController.loadViewIfNeeded()
        return viewController
    }
}
