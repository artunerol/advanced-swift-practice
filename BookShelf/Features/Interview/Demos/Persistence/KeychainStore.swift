import Foundation
import Security

/// Keychain'e metin (ör. bir erişim token'ı) yazan, okuyan ve silen küçük bir sarmalayıcı.
///
/// ## Neden Keychain? (UserDefaults neden değil?)
/// - Keychain kayıtları uygulama dosyalarından ayrı, **şifreli** bir veritabanında durur; anahtarlar cihaz parolası
///   ve Secure Enclave ile korunur. UserDefaults ise sandbox'taki düz bir plist dosyasıdır; kendine ait bir
///   şifrelemesi yoktur (yalnızca diğer dosyalar gibi Data Protection kapsamındadır); şifresiz bir bilgisayar
///   yedeğinden ya da jailbreak'li bir cihazdan düz metin olarak okunabilir.
/// - Kaydın NE ZAMAN okunabileceği seçilebilir (`kSecAttrAccessible...`) ve istenirse Face ID / parola şartı
///   eklenebilir (`SecAccessControl`).
/// - Keychain grupları (access group) ile aynı ekibin uygulamaları ve eklentileri bir sırrı paylaşabilir.
///
/// Dikkat: Uygulama silinse bile Keychain kayıtları genellikle cihazda KALIR (Apple bunu garanti edilen bir davranış
/// olarak belgelemez). Temiz başlangıç isteyen uygulamalar UserDefaults'ta (uygulamayla silinir) bir "ilk açılış"
/// bayrağı tutar ve bayrak yoksa Keychain'i temizler.
///
/// ## API
/// Keychain'in C API'si (`SecItem...`) sözlüklerle çalışır: "sınıf + service + account" bir kaydı tanımlar.
/// - `SecItemAdd`: ekle (aynı kayıt varsa `errSecDuplicateItem`)
/// - `SecItemCopyMatching`: oku
/// - `SecItemUpdate`: güncelle (kayıt yoksa `errSecItemNotFound`)
/// - `SecItemDelete`: sil
///
/// Bu fonksiyonlar thread-safe ama **senkron ve bloklayıcıdır** (sistem servisine bir süreçler arası çağrı yapar).
/// Tek seferlik bir düğme dokunuşunda sorun değil; sık çağrılan bir yolda (ör. her ağ isteğinde) değeri bellekte
/// tutmak ya da çağrıyı ana thread'den almak gerekir.
///
/// `struct` + yalnızca `let` alanlar → değer tipi ve `Sendable`. Durum Keychain'de; tipin kendisi durumsuz.
struct KeychainStore: Sendable {
    /// Kaydın "hangi hizmete ait" olduğu. Genelde uygulamanın bundle id'si.
    let service: String

    enum KeychainError: Error, Equatable, LocalizedError {
        /// Keychain bir hata kodu döndürdü (`OSStatus`). Ör. -34018 `errSecMissingEntitlement`.
        case unexpectedStatus(OSStatus)
        /// Kayıt bulundu ama içindeki veri UTF-8 metin değil.
        case invalidData

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                // `SecCopyErrorMessageString`: Kodu insan okunur bir açıklamaya çevirir.
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "bilinmeyen hata"
                return "Keychain hatası \(status): \(message)"
            case .invalidData:
                return "Keychain'deki veri okunamadı."
            }
        }
    }

    /// Değeri yazar. Kayıt varsa günceller, yoksa ekler.
    ///
    /// Önce güncellemeyi deniyoruz: Kayıt çoğu zaman zaten varsa tek çağrıda biter. "Önce sil sonra ekle" de
    /// çalışırdı ama kaydın diğer özniteliklerini (ör. erişim kontrolü) her seferinde sıfırlardı.
    func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(
            baseQuery(account: account) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var attributes = baseQuery(account: account)
            attributes[kSecValueData as String] = data
            // Ne zaman okunabilir? "İlk kilit açılışından sonra, yalnızca bu cihazda":
            // - AfterFirstUnlock: Cihaz yeniden başlatıldıktan sonra kullanıcı bir kez kilidi açınca, kilitliyken de
            //   okunabilir. Arka planda yenilenen token'lar için gerekli. (Varsayılan `WhenUnlocked` daha sıkıdır.)
            // - ThisDeviceOnly: Yedekten başka bir cihaza taşınmaz; token o cihaza bağlı kalır.
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Değeri okur. Kayıt yoksa `nil` (bu bir hata değil).
    func read(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        // Sonuç C tarzı bir "out" parametresiyle gelir: `CFTypeRef?` değişkeninin adresini veriyoruz.
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Kaydı siler. Kayıt yoksa hata fırlatmaz (idempotent).
    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Bu `service`'e ait tüm kayıtları siler (testlerde temizlik için).
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Bir kaydı tanımlayan üçlü: sınıf (genel parola), service ve account.
    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
