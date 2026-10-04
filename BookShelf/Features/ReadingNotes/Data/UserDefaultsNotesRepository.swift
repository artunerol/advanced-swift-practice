import Foundation

/// **Data katmanı → UserDefaults ile notlar.** Tüm notlar JSON'a çevrilip TEK bir anahtar altında saklanır.
///
/// Bu sınıf, UserDefaults'un neden büyüyen veri için **uygun olmadığını** göstermek için var:
/// - Her `save` çağrısında TÜM dizi yeniden kodlanır ve yazılır. 1 not eklemek için 1.000 notu yazarsın.
/// - UserDefaults bir **plist dosyasıdır** (`Library/Preferences/<bundle-id>.plist`). Alan (domain) ilk erişimde
///   bütünüyle belleğe alınır; büyüdükçe bellek ve açılış süresi maliyeti artar.
/// - Sorgu yoktur: "şu kitabın notları" demek için hepsini okuyup filtrelersin.
/// - Kendine ait bir şifrelemesi yoktur: Dosya yalnızca diğer uygulama dosyaları gibi cihazın Data Protection'ıyla
///   korunur. Token/parola gibi sırlar için Keychain kullanılır (bkz. `KeychainStore`).
///
/// UserDefaults'un doğru kullanımı küçük **tercihlerdir**: tema, okuma hızı, "tanıtım ekranı görüldü" bayrağı.
/// Bu projedeki örnek: `BookDetailViewModel.readingSpeedKey`.
///
/// Neden `actor`? `save` bir "oku → değiştir → yaz" işlemidir. İki çağrı aynı anda çalışırsa ikisi de eski
/// diziyi okur ve biri diğerinin eklediği notu ezer (lost update). Actor bu adımları sıraya sokar.
/// Ayrıca `UserDefaults` `Sendable` değil; actor onu kendi izolasyonu içinde güvenle tutar.
/// (Not: Sıralama yalnızca BU örnek içindir. Aynı anahtara yazan iki ayrı örnek yine birbirini ezebilir.)
actor UserDefaultsNotesRepository: NotesRepository {
    /// Varsayılan anahtar. Ayarlarla karışmasın diye ön ekli.
    static let defaultKey = "readingNotes.v1"

    private let defaults: UserDefaults
    private let key: String

    /// - Parameters:
    ///   - defaults: Testlerde `UserDefaults(suiteName:)` verilir; böylece testler `.standard`'ı kirletmez.
    ///     `UserDefaults` Sendable olmadığı için actor'e verdiğin örneği dışarıda kullanmaya devam edemezsin
    ///     (Swift 6: "sending ... risks causing data races"). Her seferinde yeni bir örnek ver; aynı suite adıyla
    ///     açılan örnekler aynı veriyi görür (bkz. `PersistenceLocation.defaults`).
    ///   - key: Sona eklenen `v1`: Kayıt biçimi değişirse yeni anahtarla (`v2`) başlayıp eskisini taşımak kolaylaşır.
    init(defaults: UserDefaults, key: String = UserDefaultsNotesRepository.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    func fetchAll() throws -> [ReadingNote] {
        try loadNotes().sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ note: ReadingNote) throws {
        var notes = try loadNotes()
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
        try store(notes)
    }

    func delete(id: ReadingNote.ID) throws {
        var notes = try loadNotes()
        let countBefore = notes.count
        notes.removeAll { $0.id == id }
        // Silinecek bir şey yoksa yazmaya gerek yok; yine de hata fırlatmıyoruz (idempotent).
        if notes.count != countBefore {
            try store(notes)
        }
    }

    func deleteAll() {
        defaults.removeObject(forKey: key)
    }

    // MARK: - Kayıt biçimi

    private func loadNotes() throws -> [ReadingNote] {
        // Anahtar hiç yoksa `data(forKey:)` nil döner: bu bir hata değil, "henüz not yok" demek.
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([ReadingNote].self, from: data)
        } catch {
            // Bozuk veriyi sessizce boş dizi saymıyoruz: sonraki `save` bütün eski notların üzerine yazardı.
            throw NotesRepositoryError.storageFailure(reason: "UserDefaults verisi okunamadı: \(error.localizedDescription)")
        }
    }

    private func store(_ notes: [ReadingNote]) throws {
        do {
            // Not: UserDefaults `Data`'yı doğrudan saklayabilir; Codable dizi → JSON `Data` → plist içinde tek bir değer.
            defaults.set(try JSONEncoder().encode(notes), forKey: key)
        } catch {
            throw NotesRepositoryError.storageFailure(reason: "Notlar kodlanamadı: \(error.localizedDescription)")
        }
    }
}
