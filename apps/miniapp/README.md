# DVOR Mini App

Flutter web app opened inside Telegram. Architecture, API and deploy: `docs/MINIAPP_ARCHITECTURE.md`.

```bash
flutter run -d chrome --dart-define=DVOR_DEMO=true   # local preview with demo data
flutter analyze && flutter test
../../scripts/deploy_miniapp.sh                      # build + upload to prod
```
