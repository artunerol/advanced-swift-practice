import Foundation

/// "Olur mu, olmaz mı?" quiz'indeki tek bir örnek: kod + derleyicinin gerçek tepkisi + açıklama.
///
/// Örnekler Swift kodunun içine gömülü değil; `QuizSnippets/` klasöründe ayrı `.swift.txt` dosyaları olarak duruyor.
/// Uygulama bu dosyaları paketten (bundle) okur, `scripts/check-swift-quiz.sh` ise AYNI dosyaları gerçekten derler.
/// Böylece ekrandaki "doğru cevap" ile derleyicinin söylediği hiçbir zaman birbirinden kopamaz (tek doğruluk kaynağı).
///
/// Dosya biçimi (betikteki açıklamayla aynı):
/// ```
/// // TITLE: İki any Equatable'ı == ile karşılaştırmak
/// // EXPECT: error: binary operator '==' cannot be applied to two 'any Equatable' operands
/// // FLAGS: -enable-upcoming-feature ExistentialAny      (isteğe bağlı)
/// // EXPLAIN: Birinci paragraf.
/// // EXPLAIN: İkinci paragraf.
///
/// func isSame(_ lhs: any Equatable, _ rhs: any Equatable) -> Bool { lhs == rhs }
/// ```
struct SwiftQuizSnippet: Identifiable, Equatable, Sendable {
    /// Derleyicinin örneğe verdiği tepki.
    enum Outcome: Equatable, Sendable {
        /// Uyarısız ve hatasız derlenir.
        case compiles
        /// Derlenir ama uyarı verir. İlişkili değer, uyarı metni ("warning: " öneki olmadan).
        case compilesWithWarning(String)
        /// Derlenmez. İlişkili değer, hata metni ("error: " öneki olmadan).
        case fails(String)

        /// Quiz'in sorusu "Bu kod derlenir mi?". Uyarı derlemeye engel değildir, bu yüzden cevabı "Olur".
        var compiles: Bool {
            switch self {
            case .compiles, .compilesWithWarning: true
            case .fails: false
            }
        }

        /// Derleyicinin birebir mesajı; temiz derlenen örnekte `nil`.
        var compilerMessage: String? {
            switch self {
            case .compiles: nil
            case .compilesWithWarning(let message): "warning: \(message)"
            case .fails(let message): "error: \(message)"
            }
        }

        /// Kullanıcıya gösterilen kısa sonuç.
        var summary: String {
            switch self {
            case .compiles: "Derlenir"
            case .compilesWithWarning: "Derlenir, ama uyarı verir"
            case .fails: "Derlenmez"
            }
        }
    }

    /// Dosya adı (uzantısız), ör. "quiz-03-any-equatable-equals". Paket içinde benzersizdir.
    let id: String
    /// Dosya adındaki sıra numarası (3). Örnekler bu sırayla gösterilir.
    let number: Int
    let title: String
    let outcome: Outcome
    /// Açıklama paragrafları (her `// EXPLAIN:` satırı bir paragraf).
    let explanation: [String]
    /// Örnek özel bir derleyici ayarıyla derleniyorsa o ayar, ör. "-enable-upcoming-feature ExistentialAny".
    let compilerFlags: String?
    /// Ekranda gösterilen kod (başlık satırları hariç).
    let code: String
}

/// Bir quiz dosyası okunamadığında ne yanlış gitti?
enum SwiftQuizParseError: Error, Equatable {
    /// Dosya adı "quiz-NN-ad" biçiminde değil.
    case invalidFileName(String)
    /// Zorunlu bir başlık (TITLE, EXPECT, EXPLAIN) eksik.
    case missingHeader(key: String, file: String)
    /// Tanınmayan bir başlık, ör. yazım hatası: "// EXPLAN:".
    case unknownHeader(key: String, file: String)
    /// EXPECT değeri "compiles", "warning: ..." ya da "error: ..." değil.
    case unknownExpectation(String, file: String)
    /// Başlıklardan sonra kod yok.
    case emptyCode(file: String)
}

/// Quiz dosyalarını `SwiftQuizSnippet`'e çeviren saf (pure) fonksiyonlar. Dosya sistemine dokunmaz; test etmesi kolaydır.
enum SwiftQuizParser {
    static let fileNamePrefix = "quiz-"
    /// Paketteki dosyaların uzantısı. ".swift" DEĞİL: O zaman Xcode bu dosyaları uygulamanın kaynak kodu sanıp derlemeye
    /// çalışırdı (ve derlenmeyen örnekler yüzünden uygulama derlenmezdi). ".txt" olduğu için kaynak (resource) olarak kopyalanır.
    static let fileSuffix = ".swift.txt"
    static let preludeFileName = "quiz-prelude"

    private static let knownHeaders: Set<String> = ["TITLE", "EXPECT", "EXPLAIN", "FLAGS"]

    /// - Parameters:
    ///   - fileName: Uzantısız dosya adı, ör. "quiz-03-any-equatable-equals".
    ///   - contents: Dosyanın tamamı.
    static func parse(fileName: String, contents: String) throws -> SwiftQuizSnippet {
        let number = try sequenceNumber(in: fileName)

        var headers: [String: [String]] = [:]
        var lines = contents.components(separatedBy: .newlines)[...]

        // Baştaki "// ANAHTAR: değer" satırlarını topla; ilk farklı satırda kod başlar.
        while let line = lines.first, let field = headerField(in: line) {
            guard knownHeaders.contains(field.key) else {
                throw SwiftQuizParseError.unknownHeader(key: field.key, file: fileName)
            }
            headers[field.key, default: []].append(field.value)
            lines = lines.dropFirst()
        }

        let code = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { throw SwiftQuizParseError.emptyCode(file: fileName) }

        guard let title = headers["TITLE"]?.first else {
            throw SwiftQuizParseError.missingHeader(key: "TITLE", file: fileName)
        }
        guard let expectation = headers["EXPECT"]?.first else {
            throw SwiftQuizParseError.missingHeader(key: "EXPECT", file: fileName)
        }
        guard let explanation = headers["EXPLAIN"], !explanation.isEmpty else {
            throw SwiftQuizParseError.missingHeader(key: "EXPLAIN", file: fileName)
        }

        return SwiftQuizSnippet(
            id: fileName,
            number: number,
            title: title,
            outcome: try outcome(from: expectation, file: fileName),
            explanation: explanation,
            compilerFlags: headers["FLAGS"]?.first,
            code: code
        )
    }

    /// "quiz-03-any-equatable-equals" → 3
    static func sequenceNumber(in fileName: String) throws -> Int {
        guard fileName.hasPrefix(fileNamePrefix) else { throw SwiftQuizParseError.invalidFileName(fileName) }
        let parts = fileName.dropFirst(fileNamePrefix.count).split(separator: "-", maxSplits: 1)
        guard parts.count == 2, parts[0].count == 2, let number = Int(parts[0]) else {
            throw SwiftQuizParseError.invalidFileName(fileName)
        }
        return number
    }

    /// "// EXPECT: compiles" → ("EXPECT", "compiles"). Başlık satırı değilse `nil`.
    private static func headerField(in line: String) -> (key: String, value: String)? {
        guard line.hasPrefix("// "), let separator = line.range(of: ": ") else { return nil }
        let key = line[line.index(line.startIndex, offsetBy: 3)..<separator.lowerBound]
        // Anahtar yalnızca büyük harflerden oluşur; "// Not: ..." gibi sıradan yorumlar kodun parçasıdır.
        guard !key.isEmpty, key.allSatisfy({ $0.isASCII && $0.isUppercase }) else { return nil }
        return (String(key), String(line[separator.upperBound...]))
    }

    private static func outcome(from expectation: String, file: String) throws -> SwiftQuizSnippet.Outcome {
        if expectation == "compiles" { return .compiles }
        if let message = expectation.droppingPrefix("warning: ") { return .compilesWithWarning(message) }
        if let message = expectation.droppingPrefix("error: ") { return .fails(message) }
        throw SwiftQuizParseError.unknownExpectation(expectation, file: file)
    }
}

/// Paketteki tüm quiz dosyaları: ortak tanımlar (prelude) + numaraya göre sıralı örnekler.
struct SwiftQuizLibrary: Sendable {
    /// Her örneğin başına eklenen ortak tanımlar (`ReadingItem`, `Novel`, `Shelf`...). Ekranda ayrıca gösterilir.
    let prelude: String
    let snippets: [SwiftQuizSnippet]

    /// Uygulama paketinden bir kez okunan kütüphane.
    ///
    /// `static let` tembeldir (ilk erişimde hesaplanır) ve Swift bunu thread-safe yapar. View her yeniden
    /// oluşturulduğunda dosyaları baştan okumamak için sonucu (başarı ya da hata) burada saklıyoruz.
    /// `Result` hem başarıyı hem hatayı bir DEĞER olarak tutar; hata `any Error` olduğu için `Sendable`'dır.
    static let bundled: Result<SwiftQuizLibrary, any Error> = Result { try load(from: .main) }

    /// Xcode'un "synchronized folder" özelliği, `BookShelf/` altındaki `.txt` dosyalarını paketin KÖKÜNE kopyalar
    /// (klasör yapısı korunmaz). Bu yüzden dosyaları adlarındaki "quiz-" önekiyle buluyoruz.
    static func load(from bundle: Bundle) throws -> SwiftQuizLibrary {
        let urls = bundle.urls(forResourcesWithExtension: "txt", subdirectory: nil) ?? []
        var prelude: String?
        var snippets: [SwiftQuizSnippet] = []

        for url in urls {
            let fileName = url.lastPathComponent
            guard fileName.hasPrefix(SwiftQuizParser.fileNamePrefix),
                  let baseName = fileName.droppingSuffix(SwiftQuizParser.fileSuffix) else { continue }
            let contents = try String(contentsOf: url, encoding: .utf8)
            if baseName == SwiftQuizParser.preludeFileName {
                prelude = contents.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                snippets.append(try SwiftQuizParser.parse(fileName: baseName, contents: contents))
            }
        }

        guard let prelude else {
            throw SwiftQuizParseError.missingHeader(key: "prelude", file: SwiftQuizParser.preludeFileName)
        }
        return SwiftQuizLibrary(prelude: prelude, snippets: snippets.sorted { $0.number < $1.number })
    }
}

private extension String {
    func droppingPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }

    func droppingSuffix(_ suffix: String) -> String? {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : nil
    }
}
