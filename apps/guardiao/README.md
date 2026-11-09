# Guardião — aplicativo

Um só app para Android e Windows. Veja o [README principal](../../README.md) e [docs/CONFIGURAR-FIREBASE.md](../../docs/CONFIGURAR-FIREBASE.md).

- `lib/role/`: escolha da função do aparelho (responsável ou filho) e onde ela é guardada.
- `lib/parent/`: lado do responsável (login, aparelhos, regras, resumo de uso, vincular aparelhos lendo o QR).
- `lib/child/`: lado do filho (QR de vínculo, tela principal, sincronização).
  - `platform/installed_apps_source.dart`: apps instalados.
  - `usage/`: medição e bloqueio (`android_usage_monitor.dart`, `windows_usage_monitor.dart`, `usage_controller.dart`).
- `lib/qr/qr_scanner.dart`: leitura do QR pela câmera (Android/iOS); no Windows usa o código digitado.
- `android/.../kotlin/`: parte nativa do Android: `UsageMath.kt` e `UsageReader.kt` (contas do uso), `MonitorService.kt` e `BlockOverlay.kt` (serviço e tela de bloqueio), `MainActivity.kt` (pontes com o Flutter).
