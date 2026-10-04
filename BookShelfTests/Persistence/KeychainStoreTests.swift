import Security
import XCTest
@testable import BookShelf

/// `KeychainStore` testleri. Gerçek (simülatördeki) Keychain'e yazar; her test benzersiz bir `service` kullanır
/// ve sonunda kendi kayıtlarını siler. Böylece uygulamanın ve diğer testlerin kayıtlarına dokunmaz.
final class KeychainStoreTests: XCTestCase {
    private var store: KeychainStore!

    override func setUp() {
        super.setUp()
        store = KeychainStore(service: "dev.learning.BookShelfTests.keychain.\(UUID().uuidString)")
    }

    override func tearDown() {
        try? store.deleteAll()
        store = nil
        super.tearDown()
    }

    func testSaveReadUpdateAndDeleteRoundTrip() throws {
        try saveOrSkipWithoutKeychain("ilk-token", account: "kullanici")
        XCTAssertEqual(try store.read(account: "kullanici"), "ilk-token")

        // Aynı hesaba ikinci kayıt: SecItemUpdate yolu. Yeni bir kopya değil, güncelleme olmalı.
        try store.save("ikinci-token", account: "kullanici")
        XCTAssertEqual(try store.read(account: "kullanici"), "ikinci-token")

        try store.delete(account: "kullanici")
        XCTAssertNil(try store.read(account: "kullanici"))
        // Silmek idempotent.
        XCTAssertNoThrow(try store.delete(account: "kullanici"))
    }

    func testMissingItemReadsAsNil() throws {
        try saveOrSkipWithoutKeychain("x", account: "baska")
        XCTAssertNil(try store.read(account: "olmayan"))
    }

    /// Kayıt "service + account" ikilisiyle tanımlanır: Aynı account farklı service'lerde ayrı kayıtlardır.
    func testServicesAreIsolated() throws {
        try saveOrSkipWithoutKeychain("benim", account: "ortak")
        let other = KeychainStore(service: store.service + ".diger")
        defer { try? other.deleteAll() }

        XCTAssertNil(try other.read(account: "ortak"))
        try other.save("onun", account: "ortak")
        XCTAssertEqual(try store.read(account: "ortak"), "benim")
        XCTAssertEqual(try other.read(account: "ortak"), "onun")
    }

    func testUnicodeValuesRoundTrip() throws {
        try saveOrSkipWithoutKeychain("şifre-ğüşiöç-🔑", account: "unicode")
        XCTAssertEqual(try store.read(account: "unicode"), "şifre-ğüşiöç-🔑")
    }

    func testErrorDescriptionIncludesStatusCode() {
        let error = KeychainStore.KeychainError.unexpectedStatus(errSecDuplicateItem)
        XCTAssertTrue(error.localizedDescription.contains("\(errSecDuplicateItem)"), error.localizedDescription)
    }

    // MARK: - Yardımcı

    /// İlk yazmayı yapar; test ortamında Keychain erişimi yoksa testi ATLAR (başarısız saymaz).
    ///
    /// `errSecMissingEntitlement` (-34018): Süreç Keychain'e erişim yetkisi (entitlement) taşımıyor. İmzasız bir
    /// test host'unda görülebilir. Bu, kodumuzun değil ortamın sorunu; testi kırmızı yapmak yerine nedenini yazıp atlıyoruz.
    private func saveOrSkipWithoutKeychain(_ value: String, account: String) throws {
        do {
            try store.save(value, account: account)
        } catch KeychainStore.KeychainError.unexpectedStatus(errSecMissingEntitlement) {
            throw XCTSkip("Bu test ortamında Keychain erişimi yok (errSecMissingEntitlement, -34018).")
        }
    }
}
