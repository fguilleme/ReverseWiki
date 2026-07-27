#!/bin/bash
set -euo pipefail

SIMULATOR_ID="${SIMULATOR_ID:-84FC3EAC-45B4-4507-AADB-293794107951}"
BUNDLE_ID="${BUNDLE_ID:-com.guilleme.ReverseWiki}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

locales=(
  "fr-FR|fr|fr_FR"
  "en-US|en|en_US"
  "de-DE|de|de_DE"
  "es-ES|es|es_ES"
  "pt-PT|pt-PT|pt_PT"
  "ru|ru|ru_RU"
  "ja|ja|ja_JP"
  "zh-Hans|zh-Hans|zh_Hans_CN"
  "ar-SA|ar|ar_SA"
)

screens=(
  "01-accueil|home"
  "02-modeles|settings"
  "03-resultat|result"
  "04-carte-et-sources|map"
  "05-aide|help"
)

xcrun simctl status_bar "$SIMULATOR_ID" override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3

for locale_spec in "${locales[@]}"; do
  IFS="|" read -r directory language apple_locale <<< "$locale_spec"
  output="$ROOT/$directory/screenshots-ipad"
  mkdir -p "$output"

  for screen_spec in "${screens[@]}"; do
    IFS="|" read -r filename mode <<< "$screen_spec"
    xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID" \
      -AppleLanguages "($language)" \
      -AppleLocale "$apple_locale" \
      -hasCompletedInitialHelp YES \
      -appStoreScreenshotMode "$mode" >/dev/null
    sleep 1.2
    temporary="/private/tmp/reversewiki-ipad-${directory}-${filename}.png"
    xcrun simctl io "$SIMULATOR_ID" screenshot \
      --type=png "$temporary" >/dev/null
    cp "$temporary" "$output/$filename.png"
    rm -f "$temporary"
  done
done

echo "Captures iPad 2064 x 2752 créées dans $ROOT"
