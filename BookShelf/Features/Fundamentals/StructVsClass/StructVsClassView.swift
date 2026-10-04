import SwiftUI

/// Struct ile class farkını üç küçük deneyle gösteren ekran: Kopyalama, Copy-on-write ve ARC.
///
/// Tüm mantık saf Swift tiplerinde (`CopySemanticsDemo`, `CopyOnWriteDemo`, `RetainCycleDemo`); bu view sadece
/// onları gösterip düğmelere bağlıyor. Böylece mantık, SwiftUI olmadan birim testlerle doğrulanabiliyor.
///
/// Kendi `NavigationStack`'ini içermez; Mülakat merkezindeki konu ekranının (`InterviewTopicScreen`) içinde gösterilir.
struct StructVsClassView: View {
    /// Ekranın üstündeki bölüm seçicinin seçenekleri. Etiketler `Shared/` altındaki sabitlerden gelir,
    /// böylece UI testleri de birebir aynı metinleri kullanır.
    enum Experiment: CaseIterable, Identifiable {
        case copying, copyOnWrite, arc

        var id: Self { self }

        var label: String {
            switch self {
            case .copying: AccessibilityID.Fundamentals.StructVsClass.copyingSegment
            case .copyOnWrite: AccessibilityID.Fundamentals.StructVsClass.copyOnWriteSegment
            case .arc: AccessibilityID.Fundamentals.StructVsClass.arcSegment
            }
        }
    }

    private typealias ID = AccessibilityID.Fundamentals.StructVsClass

    // `@State`: View'a ait, SwiftUI'ın view'dan ayrı bir yerde sakladığı durum. View struct'ı her çizimde
    // yeniden oluşturulsa da bu değerler korunur. Değer değiştiğinde SwiftUI `body`'yi yeniden hesaplar.
    @State private var experiment: Experiment = .copying
    @State private var copyDemo = CopySemanticsDemo()
    @State private var copyOnWriteDemo = CopyOnWriteDemo()
    @State private var retainCycleReport: RetainCycleReport?

    var body: some View {
        List {
            Section {
                Picker("Deney", selection: $experiment) {
                    ForEach(Experiment.allCases) { experiment in
                        Text(experiment.label).tag(experiment)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(ID.experimentPicker)
            }

            switch experiment {
            case .copying: copyingSections
            case .copyOnWrite: copyOnWriteSections
            case .arc: arcSections
            }
        }
        .navigationTitle("Struct vs Class")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sıfırla", action: reset)
                    .accessibilityIdentifier(ID.resetButton)
            }
        }
    }

    private func reset() {
        copyDemo = CopySemanticsDemo()
        copyOnWriteDemo = CopyOnWriteDemo()
        retainCycleReport = nil
    }

    // MARK: - 1. Kopyalama

    @ViewBuilder
    private var copyingSections: some View {
        // Düğme en üstte: Sonuçlar aşağıda değişirken düğme hep görünür kalsın.
        Section {
            Button {
                // `advanceCopies` bir `mutating` metot. `@State` değerini yerinde değiştirir;
                // SwiftUI değişikliği görür ve ekranı yeniden çizer.
                copyDemo.advanceCopies()
            } label: {
                Text(verbatim: "Kopyayı değiştir (+\(CopySemanticsDemo.step) sayfa)")
            }
            .accessibilityIdentifier(ID.mutateCopyButton)
        } footer: {
            Text("Düğme yalnızca kopyaları değiştirir; orijinallere dokunmaz.")
        }

        Section {
            // `Text(verbatim:)`: Metni yerelleştirme anahtarı olarak değil, olduğu gibi göster.
            // (Düz `Text("... \(sayı)")` sayıları cihaz diline göre biçimlendirebilir; testlerde sürpriz istemeyiz.)
            Text(verbatim: "Orijinal: \(copyDemo.structOriginal.page). sayfa")
                .accessibilityIdentifier(ID.structOriginal)
            Text(verbatim: "Kopya: \(copyDemo.structCopy.page). sayfa")
                .accessibilityIdentifier(ID.structCopy)
            Text(verbatim: "Eşit mi (==)? \(yesNo(copyDemo.structsAreEqual))")
                .accessibilityIdentifier(ID.structEquality)
        } header: {
            Text("struct BookmarkValue — değer tipi")
                .textCase(nil)
        } footer: {
            Text("`var copy = original` içeriği kopyalar: iki bağımsız değer. Kopya değişir, orijinal etkilenmez.")
        }

        Section {
            Text(verbatim: "Orijinal: \(copyDemo.classOriginal.page). sayfa")
                .accessibilityIdentifier(ID.classOriginal)
            Text(verbatim: "Kopya: \(copyDemo.classCopy.page). sayfa")
                .accessibilityIdentifier(ID.classCopy)
            Text(verbatim: "Aynı nesne mi (===)? \(yesNo(copyDemo.classesAreIdentical))")
                .accessibilityIdentifier(ID.classIdentity)
        } header: {
            Text("final class BookmarkReference — referans tipi")
                .textCase(nil)
        } footer: {
            Text("`var copy = original` yalnızca referansı (adresi) kopyalar: iki değişken, tek nesne. Kopyadaki değişiklik orijinalde de görünür.")
        }

        Section {
            Text("""
            let ile tanımlanmış bir struct tamamen sabittir: alanları değişmez, mutating metotları çağrılamaz. \
            let ile tanımlanmış bir class referansında ise yalnızca referans sabittir; nesnenin var alanları yine değiştirilebilir. \
            Bu yüzden struct'ın kendi alanını değiştiren metotları mutating olarak işaretlenir, class metotları işaretlenmez.
            """)
            .font(.callout)
        } header: {
            Text("let ve mutating")
                .textCase(nil)
        }
    }

    // MARK: - 2. Copy-on-write

    @ViewBuilder
    private var copyOnWriteSections: some View {
        Section {
            Text(verbatim: "Orijinal: \(copyOnWriteDemo.original.pages)")
                .accessibilityIdentifier(ID.cowOriginal)
            Text(verbatim: "Kopya: \(copyOnWriteDemo.copy.pages)")
                .accessibilityIdentifier(ID.cowCopy)
            Text(verbatim: "Depo ortak mı? \(yesNo(copyOnWriteDemo.sharesStorage))")
                .accessibilityIdentifier(ID.cowSharedStorage)
            Button("Kopyaya sayfa ekle") {
                copyOnWriteDemo.recordNextPageOnCopy()
            }
            .accessibilityIdentifier(ID.cowAppendButton)
        } header: {
            Text("PageHistory — elle yazılmış copy-on-write")
                .textCase(nil)
        } footer: {
            Text("""
            Array, String ve Dictionary de böyle çalışır: `var b = a` elemanları kopyalamaz, iki değer aynı depoyu paylaşır. \
            Biri değiştirilmek istendiğinde isKnownUniquelyReferenced ile "depoyu başkası da tutuyor mu?" diye bakılır; \
            tutuyorsa depo o anda kopyalanır. Böylece değer semantiği korunur, gereksiz kopya yapılmaz.
            """)
        }
    }

    // MARK: - 3. ARC ve retain cycle

    @ViewBuilder
    private var arcSections: some View {
        Section {
            scenarioButton("strong ↔ strong (döngü)", strength: .strong, identifier: ID.strongCycleButton)
            scenarioButton("weak ile kır", strength: .weak, identifier: ID.weakCycleButton)
            scenarioButton("unowned ile kır", strength: .unowned, identifier: ID.unownedCycleButton)
        } header: {
            Text("LibraryMember ↔ LibraryCard")
                .textCase(nil)
        } footer: {
            Text("Üye kartını her zaman güçlü (strong) tutar. Kartın üyeye geri tuttuğu referansın türünü seç ve kapsam bittiğinde deinit'in çalışıp çalışmadığını gör.")
        }

        if let report = retainCycleReport {
            Section {
                Text(verbatim: "Serbest bırakılan: \(report.deinitializedObjects.count)/\(report.createdObjects.count)")
                    .accessibilityIdentifier(ID.retainCycleDeinitCount)
                Text(report.hasLeak ? "Sızıntı var" : "Sızıntı yok")
                    .foregroundStyle(report.hasLeak ? Color.red : Color.green)
                    .accessibilityIdentifier(ID.retainCycleVerdict)
                Text(verbatim: logText(for: report))
                    .font(.footnote.monospaced())
                    .accessibilityIdentifier(ID.retainCycleLog)
            } header: {
                Text(verbatim: "Sonuç: \(report.strength.rawValue)")
                    .textCase(nil)
            } footer: {
                Text("""
                ARC bir çöp toplayıcı değildir: Birbirini güçlü tutan iki nesnenin sayacı hiç 0 olmaz ve bellekte kalırlar. \
                weak ve unowned sayacı artırmaz, bu yüzden döngüyü kırar. strong senaryosunda her dokunuş gerçekten \
                2 nesne sızdırır; Xcode'daki Debug Memory Graph ile görebilirsin.
                """)
            }
        }
    }

    private func scenarioButton(_ title: String, strength: ReferenceStrength, identifier: String) -> some View {
        Button(title) {
            retainCycleReport = RetainCycleDemo.run(strength)
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Yardımcılar

    private func yesNo(_ value: Bool) -> String {
        value ? "Evet" : "Hayır"
    }

    /// Günlüğü "1. ...", "2. ..." şeklinde numaralı, çok satırlı tek bir metne çevirir.
    private func logText(for report: RetainCycleReport) -> String {
        report.events.enumerated()
            .map { index, event in "\(index + 1). \(event)" }
            .joined(separator: "\n")
    }
}

#Preview {
    NavigationStack {
        StructVsClassView()
    }
}
