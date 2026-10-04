import UIKit
import XCTest
@testable import BookShelf

/// Yaşam döngüsü lab'ının pencere gerektirmeyen kısımları: günlük, yükleme sırası, görünüş geçişi, layout, containment.
///
/// Sunum stillerinin (pageSheet vs fullScreen) farkı gerçek bir pencere ve sunum ister; o UI testinde
/// (`UIKitLabsUITests.testPageSheetKeepsPresenterVisibleButFullScreenTriggersDisappear`).
final class LifecycleLabTests: XCTestCase {
    private typealias Names = AccessibilityID.UIKitLabs.Lifecycle

    // MARK: - LifecycleLogger

    @MainActor
    func testLoggerNumbersEntriesAndClearRestartsSequence() {
        let logger = LifecycleLogger()
        logger.record(.viewDidLoad, from: "A")
        logger.record(.viewWillAppear, from: "B")

        XCTAssertEqual(logger.entries.map(\.sequence), [1, 2])
        XCTAssertEqual(logger.events(from: "A"), [.viewDidLoad])
        XCTAssertTrue(logger.text.hasPrefix("1. +"), "Satır sıra numarasıyla başlamalı: \(logger.text)")
        XCTAssertTrue(logger.text.hasSuffix("B · viewWillAppear"), "En yeni satır en altta olmalı: \(logger.text)")

        logger.clear()
        XCTAssertTrue(logger.entries.isEmpty)
        logger.record(.viewDidAppear, from: "A")
        XCTAssertEqual(logger.entries.map(\.sequence), [1])
    }

    @MainActor
    func testLoggerKeepsOnlyTheNewestEntries() {
        let logger = LifecycleLogger()
        for _ in 0..<(LifecycleLogger.maximumEntryCount + 5) {
            logger.record(.viewDidLayoutSubviews, from: "A")
        }

        XCTAssertEqual(logger.entries.count, LifecycleLogger.maximumEntryCount)
        XCTAssertEqual(logger.entries.first?.sequence, 6, "En eski 5 satır atılmalı.")
    }

    /// Delegate `weak`: Günlük, delegate'i hayatta tutmaz (sahibi değildir).
    @MainActor
    func testLoggerNotifiesDelegateAndHoldsItWeakly() {
        let logger = LifecycleLogger()
        var spy: LifecycleLoggerSpy? = LifecycleLoggerSpy()
        logger.delegate = spy

        logger.record(.viewDidLoad, from: "A")
        logger.clear()
        XCTAssertEqual(spy?.changeCount, 2)

        spy = nil
        XCTAssertNil(logger.delegate, "Delegate güçlü tutulsaydı burada hâlâ yaşıyor olurdu.")
    }

    @MainActor
    func testEventTitlesMatchUIKitMethodNames() {
        XCTAssertEqual(LifecycleEvent.initialized.title, "init")
        XCTAssertEqual(LifecycleEvent.viewIsAppearing.title, "viewIsAppearing")
        XCTAssertEqual(LifecycleEvent.willMoveToParent(nil).title, "willMove(toParent: nil)")
        XCTAssertEqual(LifecycleEvent.didMoveToParent("Ana").title, "didMove(toParent: Ana)")
        XCTAssertEqual(LifecycleEvent.viewWillTransition(width: 402, height: 874).title, "viewWillTransition(to: 402×874)")
    }

    // MARK: - LoggingViewController

    /// View tembeldir (lazy): `init` view'ı yüklemez; ilk erişimde `loadView` → `viewDidLoad` gelir.
    @MainActor
    func testViewLoadsLazilyOnFirstAccess() {
        let logger = LifecycleLogger()
        let controller = makeDetail(logger: logger)

        XCTAssertEqual(logger.events(from: "X"), [.initialized])
        XCTAssertFalse(controller.isViewLoaded)

        controller.loadViewIfNeeded()

        XCTAssertEqual(logger.events(from: "X"), [.initialized, .loadView, .viewDidLoad])
    }

    @MainActor
    func testAppearanceTransitionsCallWillBeforeDidAndNeverReloadTheView() {
        let logger = LifecycleLogger()
        let controller = makeDetail(logger: logger)
        controller.loadViewIfNeeded()
        logger.clear()

        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()

        let appearance: [LifecycleEvent] = [.viewWillAppear, .viewDidAppear, .viewWillDisappear, .viewDidDisappear]
        XCTAssertEqual(logger.events(from: "X").filter(appearance.contains), appearance)
        XCTAssertFalse(logger.events(from: "X").contains(.viewDidLoad), "viewDidLoad yalnızca bir kez çalışır.")
    }

    /// `deinit` nonisolated; günlüğe ana actor'de bir Task ile yazılır, yani kısa bir an sonra görünür.
    @MainActor
    func testDeinitIsRecordedAfterLastReferenceIsGone() async {
        let logger = LifecycleLogger()
        do {
            let controller = makeDetail(logger: logger)
            controller.loadViewIfNeeded()
        }

        await waitUntil("deinit günlüğe düşmeli") { logger.events(from: "X").last == .deinitialized }
    }

    // MARK: - "Ana" ekran

    @MainActor
    func testRelayoutRunsOnlyTheLayoutPair() {
        let logger = LifecycleLogger()
        let subject = LifecycleSubjectViewController(logger: logger)
        subject.loadViewIfNeeded()
        subject.view.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
        subject.view.layoutIfNeeded()
        logger.clear()

        subject.relayout()

        XCTAssertEqual(logger.events(from: Names.presenterName), [.viewWillLayoutSubviews, .viewDidLayoutSubviews])
    }

    @MainActor
    func testMakeModalSetsPresentationStyleOnThePresentedController() {
        let subject = LifecycleSubjectViewController(logger: LifecycleLogger())

        let pageSheet = subject.makeModal(style: .pageSheet)
        let fullScreen = subject.makeModal(style: .fullScreen)

        XCTAssertEqual(pageSheet.modalPresentationStyle, .pageSheet)
        XCTAssertEqual(pageSheet.logName, Names.pageSheetName)
        XCTAssertEqual(fullScreen.modalPresentationStyle, .fullScreen)
        XCTAssertEqual(fullScreen.logName, Names.fullScreenName)
        XCTAssertTrue(subject.presentedViewController == nil, "makeModal yalnızca hazırlar, sunmaz.")
    }

    /// Containment sırası: ekleme willMove(Ana) → (view yüklenir) → didMove(Ana); çıkarma willMove(nil) → didMove(nil).
    @MainActor
    func testChildContainmentOrderAndRelease() async throws {
        let logger = LifecycleLogger()
        let subject = LifecycleSubjectViewController(logger: logger)
        subject.loadViewIfNeeded()
        logger.clear()

        subject.toggleChild()

        // `do` bloğu: Testin kendi yerel değişkeni child'ı güçlü tutmasın. (Debug/-Onone derlemede yerel değişkenler
        // pratikte kapsam sonuna kadar yaşar.) Yoksa aşağıdaki "serbest kalmalı" beklentisini test kendisi bozardı.
        do {
            let child = try XCTUnwrap(subject.embeddedChild)
            XCTAssertTrue(subject.children.contains(child))
        }
        let added = logger.events(from: Names.childName)
        let willMove = try XCTUnwrap(added.firstIndex(of: .willMoveToParent(Names.presenterName)))
        let viewDidLoad = try XCTUnwrap(added.firstIndex(of: .viewDidLoad))
        let didMove = try XCTUnwrap(added.firstIndex(of: .didMoveToParent(Names.presenterName)))
        XCTAssertLessThan(willMove, viewDidLoad)
        XCTAssertLessThan(viewDidLoad, didMove)

        logger.clear()
        subject.toggleChild()

        XCTAssertNil(subject.embeddedChild)
        XCTAssertTrue(subject.children.isEmpty)
        XCTAssertEqual(Array(logger.events(from: Names.childName).prefix(2)), [.willMoveToParent(nil), .didMoveToParent(nil)])
        await waitUntil("çıkarılan child serbest kalmalı") {
            logger.events(from: Names.childName).last == .deinitialized
        }
    }

    // MARK: - Lab çerçevesi

    @MainActor
    func testLabRendersLogIntoTextViewAndClearEmptiesIt() {
        let lab = LifecycleLabViewController()
        lab.loadViewIfNeeded()

        XCTAssertTrue(lab.logger.delegate === lab)
        XCTAssertTrue(lab.logTextView.text.contains("\(Names.presenterName) · init"), "Ana'nın init'i görünmeli.")

        lab.logger.clear()
        XCTAssertEqual(lab.logTextView.text, "")

        lab.logger.record(.viewDidLoad, from: "Test")
        XCTAssertTrue(lab.logTextView.text.contains("Test · viewDidLoad"))
    }

    /// Sahiplik zinciri doğru mu? Lab → günlük güçlü, günlük → lab zayıf. Döngü olsaydı lab hiç serbest kalmazdı.
    @MainActor
    func testLabIsReleasedWhenNoLongerReferenced() async {
        weak var weakLab: LifecycleLabViewController?
        do {
            let lab = LifecycleLabViewController()
            lab.loadViewIfNeeded()
            weakLab = lab
        }

        await waitUntil("lab bellekten silinmeli; silinmiyorsa bir retain cycle var") { weakLab == nil }
    }

    // MARK: - Yardımcılar (private: diğer test dosyalarıyla isim çakışmasın)

    @MainActor
    private func makeDetail(logger: LifecycleLogger) -> LifecycleDetailViewController {
        LifecycleDetailViewController(logName: "X", logger: logger, message: "test", closeStyle: .dismiss)
    }

    /// Koşul sağlanana kadar ana actor'ü kısa aralıklarla serbest bırakarak bekler (deinit'in Task'ı çalışabilsin).
    @MainActor
    private func waitUntil(
        _ description: String,
        timeout: Duration = .seconds(3),
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Zaman aşımı: \(description)", file: file, line: line)
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// Delegate çağrılarını sayan sahte nesne. `@MainActor` protokole sınıf bildiriminde uyduğu için ana actor'e bağlıdır.
private final class LifecycleLoggerSpy: LifecycleLoggerDelegate {
    private(set) var changeCount = 0

    func lifecycleLoggerDidChange(_ logger: LifecycleLogger) {
        changeCount += 1
    }
}
