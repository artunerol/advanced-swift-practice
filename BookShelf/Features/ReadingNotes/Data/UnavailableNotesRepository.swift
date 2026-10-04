import Foundation

/// Depo açılamadığında (ör. Core Data dosyası bozuk, disk dolu) fabrikanın döndürdüğü yedek repository.
///
/// Her çağrıda aynı `NotesRepositoryError`'ı fırlatır. Neden çökmek ya da sessizce bellekteki depoya geçmek yerine bu?
/// - Çökmek (`fatalError`) kullanıcının bütün uygulamayı kullanamaması demek; sorun yalnızca notlarda.
/// - Sessizce bellekteki depoya geçmek daha kötü: Kullanıcı not yazar, "kaydedildi" sanır, uygulama kapanınca kaybolur.
/// - Bu tip ise hatayı ekrana kadar taşır; ekran "Notlar kaydedilemedi: ..." gösterir ve kullanıcı durumu bilir.
///
/// Fabrikanın imzası (`make(_:) -> any NotesRepository`) hata fırlatmıyor; bu tip sayesinde fırlatmak zorunda da kalmıyor.
struct UnavailableNotesRepository: NotesRepository {
    let error: NotesRepositoryError

    func fetchAll() throws -> [ReadingNote] { throw error }
    func save(_ note: ReadingNote) throws { throw error }
    func delete(id: ReadingNote.ID) throws { throw error }
    func deleteAll() throws { throw error }
}
