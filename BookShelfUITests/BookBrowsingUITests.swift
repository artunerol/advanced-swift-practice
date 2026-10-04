import XCTest

/// Kitaplar sekmesinde gezinme: liste → detay → geri.
///
/// Test adları beklenen davranışı cümle gibi anlatır: "satıra dokununca detay Objective-C değerleriyle açılır".
/// Her test uygulamayı sıfırdan başlatır (`launchApp()`), yani sıraları değişse de sonuçları değişmez.
///
/// `XCTContext.runActivity(named:)` testi adlandırılmış adımlara böler. Xcode'un test raporunda (ve `.xcresult`'ta)
/// her adım ayrı bir satır olarak görünür; başarısız olan adım kırmızı işaretlenir. Uzun bir UI testinde
/// "nerede kırıldı?" sorusunun cevabını log okumadan verir.
final class BookBrowsingUITests: BookShelfUITestCase {

    @MainActor
    func testListShowsBooksFromCatalog() {
        let bookList = BookListScreen(app: launchApp()).waitUntilDisplayed()

        XCTContext.runActivity(named: "İlk kitap, başlığı ve yazar/yıl bilgisiyle listede") { _ in
            // NavigationLink satırının label'ı, satırdaki metinlerin birleşimidir.
            assertLabel(bookList.row(bookID: 1), equals: "Tutunamayanlar, Oğuz Atay · 1972")
        }

        XCTContext.runActivity(named: "Son kitaba (8) kaydırarak ulaşılabiliyor") { _ in
            let lastRow = bookList.revealRow(bookID: 8)
            assertLabel(lastRow, contains: "Huzur")
        }

        XCTContext.runActivity(named: "Hiçbir kitap favori olarak başlamıyor") { _ in
            // Uygulama her başlatmada boş bir favori listesiyle açılır; testler birbirini etkilemez.
            // Burada beklemeye gerek yok: Liste zaten yüklü ve beklediğimiz şey bir DEĞİŞİKLİK değil, başlangıç durumu.
            // Favori olmayan satırın value'su boş metindir; XCUITest boş value'yu `nil` olarak da verebilir,
            // bu yüzden "boş mu?" yerine "Favori değil mi?" diye soruyoruz.
            XCTAssertNotEqual(bookList.row(bookID: 1).value as? String, AccessibilityID.BookValue.favorite)
        }
    }

    @MainActor
    func testTappingRowOpensDetailWithObjectiveCValues() {
        let app = launchApp()
        let bookList = BookListScreen(app: app).waitUntilDisplayed()

        let detail = XCTContext.runActivity(named: "Tutunamayanlar satırına dokun") { _ in
            bookList.openBook(id: 1)
        }

        XCTContext.runActivity(named: "Başlık, yazar, ISBN rozeti ve okuma süresi doğru") { _ in
            assertLabel(detail.title, equals: "Tutunamayanlar")
            assertLabel(detail.author, equals: "Oğuz Atay")
            // Rozet ve süre Objective-C sınıflarından geliyor: BKISBNValidator ve BKReadingTimeEstimator.
            assertLabel(detail.isbnStatus, equals: AccessibilityID.BookValue.isbnValid)
            // 724 sayfa ÷ saatte 40 sayfa = 18,1 saat = 18 sa 6 dk.
            assertLabel(detail.readingTime, equals: "18 sa 6 dk")
        }

        XCTContext.runActivity(named: "Ekranın üst kısmının görüntüsünü rapora ekle") { activity in
            // `XCTAttachment`: Test raporuna dosya (ekran görüntüsü, metin, JSON...) ekler.
            // Varsayılan ömür `.deleteOnSuccess`: Test geçerse ek silinir, yalnızca başarısız testlerde saklanır.
            // Bu ekran görüntüsünü her zaman görmek istediğimiz için `.keepAlways` diyoruz.
            // Bulmak için: Xcode → Report navigator (⌘9) → test → bu adım; ya da
            // `xcrun xcresulttool export attachments --path build/results/ui.xcresult --output-path <klasör>`.
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Kitap detayı - Tutunamayanlar"
            screenshot.lifetime = .keepAlways
            activity.add(screenshot)
        }

        XCTContext.runActivity(named: "Paralel yüklenen yorumlar ve yazar bilgisi geliyor") { _ in
            detail.revealExtras()
            assertAppears(detail.authorBio)
            // Süre her çalıştırmada farklı olabilir; yalnızca metnin biçimini doğruluyoruz.
            assertLabel(detail.loadDuration, matches: "Yükleme süresi: [0-9]+,[0-9] sn \\(paralel\\)")
        }
    }

    @MainActor
    func testBookWithInvalidChecksumShowsInvalidBadge() {
        let bookList = BookListScreen(app: launchApp()).waitUntilDisplayed()

        // "Huzur"un ISBN'i (978-605-000-008-6) bilerek hatalı: doğru kontrol hanesi 5 olmalıydı.
        let detail = bookList.openBook(id: 8)

        assertLabel(detail.title, equals: "Huzur")
        assertLabel(detail.isbnStatus, equals: AccessibilityID.BookValue.isbnInvalid)
        // 392 sayfa ÷ 40 = 9,8 saat = 9 sa 48 dk.
        assertLabel(detail.readingTime, equals: "9 sa 48 dk")
    }

    @MainActor
    func testBackButtonReturnsToList() {
        let bookList = BookListScreen(app: launchApp()).waitUntilDisplayed()
        let detail = bookList.openBook(id: 2)
        assertLabel(detail.title, equals: "Kürk Mantolu Madonna")

        detail.goBackToBookList()

        // İki taraflı kontrol: Detay kayboldu VE liste geri geldi. Sadece birine bakmak, geçiş sırasında
        // iki ekranın da bir an ağaçta olduğu durumları gözden kaçırabilir.
        assertDisappears(detail.title)
        assertAppears(bookList.row(bookID: 2))
    }
}
