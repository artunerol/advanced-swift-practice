# Makefile — scripts/ci.sh için kısa yollar.
#
# Asıl mantık scripts/ci.sh içinde; buradaki hedefler sadece ince sarmalayıcılar (thin wrapper).
# Böylece "make test" yazan da, CI'daki "./scripts/ci.sh unit" adımı da AYNI komutu çalıştırır.
#
# Belirli bir simülatör kullanmak için:  make test SIMULATOR_ID=<UDID>
# (Komut satırında verilen değişkenler tariflerin ortamına aktarılır; ci.sh onu okur.)
#
# Dikkat: Makefile'da tarif (recipe) satırları BOŞLUKLA değil, SEKME (tab) karakteriyle başlamak zorundadır.
# Aksi halde "missing separator" hatası alırsın.

CI := ./scripts/ci.sh

# Sadece "make" yazılırsa yardım gösterilsin.
.DEFAULT_GOAL := help

# Bu hedefler dosya adı değil, komut adıdır. Aynı adda bir dosya/klasör olsa bile (ör. build/) hedef çalışır.
.PHONY: help build test unit ui ci clean open

# "make -j" ile çalıştırılsa bile hedefler sırayla koşsun: birim ve UI testleri aynı simülatörü ve
# aynı build/ klasörünü kullanır, paralel çalışırlarsa birbirlerini bozarlar.
.NOTPARALLEL:

help: ## Bu yardımı gösterir
	@echo "Kullanım: make <hedef>"
	@echo ""
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  make %-7s %s\n", $$1, $$2}'

build: ## Uygulamayı ve test paketlerini derler (build-for-testing)
	$(CI) build

# unit ve ui "build"e bağımlı: test-without-building önceden derlenmiş ürün ister.
# "make test" dediğimizde make, build'i bir çalıştırmada yalnızca BİR kez koşar.
unit: build ## Derler ve birim testlerini (XCTest) çalıştırır
	$(CI) unit

ui: build ## Derler ve UI testlerini (XCUITest) çalıştırır
	$(CI) ui

test: unit ui ## Derler, birim + UI testlerini çalıştırır

ci: ## CI'daki akışın aynısı: build + unit + ui + kod kapsamı özeti
	$(CI) all

clean: ## build/ klasörünü (DerivedData + test sonuçları) siler
	$(CI) clean

open: ## Projeyi Xcode'da açar
	open BookShelf.xcodeproj
