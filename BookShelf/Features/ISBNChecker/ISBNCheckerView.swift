import SwiftUI

/// ISBN-13 doğrulayıcı ekranı: SwiftUI arayüzü, doğrulama işini Objective-C'de yazılmış `BKISBNValidator`'a yaptırır.
///
/// Sözleşme: Kendi `NavigationStack`'ini İÇERMEZ; `FundamentalsView`'daki yığına (stack) push edilir.
/// İçine bir `NavigationStack` daha koysaydık iç içe iki navigasyon yığını oluşur, başlık ve geri düğmesi karışırdı.
struct ISBNCheckerView: View {
    /// Metin kutusunun içeriği. `@State`: Bu değerin sahibi view'dur; SwiftUI onu view yeniden oluşturulsa da saklar.
    /// `private`: Durum dışarıdan verilmez, yalnızca bu ekran değiştirir.
    @State private var input = ""
    /// Son doğrulamanın sonucu. `nil` = henüz doğrulanmadı (ya da girdi değişti).
    @State private var outcome: ISBNCheckOutcome?

    var body: some View {
        Form {
            inputSection
            if let outcome {
                resultSection(outcome)
            }
            samplesSection
            aboutSection
        }
        .navigationTitle("ISBN Doğrulayıcı")
        .navigationBarTitleDisplayMode(.inline)
        // Girdi değişince eski sonuç artık bu metne ait değildir; ekranda yanlış bilgi kalmasın diye temizliyoruz.
        .onChange(of: input) {
            outcome = nil
        }
    }

    // MARK: - Bölümler

    private var inputSection: some View {
        Section {
            TextField("978-605-000-001-6", text: $input)
                // ISBN bir kelime değil: otomatik düzeltme ve büyük harfe çevirme girdiyi bozardı.
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.numbersAndPunctuation)
                .font(.body.monospaced())
                .submitLabel(.done)
                .onSubmit(validate)
                .accessibilityIdentifier(AccessibilityID.ISBNChecker.inputField)

            Button("Doğrula", systemImage: "checkmark.seal", action: validate)
                .accessibilityIdentifier(AccessibilityID.ISBNChecker.validateButton)
        } header: {
            Text("ISBN-13")
        } footer: {
            Text("Tire ve boşluk kullanabilirsin; doğrulamadan önce temizlenirler.")
        }
    }

    private func resultSection(_ outcome: ISBNCheckOutcome) -> some View {
        Section("Sonuç") {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: outcome.isValid ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(outcome.isValid ? .green : .red)
                    // Simge, metnin söylediğini tekrar ediyor; VoiceOver'ın iki kez okumaması için gizliyoruz.
                    .accessibilityHidden(true)
                // Kimlik, değeri taşıyan `Text`'in kendisinde: UI testi `app.staticTexts[...]` ile tam bu metni okur.
                Text(outcome.message)
                    .accessibilityIdentifier(AccessibilityID.ISBNChecker.resultLabel)
            }

            if case .invalid(_, _, let hint?) = outcome {
                Text(hint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.ISBNChecker.hintLabel)
            }

            if case .valid(let normalized) = outcome {
                // `LabeledContent` yerine düz `HStack`: LabeledContent, erişilebilirlikte etiket ve değeri tek bir
                // öğede birleştirebilir; o zaman değerin kendi kimliği UI testinden görünmeyebilirdi.
                HStack {
                    Text("Temizlenmiş hali")
                    Spacer()
                    Text(normalized)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(AccessibilityID.ISBNChecker.normalizedLabel)
                }
            }
        }
    }

    private var samplesSection: some View {
        Section {
            sampleButton(
                "978-605-000-001-6",
                caption: "Geçerli",
                identifier: AccessibilityID.ISBNChecker.sampleValidButton
            )
            sampleButton(
                "978-605-000-008-6",
                caption: "Kontrol hanesi hatalı (Huzur)",
                identifier: AccessibilityID.ISBNChecker.sampleChecksumMismatchButton
            )
            sampleButton(
                "978-605-ABC-001-6",
                caption: "Harf içeriyor",
                identifier: AccessibilityID.ISBNChecker.sampleLettersButton
            )
        } header: {
            Text("Örnekler")
        } footer: {
            Text("Bir örneğe dokununca metin kutusuna yazılır; sonra Doğrula'ya dokun.")
        }
    }

    private var aboutSection: some View {
        Section("Nasıl çalışır?") {
            Text("Doğrulama, Objective-C ile yazılmış BKISBNValidator sınıfında yapılır. Swift onu köprü başlığı (bridging header) sayesinde ISBNValidator adıyla görür; ObjC'nin NSError** hatası Swift'te throws olur.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Yardımcılar

    private func sampleButton(_ isbn: String, caption: String, identifier: String) -> some View {
        // Örnek yalnızca metin kutusunu doldurur; doğrulamayı kullanıcı başlatır. Böylece aynı akış
        // (yaz → Doğrula) hem elle hem örnekle aynı şekilde test edilebilir.
        Button {
            input = isbn
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(isbn)
                    .font(.body.monospaced())
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(identifier)
    }

    /// Senkron bir işlem: ObjC doğrulayıcısı hızlı ve saf (pure) bir hesap yapıyor, bekleme gerektirmiyor.
    /// Bu yüzden `Task` ya da `async` gerekmez; buton eyleminde doğrudan çağırıp durumu hemen güncelliyoruz.
    private func validate() {
        outcome = ISBNCheckOutcome.evaluate(input)
    }
}

#Preview {
    NavigationStack {
        ISBNCheckerView()
    }
}
