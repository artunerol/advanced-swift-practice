import SwiftUI

/// "Laboratuvar" sekmesi: Swift Concurrency'yi dokunarak deneyebileceğin küçük deneyler.
///
/// View yalnızca durumu gösterir ve dokunuşları view model'e iletir. Mantığın tamamı `ConcurrencyLab`
/// (saf, test edilebilir) ve `ConcurrencyLabViewModel` (`@MainActor` durum) içindedir.
///
/// `View` protokolü `@MainActor` olarak işaretli olduğundan bu struct ve `body` otomatik olarak ana actor'dedir.
struct ConcurrencyLabView: View {
    /// `@State` + `@Observable` sınıf: SwiftUI View struct'larını sık sık yeniden oluşturur, ama `@State`
    /// ile tutulan view model ekran yaşadığı sürece BİR kez yaratılır ve korunur.
    @State private var viewModel = ConcurrencyLabViewModel(
        settings: .forLaunch(arguments: ProcessInfo.processInfo.arguments)
    )

    var body: some View {
        NavigationStack {
            Form {
                parallelismSection
                sharedStateSection
                reentrancySection
                cancellationSection
            }
            // Kimlik kabın (container) kendisinde; içindeki düğme ve metinler kendi kimliklerini korur.
            .accessibilityIdentifier(AccessibilityID.Lab.form)
            .navigationTitle("Laboratuvar")
        }
    }

    // MARK: - Sıralı vs Paralel

    private var parallelismSection: some View {
        Section {
            Text(viewModel.jobsDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)

            strategyRows(
                .sequential,
                buttonTitle: "Sırayla bekle",
                systemImage: "arrow.down",
                buttonID: AccessibilityID.Lab.runSequentialButton,
                resultID: AccessibilityID.Lab.sequentialResult
            )
            strategyRows(
                .asyncLet,
                buttonTitle: "async let ile paralel",
                systemImage: "arrow.triangle.branch",
                buttonID: AccessibilityID.Lab.runAsyncLetButton,
                resultID: AccessibilityID.Lab.asyncLetResult
            )
            strategyRows(
                .taskGroup,
                buttonTitle: "TaskGroup ile paralel",
                systemImage: "square.stack.3d.down.right",
                buttonID: AccessibilityID.Lab.runTaskGroupButton,
                resultID: AccessibilityID.Lab.taskGroupResult
            )

            Text(viewModel.taskGroupArrivalText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(AccessibilityID.Lab.taskGroupArrivalOrder)
        } header: {
            Text("Sıralı vs Paralel")
        } footer: {
            Text("Sırayla `await` edilen işlerin süreleri toplanır. `async let` ve `TaskGroup` işleri aynı anda başlatır; toplam süre en yavaş iş kadardır. TaskGroup sonuçları *bitiş* sırasıyla teslim eder.")
        }
    }

    /// Bir strateji için iki satır: düğme + sonuç metni.
    ///
    /// Düğme ile sonuç ayrı satırlarda: Böylece XCUITest düğmeyi `app.buttons[...]`, sonucu
    /// `app.staticTexts[...]` ile birbirine karışmadan bulur.
    @ViewBuilder
    private func strategyRows(
        _ strategy: ConcurrencyLab.ParallelismStrategy,
        buttonTitle: String,
        systemImage: String,
        buttonID: String,
        resultID: String
    ) -> some View {
        Button(buttonTitle, systemImage: systemImage) {
            // Düğme aksiyonu SENKRONDUR; async bir işi başlatmak için `Task` açarız.
            // Bu `Task`, View'ın izolasyonunu (`@MainActor`) miras alır.
            Task { await viewModel.runParallelism(strategy) }
        }
        .disabled(viewModel.isParallelismRunning)
        .accessibilityIdentifier(buttonID)

        Text(viewModel.parallelismText(for: strategy))
            .monospacedDigit()
            .accessibilityIdentifier(resultID)
    }

    // MARK: - Paylaşılan Durum

    private var sharedStateSection: some View {
        Section {
            Button("Üç sayacı çalıştır", systemImage: "play.fill") {
                Task { await viewModel.runCounters() }
            }
            .disabled(viewModel.isRunningCounters)
            .accessibilityIdentifier(AccessibilityID.Lab.runCountersButton)

            resultRow(viewModel.unsafeCounterText, systemImage: "exclamationmark.triangle", tint: .red,
                      id: AccessibilityID.Lab.unsafeCounterResult)
            resultRow(viewModel.lockedCounterText, systemImage: "lock", tint: .green,
                      id: AccessibilityID.Lab.lockedCounterResult)
            resultRow(viewModel.actorCounterText, systemImage: "person.badge.shield.checkmark", tint: .green,
                      id: AccessibilityID.Lab.actorCounterResult)
        } header: {
            Text("Paylaşılan Durum: Data Race vs Actor")
        } footer: {
            // `verbatim`: Sayılar yerelleştirilmesin ("1.000" değil "1000"), sonuç satırlarıyla aynı görünsün.
            Text(verbatim: "\(viewModel.settings.counterChildTaskCount) eşzamanlı görev aynı sayacı toplam \(viewModel.settings.expectedCounterTotal) kez artırır. Korumasız sınıfta artışlar kaybolabilir (data race); kilit ve actor her zaman tam sonucu verir.")
        }
    }

    // MARK: - Actor Reentrancy

    private var reentrancySection: some View {
        Section {
            Button("Reentrancy deneyini çalıştır", systemImage: "arrow.uturn.backward.circle") {
                Task { await viewModel.runReentrancy() }
            }
            .disabled(viewModel.isRunningReentrancy)
            .accessibilityIdentifier(AccessibilityID.Lab.runReentrancyButton)

            resultRow(viewModel.reentrancyText, systemImage: "exclamationmark.triangle", tint: .orange,
                      id: AccessibilityID.Lab.reentrancyResult)
            resultRow(viewModel.reentrancyFixedText, systemImage: "checkmark.circle", tint: .green,
                      id: AccessibilityID.Lab.reentrancyFixedResult)
        } header: {
            Text("Actor Reentrancy")
        } footer: {
            Text("İki sayaç da actor, yani data race yok. Ama değeri okuyup `await` ettikten sonra yazarsan, bekleme sırasında araya giren çağrıların artışları silinir. Çözüm: okuma ile yazma arasında `await` olmasın.")
        }
    }

    // MARK: - İptal

    private var cancellationSection: some View {
        Section {
            ProgressView(value: viewModel.longTaskProgress)
                .accessibilityIdentifier(AccessibilityID.Lab.longTaskProgress)

            Text(viewModel.longTaskStatusText)
                .monospacedDigit()
                .accessibilityIdentifier(AccessibilityID.Lab.longTaskStatus)

            Button("Uzun işi başlat", systemImage: "play.fill") {
                viewModel.startLongTask()
            }
            .disabled(viewModel.isLongTaskRunning)
            .accessibilityIdentifier(AccessibilityID.Lab.startLongTaskButton)

            Button("İptal et", systemImage: "stop.fill", role: .destructive) {
                viewModel.cancelLongTask()
            }
            .disabled(!viewModel.isLongTaskRunning)
            .accessibilityIdentifier(AccessibilityID.Lab.cancelLongTaskButton)
        } header: {
            Text("İptal (Cancellation)")
        } footer: {
            Text("`cancel()` işi zorla durdurmaz, yalnızca bir bayrak kaldırır. İş her adımda bayrağa bakıp kendisi durur; buna kooperatif iptal denir.")
        }
    }

    // MARK: - Yardımcılar

    /// Tek bir `Text`'ten oluşan sonuç satırı. Simge `Label` yerine ayrı tutulur ki erişilebilirlik kimliği
    /// doğrudan metnin kendisine (`staticTexts`) verilebilsin.
    private func resultRow(_ text: String, systemImage: String, tint: Color, id: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .monospacedDigit()
                .accessibilityIdentifier(id)
        }
    }
}

#Preview {
    ConcurrencyLabView()
}
