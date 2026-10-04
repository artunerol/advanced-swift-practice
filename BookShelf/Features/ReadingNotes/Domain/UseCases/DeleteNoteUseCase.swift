import Foundation

/// **Domain katmanı → Use case.** Bir notu siler.
///
/// Depo sözleşmesine göre silme *idempotent*: not zaten yoksa hata fırlatmaz. Böylece kullanıcı aynı satırı iki kez
/// kaydırırsa (ya da iki ekran aynı notu silerse) hata penceresi çıkmaz.
struct DeleteNoteUseCase: Sendable {
    private let repository: any NotesRepository

    init(repository: any NotesRepository) {
        self.repository = repository
    }

    func execute(id: ReadingNote.ID) async throws {
        try await repository.delete(id: id)
    }
}
