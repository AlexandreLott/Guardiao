import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Leitor de QR usado pelo responsável para vincular o aparelho do filho.
///
/// É uma interface para que os testes troquem a câmera por um leitor falso, e
/// para que computadores sem câmera simplesmente não ofereçam o botão (o
/// código escrito abaixo do QR continua funcionando).
abstract class QrScanner {
  /// Este aparelho consegue abrir a câmera para ler QR?
  bool get supported;

  /// Tela de leitura. Chama [onCode] a cada texto lido; [onProblem] recebe uma
  /// mensagem em português quando a câmera não pode ser usada (por exemplo,
  /// permissão negada).
  Widget build(
    BuildContext context, {
    required ValueChanged<String> onCode,
    required ValueChanged<String> onProblem,
  });

  /// Câmera no Android e no iPhone; nos demais sistemas, sem leitor.
  static QrScanner detect() {
    if (kIsWeb) return UnsupportedQrScanner();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return CameraQrScanner();
      default:
        return UnsupportedQrScanner();
    }
  }
}

class UnsupportedQrScanner implements QrScanner {
  @override
  bool get supported => false;

  @override
  Widget build(
    BuildContext context, {
    required ValueChanged<String> onCode,
    required ValueChanged<String> onProblem,
  }) => const SizedBox.shrink();
}

/// Leitor de verdade, em cima da câmera (biblioteca `mobile_scanner`).
class CameraQrScanner implements QrScanner {
  @override
  bool get supported => true;

  @override
  Widget build(
    BuildContext context, {
    required ValueChanged<String> onCode,
    required ValueChanged<String> onProblem,
  }) => _CameraView(onCode: onCode, onProblem: onProblem);
}

class _CameraView extends StatefulWidget {
  const _CameraView({required this.onCode, required this.onProblem});

  final ValueChanged<String> onCode;
  final ValueChanged<String> onProblem;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _message(MobileScannerException e) => switch (e.errorCode) {
    MobileScannerErrorCode.permissionDenied =>
      'Sem a permissão da câmera não dá para ler o QR. Libere nas '
          'configurações do app, ou digite o código.',
    MobileScannerErrorCode.unsupported =>
      'Este aparelho não consegue ler QR pela câmera. Digite o código.',
    _ => 'Não foi possível abrir a câmera. Digite o código.',
  };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final value = barcode.rawValue;
              if (value != null && value.isNotEmpty) {
                widget.onCode(value);
                return;
              }
            }
          },
          errorBuilder: (context, error) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onProblem(_message(error));
            });
            return const ColoredBox(color: Colors.black);
          },
        ),
      ),
    );
  }
}
