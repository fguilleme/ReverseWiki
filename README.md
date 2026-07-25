# Reverse Wiki

MVP iOS 17+ : capture/import, géolocalisation, géocodage inverse, fait historique
sourcé, cache Core Data et export PNG 1080 × 1350.

## Fournisseur LLM

Copier `Config.example.xcconfig` vers `Config.xcconfig`, puis sélectionner ce fichier
comme configuration de base Debug/Release de la cible dans Xcode. Les valeurs sont
injectées dans Info.plist par les Build Settings du projet.

Fournisseurs intégrés :

- `anthropic` : API Messages native.
- `openai` : API Chat Completions.
- `gemini` : API Google `generateContent` native (un palier gratuit existe selon
  le modèle, la région et les quotas Google en vigueur).
- `kimi` : endpoint Moonshot compatible OpenAI.
- `openrouter` : Chat Completions OpenRouter.
- `custom` : endpoint Chat Completions compatible OpenAI ; définir `LLM_ENDPOINT`.

Configurer `LLM_PROVIDER`, `LLM_API_KEY` et `LLM_MODEL`. `Config.xcconfig` est ignoré
par Git. Une app distribuée ne doit cependant pas embarquer un secret fournisseur :
utiliser un backend/proxy qui conserve les clés côté serveur.

L’exemple utilise `gemini-3.6-flash`, disponible sur le palier gratuit Gemini au
moment de cette version.
