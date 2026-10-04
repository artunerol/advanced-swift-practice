import XCTest

/// Mülakat sekmesindeki dört UIKit lab'ı: yaşam döngüsü, dinamik hücreler, frame vs bounds, table vs collection.
///
/// Lab'lar tamamen UIKit; testler bunu bilmez, yalnızca erişilebilirlik ağacını görür (bkz. `UIKitLab*Screen`).
final class UIKitLabsUITests: BookShelfUITestCase {
    private typealias TopicID = AccessibilityID.Interview.TopicID
    private typealias Lifecycle = AccessibilityID.UIKitLabs.Lifecycle

    /// Uygulamayı açar, Mülakat sekmesinde konuyu bulur, "Demo" bölümüne geçer ve demo ekranını bekler.
    @MainActor
    private func openLab<S: Screen>(
        _ topicID: String,
        as screenType: S.Type,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> S {
        let app = launchApp(file: file, line: line)
        TabBarScreen(app: app).openInterview().waitUntilDisplayed(file: file, line: line)
            .openTopic(topicID, file: file, line: line)
            .showDemo()
        return screenType.init(app: app).waitUntilDisplayed(file: file, line: line)
    }

    // MARK: - Yaşam döngüsü

    @MainActor
    func testLifecycleLogShowsLoadAndLayoutCallbacksAndRelayoutDoesNotReload() {
        let lab = openLab(TopicID.vcLifecycle, as: UIKitLabLifecycleScreen.self)

        XCTContext.runActivity(named: "İlk görünüş: yükleme, görünme ve yerleşim çağrıları") { activity in
            assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.presenterName, "viewDidLoad"))
            assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.presenterName, "viewIsAppearing"))
            assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.presenterName, "viewDidLayoutSubviews"))
            assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.presenterName, "viewDidAppear"))
            attachLog(lab, to: activity)
        }

        XCTContext.runActivity(named: "setNeedsLayout + layoutIfNeeded: layout çifti gelir, viewDidLoad gelmez") { _ in
            lab.clearLog()
            lab.relayoutButton.tap()
            assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.presenterName, "viewWillLayoutSubviews"))
            assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.presenterName, "viewDidLayoutSubviews"))
            XCTAssertFalse(lab.logText.contains("viewDidLoad"), "Yeniden yerleşim view'ı yeniden yüklememeli.\n\(lab.logText)")
        }
    }

    /// Klasik mülakat tuzağı: `.pageSheet` alttaki ekranı "kaybolmuş" saymaz, `.fullScreen` sayar.
    @MainActor
    func testPageSheetKeepsPresenterVisibleButFullScreenTriggersDisappear() {
        let lab = openLab(TopicID.vcLifecycle, as: UIKitLabLifecycleScreen.self)
        let presenterEvents = ["viewWillDisappear", "viewDidDisappear", "viewWillAppear", "viewDidAppear"]
            .map { UIKitLabLifecycleScreen.entry(Lifecycle.presenterName, $0) }

        XCTContext.runActivity(named: ".pageSheet: Ana kaybolma/görünme bildirimi ALMAZ") { activity in
            lab.clearLog()
            lab.openAndClose(using: lab.presentPageSheetButton)
            // Sheet'in kendi kapanışı bitene kadar bekle; ondan sonra Ana'nın satırı yoksa hiç gelmeyecek demektir.
            assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.pageSheetName, "viewDidDisappear"))
            attachLog(lab, to: activity)
            for event in presenterEvents {
                XCTAssertFalse(lab.logText.contains(event), "pageSheet'te beklenmeyen satır: \(event)\n\(lab.logText)")
            }
        }

        XCTContext.runActivity(named: ".fullScreen: Ana kaybolur ve geri dönünce yeniden görünür") { activity in
            lab.clearLog()
            lab.openAndClose(using: lab.presentFullScreenButton)
            assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.fullScreenName, "viewDidDisappear"))
            for event in presenterEvents {
                assertLog(lab, contains: event)
            }
            attachLog(lab, to: activity)
        }
    }

    @MainActor
    func testPushHidesPresenterAndPopShowsItAgain() {
        let lab = openLab(TopicID.vcLifecycle, as: UIKitLabLifecycleScreen.self)
        lab.clearLog()

        lab.openAndClose(using: lab.pushButton)

        assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.pushedName, "viewDidAppear"))
        assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.presenterName, "viewDidDisappear"))
        assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.pushedName, "viewDidDisappear"))
        assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.presenterName, "viewDidAppear"))
        // Pop edilen ekranın son referansı gidince deinit (günlüğe Task ile, kısa bir an sonra) düşer.
        assertLog(lab, contains: UIKitLabLifecycleScreen.entry(Lifecycle.pushedName, "deinit"))
    }

    // MARK: - Dinamik hücreler

    @MainActor
    func testTappingBookCellExpandsAndCollapsesSummary() {
        let lab = openLab(TopicID.dynamicCells, as: UIKitLabDynamicCellsScreen.self)
        let cell = lab.bookCell(1)
        let ID = AccessibilityID.UIKitLabs.DynamicCells.self

        assertValue(cell, equals: ID.collapsedValue)
        let collapsedHeight = cell.frame.height

        cell.tap()
        assertValue(cell, equals: ID.expandedValue)
        XCTAssertGreaterThan(cell.frame.height, collapsedHeight, "Açılan hücre uzamalı (self-sizing).")

        cell.tap()
        assertValue(cell, equals: ID.collapsedValue)
    }

    // MARK: - frame vs bounds

    @MainActor
    func testRotationChangesFrameButNotBounds() {
        let lab = openLab(TopicID.frameVsBounds, as: UIKitLabFrameBoundsScreen.self)
        let initialFrame = lab.childFrameLabel.label
        let initialBounds = lab.childBoundsLabel.label

        lab.rotate(toNormalizedPosition: 0.25)   // 0…180° aralığında yaklaşık 45°

        XCTAssertTrue(
            lab.childFrameLabel.waitUntil(NSPredicate(format: "label != %@", initialFrame), timeout: UITestTimeout.standard),
            "Döndürünce frame değişmeli. Hâlâ: \(lab.childFrameLabel.label)"
        )
        assertLabel(lab.childBoundsLabel, equals: initialBounds)
    }

    @MainActor
    func testShiftingContainerOriginMovesChildOnScreenButNotItsFrame() {
        let lab = openLab(TopicID.frameVsBounds, as: UIKitLabFrameBoundsScreen.self)
        let initialFrame = lab.childFrameLabel.label
        let initialContainerBounds = lab.containerBoundsLabel.label
        let initialConverted = lab.convertedLabel.label

        // Kaydırıcı -80…80 aralığında; 0.9 yaklaşık +65. Kesin değer önemli değil, değişmesi önemli.
        lab.shiftContainerOrigin(toNormalizedPosition: 0.9)

        XCTAssertTrue(
            lab.containerBoundsLabel.waitUntil(
                NSPredicate(format: "label != %@", initialContainerBounds),
                timeout: UITestTimeout.standard
            ),
            "container.bounds.origin değişmeli. Hâlâ: \(lab.containerBoundsLabel.label)"
        )
        XCTAssertNotEqual(lab.convertedLabel.label, initialConverted, "child ekranda kaymalı (convert sonucu değişmeli).")
        assertLabel(lab.childFrameLabel, equals: initialFrame)
    }

    // MARK: - UITableView vs UICollectionView

    @MainActor
    func testSwitchingModesShowsSameBooksInTableListAndGrid() {
        let lab = openLab(TopicID.tableVsCollection, as: UIKitLabTableVsCollectionScreen.self)
        let ID = AccessibilityID.UIKitLabs.TableVsCollection.self

        XCTContext.runActivity(named: "Tablo") { _ in
            assertAppears(lab.tableCell(1))
            XCTAssertFalse(lab.listCollection.exists)
        }

        XCTContext.runActivity(named: "Liste (collection view + list configuration)") { _ in
            lab.selectMode(ID.listSegment)
            assertAppears(lab.listCell(1))
            XCTAssertFalse(lab.table.exists, "Tablo gizlenmeli.")
        }

        XCTContext.runActivity(named: "Izgara (compositional layout): aynı kitap iki bölümde") { _ in
            lab.selectMode(ID.gridSegment)
            assertAppears(lab.featuredCell(1))
            assertAppears(lab.gridCell(1))
            assertLabel(lab.caption, contains: "compositional")
        }
    }

    // MARK: - Yardımcılar

    /// Günlük metni (`value`) `text`'i içerene kadar bekler.
    @MainActor
    private func assertLog(
        _ lab: UIKitLabLifecycleScreen,
        contains text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = lab.log.waitUntil(
            NSPredicate(format: "exists == true AND value CONTAINS %@", text),
            timeout: UITestTimeout.standard
        )
        XCTAssertTrue(found, "Günlükte \"\(text)\" yok. Günlük:\n\(lab.logText)", file: file, line: line)
    }

    /// Günlüğü test raporuna ekler: Xcode'un Report Navigator'ında hangi sırayla ne çağrıldığını görebilesin.
    @MainActor
    private func attachLog(_ lab: UIKitLabLifecycleScreen, to activity: any XCTActivity) {
        let attachment = XCTAttachment(string: lab.logText)
        attachment.name = "Yaşam döngüsü günlüğü"
        attachment.lifetime = .keepAlways
        activity.add(attachment)
    }
}
