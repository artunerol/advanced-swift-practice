import Foundation
import Observation

/// "Notlar" bölümünün view model'i: Beş depolama türünü AYNI arayüzle (`any NotesRepository`) kullanır.
///
/// Bu sınıfta `UserDefaults`, `FileManager`, Core Data ya da SwiftData kelimesi geçmez. Hepsi aynı dört metodu
/// (`fetchAll`, `save`, `delete`, `deleteAll`) karşılıyor; bu yüzden biri diğerinin yerine konabiliyor
/// (Liskov yerine geçme ilkesi). Hangi somut tipin oluşturulacağına `NotesRepositoryFactory` karar veriyor.
///
/// "Yeniden aç" (`reopen`): Aynı depoya YENİ bir repository örneğiyle bağlanıp tekrar okur. Uygulamayı kapatıp
/// açmanın küçük bir benzetimidir: Bellekteki depo yeni örnekte boş gelir, diğerleri veriyi diskten okur.
@MainActor
@Observable
final class NotesStorageInspector {
    let location: PersistenceLocation

    private(set) var selectedKind: NotesStorageKind = .file
    /// Tür başına not sayısı. Okunamadıysa (hata) değer yok.
    private(set) var counts: [NotesStorageKind: Int] = [:]
    /// Seçili türün notları, en yeni en üstte.
    private(set) var selectedNotes: [ReadingNote] = []
    /// Son işlemin kullanıcıya açıklaması.
    private(set) var message: String?
    /// Bir işlem sürerken düğmeler kapalı: Art arda dokunuşlar iki işlemi iç içe geçirmesin.
    private(set) var isWorking = false

    /// Açılmış repository'ler. Her tür ilk ihtiyaçta bir kez açılır; `reopen` yenisiyle değiştirir.
    private var repositories: [NotesStorageKind: any NotesRepository] = [:]
    /// Eklenen örnek notları numaralandırmak için.
    private var sampleCounter = 0

    init(location: PersistenceLocation) {
        self.location = location
    }

    /// Ekran açılınca: tüm türlerin sayısını ve seçili türün notlarını yükler.
    func load() async {
        await perform {
            for kind in NotesStorageKind.allCases {
                let notes = try await self.repository(for: kind).fetchAll()
                self.counts[kind] = notes.count
                if kind == self.selectedKind {
                    self.selectedNotes = notes
                }
            }
        }
    }

    func select(_ kind: NotesStorageKind) async {
        await perform {
            self.selectedKind = kind
            self.message = nil
            try await self.reloadSelected()
        }
    }

    func addSample() async {
        await perform {
            self.sampleCounter += 1
            let note = ReadingNote(text: "Örnek not \(self.sampleCounter) · \(self.selectedKind.storageTitle)")
            try await self.repository(for: self.selectedKind).save(note)
            try await self.reloadSelected()
            self.message = "Eklendi: \"\(note.text)\""
        }
    }

    /// Aynı depoya yeni bir örnekle bağlanır ve not sayısını karşılaştırır.
    func reopen() async {
        await perform {
            let kind = self.selectedKind
            let countBefore = self.counts[kind] ?? 0
            // Eski örneği bırakıp yenisini açıyoruz. In-memory için bu, verinin de gitmesi demek.
            let fresh = await Self.openRepository(kind, location: self.location)
            self.repositories[kind] = fresh
            try await self.reloadSelected()
            let countAfter = self.counts[kind] ?? 0
            self.message = Self.reopenVerdict(before: countBefore, after: countAfter)
        }
    }

    func deleteAll() async {
        await perform {
            try await self.repository(for: self.selectedKind).deleteAll()
            try await self.reloadSelected()
            self.message = "Seçili depodaki notlar silindi."
        }
    }

    /// "Yeniden aç" sonucunun açıklaması. Ayrı ve `static`: Mantık SwiftUI olmadan test edilebilsin.
    nonisolated static func reopenVerdict(before: Int, after: Int) -> String {
        switch (before, after) {
        case (0, _):
            "Depo zaten boştu; önce bir not ekle, sonra yeniden aç."
        case let (before, after) where after == before:
            "Yeni örnek \(after) not gördü: veri kalıcı."
        case (_, 0):
            "Yeni örnek 0 not gördü: veri yalnızca eski örneğin belleğindeydi."
        default:
            "Yeni örnek \(after) not gördü (öncesinde \(before))."
        }
    }

    // MARK: - Yardımcılar

    private func reloadSelected() async throws {
        let notes = try await repository(for: selectedKind).fetchAll()
        counts[selectedKind] = notes.count
        selectedNotes = notes
    }

    private func repository(for kind: NotesStorageKind) async -> any NotesRepository {
        if let existing = repositories[kind] {
            return existing
        }
        let repository = await Self.openRepository(kind, location: location)
        // `await` sırasında başka bir çağrı aynı türü açmış olabilir (actor reentrancy'nin ana actor'deki hali).
        // Önce gelenin örneğini kullanıyoruz ki iki ayrı in-memory depo oluşmasın.
        if let existing = repositories[kind] {
            return existing
        }
        repositories[kind] = repository
        return repository
    }

    /// Depoyu açar (SQLite dosyasını açmak, şemayı kontrol etmek ana thread'de yapılmasın).
    ///
    /// `nonisolated async`: Bu projede "nonisolated async fonksiyonlar çağıranın actor'ünde çalışsın" ayarı
    /// (`NonisolatedNonsendingByDefault`) KAPALI; bu yüzden fonksiyon ana actor'den çağrılsa da global executor'da,
    /// yani arka planda çalışır. (Ayar açık olsaydı aynı etki için `@concurrent` yazmak gerekirdi.)
    /// Dönen değer `any NotesRepository`, yani `Sendable`: actor sınırını güvenle geçer.
    private nonisolated static func openRepository(
        _ kind: NotesStorageKind,
        location: PersistenceLocation
    ) async -> any NotesRepository {
        NotesRepositoryFactory.make(kind, location: location)
    }

    /// İşlemi `isWorking` bayrağıyla sarar ve hatayı mesaja çevirir.
    private func perform(_ work: () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
        } catch {
            message = "Hata: \(error.localizedDescription)"
        }
    }
}
