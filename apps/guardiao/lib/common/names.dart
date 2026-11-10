/// "Celular da Duda" → "Duda"; "Notebook do Pedro" → "Pedro"; sem esse
/// formato, a primeira palavra do nome.
String childName(String deviceName) {
  final words = deviceName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'Filho';
  for (var i = 0; i < words.length - 1; i++) {
    final w = words[i].toLowerCase();
    if (w == 'da' || w == 'do' || w == 'de') return words[i + 1];
  }
  return words.first;
}

const _longMonths = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];
const _longDays = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];

/// "Terça-feira, 10 de nov."
String dayTitle(DateTime d) =>
    '${_longDays[d.weekday - 1]}, ${d.day} de ${_longMonths[d.month - 1]}.';

/// Minutos desde a meia-noite → "07:30".
String clockText(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
