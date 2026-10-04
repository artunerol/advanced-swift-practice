import Foundation

/// **Data katmanı → Dosya ile notlar.** Notlar `Codable` ile JSON'a çevrilip tek bir dosyaya yazılır.
///
/// Ne zaman dosya? Belgeler, görseller, dışa aktarılan veriler ve "hepsini oku / hepsini yaz" ile yetinen
/// küçük-orta boy model listeleri. Sorgu, ilişki ya da çok büyük veri gerekiyorsa Core Data / SwiftData / SQLite.
///
/// Üç önemli ayrıntı:
/// 1. **Klasör:** `Application Support`. iOS'ta bu klasörün var olacağı garanti değildir; ilk yazmadan önce
///    `createDirectory(withIntermediateDirectories: true)` ile oluşturulur (zaten varsa hata vermez).
/// 2. **Atomik yazma (`.atomic`):** Veri önce geçici bir dosyaya yazılır, sonra tek adımda asıl dosyanın yerine
///    taşınır (rename). Yazma yarıda kesilirse (uygulama öldürüldü, disk doldu) eski dosya sağlam kalır;
///    yarım yazılmış, bozuk bir JSON hiç oluşmaz.
/// 3. **Dosya koruması (`.completeFileProtection`):** Dosya, cihaz kilitliyken şifreli ve okunamaz olur.
///    Uygulama dosyalarının varsayılanı `completeUntilFirstUserAuthentication`'dır (açılıştan sonraki ilk kilit
///    açılıştan itibaren okunabilir). `.complete` daha güvenlidir ama cihaz kilitliyken arka planda çalışan kod
///    (ör. background fetch) dosyayı okuyamaz; seçim buna göre yapılır. Simülatörde fark gözlenmez.
///
/// Neden `actor`? `save` "oku → değiştir → yaz" yapar; actor bu adımları sıraya sokarak kayıp güncellemeyi önler.
actor FileNotesRepository: NotesRepository {
    static let defaultFileName = "notes.json"

    private let fileURL: URL
    private let fileManager = FileManager.default

    /// - Parameter fileURL: Testlerde geçici bir klasördeki dosya verilir.
    init(fileURL: URL) {
        self.fileURL = fileURL
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
        try write(notes)
    }

    func delete(id: ReadingNote.ID) throws {
        var notes = try loadNotes()
        let countBefore = notes.count
        notes.removeAll { $0.id == id }
        if notes.count != countBefore {
            try write(notes)
        }
    }

    func deleteAll() throws {
        // Dosya yoksa silinecek bir şey de yok: idempotent.
        guard fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return }
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw NotesRepositoryError.storageFailure(reason: "Dosya silinemedi: \(error.localizedDescription)")
        }
    }

    // MARK: - Okuma / yazma

    private func loadNotes() throws -> [ReadingNote] {
        guard fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([ReadingNote].self, from: data)
        } catch {
            // Bozuk dosyayı "boş" sayıp üzerine yazmak kullanıcının bütün notlarını silerdi; hatayı yukarı bildiriyoruz.
            throw NotesRepositoryError.storageFailure(reason: "Not dosyası okunamadı: \(error.localizedDescription)")
        }
    }

    private func write(_ notes: [ReadingNote]) throws {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            // Okunabilir JSON: dosyayı simülatör klasöründe açıp incelemek kolay olsun. Gerçek uygulamada gerekmez.
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(notes).write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw NotesRepositoryError.storageFailure(reason: "Not dosyası yazılamadı: \(error.localizedDescription)")
        }
    }
}
