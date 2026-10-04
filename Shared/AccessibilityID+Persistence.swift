import Foundation

// Sahibi: Kalıcılık demosu (Mülakat → "iOS'ta veri saklama yolları"). `PersistenceDemoView` ve UI testleri kullanır.
extension AccessibilityID {
    enum Persistence {
        /// Ekranın üstündeki bölüm seçici (segmented). Bölümler GÖRÜNEN etiketleriyle seçilir:
        /// `app.segmentedControls[Persistence.sectionPicker].buttons[Persistence.notesSegment].tap()`
        static let sectionPicker = "persistence.sectionPicker"
        /// Demonun `List`'i. Tür: collectionView. UI testleri alttaki satırlara kaydırmak için kullanır.
        static let list = "persistence.list"
        static let settingsSegment = "Ayar & Sır"
        static let notesSegment = "Notlar"
        static let comparisonSegment = "Karşılaştır"

        // MARK: Ayar (UserDefaults · @AppStorage)

        /// Okuma hızı stepper'ı. Tür: stepper; içindeki düğmeler sırayla azalt (0) ve artır (1).
        static let readingSpeedStepper = "persistence.readingSpeed.stepper"
        /// Ayarın etkisi: "400 sayfalık bir kitap ≈ 10 sa". Tür: staticText.
        static let readingSpeedExample = "persistence.readingSpeed.example"

        // MARK: Sır (Keychain)

        static let keychainSaveButton = "persistence.keychain.save"
        static let keychainReadButton = "persistence.keychain.read"
        static let keychainDeleteButton = "persistence.keychain.delete"
        /// Son işlemin sonucu: "Kaydedildi", "Okundu", "Kayıt yok", "Silindi" ya da "Hata: ...". Tür: staticText.
        static let keychainStatus = "persistence.keychain.status"
        /// Okunan token'ın maskelenmiş hali, ör. "bk_d••••••••9F4K". Okunmadıysa "—". Tür: staticText.
        static let keychainMaskedToken = "persistence.keychain.maskedToken"

        // MARK: Notlar (NotesRepository uygulamaları)

        /// Depolama türü satırı (düğme). `value` seçiliyse "Seçili", değilse boş.
        /// - Parameter kindRawValue: `StorageKindRawValue` sabitlerinden biri.
        static func kindRow(_ kindRawValue: String) -> String { "persistence.notes.kind.\(kindRawValue)" }
        /// Seçili türdeki not sayısı: "Not sayısı: 2". Tür: staticText.
        static let selectedCount = "persistence.notes.selectedCount"
        /// "Kapatıp açınca kalır mı? Evet" / "... Hayır". Tür: staticText.
        static let selectedSurvivesRelaunch = "persistence.notes.survivesRelaunch"
        static let addSampleButton = "persistence.notes.addSample"
        /// Aynı depoya YENİ bir repository örneğiyle bağlanıp yeniden okur (uygulamayı kapatıp açmanın benzetimi).
        static let reopenButton = "persistence.notes.reopen"
        static let deleteAllButton = "persistence.notes.deleteAll"
        /// Son işlemin açıklaması. Yeniden açma sonrası "Yeni örnek 1 not gördü: veri kalıcı." gibi. Tür: staticText.
        static let notesMessage = "persistence.notes.message"

        /// `NotesStorageKind` ham değerleri. UI testleri uygulama modülünü göremediği için burada tekrar ediliyor;
        /// bir birim testi (`NotesRepositoryFactoryTests`) ikisinin aynı kaldığını doğrular.
        enum StorageKindRawValue {
            static let inMemory = "inMemory"
            static let userDefaults = "userDefaults"
            static let file = "file"
            static let coreData = "coreData"
            static let swiftData = "swiftData"
        }

        // MARK: Karşılaştırma tablosu

        /// Karşılaştırma tablosundaki açılır satır (`DisclosureGroup`). `optionID`: `StorageComparisonItem.id`, ör. "keychain".
        static func comparisonRow(_ optionID: String) -> String { "persistence.comparison.\(optionID)" }
    }
}
