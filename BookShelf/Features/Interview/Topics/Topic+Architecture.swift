import SwiftUI

extension InterviewTopic {
    static let architecture = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.architecture,
        section: .architecture,
        question: "Clean Architecture, VIPER ve MVVM: farkları ne, hangisini ne zaman seçersin?",
        shortAnswer: [
            """
            Aynı seviyede değiller: MVC, MVVM ve VIPER sunum (presentation) katmanını böler; Clean Architecture bütün \
            uygulamanın katmanlarını ve bağımlılık yönünü belirler. Clean Architecture içinde sunumu MVVM ile de \
            VIPER ile de yazabilirim.
            """,
            """
            Clean Architecture'ın özü bağımlılık kuralı: oklar içeri, domain'e bakar. Domain (entity, use case, \
            repository protokolü) UIKit, SwiftUI, Core Data bilmez; Data katmanı domain'in protokolünü uygular.
            """,
            """
            MVVM: ViewModel durumu ve kullanıcı eylemlerini yönetir, View'ı tanımaz; View onu gözlemler. \
            UI açmadan test edilir; SwiftUI'da @Observable ile çok doğal.
            """,
            """
            VIPER: View, Interactor, Presenter, Entity, Router; sorumluluklar protokollerle ayrılır. \
            Test edilebilirlik çok yüksek, tören (boilerplate) de çok. Geri referanslar weak: \
            presenter → view, interactor → presenter, router → view controller.
            """,
            """
            Seçim maliyet/fayda işi: basit ekranda MVC ya da MVVM yeter; SwiftUI'da MVVM; büyük UIKit ekibi, karmaşık \
            akış ve sıkı modül sınırlarında VIPER ya da MVVM + Coordinator.
            """,
        ],
        followUps: [
            FollowUp(
                question: "VIPER'da kim kimi tutar? Neden?",
                answer: """
                VC → presenter strong; presenter → interactor ve router strong. Geri dönenler weak: presenter → view, \
                interactor → presenter (output), router → VC. Modülün tek dış sahibi VC'yi gösteren yapıdır \
                (navigation controller); onu bırakınca zincir çözülür. Geri referanslardan biri strong olsaydı \
                retain cycle olur, modül hiç serbest kalmazdı. Weak geri referanslar property injection ile bağlanır, \
                çünkü presenter oluşturulurken VC henüz yoktur.
                """
            ),
            FollowUp(
                question: "Presenter ile ViewModel arasındaki fark ne?",
                answer: """
                Presenter View'ı bir protokol üzerinden tanır ve ona komut verir (view?.render(...)); bu yüzden \
                view'a weak referans tutar. ViewModel View'ı tanımaz; durumu yayınlar, View gözlemler (@Observable, \
                Combine, closure). İkisi de UIKit/SwiftUI olmadan test edilebilir olmalı.
                """
            ),
            FollowUp(
                question: "MVVM'de navigasyonu kim yönetir?",
                answer: """
                ViewModel navigasyon nesnelerini (UINavigationController, NavigationPath ayrıntıları) bilmemeli. \
                SwiftUI'da view, view model'in durumuna göre sheet/navigationDestination gösterir; UIKit'te genellikle \
                bir Coordinator akışı yönetir (MVVM-C). VIPER'da bu işin karşılığı Router.
                """
            ),
            FollowUp(
                question: "Her özellik için use case yazmak şart mı?",
                answer: """
                Hayır. İş kuralı varsa (bu projede: kırp, boş olamaz, en fazla 280 karakter) use case onu tek yerde \
                tutar ve iki arayüz paylaşır. Sadece "depodan al, göster" ise ekstra katman tören olur; pragmatik ol. \
                Önemli olan iş kuralının view controller'a ya da view model'e gömülmemesi.
                """
            ),
            FollowUp(
                question: "Core Data nesnelerini (NSManagedObject) doğrudan ekrana verebilir miyim?",
                answer: """
                Clean Architecture'da hayır: sınırda domain struct'ına (ReadingNote) çevir. Managed object'ler \
                context'in kuyruğuna bağlıdır, thread'ler arasında taşınamaz ve ekranı depolama teknolojisine bağlar. \
                Struct Sendable'dır, test kolaydır, depo değişince ekran değişmez.
                """
            ),
        ],
        pitfalls: [
            """
            "Massive View Controller"dan kaçarken "Massive ViewModel/Presenter" yaratmak: iş kuralı view model'e \
            gömülürse ikinci bir arayüz onu kopyalamak zorunda kalır. Kural use case'te olmalı.
            """,
            """
            VIPER'da presenter.view ya da interactor.output'u strong tutmak: modül ekrandan kalksa da bellekte kalır \
            (deinit hiç çalışmaz).
            """,
            """
            Her ekrana VIPER uygulamak: basit bir ayar ekranı için 5 dosya ve 5 protokol, kazandırdığından fazlasını \
            götürür. Mimari, ekranın karmaşıklığına ve ekibe göre seçilir.
            """,
            """
            Domain katmanına import UIKit/SwiftUI/CoreData eklemek: bağımlılık kuralı kırılır; domain artık UI'sız \
            ve depodan bağımsız test edilemez.
            """,
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListContracts.swift",
                symbol: "NotesListViewProtocol, NotesListInteractorOutput",
                note: "VIPER'ın haritası: 5 protokol ve sahiplik tablosu (hangi referans weak, neden)."
            ),
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListRouter.swift",
                symbol: "NotesListRouter.build(repository:formatter:)",
                note: "Modül kurulumu: strong bağımlılıklar init ile, weak geri referanslar property injection ile."
            ),
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListPresenter.swift",
                symbol: "NotesListPresenter.viewState(for:formatter:)",
                note: "UIKit import etmeyen presenter; entity'yi ekran metnine çeviren saf fonksiyon."
            ),
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Presentation/MVVM/NotesListViewModel.swift",
                symbol: "NotesListViewModel",
                note: "Aynı use case'ler, View'ı tanımayan @Observable durum; iyimser silme (optimistic update)."
            ),
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Domain/UseCases/AddNoteUseCase.swift",
                symbol: "AddNoteUseCase.validate(_:)",
                note: "İş kuralı domain'de: iki arayüz aynı kuralı ve aynı Türkçe hata mesajını kullanır."
            ),
            CodePointer(
                file: "BookShelfTests/ReadingNotes/NotesListRouterTests.swift",
                symbol: "testReleasingViewControllerReleasesWholeModule",
                note: "VC bırakılınca presenter, interactor ve router da serbest kalıyor: retain cycle yok."
            ),
        ],
        demo: { dependencies in AnyView(ReadingNotesDemoView(dependencies: dependencies)) }
    )
}
