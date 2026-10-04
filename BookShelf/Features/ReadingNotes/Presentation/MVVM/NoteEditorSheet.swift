import SwiftUI

/// MVVM tarafının not yazma sayfası (sheet). Çok satırlı metin, canlı karakter sayacı ve satır içi hata mesajı.
///
/// Doğrulama burada YAPILMAZ: "Kaydet" her zaman etkin, kuralı use case uygular ve mesajı view model'e verir.
/// Böylece VIPER tarafıyla aynı kural, aynı mesaj. (Düğmeyi boşken devre dışı bırakmak da iyi bir UX olurdu;
/// ama o zaman kural ikinci kez, arayüzde yazılmış olurdu.)
struct NoteEditorSheet: View {
    private typealias ID = AccessibilityID.ReadingNotes.MVVM

    /// `@Bindable`: `@Observable` bir nesnenin özelliklerine `$viewModel.draftText` gibi bağlantı (Binding) üretir.
    /// Sahiplik burada değil (o, listedeki `@State`'te); bu view sadece aynı nesneyi kullanır.
    @Bindable var viewModel: NotesListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    var body: some View {
        // Sheet ayrı bir sunum (presentation) bağlamıdır; kendi `NavigationStack`'i başlık ve araç çubuğu içindir.
        NavigationStack {
            Form {
                Section {
                    TextField("Kitaptan aklında kalan…", text: $viewModel.draftText, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier(ID.editorTextField)
                } footer: {
                    Text(viewModel.characterCountText)
                        .monospacedDigit()
                        .foregroundStyle(viewModel.isDraftTooLong ? .red : .secondary)
                        .accessibilityIdentifier(ID.editorCharacterCount)
                }

                if let message = viewModel.editorMessage {
                    Section {
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: "exclamationmark.circle")
                                .accessibilityHidden(true)
                            // Kimlik ikona değil metne: XCUITest `staticTexts[...]` ile mesajı doğrudan okur.
                            Text(message)
                                .accessibilityIdentifier(ID.editorValidationMessage)
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Yeni not")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                        .accessibilityIdentifier(ID.editorCancelButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save)
                        .disabled(isSaving)
                        .accessibilityIdentifier(ID.editorSaveButton)
                }
            }
        }
    }

    /// Düğme aksiyonu senkron; async kaydetme için bir `Task` açıyoruz (ana actor'ü miras alır).
    /// `isSaving`: kaydetme sürerken ikinci dokunuş aynı notu iki kez eklemesin.
    private func save() {
        isSaving = true
        Task {
            let saved = await viewModel.saveDraft()
            isSaving = false
            if saved { dismiss() }
        }
    }
}
