import CoreData

/// Core Data'daki **kayıt tipi** (`NotesModel.xcdatamodeld` içindeki `NoteEntity` entity'si).
///
/// Bu sınıf Data katmanının içinde kalır; dışarıya hiçbir zaman çıkmaz. Sınırda `ReadingNote` struct'ına
/// çevrilir (`readingNote`). Neden?
/// - `NSManagedObject` **Sendable değildir** (SDK'da `NS_SWIFT_NONSENDABLE`): Yalnızca onu getiren context'in
///   kuyruğunda, `perform` bloğunun içinde kullanılabilir. Başka bir thread'e taşınırsa çökme ya da bozuk veri olur.
/// - Üst katmanlar Core Data'yı hiç bilmez; depolama değişse de ekranlar değişmez.
///
/// Elle yazılmış alt sınıf: Model dosyasında "Codegen: Manual/None" (XML'de `codeGenerationType` yok).
/// Xcode'un otomatik ürettiği sınıf yerine kendimiz yazınca tipler ve yorumlar gözümüzün önünde olur.
///
/// `@objc(NoteEntity)`: Objective-C çalışma zamanındaki sınıf adını modül adı olmadan sabitler. Model dosyasındaki
/// `representedClassName="NoteEntity"` bu adla eşleşir. (Vermeseydik ad `BookShelf.NoteEntity` olurdu ve modeldeki
/// "Module" ayarının da buna göre seçilmesi gerekirdi.)
@objc(NoteEntity)
final class NoteEntity: NSManagedObject {
    /// `@NSManaged`: "Bu özelliğin deposu ve erişimcileri çalışma anında Core Data tarafından sağlanır" demektir.
    /// Swift kendi saklama alanını üretmez; okuma/yazma Core Data'nın değişiklik takibinden geçer.
    @NSManaged var noteID: UUID
    @NSManaged var text: String
    /// Opsiyonel bir **sayı**: `Int64?` yazamayız, çünkü `@NSManaged` özellikleri Objective-C'de temsil edilebilmeli
    /// ve ObjC'de opsiyonel skaler tip yoktur. Bu yüzden `NSNumber?` (modelde "Use Scalar Type" kapalı).
    @NSManaged var bookID: NSNumber?
    @NSManaged var createdAt: Date

    /// Entity adı tek yerde: fetch request'ler ve testler bunu kullanır.
    static let entityName = "NoteEntity"

    /// Tip güvenli fetch request. Adı bilerek `fetchRequest()` değil: `NSManagedObject`'in aynı adlı
    /// (`NSFetchRequest<NSFetchRequestResult>` döndüren) sınıf metoduyla karışmasın.
    static func typedFetchRequest() -> NSFetchRequest<NoteEntity> {
        NSFetchRequest<NoteEntity>(entityName: entityName)
    }

    /// Kayıt → domain dönüşümü. YALNIZCA context'in `perform` bloğu içinde çağrılmalı.
    var readingNote: ReadingNote {
        ReadingNote(id: noteID, text: text, bookID: bookID?.intValue, createdAt: createdAt)
    }

    /// Domain → kayıt dönüşümü (ekleme ve güncelleme için ortak).
    func update(from note: ReadingNote) {
        noteID = note.id
        text = note.text
        bookID = note.bookID.map { NSNumber(value: $0) }
        createdAt = note.createdAt
    }
}
