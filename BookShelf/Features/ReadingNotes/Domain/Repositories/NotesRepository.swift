import Foundation

/// **Domain katmanı → Repository sözleşmesi.** Notların nerede saklandığını soyutlar.
///
/// Dependency Inversion Principle (SOLID'deki "D") tam olarak burada:
/// - Üst seviye kod (use case'ler, VIPER interactor, MVVM view model) bu protokole bağlıdır.
/// - Alt seviye kod (UserDefaults, dosya, Core Data, SwiftData uygulamaları) da bu protokole bağlıdır.
/// - Protokolün **sahibi domain katmanıdır**; yani bağımlılık oku "depolama → domain" yönünü gösterir,
///   tersi değil. Depolamayı değiştirmek domain'e ve ekranlara dokunmayı gerektirmez.
///
/// Hangi somut uygulamanın verileceğine ise *Dependency Injection* karar verir (bkz. `AppDependencies`).
protocol NotesRepository: Sendable {
    /// Tüm notlar, **en yeni en başta** olacak şekilde.
    func fetchAll() async throws -> [ReadingNote]
    /// Aynı `id`'ye sahip not varsa günceller, yoksa ekler (upsert).
    func save(_ note: ReadingNote) async throws
    /// Notu siler. Not yoksa hata fırlatmaz (idempotent).
    func delete(id: ReadingNote.ID) async throws
    func deleteAll() async throws
}

/// Depolama katmanının üst katmanlara sızdırdığı tek hata tipi. Alttaki hata (`NSError`, `DecodingError`...)
/// mesaj olarak taşınır; üst katmanlar Core Data ya da dosya sistemi hatalarını tanımak zorunda kalmaz.
enum NotesRepositoryError: Error, Equatable, LocalizedError {
    case storageFailure(reason: String)

    var errorDescription: String? {
        switch self {
        case .storageFailure(let reason): "Notlar kaydedilemedi: \(reason)"
        }
    }
}
