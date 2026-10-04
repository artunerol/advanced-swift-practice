import SwiftUI

extension Text {
    /// Konu metinlerindeki satır içi Markdown'ı çizer: `` `await` `` kod yazı tipiyle, `**kalın**` kalın görünür.
    ///
    /// Neden gerekli? `Text("...")` bir **literal** alınca onu `LocalizedStringKey` sayar ve Markdown'ı yorumlar;
    /// ama bir `String` **değişkeni** alınca metni olduğu gibi (verbatim) çizer. Konu metinleri değişkenlerden
    /// geldiği için ters tırnaklar ekranda ham haliyle görünürdü.
    ///
    /// `inlineOnlyPreservingWhitespace`: Yalnızca satır içi biçimler (kod, kalın, italik, bağlantı) yorumlanır;
    /// başlık ve liste gibi blok yapılar yorumlanmaz, boşluklar korunur. Metin geçersiz Markdown ise düz metne düşeriz.
    init(interviewMarkdown source: String) {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let attributed = (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
        self.init(attributed)
    }
}
