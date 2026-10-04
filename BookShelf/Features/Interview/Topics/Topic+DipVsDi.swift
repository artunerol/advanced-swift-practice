import SwiftUI

extension InterviewTopic {
    static let dipVsDi = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.dipVsDi,
        section: .architecture,
        question: "Dependency Inversion ile Dependency Injection aynı şey mi?",
        shortAnswer: [
            """
            Hayır. Dependency Inversion (DIP) bir tasarım İLKESİ, SOLID'in D'si: üst seviye politika kodu alt seviye \
            ayrıntıya değil soyutlamaya bağlı olmalı; ayrıntı da o soyutlamaya bağlı olmalı.
            """,
            """
            Kritik nokta soyutlamanın sahibi: protokol politika tarafında (domain) durur. Bu projede NotesRepository \
            Domain'de; depolar (bellek, dosya, Core Data...) onu uygular. Kaynak koddaki ok "depo → domain" olur, \
            yani tersine döner.
            """,
            """
            Dependency Injection (DI) bir TEKNİK: nesne bağımlılığını kendisi oluşturmaz, dışarıdan alır. \
            Init (constructor), property ya da metot parametresiyle.
            """,
            """
            DI, DIP'i uygulamanın en yaygın yolu ama aynı şey değil: somut bir sınıfı enjekte edersem DI var, DIP yok. \
            Tersi de olur: protokol tipindeki bağımlılığı bir factory ya da service locator'dan kendisi isteyen kod DIP'e \
            uyar ama DI yapmaz. İkisi için de DI container (Swinject vb.) şart değil; elle kurulan bir composition root yeter.
            """,
        ],
        followUps: [
            FollowUp(
                question: "DI çeşitleri neler, hangisini ne zaman kullanırsın?",
                answer: """
                Constructor injection varsayılan tercih: zorunlu bağımlılık eksik kalamaz, let ile değişmez, \
                test kolay. Property injection: geri (weak) referanslar, storyboard'dan gelen VC'ler; atanmayı \
                unutma riski var. Method injection: çağrıya özel strateji (sorted(by:) gibi). SwiftUI'da \
                Environment ağaç boyunca DI yapar.
                """
            ),
            FollowUp(
                question: "Composition root nedir?",
                answer: """
                Somut tiplerin seçilip birbirine bağlandığı tek yer, genellikle uygulamanın girişi. Bu projede \
                AppDependencies.makeForLaunch: UI testinde bellek deposu, normalde varsayılan depo. Geri kalan kod \
                sadece protokolleri görür.
                """
            ),
            FollowUp(
                question: "Service locator neden anti-kalıp sayılır?",
                answer: """
                Nesne bağımlılığını global bir kayıttan kendisi ister: Locator.shared.resolve(...). Bağımlılık imzada \
                görünmez, global değişken durumu taşır, testler birbirini etkiler ve eksik kayıt ancak çalışma anında \
                çöker. DI'da bağımlılık init'te görünür ve derleyici denetler.
                """
            ),
            FollowUp(
                question: "Inversion tam olarak neyi tersine çeviriyor?",
                answer: """
                Kaynak kod bağımlılığının yönünü. Klasik katmanlamada üst katman alt katmanı import eder. DIP'te alt \
                katman, üst katmanın tanımladığı protokolü uygular; ok tersine döner. Çalışma anındaki çağrı akışı \
                değişmez: use case yine depoyu çağırır.
                """
            ),
            FollowUp(
                question: "Her şeye protokol yazmalı mıyım?",
                answer: """
                Hayır. Soyutlama, değişmesi muhtemel ya da testte değiştirilmesi gereken bir sınırda değerlidir \
                (depo, ağ, saat). Tek uygulaması olan ve yan etkisi olmayan bir tipi soyutlamak sadece dolaylılık ekler.
                """
            ),
        ],
        pitfalls: [
            """
            Protokolü alt katmana koymak (ör. CoreData modülünde CoreDataNotesStoreProtocol): soyutlama yine ayrıntıya \
            ait olur, domain o modülü import etmek zorunda kalır; DIP gerçekleşmez.
            """,
            """
            "DI kullanıyorum, o zaman DIP de var" demek: init(repository: CoreDataNotesRepository) DI'dır ama üst \
            seviye kod hâlâ Core Data'ya bağlıdır.
            """,
            """
            Zorunlu bir bağımlılığı property injection ile vermek: atanmayı unutursan nil kalır ve sessizce hiçbir şey \
            olmaz. Zorunluyu init ile ver.
            """,
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Domain/Repositories/NotesRepository.swift",
                symbol: "NotesRepository",
                note: "Soyutlama Domain'de duruyor: DIP'in kalbi. Depolar bu protokolü uygular."
            ),
            CodePointer(
                file: "BookShelf/App/AppDependencies.swift",
                symbol: "AppDependencies.makeForLaunch(arguments:)",
                note: "Composition root: somut depo burada seçilir ve init ile aşağı verilir."
            ),
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Domain/UseCases/AddNoteUseCase.swift",
                symbol: "AddNoteUseCase.init(repository:now:)",
                note: "Constructor injection; \"şu anki zaman\" bile enjekte edilen bir bağımlılık."
            ),
            CodePointer(
                file: "BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListRouter.swift",
                symbol: "NotesListRouter.build(repository:formatter:)",
                note: "Property injection: presenter.view, interactor.output, router.viewController (weak)."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/Architecture/DependencyExamples.swift",
                symbol: "TightlyCoupledNoteCounter, ConcreteInjectedNoteCounter, InjectedNoteCounter",
                note: "Sıkı bağlılık, DIP'siz DI ve DI + DIP yan yana; method injection: NotesPlainTextExporter."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/Architecture/DependencyInjectionDemoView.swift",
                symbol: "EnvironmentValues.noteFormatter",
                note: "SwiftUI Environment ile DI: @Entry ile tanım, .environment ile verme, @Environment ile okuma."
            ),
        ],
        demo: { _ in AnyView(DependencyInjectionDemoView()) }
    )
}
