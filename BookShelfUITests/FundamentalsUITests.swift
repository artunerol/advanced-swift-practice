import XCTest

/// Temeller sekmesi: struct vs class deneyi ve Objective-C ISBN doğrulayıcısı.
final class FundamentalsUITests: BookShelfUITestCase {

    // MARK: - Struct vs Class

    @MainActor
    func testMutatingCopiesLeavesStructOriginalButChangesClassOriginal() {
        let screen = TabBarScreen(app: launchApp()).openFundamentals().waitUntilDisplayed().openStructVsClass()

        XCTContext.runActivity(named: "Başlangıç: orijinaller ve kopyalar aynı sayfada") { _ in
            assertLabel(screen.structOriginal, equals: "Orijinal: 10. sayfa")
            assertLabel(screen.classOriginal, equals: "Orijinal: 10. sayfa")
        }

        XCTContext.runActivity(named: "Yalnızca KOPYALARI 10 sayfa ilerlet") { _ in
            screen.mutateCopies()
        }

        XCTContext.runActivity(named: "struct: kopya değişti, orijinal aynı kaldı (değer semantiği)") { _ in
            assertLabel(screen.structCopy, equals: "Kopya: 20. sayfa")
            assertLabel(screen.structOriginal, equals: "Orijinal: 10. sayfa")
            assertLabel(screen.structEquality, equals: "Eşit mi (==)? Hayır")
        }

        XCTContext.runActivity(named: "class: orijinal de değişti, çünkü ikisi aynı nesne (referans semantiği)") { _ in
            assertLabel(screen.classCopy, equals: "Kopya: 20. sayfa")
            assertLabel(screen.classOriginal, equals: "Orijinal: 20. sayfa")
            assertLabel(screen.classIdentity, equals: "Aynı nesne mi (===)? Evet")
        }
    }

    @MainActor
    func testStrongReferenceCycleLeaksAndWeakReferenceDoesNot() {
        let screen = TabBarScreen(app: launchApp()).openFundamentals().waitUntilDisplayed().openStructVsClass()
        screen.selectExperiment(AccessibilityID.Fundamentals.StructVsClass.arcSegment)

        XCTContext.runActivity(named: "strong ↔ strong: iki nesne de serbest bırakılmaz") { _ in
            screen.strongCycleButton.tap()
            assertLabel(screen.deinitCount, equals: "Serbest bırakılan: 0/2")
            assertLabel(screen.verdict, equals: "Sızıntı var")
        }

        XCTContext.runActivity(named: "weak ile kırılan döngü: ikisi de serbest bırakılır") { _ in
            screen.weakCycleButton.tap()
            assertLabel(screen.deinitCount, equals: "Serbest bırakılan: 2/2")
            assertLabel(screen.verdict, equals: "Sızıntı yok")
        }
    }

    // MARK: - ISBN doğrulayıcı (Objective-C)

    @MainActor
    func testISBNCheckerAcceptsValidISBN() {
        let checker = TabBarScreen(app: launchApp()).openFundamentals().waitUntilDisplayed().openISBNChecker()

        checker.check("978-605-000-001-6")

        assertLabel(checker.resultLabel, equals: "Geçerli ISBN-13 ✓")
        // Objective-C `+normalizedISBN:` tireleri temizler.
        assertLabel(checker.normalizedLabel, equals: "9786050000016")
        XCTAssertFalse(checker.hintLabel.exists, "Geçerli sonuçta ipucu gösterilmemeli.")
    }

    @MainActor
    func testISBNCheckerExplainsChecksumMismatch() {
        let checker = TabBarScreen(app: launchApp()).openFundamentals().waitUntilDisplayed().openISBNChecker()

        // "Huzur"un kasıtlı olarak hatalı ISBN'i.
        checker.check("978-605-000-008-6")

        // Mesaj, Objective-C'deki NSError'ın localizedDescription'ı; Swift'e `throws` olarak geliyor.
        assertLabel(checker.resultLabel, equals: "Kontrol hanesi (son hane) hatalı.")
        assertLabel(checker.hintLabel, equals: "Doğru kontrol hanesi: 5")
        XCTAssertFalse(checker.normalizedLabel.exists)
    }

    @MainActor
    func testEditingInputClearsPreviousResult() {
        let checker = TabBarScreen(app: launchApp()).openFundamentals().waitUntilDisplayed().openISBNChecker()

        XCTContext.runActivity(named: "Örnek düğmesiyle doldur ve doğrula") { _ in
            checker.lettersSampleButton.tap()
            assertValue(checker.inputField, equals: "978-605-ABC-001-6")
            checker.validate()
            assertLabel(checker.resultLabel, equals: "ISBN yalnızca rakam, tire ve boşluk içerebilir.")
        }

        XCTContext.runActivity(named: "Metni değiştir: eski sonuç ekrandan kalkar") { _ in
            // Metin kutusu zaten dolu; `typeText` karakteri imlecin olduğu yere ekler. Nereye eklendiği önemli değil:
            // Metnin değişmesi `onChange`'i tetikler ve eski sonuç artık bu metne ait olmadığı için silinir.
            checker.type("7")
            assertDisappears(checker.resultLabel)
        }
    }
}
