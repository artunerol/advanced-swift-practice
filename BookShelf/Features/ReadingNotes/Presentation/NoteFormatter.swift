import Foundation

/// Bir notun listedeki ikincil satırını üreten **strateji** (Strategy kalıbı).
///
/// Presenter ve view model hangi biçimlendiricinin kullanılacağını bilmez; `init` ile alırlar (constructor injection).
/// Testler sabit çıktılı bir biçimlendirici verir; tarih, saat dilimi ve dil ayarı testleri kırmaz.
/// DIP vs DI demosunda aynı protokolün iki uygulaması arasında canlı geçiş yapılır.
///
/// `Sendable`: biçimlendirici `static let` sabitlerde ve SwiftUI `Environment`'ında saklanabilsin diye.
protocol NoteFormatter: Sendable {
    func detail(for note: ReadingNote) -> String
}

/// Varsayılan strateji: notun oluşturulma tarihi, ör. "3 Eki 2026 14:05".
///
/// Dil ve saat dilimi de dışarıdan verilebilir. Varsayılan dil Türkçe, çünkü arayüz metinleri Türkçe; cihaz
/// İngilizce olsa bile "Oct 3" yerine "3 Eki" görünsün. Testler saat dilimini sabitler (`UTC`); yoksa sonuç,
/// testin koştuğu makineye göre değişirdi.
struct DateNoteFormatter: NoteFormatter {
    private let style: Date.FormatStyle

    init(locale: Locale = Locale(identifier: "tr_TR"), timeZone: TimeZone = .current) {
        style = Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, timeZone: timeZone)
    }

    func detail(for note: ReadingNote) -> String {
        note.createdAt.formatted(style)
    }
}

/// İkinci strateji: notun uzunluğu, ör. "42 karakter · 2 satır". Tarihe bağlı olmadığı için çıktısı her yerde aynı.
struct LengthNoteFormatter: NoteFormatter {
    func detail(for note: ReadingNote) -> String {
        // `split` boş satırları varsayılan olarak atlar; "satır" sayısı burada dolu satırların sayısı.
        let lineCount = note.text.split(whereSeparator: \.isNewline).count
        return "\(note.text.count) karakter · \(lineCount) satır"
    }
}
