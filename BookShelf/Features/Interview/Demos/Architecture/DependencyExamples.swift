import Foundation

// DIP vs DI demosunun gerçek (derlenen ve test edilen) örnekleri. Üç sayaç aynı işi yapar: depodaki notları sayar.
// Fark, bağımlılığı NASIL aldıkları ve NEYE bağlı oldukları.

/// **(a) Sıkı bağlılık (tight coupling): ne DI ne DIP.**
///
/// Bağımlılığını kendisi oluşturur. Sonuçları:
/// - Hangi depoyu kullanacağına dışarıdan karar verilemez; demoda "Dolu depo" seçilse bile 0 sayar.
/// - Test etmek için gerçek depoyu kullanmak zorundasın; sahte bir depo veremezsin.
/// - Depo değişirse (ör. Core Data) bu tipin kaynak kodu da değişmek zorunda.
struct TightlyCoupledNoteCounter {
    private let repository = InMemoryNotesRepository()

    /// Dikkat: somut actor'ün `fetchAll()`'u hata fırlatmıyor, bu yüzden burada `try` yok. Somut tipe bağlanınca
    /// onun ayrıntıları (hata fırlatmama, actor olması) da bu koda sızar.
    func count() async -> Int {
        await repository.fetchAll().count
    }
}

/// **(b) DI var, DIP yok: somut tipi enjekte etmek.**
///
/// Bağımlılık dışarıdan geliyor (constructor injection), ama tipi somut bir sınıf. Testte farklı bir
/// `InMemoryNotesRepository` örneği verilebilir; fakat Core Data deposu vermek **derleme hatasıdır**.
/// Üst seviye kod hâlâ alt seviye bir ayrıntıya bağlı; bağımlılığın yönü tersine dönmedi.
struct ConcreteInjectedNoteCounter {
    let repository: InMemoryNotesRepository

    func count() async -> Int {
        await repository.fetchAll().count
    }
}

/// **(c) DI + DIP: soyutlamayı enjekte etmek.**
///
/// Bağımlılık dışarıdan geliyor VE tipi domain'in tanımladığı protokol. Bellek, dosya, Core Data, sahte depo...
/// `NotesRepository`'yi uygulayan her şey çalışır; bu tip hiçbirini tanımaz.
struct InjectedNoteCounter {
    let repository: any NotesRepository

    func count() async throws -> Int {
        try await repository.fetchAll().count
    }
}

/// **Method injection**: bağımlılık (biçimlendirme stratejisi) nesneye değil, tek bir çağrıya parametre olarak verilir.
///
/// Ne zaman? Bağımlılık çağrıdan çağrıya değişiyorsa ya da nesnenin onu saklamasına gerek yoksa.
/// Standart kütüphanedeki en tanıdık örnek: `sorted(by:)` sıralama stratejisini çağrıya enjekte eder.
enum NotesPlainTextExporter {
    /// Her not için "• metin (ayrıntı)" satırı üretir.
    static func export(_ notes: [ReadingNote], using formatter: some NoteFormatter) -> String {
        notes
            .map { "• \($0.text) (\(formatter.detail(for: $0)))" }
            .joined(separator: "\n")
    }
}

/// Demoda kullanılan sabit örnek notlar. Tarihler sabit; "Uzunluk" stratejisinin çıktısı her cihazda aynıdır.
enum DependencyDemoSamples {
    static let notes: [ReadingNote] = [
        ReadingNote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            text: "Tutunamayanlar'ın ilk bölümü ağır ama ödüllendirici.",
            createdAt: Date(timeIntervalSince1970: 1_790_000_000)
        ),
        ReadingNote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            text: "Kürk Mantolu Madonna\nRaif Efendi'nin defteri.",
            createdAt: Date(timeIntervalSince1970: 1_789_000_000)
        ),
    ]

    /// "Dolu depo" seçeneği için üç notlu bir depo.
    static func filledRepository() -> InMemoryNotesRepository {
        InMemoryNotesRepository(notes: notes + [
            ReadingNote(text: "Üçüncü not.", createdAt: Date(timeIntervalSince1970: 1_788_000_000)),
        ])
    }
}
