import SwiftUI

extension InterviewTopic {
    /// VIPER'ı bir servis çağrısıyla pekiştirir: Kitap Arama modülü (yazarken arama, iptal, dört tür use case) ve her
    /// katmanın nasıl test edildiği. "Clean Architecture, VIPER ve MVVM" konusunun devamı.
    static let viperService = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.viperService,
        section: .architecture,
        question: "VIPER'da bir servis çağrısı nasıl akar? Her katmanı nasıl test edersin?",
        shortAnswer: [
            """
            Akış tek yönlü ve her ok bir protokol: View olayı iletir (`didChangeSearchText`), Presenter karar verir \
            (`interactor.search(query:trigger:)`), Interactor bir `Task` açıp use case'i `await` eder, use case servisi \
            çağırıp iş kurallarını uygular. Sonuç geri döner: Interactor `output`'a (Presenter'a) bildirir, Presenter onu \
            ekran durumuna çevirip `view.render(...)` der. Router yalnızca navigasyonda devreye girer: satıra dokununca detayı push eder.
            """,
            """
            Async sınır Interactor'da. View ve Presenter senkron ve `@MainActor`; Interactor senkron çağrıyı `Task`'a çevirir. \
            `await` sırasında ana actor serbest kalır, nonisolated use case arka planda çalışır, sonuç ana actor'e döner.
            """,
            """
            İptal de Interactor'da: Uçuştaki arama bir `Task` olarak saklanır; yeni sorgu öncekini iptal eder ("son arama \
            kazanır"), yazarken 300 ms debounce beklenir. İptal edilmiş aramanın ne sonucu ne hatası bildirilir: \
            `await`'ten sonraki `Task.checkCancellation()` geç gelen sonucu, `catch _ where Task.isCancelled` geç gelen \
            hatayı (ör. `URLSession`'ın `URLError(.cancelled)`'ı) düşürür.
            """,
            """
            İş kuralları use case'lerde ve türleri farklı: sorgu + kural (en az 2 harf, Türkçe katlama, önce başlık), \
            birleştirme (`async let` ile iki istek, kısmi hata politikası), komut (favori, yeni durumu döndürür), yerel \
            depolama politikası (son 5 arama, tekrar yok).
            """,
            """
            Test katman katman: use case → stub servisle kural; Interactor → spy use case + spy output, async test ve \
            `fulfillment(of:)`; Presenter → spy view + mock interactor + spy router, tamamen senkron; Router → `build` \
            bağlantıları ve retain cycle; View → `render(state)`; uçtan uca akış → XCUITest.
            """,
        ],
        followUps: [
            FollowUp(
                question: "Neden hepsi @MainActor?",
                answer: """
                View bir UIViewController, SDK'da zaten @MainActor. Presenter view'ı, Interactor da Presenter'ı senkron \
                çağırıyor; hepsi aynı actor'deyse bu çağrılar düz fonksiyon çağrısı olur: hop yok, await yok, durum tek \
                seri yerde, data race imkânsız. Yavaş iş ana actor'de değil: nonisolated async use case'lerde; her await \
                ana actor'den çıkıp geri döner. Xcode 26 şablonlarındaki "Default Actor Isolation = MainActor" aynı fikri \
                modül varsayılanı yapar; dışarı çıkmak için nonisolated ve @concurrent kullanılır.
                """
            ),
            FollowUp(
                question: "İptal nerede yaşar, neden Presenter'da değil?",
                answer: """
                Interactor'da: Task'ın sahibi o, use case'i o await ediyor. Presenter senkron ve UIKit'siz kalmalı; Task \
                tutarsa testleri bekleme gerektirir ve iş mantığı sunuma sızar. Interactor yeni aramada önceki Task'ı \
                cancel() eder, await'ten sonra Task.checkCancellation() ile eski sonucu düşürür ve deinit'te uçuştaki \
                işi iptal eder. İptal edilmiş task'ın hatası da bildirilmez: Ölçüt hatanın türü değil Task.isCancelled, \
                çünkü URLSession iptali CancellationError değil URLError(.cancelled) olarak gelir.
                """
            ),
            FollowUp(
                question: "Use case'lere burada neden protokol yazdın, Okuma Notları'nda yazmadın?",
                answer: """
                Notlarda interactor'ın işi basit; tek dikiş (seam) repository, testler gerçek kuralları bellek deposuyla \
                çalıştırıyor. Burada interactor'ın asıl işi zamanlama: debounce, iptal, hata ayrımı. "İlk sorgu yavaş, \
                ikincisi hızlı" senaryosunu kurmak için sorgu başına kontrol edilebilen bir spy gerekiyor. Bedeli: daha \
                fazla tip ve spy gerçek davranıştan saparsa yanlış güven. Kurallar kendi testlerinde ayrıca doğrulanıyor.
                """
            ),
            FollowUp(
                question: "Async çalışan bir interactor'ı nasıl test edersin?",
                answer: """
                Interactor sonucu dönüş değeriyle değil output'la, sonra bildirir. Test metodunu @MainActor ve async \
                yaparım; spy output her olayda bir XCTestExpectation'ı fulfill eder, test await fulfillment(of:timeout:) \
                ile bekler. "Spy çağrıyı aldı mı?" gibi ara durumlar için zaman sınırlı bir yoklama (polling) yardımcısı. \
                Sınırsız sleep yok; debounce süresini testte yapılandırmayla kısaltırım.
                """
            ),
            FollowUp(
                question: "Stub, spy, mock ve fake farkı ne? Bu modülde hangisi nerede?",
                answer: """
                Stub hazır cevap döner (StubBookService, özet use case stub'ı). Spy çağrıları kaydeder, doğrulamayı test \
                yapar (spy view, spy router, spy use case'ler). Mock beklentiyi önceden bilir ve kendisi doğrular \
                (Presenter testlerindeki InteractorMock.verify()). Fake çalışan basit bir uygulamadır \
                (InMemoryRecentSearchesStore). Dummy yalnızca imzayı doldurur.
                """
            ),
        ],
        pitfalls: [
            """
            Servisi Presenter'da (ya da View'da) bir Task ile çağırmak: async, iptal ve iş kuralı sunuma dolar; Presenter \
            testleri beklemek zorunda kalır, VIPER'ın "senkron ve sahte view ile test edilen presenter" vaadi biter.
            """,
            """
            Önceki aramayı iptal etmemek ya da await'ten sonra iptali kontrol etmemek: "ata" sorgusunun geç gelen sonucu \
            "atay"ın sonucunu ezer (race condition; data race olmadan da olur).
            """,
            """
            İptali hata gibi göstermek (her harfte "Bir sorun oluştu"). Yalnızca CancellationError'u ayırmak da yetmez: \
            URLSession iptali URLError(.cancelled) olarak gelir; ölçüt Task.isCancelled olmalı. Tersi de tuzak: isteğe \
            bağlı bir istekte try? ile iptali yutup iptal edilmiş işi sürdürmek.
            """,
            """
            Task içinde self'i strong yakalamak: 600 ms'lik ağ çağrısı modülü ekran kapandıktan sonra da yaşatır; \
            [weak self] ve gereken değerleri task'tan önce yerel sabitlere kopyalamak doğrusu.
            """,
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/BookSearch/Presentation/VIPER/BookSearchContracts.swift",
                symbol: "BookSearchInteractorOutput, BookSearchViewState",
                note: "Bir aramanın yolculuğu şeması ve \"Neden hepsi @MainActor?\" açıklaması."
            ),
            CodePointer(
                file: "BookShelf/Features/BookSearch/Presentation/VIPER/BookSearchInteractor.swift",
                symbol: "BookSearchInteractor.search(query:trigger:)",
                note: "Task saklama, son arama kazanır, debounce, iptal edilmiş aramanın sonucunu da hatasını da düşürmek, geçmişe yalnızca taahhüt edilen arama."
            ),
            CodePointer(
                file: "BookShelf/Features/BookSearch/Domain/SearchBooksUseCase.swift",
                symbol: "SearchBooksUseCase.searchKey(for:)",
                note: "Türkçe katlama: İ/I/ı/i ve aksanlar; neden \"oguz\" Oğuz'u bulur, sıralama neden Türkçe."
            ),
            CodePointer(
                file: "BookShelf/Features/BookSearch/Domain/LoadBookInsightsUseCase.swift",
                symbol: "LoadBookInsightsUseCase.execute(for:)",
                note: "async let ile iki paralel istek; yorumlar zorunlu, yazar profili isteğe bağlı, iptal yeniden fırlatılıyor."
            ),
            CodePointer(
                file: "BookShelf/Features/BookSearch/Presentation/VIPER/BookSearchRouter.swift",
                symbol: "BookSearchRouter.build(dependencies:recentSearchesStore:configuration:)",
                note: "Modül kurulumu ve gerçek navigasyon: UIHostingController(BookDetailView) push."
            ),
            CodePointer(
                file: "BookShelfTests/BookSearch/BookSearchInteractorTests.swift",
                symbol: "testNewQueryCancelsSlowPreviousSearch",
                note: "Yavaş ilk arama ikincisi tarafından iptal ediliyor; output'a yalnızca ikincinin sonucu ulaşıyor."
            ),
        ],
        demo: { dependencies in AnyView(BookSearchVIPERContainer(dependencies: dependencies)) }
    )
}
