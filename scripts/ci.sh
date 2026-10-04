#!/usr/bin/env bash
#
# scripts/ci.sh — Kitaplık (BookShelf) için derleme ve test betiği.
#
# Aynı betiği hem kendi Mac'imizde hem de GitHub Actions'ta çalıştırıyoruz. Böylece "CI'da ne oluyorsa
# lokalde de aynısı olur": YAML dosyası (.github/workflows/ci.yml) sadece bu betiği çağırır, asıl mantık burada.
#
# Kullanım:
#   ./scripts/ci.sh quiz         # "Derlenir mi?" quiz örneklerini derleyiciyle doğrular (simülatör gerekmez, hızlı)
#   ./scripts/ci.sh build        # Uygulamayı ve test paketlerini BİR kez derler (build-for-testing)
#   ./scripts/ci.sh unit         # Birim testlerini (XCTest) derlemeden çalıştırır
#   ./scripts/ci.sh ui           # UI testlerini (XCUITest) derlemeden çalıştırır
#   ./scripts/ci.sh all          # quiz + build + unit + ui + kod kapsamı özeti (CI'daki akışın aynısı)
#   ./scripts/ci.sh coverage     # Son birim testi sonucundan kod kapsamı özetini yazdırır
#   ./scripts/ci.sh archive      # Release arşivi (.xcarchive) + zip; İMZASIZ (CD'nin ilk işi, release.yml)
#   ./scripts/ci.sh destination  # Seçilecek simülatörü yalnızca YAZDIRIR (hiçbir şey başlatmaz)
#   ./scripts/ci.sh clean        # build/ klasörünü siler
#
# Ortam değişkenleri:
#   SIMULATOR_ID       Belirli bir simülatörün UDID'si. Verilirse otomatik seçim yapılmaz.
#                      UDID'leri görmek için: xcrun simctl list devices available
#                      Örnek: SIMULATOR_ID=3353AF19-5AF2-41FB-AC7A-081D32BBD30B ./scripts/ci.sh all
#   BUILD_NUMBER       (archive) CFBundleVersion, yani build numarası. CI'da github.run_number verilir. Varsayılan: 1
#   MARKETING_VERSION  (archive) CFBundleShortVersionString, ör. 1.2.0. Verilmezse projedeki değer kullanılır.
#                      Örnek: BUILD_NUMBER=42 MARKETING_VERSION=1.2.0 ./scripts/ci.sh archive
#
# Not: macOS'taki /bin/bash hâlâ 3.2 sürümü (GitHub'ın macOS runner'larında da öyle). Bu yüzden betik
# bilerek bash 3.2 ile uyumlu yazıldı: ilişkisel dizi (declare -A), mapfile, ${var,,} gibi özellikler yok.

# "Sıkı mod" (strict mode):
#   -e           Bir komut hata verirse betik hemen durur (CI'ın kırmızıya dönmesi için şart).
#   -u           Tanımsız bir değişken kullanılırsa hata verir (yazım hatalarını yakalar).
#   -o pipefail  `a | b` zincirinde herhangi bir komut başarısız olursa zincirin sonucu da başarısız olur.
#                Bu olmasaydı `xcodebuild ... | xcbeautify` her zaman xcbeautify'ın çıkış kodunu (0) döndürürdü
#                ve testler kırılsa bile CI YEŞİL görünürdü!
set -euo pipefail

# Betik nereden çağrılırsa çağrılsın proje kök dizininde çalışalım (make, CI ve elle çağırma hep aynı olsun).
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
cd "$ROOT_DIR"

readonly PROJECT="BookShelf.xcodeproj"
readonly SCHEME="BookShelf"
readonly CONFIGURATION="Debug"
readonly UNIT_TEST_TARGET="BookShelfTests"
readonly UI_TEST_TARGET="BookShelfUITests"

# Tüm çıktılar build/ altında toplanır: tek komutla temizlenir (.gitignore'da) ve CI'da kolayca bulunur.
# -derivedDataPath vermeseydik Xcode ~/Library/Developer/Xcode/DerivedData/BookShelf-<karma> gibi, yolu önceden
# bilinmeyen bir klasör kullanırdı; betiğin ve CI'ın ürünleri ve sonuçları bulması zorlaşırdı.
readonly DERIVED_DATA_PATH="build/DerivedData"
readonly RESULTS_DIR="build/results"
readonly UNIT_RESULT_BUNDLE="$RESULTS_DIR/unit.xcresult"
readonly UI_RESULT_BUNDLE="$RESULTS_DIR/ui.xcresult"

# "Protocol as a type" quiz'indeki "derlenir / derlenmez" iddialarını gerçek derleyiciyle sınayan betik.
# Betiğin sahibi Swift temelleri konusu; biz sadece çağırıyoruz.
readonly QUIZ_SCRIPT="scripts/check-swift-quiz.sh"

# Arşiv (CD) çıktıları. Testlerle aynı DerivedData'yı kullanıyoruz: Release + cihaz (iphoneos) ürünleri
# Debug + simülatör ürünlerinden ayrı klasörlere yazılır, birbirlerini ezmezler.
readonly ARCHIVE_DIR="build/archive"
readonly ARCHIVE_PATH="$ARCHIVE_DIR/$SCHEME.xcarchive"
readonly ARCHIVE_CONFIGURATION="Release"

# xcodebuild, çıktısı bir terminale değil de bir boruya (pipe) gittiğinde çıktıyı tamponlar (buffer) ve
# loglar parça parça, gecikmeli gelir. Bu değişken tamponlamayı kapatır; CI loglarını canlı izleyebiliriz.
export NSUnbufferedIO=YES

# ---------------------------------------------------------------------------------------------------------
# Yardımcılar
# ---------------------------------------------------------------------------------------------------------

# Bilgi mesajlarını stderr'e yazıyoruz: böylece `destination` komutunun stdout'u SADECE hedefi içerir ve
# başka betikler onu `$(./scripts/ci.sh destination)` diye güvenle yakalayabilir.
log() {
    printf '\n==> %s\n' "$*" >&2
}

die() {
    printf '\nHATA: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Kullanım: ./scripts/ci.sh <komut>

Komutlar:
  quiz         Swift quiz örneklerini derleyiciyle doğrular (scripts/check-swift-quiz.sh)
  build        Uygulamayı ve test paketlerini derler (xcodebuild build-for-testing)
  unit         Birim testlerini çalıştırır (test-without-building, -only-testing:BookShelfTests)
  ui           UI testlerini çalıştırır (test-without-building, -only-testing:BookShelfUITests)
  all          quiz + build + unit + ui + kod kapsamı özeti
  coverage     build/results/unit.xcresult içinden kod kapsamı özetini yazdırır
  archive      İmzasız Release arşivi: build/archive/BookShelf.xcarchive (+ .zip)
  destination  Kullanılacak simülatör hedefini yazdırır (hiçbir şey başlatmaz)
  clean        build/ klasörünü siler

Ortam değişkenleri:
  SIMULATOR_ID       Kullanılacak simülatörün UDID'si (verilmezse otomatik seçilir)
  BUILD_NUMBER       archive: build numarası (CFBundleVersion), varsayılan 1
  MARKETING_VERSION  archive: sürüm (CFBundleShortVersionString), ör. 1.2.0
EOF
}

# Otomatik simülatör seçimi.
#
# `xcrun simctl list devices available -j` bütün simülatörleri JSON olarak verir:
#   { "devices": { "com.apple.CoreSimulator.SimRuntime.iOS-26-2": [ { "name": ..., "udid": ..., "state": ...,
#                                                                     "deviceTypeIdentifier": ... }, ... ], ... } }
# JSON'u bash ile güvenilir biçimde ayrıştırmak zor; python3 hem macOS'ta hem GitHub runner'larında hazır.
#
# Seçim kuralları:
#   1. Sadece iOS runtime'ları ve sadece iPhone'lar (cihaz TİPİNE bakıyoruz, isme değil; isim değiştirilebilir).
#   2. Seçili Xcode'un simülatör SDK'sından daha yeni olmayan runtime'lar tercih edilir. (CI makinesinde birden
#      çok Xcode ve runtime kurulu olabilir; seçili Xcode yeni bir runtime'ı hedef olarak kabul etmeyebilir.)
#   3. Bunlar arasında EN YENİ iOS sürümü.
#   4. O sürümde zaten açık (Booted) bir iPhone varsa o (lokalde açılış süresinden tasarruf); yoksa ada göre ilki
#      (her çalıştırmada aynı cihazın seçilmesi için deterministik sıralama).
#
# Çıktı: stdout'a yalnızca UDID; açıklama stderr'e.
#
# Dikkat: Bu fonksiyon `$(pick_simulator_udid)` biçiminde, yani bir alt kabukta (subshell) çağrılıyor. bash 3.2'de
# `set -e` komut ikamesi (command substitution) içindeki alt kabuğa AKTARILMAZ. Bu yüzden hata kontrollerini
# `|| die` ile açıkça yazıyoruz; yoksa xcrun başarısız olsa bile fonksiyon sessizce devam ederdi.
pick_simulator_udid() {
    local sdk_version devices_json
    sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)" \
        || die "iOS Simulator SDK bulunamadı. Seçili Xcode'u kontrol et: xcode-select -p"
    devices_json="$(xcrun simctl list devices available -j)" \
        || die "Simülatör listesi alınamadı (xcrun simctl)."

    DEVICES_JSON="$devices_json" SDK_VERSION="$sdk_version" python3 - <<'PY'
import json
import os
import re
import sys

def major_minor(parts):
    """(26, 4, 1) -> (26, 4). Sürümleri sadece ana.alt düzeyinde karşılaştırıyoruz."""
    return tuple(parts[:2])

sdk = major_minor([int(p) for p in re.findall(r"\d+", os.environ["SDK_VERSION"])])
runtimes = json.loads(os.environ["DEVICES_JSON"])["devices"]

candidates = []  # (runtime_sürümü, cihaz)
for runtime_id, devices in runtimes.items():
    # Örnek: com.apple.CoreSimulator.SimRuntime.iOS-26-2  (tvOS, watchOS, xrOS runtime'ları elenir)
    match = re.search(r"SimRuntime\.iOS-([0-9-]+)$", runtime_id)
    if not match:
        continue
    version = tuple(int(p) for p in match.group(1).split("-"))
    for device in devices:
        if ".iPhone-" in device.get("deviceTypeIdentifier", ""):
            candidates.append((version, device))

if not candidates:
    sys.exit("Kullanılabilir iPhone simülatörü bulunamadı. Xcode > Settings > Components'tan bir iOS runtime'ı kur "
             "ya da SIMULATOR_ID ortam değişkenini ver.")

compatible = [c for c in candidates if major_minor(c[0]) <= sdk]
if not compatible:
    print("Uyarı: iOS %s SDK'sı ile eşleşen runtime yok; en yeni runtime deneniyor." % ".".join(map(str, sdk)),
          file=sys.stderr)
    compatible = candidates

newest = max(version for version, _ in compatible)
on_newest = [device for version, device in compatible if version == newest]
# False < True olduğu için "state != Booted" anahtarı açık cihazları başa alır.
on_newest.sort(key=lambda d: (d.get("state") != "Booted", d.get("name", "")))
chosen = on_newest[0]

print("Seçilen simülatör: %s (iOS %s, %s, %s)" % (
    chosen["name"], ".".join(map(str, newest)), chosen.get("state", "?"), chosen["udid"]), file=sys.stderr)
print(chosen["udid"])
PY
}

# SIMULATOR_UDID ve DESTINATION global değişkenlerini doldurur.
# Not: `local x="$(komut)"` yazsaydık `local` kendi çıkış kodunu (0) döndürür ve `set -e` hatayı YUTARDI.
# Bu yüzden atamayı `local` olmadan yapıyoruz.
resolve_destination() {
    if [[ -n "${SIMULATOR_ID:-}" ]]; then
        SIMULATOR_UDID="$SIMULATOR_ID"
        log "SIMULATOR_ID verilmiş, otomatik seçim atlandı: $SIMULATOR_UDID"
    else
        SIMULATOR_UDID="$(pick_simulator_udid)"
    fi
    # Simülatörü adıyla (name=iPhone 17 Pro) değil UDID'siyle (id=...) hedefliyoruz: aynı adda birden çok
    # simülatör olabilir ve ad hedeflemesi farklı iOS sürümlerinde farklı cihazlara gidebilir. UDID tektir.
    DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
}

# Testlerden önce simülatörü açar ve tamamen açılana kadar bekler (zaten açıksa hemen döner).
# xcodebuild bunu kendisi de yapar; ama CI makinelerinde ilk açılış yavaş olabildiği için test çalıştırıcısının
# zaman aşımına uğramasını ("test runner never began executing tests") önlemek adına önceden açmak daha kararlıdır.
boot_simulator() {
    log "Simülatör hazırlanıyor: $SIMULATOR_UDID"
    xcrun simctl bootstatus "$SIMULATOR_UDID" -b >&2
}

# xcodebuild'i çalıştırır. xcbeautify kuruluysa çıktıyı okunaklı hale getirir; değilse ham çıktı gösterilir.
# `set -o pipefail` sayesinde xcodebuild başarısız olursa bu fonksiyon da başarısız olur (xcbeautify 0 dönse bile).
run_xcodebuild() {
    log "xcodebuild $*"
    if command -v xcbeautify >/dev/null 2>&1; then
        if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
            # GitHub renderer'ı hata ve uyarıları "annotation" (workflow komutu) olarak yazar;
            # çalıştırmanın özet sayfasında ayrıca listelenirler.
            xcodebuild "$@" 2>&1 | xcbeautify --renderer github-actions
        else
            xcodebuild "$@" 2>&1 | xcbeautify
        fi
    else
        xcodebuild "$@"
    fi
}

# build, unit ve ui komutlarının ortak argümanları. Hepsinin AYNI -derivedDataPath'i kullanması şart:
# test-without-building, build-for-testing'in bıraktığı ürünleri (ve .xctestrun dosyasını) orada arar.
common_xcodebuild_args() {
    COMMON_ARGS=(
        -project "$PROJECT"
        -scheme "$SCHEME"
        -configuration "$CONFIGURATION"
        -destination "$DESTINATION"
        -derivedDataPath "$DERIVED_DATA_PATH"
    )
}

# test-without-building öncesinde derlenmiş ürün var mı? Yoksa xcodebuild'in anlaşılması zor hatası yerine
# ne yapılması gerektiğini söyleyen bir mesaj verelim.
require_build_products() {
    if ! compgen -G "$DERIVED_DATA_PATH/Build/Products/${SCHEME}_*.xctestrun" >/dev/null; then
        die "Derlenmiş test ürünü bulunamadı. Önce './scripts/ci.sh build' çalıştır."
    fi
}

# ---------------------------------------------------------------------------------------------------------
# Komutlar
# ---------------------------------------------------------------------------------------------------------

# build-for-testing: Uygulamayı + iki test paketini derler ve Build/Products altına bir .xctestrun dosyası yazar.
# Bu dosya "hangi test paketi, hangi uygulamayla, hangi ayarlarla çalışacak" bilgisini taşır. Sonraki
# test-without-building çağrıları DERLEME YAPMADAN bu dosyayı kullanır: bir kez derle, çok kez test et.
#
# -enableCodeCoverage YES: Kodu kapsam ölçümü için enstrümante ederek derler (hangi satırın çalıştığını sayan
# ek kod eklenir). Kapsam derleme anında karar verilen bir şey olduğu için build aşamasında da verilmeli.
cmd_build() {
    resolve_destination
    common_xcodebuild_args
    run_xcodebuild build-for-testing \
        "${COMMON_ARGS[@]}" \
        -enableCodeCoverage YES
}

# Birim testleri: -only-testing ile sadece BookShelfTests hedefini çalıştırır.
#
# -resultBundlePath: Sonuçlar (loglar, test sonuçları, kapsam verisi) tek bir .xcresult paketine yazılır.
#   O yolda zaten bir paket varsa xcodebuild testleri HİÇ çalıştırmadan hata verir
#   ("Existing file at -resultBundlePath"); bu yüzden önce eskisini siliyoruz.
# -parallel-testing-enabled NO: Testler tek simülatörde sırayla koşar. Xcode paralel testte simülatörün
#   kopyalarını (klon) açar; küçük bir projede bu hızlandırmaz, sadece bellek ve karmaşıklık ekler.
cmd_unit() {
    resolve_destination
    common_xcodebuild_args
    require_build_products
    boot_simulator
    rm -rf "$UNIT_RESULT_BUNDLE"
    mkdir -p "$RESULTS_DIR"
    run_xcodebuild test-without-building \
        "${COMMON_ARGS[@]}" \
        -only-testing:"$UNIT_TEST_TARGET" \
        -parallel-testing-enabled NO \
        -enableCodeCoverage YES \
        -resultBundlePath "$UNIT_RESULT_BUNDLE"
}

# UI testleri: birim testlerle aynı, ek olarak başarısız testi BİR kez daha dener.
#
# -retry-tests-on-failure -test-iterations 2: Başarısız olan test en fazla 2 kez (1 asıl + 1 tekrar) koşar.
#   Artısı: UI testleri simülatör yavaşlığı gibi bizden bağımsız nedenlerle ara sıra düşebilir (flaky);
#   tek bir şanssız çalıştırma bütün pipeline'ı kırmızıya çevirmez.
#   Eksisi: Gerçekten "bazen" ortaya çıkan bir hatayı (ör. bir yarış durumu) gizleyebilir. Bu yüzden:
#   - Tekrar sadece UI testlerinde açık; birim testleri deterministik olmak ZORUNDA, orada tekrar yok.
#   - Her deneme .xcresult içinde kayıtlıdır; "ikinci denemede geçti" durumlarını raporda görüp düzeltmek gerekir.
cmd_ui() {
    resolve_destination
    common_xcodebuild_args
    require_build_products
    boot_simulator
    rm -rf "$UI_RESULT_BUNDLE"
    mkdir -p "$RESULTS_DIR"
    run_xcodebuild test-without-building \
        "${COMMON_ARGS[@]}" \
        -only-testing:"$UI_TEST_TARGET" \
        -parallel-testing-enabled NO \
        -enableCodeCoverage YES \
        -retry-tests-on-failure \
        -test-iterations 2 \
        -resultBundlePath "$UI_RESULT_BUNDLE"
}

# Kod kapsamı özeti: --only-targets hedef (target) başına yüzdeleri gösterir.
# Dosya/fonksiyon ayrıntısı için: xcrun xccov view --report build/results/unit.xcresult
cmd_coverage() {
    [[ -d "$UNIT_RESULT_BUNDLE" ]] || die "$UNIT_RESULT_BUNDLE bulunamadı. Önce './scripts/ci.sh unit' çalıştır."
    log "Kod kapsamı (birim testleri)"
    xcrun xccov view --report --only-targets "$UNIT_RESULT_BUNDLE"
}

# Quiz kontrolü: "Bu kod derlenir mi?" sorularının cevaplarını derleyiciye sorar (swiftc -typecheck).
# Simülatör ve proje derlemesi gerektirmez, saniyeler sürer. Bu yüzden CI'da derlemeden ÖNCE koşar:
# öğretici içerik yanlışsa pahalı macOS dakikalarını harcamadan hemen kırmızı yanar (fail fast).
# Betiği `bash betik` diye çağırıyoruz: çalıştırılabilir biti (chmod +x) commit'lenmemiş olsa bile çalışır.
# `set -e` sayesinde betik sıfır dışı bir kodla biterse ci.sh de aynı kodla durur.
cmd_quiz() {
    [[ -f "$QUIZ_SCRIPT" ]] || die "$QUIZ_SCRIPT bulunamadı."
    log "Swift quiz örnekleri derleyiciyle doğrulanıyor ($QUIZ_SCRIPT)"
    bash "$QUIZ_SCRIPT"
}

# Release arşivi: CD'nin (release.yml) imza gerektirmeyen ilk işi.
#
# Sürüm numaraları (ikisi de Info.plist'e yazılır):
#   MARKETING_VERSION → CFBundleShortVersionString: Kullanıcının gördüğü sürüm, ör. 1.2.0. App Store kuralı:
#     noktayla ayrılmış en fazla üç tamsayı. Git etiketi "v1.2.0" ise baştaki "v"yi workflow atar.
#   BUILD_NUMBER → CFBundleVersion: Aynı sürümün kaçıncı derlemesi olduğu. App Store Connect, aynı sürüm için
#     aynı build numarasını İKİNCİ KEZ kabul etmez. CI'da her çalıştırmada artan github.run_number veriyoruz.
#
# Proje GENERATE_INFOPLIST_FILE = YES kullanıyor: Info.plist'teki bu iki anahtar $(MARKETING_VERSION) ve
# $(CURRENT_PROJECT_VERSION) ayarlarından üretilir. Komut satırındaki AYAR=değer biçimi, projedeki değeri yalnızca
# bu çalıştırma için ezer (override). Proje dosyası değişmez, commit gerekmez.
#
# CODE_SIGNING_ALLOWED=NO: İmzalamayı tamamen kapatır. Sertifika, provisioning profile ve takım (team) olmadan
# arşivlemenin yolu bu. Ortaya çıkan .app hiçbir cihaza kurulamaz ve App Store Connect'e yüklenemez. Ne işe yarar?
#   - Uygulamanın Release yapılandırmasıyla ve gerçek cihaz SDK'sıyla (iphoneos, arm64) derlendiğini kanıtlar.
#     Testler Debug + simülatörde koşar; yalnızca Release'te ortaya çıkan hataları ancak burada görürüz.
#   - Sürüm bilgisini ve dSYM'leri (çökme raporlarını sembolize etmek için) taşıyan bir arşiv bırakır.
# İmzalı arşiv ve TestFlight için release.yml'deki "testflight" işine bak.
#
# -destination 'generic/platform=iOS': Belirli bir cihaz değil, "herhangi bir iOS cihazı". Arşiv her zaman
# cihaz için yapılır; simülatör için arşiv olmaz. Bu yüzden simülatör seçmiyor ve açmıyoruz.
cmd_archive() {
    local build_number="${BUILD_NUMBER:-1}"
    local marketing_version="${MARKETING_VERSION:-}"

    [[ "$build_number" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] \
        || die "BUILD_NUMBER geçersiz: '$build_number' (beklenen: 42 ya da 42.1 gibi sayılar)."
    if [[ -n "$marketing_version" ]]; then
        [[ "$marketing_version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] \
            || die "MARKETING_VERSION geçersiz: '$marketing_version' (beklenen: 1.2.0 gibi en fazla üç sayı)."
    fi

    local -a version_overrides=(CURRENT_PROJECT_VERSION="$build_number")
    if [[ -n "$marketing_version" ]]; then
        version_overrides+=(MARKETING_VERSION="$marketing_version")
    fi

    # Eski arşiv kalırsa xcodebuild üzerine yazar ama içinde eski dosyalar kalabilir; temiz başlayalım.
    rm -rf "$ARCHIVE_DIR"
    mkdir -p "$ARCHIVE_DIR"

    run_xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$ARCHIVE_CONFIGURATION" \
        -destination "generic/platform=iOS" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGNING_ALLOWED=NO \
        "${version_overrides[@]}"

    # Arşivin kök Info.plist'i, içindeki uygulamanın sürüm bilgisini de taşır. Override'ın gerçekten işe yaradığını
    # (ör. biri ileride elle yazılmış bir Info.plist'e geçerse) burada yakalarız: yanlış numarayla yüklemekten iyidir.
    local archive_info="$ARCHIVE_PATH/Info.plist"
    local actual_build actual_version
    actual_build="$(plutil -extract ApplicationProperties.CFBundleVersion raw -o - "$archive_info")" \
        || die "Arşivde CFBundleVersion okunamadı: $archive_info"
    actual_version="$(plutil -extract ApplicationProperties.CFBundleShortVersionString raw -o - "$archive_info")" \
        || die "Arşivde CFBundleShortVersionString okunamadı: $archive_info"
    [[ "$actual_build" == "$build_number" ]] \
        || die "Build numarası beklenen gibi değil: arşivde $actual_build, beklenen $build_number."
    if [[ -n "$marketing_version" && "$actual_version" != "$marketing_version" ]]; then
        die "Sürüm beklenen gibi değil: arşivde $actual_version, beklenen $marketing_version."
    fi

    # .xcarchive bir klasör (paket). Tek dosya olarak saklamak ve GitHub Release'e eklemek için zip'liyoruz.
    # Neden zip yerine ditto? ditto, Apple paketlerindeki sembolik bağlantıları (symlink) ve çalıştırılabilir
    # bitlerini korur. (upload-artifact klasör yüklerken dosya izinlerini korumaz; önceden zip'lemek bunu da çözer.)
    local zip_path="$ARCHIVE_DIR/$SCHEME-$actual_version-$actual_build.xcarchive.zip"
    ditto -c -k --keepParent "$ARCHIVE_PATH" "$zip_path"

    # GitHub Actions'ta adımın çıktısı (step output) olarak da ver: sonraki adımlar dosya adını tahmin etmesin,
    # ${{ steps.<id>.outputs.zip_path }} diye okusun. $GITHUB_OUTPUT yalnızca Actions içinde tanımlıdır.
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        {
            echo "zip_path=$zip_path"
            echo "marketing_version=$actual_version"
            echo "build_number=$actual_build"
        } >> "$GITHUB_OUTPUT"
    fi

    log "Arşiv hazır: $ARCHIVE_PATH (sürüm $actual_version, build $actual_build, İMZASIZ)"
    log "Zip: $zip_path"
}

cmd_all() {
    cmd_quiz
    cmd_build
    cmd_unit
    cmd_ui
    cmd_coverage
    log "Tamamlandı: quiz + derleme + birim testleri + UI testleri (${SECONDS} sn). Sonuçlar: $RESULTS_DIR/"
}

cmd_clean() {
    log "build/ siliniyor"
    rm -rf build
}

main() {
    local command="${1:-}"
    case "$command" in
        quiz) cmd_quiz ;;
        build) cmd_build ;;
        unit) cmd_unit ;;
        ui) cmd_ui ;;
        all) cmd_all ;;
        coverage) cmd_coverage ;;
        archive) cmd_archive ;;
        clean) cmd_clean ;;
        destination)
            resolve_destination
            printf '%s\n' "$DESTINATION"
            ;;
        help | -h | --help) usage ;;
        *)
            usage >&2
            # 64 = EX_USAGE: "komut yanlış kullanıldı" anlamına gelen geleneksel çıkış kodu.
            exit 64
            ;;
    esac
}

main "$@"
