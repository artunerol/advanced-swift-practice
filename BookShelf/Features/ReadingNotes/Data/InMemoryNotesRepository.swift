import Foundation

/// **Data katmanı → En basit repository:** notları sadece bellekte tutar; uygulama kapanınca kaybolur.
///
/// Nerede kullanılır? Unit testlerde ve UI testlerinde (her test temiz bir durumla başlar),
/// ayrıca diğer depolama türleriyle karşılaştırma için "kalıcı olmayan" referans noktası olarak.
///
/// Neden `actor`? Protokol `Sendable` istiyor ve biz değiştirilebilir bir dizi tutuyoruz.
/// Actor bu durumu korur; protokolün `async` gereksinimlerini izole metotlarıyla doğrudan karşılar.
actor InMemoryNotesRepository: NotesRepository {
    private var notes: [ReadingNote]

    init(notes: [ReadingNote] = []) {
        self.notes = notes
    }

    func fetchAll() -> [ReadingNote] {
        notes.sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ note: ReadingNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
    }

    func delete(id: ReadingNote.ID) {
        notes.removeAll { $0.id == id }
    }

    func deleteAll() {
        notes.removeAll()
    }
}
