import Foundation

/// Okuma notları özelliğinin üç use case'ini bir arada taşıyan küçük paket.
///
/// VIPER interactor'ı da MVVM view model'i de bu paketi `init` ile alır (constructor injection). İki arayüzün
/// **aynı** iş kurallarını çalıştırdığının en net kanıtı budur: fark sadece sunum (presentation) katmanında.
///
/// ## Clean Architecture: bağımlılık kuralı (dependency rule)
/// ```
///   Presentation (VIPER, MVVM)  ──▶  Domain (Entity, Use case, NotesRepository protokolü)  ◀──  Data (depolar)
///        UIKit / SwiftUI                     sadece Foundation                               InMemory, Core Data...
/// ```
/// Oklar "bilir / import eder / bağımlıdır" demek ve hep **içeri**, domain'e doğru bakar:
/// - Domain hiçbir dış katmanı bilmez: bu klasörde `import UIKit`, `SwiftUI`, `CoreData` yok, olmamalı.
/// - Data katmanı domain'in protokolünü uygular (Core Data deposu → `NotesRepository`). Ok yine içeri bakar,
///   oysa çalışma anında çağrı dışarı (use case → depo) gider. Bu ters çevirme *Dependency Inversion*'dır.
///
/// ## Use case'ler için protokol tanımlamalı mı? (bilinçli karar)
/// Burada use case'ler somut `struct`. Her biri için `protocol AddNoteUseCaseProtocol` yazmadık, çünkü:
/// - Test dikişi (seam) zaten var: `NotesRepository`. Testler gerçek use case'leri `InMemoryNotesRepository` ile
///   çalıştırır; yani iş kuralları da teste dahil olur ve sahte (mock) davranış gerçek kuraldan sapamaz.
/// - Her protokol bir dosya, bir mock ve bir dolaylılık daha demek; okunabilirliği düşürür.
/// Ne zaman protokol eklenir? Use case ağır bir yan etki içeriyorsa (ağ, ödeme, analitik) ya da presenter'ı/view
/// model'i use case'in iç davranışından tamamen yalıtarak test etmek gerekiyorsa. VIPER tarafında o yalıtımı zaten
/// `NotesListInteractorInput` protokolü sağlıyor (presenter testleri sahte interactor kullanır).
struct NotesUseCases: Sendable {
    let fetch: FetchNotesUseCase
    let add: AddNoteUseCase
    let delete: DeleteNoteUseCase

    /// Hepsi aynı depoyu kullanır. `now` sadece testlerde sabit tarih vermek için.
    init(repository: any NotesRepository, now: @escaping @Sendable () -> Date = { Date() }) {
        fetch = FetchNotesUseCase(repository: repository)
        add = AddNoteUseCase(repository: repository, now: now)
        delete = DeleteNoteUseCase(repository: repository)
    }
}
