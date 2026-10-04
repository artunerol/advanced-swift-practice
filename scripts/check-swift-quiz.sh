#!/usr/bin/env bash
#
# scripts/check-swift-quiz.sh — "Protocol as a type: olur mu, olmaz mı?" quiz'inin cevaplarını DERLEYİCİYE doğrulatır.
#
# Quiz'deki her örnek, uygulamanın paketlediği bir kaynak dosyasıdır:
#   BookShelf/Features/Interview/Demos/SwiftBasics/QuizSnippets/quiz-NN-<ad>.swift.txt
# Uygulama bu dosyaları ekranda gösterir; bu betik ise AYNI dosyaları derler. Tek doğruluk kaynağı (single source of
# truth) budur: Quiz'deki "doğru cevap" bir tahmin değil, derleyicinin gerçek çıktısıdır. Derleyici sürümü değişip
# bir mesaj ya da davranış değişirse bu betik kırmızıya döner ve quiz'i güncellememiz gerektiğini söyler.
#
# Her örneğin başındaki başlık satırları:
#   // TITLE: <soru başlığı>
#   // EXPECT: compiles                  → uyarısız ve hatasız derlenmeli
#   // EXPECT: warning: <mesaj>          → derlenmeli, çıktıda "warning: <mesaj>" olmalı
#   // EXPECT: error: <mesaj>            → derlenmemeli, çıktıda "error: <mesaj>" olmalı
#   // FLAGS: <derleyici bayrakları>     → (isteğe bağlı) ör. -enable-upcoming-feature ExistentialAny
#   // EXPLAIN: <açıklama>               → (bir ya da daha fazla satır) uygulamada gösterilen açıklama
#
# Her örnek, quiz-prelude.swift.txt (ortak tanımlar) ile birleştirilip main.swift adıyla yalnızca tip denetiminden
# (-typecheck) geçirilir. main.swift adı önemli: En üst düzeyde (top-level) ifade yazmaya yalnızca o dosyada izin var.
# Uygulamayla aynı koşullar: Swift 6 dil modu, iOS 17 simülatör hedefi.
#
# Kullanım:  ./scripts/check-swift-quiz.sh
# Çıkış kodu: 0 = tüm örnekler beklendiği gibi, 1 = en az bir uyuşmazlık (ya da eksik başlık).
#
# macOS'taki /bin/bash 3.2 ile uyumlu yazıldı (ci.sh ile aynı gerekçe): ilişkisel dizi, mapfile vb. yok.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
cd "$ROOT_DIR"

readonly SNIPPET_DIR="BookShelf/Features/Interview/Demos/SwiftBasics/QuizSnippets"
readonly PRELUDE="$SNIPPET_DIR/quiz-prelude.swift.txt"
readonly TARGET="arm64-apple-ios17.0-simulator"

die() {
    printf 'HATA: %s\n' "$*" >&2
    exit 1
}

[[ -f "$PRELUDE" ]] || die "Ortak tanımlar bulunamadı: $PRELUDE"
xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1 \
    || die "iOS Simulator SDK bulunamadı. Xcode kurulu ve seçili mi? (xcode-select -p)"

# Geçici klasör; betik nasıl biterse bitsin (hata, Ctrl+C) silinir.
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/check-swift-quiz.XXXXXX")"
readonly WORK_DIR
trap 'rm -rf "$WORK_DIR"' EXIT

# Bir dosyadaki "// ANAHTAR: değer" başlığının İLK değerini yazdırır (yoksa boş).
header_value() {
    local key="$1" file="$2"
    sed -n "s|^// $key: ||p" "$file" | head -n 1
}

# Verilen kaynağı derler. Çıktıyı COMPILER_OUTPUT'a, çıkış kodunu COMPILER_STATUS'a yazar.
# `set -e` altında başarısız bir komut betiği durdurur; derleme hatası burada BEKLENEN bir sonuç olabildiği için
# komutu `if` içinde çalıştırıp çıkış kodunu kendimiz yakalıyoruz.
#
# $flags bilerek tırnaksız: "-enable-upcoming-feature ExistentialAny" iki ayrı argüman olmalı. Bölme sırasında
# joker karakter genişletmesi (glob) olmasın diye `set -f` ile kapatıp hemen ardından geri açıyoruz.
typecheck() {
    local source_file="$1" flags="$2"
    set -f
    # shellcheck disable=SC2086
    if COMPILER_OUTPUT="$(xcrun --sdk iphonesimulator swiftc -typecheck -swift-version 6 -target "$TARGET" \
        $flags "$source_file" 2>&1)"; then
        COMPILER_STATUS=0
    else
        COMPILER_STATUS=$?
    fi
    set +f
}

# 1) Ortak tanımlar tek başına temiz derlenmeli; yoksa her örnek yanlış nedenle kırılır.
mkdir -p "$WORK_DIR/prelude"
cp "$PRELUDE" "$WORK_DIR/prelude/main.swift"
typecheck "$WORK_DIR/prelude/main.swift" ""
if [[ $COMPILER_STATUS -ne 0 ]] || grep -qE "(error|warning):" <<<"$COMPILER_OUTPUT"; then
    printf '%s\n' "$COMPILER_OUTPUT" >&2
    die "Ortak tanımlar ($PRELUDE) uyarısız derlenmiyor."
fi

# 2) Örnekleri sırayla doğrula.
total=0
failures=0
# Not: bash'in printf'i genişliği bayt olarak sayar; Ö ve Ç ikişer bayt olduğu için başlıkta +1 pay var.
printf '%-45s %-10s %-11s %s\n' "ÖRNEK" "BEKLENEN" "SONUÇ" "DURUM"
printf '%-44s %-10s %-10s %s\n' "-----" "--------" "-----" "-----"

for snippet in "$SNIPPET_DIR"/quiz-[0-9][0-9]-*.swift.txt; do
    [[ -f "$snippet" ]] || continue
    total=$((total + 1))
    name="$(basename "$snippet" .swift.txt)"

    expect="$(header_value EXPECT "$snippet")"
    flags="$(header_value FLAGS "$snippet")"
    problem=""
    [[ -n "$(header_value TITLE "$snippet")" ]] || problem="TITLE başlığı yok"
    [[ -n "$(header_value EXPLAIN "$snippet")" ]] || problem="EXPLAIN başlığı yok"

    case "$expect" in
        compiles) kind="compiles"; message="" ;;
        "warning: "*) kind="warning"; message="${expect#warning: }" ;;
        "error: "*) kind="error"; message="${expect#error: }" ;;
        *) kind="?"; message=""; problem="EXPECT anlaşılamadı: '$expect'" ;;
    esac

    mkdir -p "$WORK_DIR/$name"
    cat "$PRELUDE" "$snippet" >"$WORK_DIR/$name/main.swift"
    typecheck "$WORK_DIR/$name/main.swift" "$flags"

    # Gerçekte ne oldu? Hata > uyarı > temiz.
    if [[ $COMPILER_STATUS -ne 0 ]]; then
        actual="error"
    elif grep -q "warning:" <<<"$COMPILER_OUTPUT"; then
        actual="warning"
    else
        actual="compiles"
    fi

    if [[ -z "$problem" ]]; then
        if [[ "$actual" != "$kind" ]]; then
            problem="beklenen '$kind', gerçek '$actual'"
        elif [[ -n "$message" ]] && ! grep -qF -- "$kind: $message" <<<"$COMPILER_OUTPUT"; then
            problem="mesaj farklı"
        fi
    fi

    if [[ -z "$problem" ]]; then
        printf '%-44s %-10s %-10s %s\n' "$name" "$kind" "$actual" "✓"
    else
        failures=$((failures + 1))
        printf '%-44s %-10s %-10s %s\n' "$name" "$kind" "$actual" "✗ $problem"
        [[ -n "$message" ]] && printf '    beklenen mesaj: %s: %s\n' "$kind" "$message"
        # Derleyici çıktısının yalnızca tanı (diagnostic) satırlarını göster; kod alıntıları gürültü yapar.
        grep -E "(error|warning):" <<<"$COMPILER_OUTPUT" | grep -v '^ *|' | sed 's/^/    derleyici: /' || true
    fi
done

[[ $total -gt 0 ]] || die "Hiç örnek bulunamadı: $SNIPPET_DIR/quiz-NN-*.swift.txt"

printf '\n%d örnek, %d uyuşmazlık. (%s)\n' "$total" "$failures" "$(xcrun swiftc --version 2>&1 | head -n 1)"
if [[ $failures -gt 0 ]]; then
    exit 1
fi
