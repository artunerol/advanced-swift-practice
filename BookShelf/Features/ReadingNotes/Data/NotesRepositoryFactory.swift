import Foundation

// GEÇİCİ İSKELET (çalışır durumda) — sahibi: persistence. Gerçek depolama türlerini uygula;
// `NotesStorageKind` vakalarını ve `NotesRepositoryFactory.make(_:)` imzasını koru.

/// Notların saklanabileceği yerler. Mimari demosunda kullanıcı bunlar arasında geçiş yapabilir:
/// ekran kodu değişmeden depolama değişir → Dependency Inversion'ın canlı kanıtı.
enum NotesStorageKind: String, CaseIterable, Identifiable, Sendable {
    case inMemory
    case userDefaults
    case file
    case coreData
    case swiftData

    var id: String { rawValue }

    /// Uygulamanın normal çalışırken kullandığı depolama.
    static let appDefault: NotesStorageKind = .inMemory
}

/// Seçilen türe göre somut repository üretir (Factory). Hangi sınıfın oluşturulacağı bilgisi tek yerde toplanır.
enum NotesRepositoryFactory {
    static func make(_ kind: NotesStorageKind) -> any NotesRepository {
        InMemoryNotesRepository()
    }
}
