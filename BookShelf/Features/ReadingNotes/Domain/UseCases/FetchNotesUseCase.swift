import Foundation

/// **Domain katmanı → Use case.** Tüm notları, en yeni en başta olacak şekilde getirir.
///
/// Şu an tek satırlık bir iletici gibi görünüyor; neden yine de var?
/// - Arayüz katmanı (presenter, view model) depoyu (`NotesRepository`) hiç görmez; sadece use case'leri görür.
///   Yarın "arşivlenmiş notları gizle" ya da "önce sabitlenenler" kuralı gelirse değişecek tek yer burası olur.
/// - Sıralama sözleşmesini (en yeni başta) burada **garanti** ediyoruz. Protokol bunu söylüyor ama yeni yazılan bir
///   depo (ör. Core Data) yanlış sıralarsa ekranlar bozulmasın. Kural iç halkada, depo dış halkada.
///
/// Mülakat notu: Use case'leri her özellikte zorunlu saymak gereksiz katman (boilerplate) üretir. Mantık gerçekten
/// "depodan al, göster" ise birçok ekip arayüzü doğrudan repository'ye bağlar. Burada üç use case'i de gösteriyoruz
/// ki VIPER ve MVVM'in AYNI iş mantığını paylaştığı görülsün.
struct FetchNotesUseCase: Sendable {
    private let repository: any NotesRepository

    init(repository: any NotesRepository) {
        self.repository = repository
    }

    /// `nonisolated` bir `async` fonksiyon (bu projede varsayılan): gövdesi ana thread'de değil, global executor'de
    /// çalışır. Çağıran (`@MainActor` presenter/view model) `await` sırasında ana thread'i bırakır.
    func execute() async throws -> [ReadingNote] {
        try await repository.fetchAll().sorted { $0.createdAt > $1.createdAt }
    }
}
