# Guardião Gamer — aplicativo

Um só app para Android e Windows. Veja o [README principal](../../README.md) e [docs/CONFIGURAR-FIREBASE.md](../../docs/CONFIGURAR-FIREBASE.md).

- `lib/role/`: escolha da função do aparelho (responsável ou filho) e onde ela é guardada.
- `lib/parent/`: lado do responsável (login, aparelhos, regras, resumo de uso, envio por Bluetooth).
- `lib/child/`: lado do filho (pareamento, tela principal, sincronização).
  - `platform/installed_apps_source.dart`: apps instalados.
  - `usage/`: medição e bloqueio (`android_usage_monitor.dart`, `windows_usage_monitor.dart`, `usage_controller.dart`).
- `lib/nearby/nearby.dart`: pareamento por Bluetooth (interface Dart).
- `android/.../kotlin/`: parte nativa do Android: `BleNearby.kt` (Bluetooth), `UsageMath.kt` e `UsageReader.kt` (contas do uso), `MonitorService.kt` e `BlockOverlay.kt` (serviço e tela de bloqueio), `MainActivity.kt` (pontes com o Flutter).
