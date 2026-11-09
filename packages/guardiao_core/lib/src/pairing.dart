import 'dart:math';

/// Alfabeto sem caracteres confundíveis (sem 0/O, 1/I/L).
const pairingAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Tamanho do código: 8 caracteres = ~8,5 x 10^11 combinações.
const pairingCodeLength = 8;

/// Tempo de validade do código.
const pairingCodeTtl = Duration(minutes: 10);

/// Gera um código de pareamento (quem gera é o aparelho do filho).
/// Usa [Random.secure] fora de testes.
String generatePairingCode([Random? random]) {
  final rng = random ?? Random.secure();
  return List.generate(
    pairingCodeLength,
    (_) => pairingAlphabet[rng.nextInt(pairingAlphabet.length)],
  ).join();
}

/// Deixa o código no formato canônico: maiúsculo, sem traço e sem espaços.
String normalizePairingCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool isValidPairingCode(String input) {
  final code = normalizePairingCode(input);
  return code.length == pairingCodeLength &&
      code.split('').every(pairingAlphabet.contains);
}

/// Mostra o código em dois blocos, como "K7M2-9QXA".
String formatPairingCode(String code) {
  final c = normalizePairingCode(code);
  if (c.length != pairingCodeLength) return c;
  return '${c.substring(0, 4)}-${c.substring(4)}';
}

/// Texto que vai dentro do QR do aparelho do filho. Em formato de endereço
/// (`guardiao://pair?code=K7M29QXA`) para, no futuro, poder abrir o app direto.
String pairingQrPayload(String code) =>
    'guardiao://pair?code=${normalizePairingCode(code)}';

/// Lê o conteúdo de um QR (ou um código digitado) e devolve o código de
/// pareamento no formato canônico. `null` se não for do Guardião.
String? parsePairingQr(String? text) {
  final value = (text ?? '').trim();
  if (value.isEmpty) return null;
  if (isValidPairingCode(value)) return normalizePairingCode(value);
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'guardiao' || uri.host != 'pair') {
    return null;
  }
  final code = uri.queryParameters['code'];
  if (code == null || !isValidPairingCode(code)) return null;
  return normalizePairingCode(code);
}

/// Esconde parte do e-mail para mostrá-lo ao filho: `joao.silva@gmail.com`
/// vira `jo***@gmail.com`. Serve para o filho confirmar a quem está se
/// vinculando, sem expor o endereço inteiro.
String maskEmail(String? email) {
  final value = (email ?? '').trim();
  final at = value.indexOf('@');
  if (at <= 0) return 'um responsável';
  final local = value.substring(0, at);
  final shown = local.length <= 2
      ? local.substring(0, 1)
      : local.substring(0, 2);
  return '$shown***${value.substring(at)}';
}
