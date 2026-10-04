import SwiftUI

/// "Ayar & Sır" bölümü: aynı büyüklükte iki küçük veri, iki farklı yer.
/// - Okuma hızı bir **tercih** → UserDefaults (`@AppStorage`).
/// - Erişim token'ı bir **sır** → Keychain.
struct PersistenceSettingsSections: View {
    private typealias ID = AccessibilityID.Persistence

    /// `@AppStorage`: UserDefaults'taki bir anahtarı SwiftUI durumu gibi kullanmayı sağlar. Değer değişince
    /// UserDefaults'a yazılır ve bu anahtarı izleyen her view yeniden çizilir. Varsayılan değer (40) yalnızca
    /// anahtar hiç yazılmamışsa kullanılır; UserDefaults'a yazılmaz.
    ///
    /// Anahtar `BookDetailViewModel.readingSpeedKey`: Kitap detayındaki tahmini okuma süresi bu ayarı okur.
    /// `store:` hangi UserDefaults'un kullanılacağını seçer (UI testlerinde ayrı, her açılışta sıfırlanan bir alan).
    @AppStorage private var pagesPerHour: Double

    private let keychain: KeychainStore
    @State private var keychainStatus = "—"
    @State private var maskedToken = "—"

    init(location: PersistenceLocation) {
        _pagesPerHour = AppStorage(
            wrappedValue: ReadingPace.defaultPagesPerHour,
            BookDetailViewModel.readingSpeedKey,
            store: location.defaults
        )
        keychain = KeychainStore(service: location.keychainService)
    }

    var body: some View {
        readingSpeedSection
        keychainSection
    }

    // MARK: - UserDefaults

    private var readingSpeedSection: some View {
        Section {
            // Aralık ve varsayılan Swift'teki `ReadingPace`'ten (Objective-C de aynı sabiti kullanıyor).
            Stepper(value: $pagesPerHour, in: ReadingPace.typicalRange, step: 5) {
                Text(verbatim: "Okuma hızı: saatte \(Int(pagesPerHour)) sayfa")
            }
            .accessibilityIdentifier(ID.readingSpeedStepper)

            // Ayrı bir satır: Stepper'ın etiketi stepper öğesinin içinde kalır; bu metin ise testte doğrudan okunur.
            Text(verbatim: "400 sayfalık bir kitap ≈ \(ReadingTimeEstimator(pagesPerHour: pagesPerHour).formattedEstimate(forPageCount: 400))")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(ID.readingSpeedExample)
        } header: {
            Text("Tercih → UserDefaults (@AppStorage)")
                .textCase(nil)
        } footer: {
            Text("""
            Değiştir, sonra Kitaplar sekmesinde bir kitabı aç: "Tahmini okuma süresi" bu ayarla hesaplanır. \
            UserDefaults küçük tercihler içindir: tek bir plist dosyası, ilk erişimde tamamı belleğe alınır. \
            Büyüyen veri ya da sır için uygun değildir.
            """)
        }
    }

    // MARK: - Keychain

    private var keychainSection: some View {
        Section {
            // Sonuç satırları düğmelerin ÜSTÜNDE: Dokununca sonuç, ekranın altındaki sekme çubuğunun arkasında kalmasın.
            // `LabeledContent` yerine `HStack`: LabeledContent başlık ve değeri tek bir erişilebilirlik öğesinde
            // birleştirir ("Durum, Kaydedildi"); burada değeri ayrı bir öğe olarak okumak istiyoruz.
            HStack {
                Text("Durum")
                Spacer()
                Text(verbatim: keychainStatus)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(ID.keychainStatus)
            }
            HStack {
                Text("Okunan token")
                Spacer()
                // Sırrı ekranda (ve ekran görüntülerinde, loglarda) açık göstermiyoruz.
                Text(verbatim: maskedToken)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(ID.keychainMaskedToken)
            }
            Button("Sahte token'ı Keychain'e kaydet", action: saveToken)
                .accessibilityIdentifier(ID.keychainSaveButton)
            Button("Keychain'den oku", action: readToken)
                .accessibilityIdentifier(ID.keychainReadButton)
            Button("Keychain'den sil", role: .destructive, action: deleteToken)
                .accessibilityIdentifier(ID.keychainDeleteButton)
        } header: {
            Text("Sır → Keychain")
                .textCase(nil)
        } footer: {
            Text("""
            Token, parola ve şifreleme anahtarları Keychain'e yazılır: ayrı, şifreli bir veritabanı; ne zaman \
            okunabileceği seçilebilir (burada "ilk kilit açılışından sonra, yalnızca bu cihazda"). \
            Bu token sahte bir demo değeridir.
            """)
        }
    }

    // Keychain çağrıları senkron ve kısa; tek bir düğme dokunuşu için ana thread'de yapmak kabul edilebilir.

    private func saveToken() {
        do {
            try keychain.save(DemoToken.value, account: DemoToken.account)
            keychainStatus = "Kaydedildi"
            maskedToken = "—"
        } catch {
            keychainStatus = "Hata: \(error.localizedDescription)"
        }
    }

    private func readToken() {
        do {
            if let token = try keychain.read(account: DemoToken.account) {
                keychainStatus = "Okundu"
                maskedToken = DemoToken.masked(token)
            } else {
                keychainStatus = "Kayıt yok"
                maskedToken = "—"
            }
        } catch {
            keychainStatus = "Hata: \(error.localizedDescription)"
        }
    }

    private func deleteToken() {
        do {
            try keychain.delete(account: DemoToken.account)
            keychainStatus = "Silindi"
            maskedToken = "—"
        } catch {
            keychainStatus = "Hata: \(error.localizedDescription)"
        }
    }
}

/// Demo için SAHTE bir erişim token'ı. Gerçek bir sır asla kaynak koduna yazılmaz; sunucudan gelir ve
/// doğrudan Keychain'e konur.
enum DemoToken {
    static let account = "demo-access-token"
    static let value = "bk_demo_7Q2X9F4K"

    /// Sırrı maskeler: ilk 4 ve son 4 karakter görünür, arası "•". 8 karakter ya da daha kısaysa tamamı gizlenir.
    /// Ör. "bk_demo_7Q2X9F4K" → "bk_d••••••••9F4K".
    static func masked(_ secret: String) -> String {
        let visible = 4
        guard secret.count > visible * 2 else { return String(repeating: "•", count: secret.count) }
        let hiddenCount = secret.count - visible * 2
        return "\(secret.prefix(visible))\(String(repeating: "•", count: hiddenCount))\(secret.suffix(visible))"
    }
}
