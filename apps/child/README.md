# Guardião Gamer — app do filho

Android e Windows. Veja o [README principal](../README.md) e [docs/CONFIGURAR-FIREBASE.md](../../docs/CONFIGURAR-FIREBASE.md).

- `lib/platform/installed_apps_source.dart`: leitura dos apps instalados (Android pelo canal `MainActivity.kt`; Windows pelo registro).
- `lib/screens/pairing_screen.dart`: digitar o código do responsável.
- `lib/screens/home_screen.dart`: tempo restante por app.
- `lib/sync/device_sync.dart`: envia a lista de apps e o sinal de vida.
