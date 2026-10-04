import CoreGraphics

/// Lab'daki dikdörtgen ve noktaları ekranda okunur metne çevirir: "x 60 · y 70 · w 120 · h 80".
///
/// Değerler tam sayıya yuvarlanır; ekranda 141.42135 yerine 141 görmek kavramı anlatmaya yeter.
/// (Kesin değerleri birim testleri `accuracy:` ile denetler.)
enum GeometryText {
    static func rect(_ rect: CGRect) -> String {
        "x \(number(rect.minX)) · y \(number(rect.minY)) · w \(number(rect.width)) · h \(number(rect.height))"
    }

    static func point(_ point: CGPoint) -> String {
        "x \(number(point.x)) · y \(number(point.y))"
    }

    /// `-0.4` → "0" (eksi sıfır göstermemek için önce yuvarlayıp tam sayıya çeviriyoruz).
    static func number(_ value: CGFloat) -> String {
        String(Int(value.rounded()))
    }
}
