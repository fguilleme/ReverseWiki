#!/bin/bash
set -euo pipefail

SIMULATOR_ID="${SIMULATOR_ID:-55409C09-1F8E-4294-9973-C1EAEF7A37C4}"
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
  --wifiBars 3 \
  --cellularBars 4

for locale_spec in "${locales[@]}"; do
  IFS="|" read -r directory language apple_locale <<< "$locale_spec"
  output="$ROOT/$directory/screenshots"
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
    temporary="/private/tmp/reversewiki-${directory}-${filename}.png"
    xcrun simctl io "$SIMULATOR_ID" screenshot \
      --type=png "$temporary" >/dev/null
    cp "$temporary" "$output/$filename.png"
    sips --resampleWidth 1284 "$output/$filename.png" >/dev/null
    sips --cropToHeightWidth 2778 1284 "$output/$filename.png" >/dev/null
    rm -f "$temporary"
  done
done

echo "Captures 1284 x 2778 créées dans $ROOT"
