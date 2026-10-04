import Foundation

/// Delegate senaryosundaki geri bildirim protokolü.
///
/// `AnyObject`: Protokolü yalnızca class'ların uygulayabileceğini söyler. Bu olmadan `weak var delegate` yazılamaz:
/// "'weak' must not be applied to non-class-bound 'any LeakLabReporterDelegate'" hatası alınır, çünkü struct'ın
/// referans sayacı yoktur, zayıf tutulacak bir nesne de yoktur.
///
/// `@MainActor`: Kendi yazdığımız, UI'a geri haber veren bir protokol; ana actor'e bağlamak, uygulayan VC'nin
/// metotlarını ekstra izolasyon dansı olmadan çağırmamızı sağlar.
@MainActor
protocol LeakLabReporterDelegate: AnyObject {
    func reporterDidProduceUpdate(_ reporter: LeakLabReporter)
}

/// VC'nin sahip olduğu (strong tuttuğu) küçük bir yardımcı nesne. Olayları delegate'ine bildirir.
///
/// Normal kodda yalnızca `weak var delegate` olur. Burada iki sürümü aynı tipte göstermek için iki ayrı depo var
/// (`RetainCycleDemo`'daki `LibraryCard` gibi); hangisinin kullanılacağına `init` karar verir.
@MainActor
final class LeakLabReporter {
    /// YANLIŞ (sızdıran sürüm): Güçlü referans. VC → reporter → VC döngüsünü kurar.
    private var strongDelegate: (any LeakLabReporterDelegate)?
    /// DOĞRU: Sayacı artırmaz; delegate yok edilince Swift bunu otomatik olarak `nil` yapar.
    private weak var weakDelegate: (any LeakLabReporterDelegate)?

    init(delegate: any LeakLabReporterDelegate, holdsDelegateStrongly: Bool) {
        if holdsDelegateStrongly {
            strongDelegate = delegate
        } else {
            weakDelegate = delegate
        }
    }

    var delegate: (any LeakLabReporterDelegate)? {
        strongDelegate ?? weakDelegate
    }

    var holdsDelegateStrongly: Bool {
        strongDelegate != nil
    }

    /// Optional chaining: Delegate yoksa (ya da çoktan yok edildiyse) hiçbir şey olmaz; çökme de olmaz.
    func report() {
        delegate?.reporterDidProduceUpdate(self)
    }

    /// Sızıntıyı temizlemek için güçlü oku koparır.
    func detachDelegate() {
        strongDelegate = nil
        weakDelegate = nil
    }
}
