/// Uma versão do app publicada no GitHub (Release "apk-N").
class AppUpdate {
  const AppUpdate({
    required this.build,
    required this.apkUrl,
    this.sizeBytes,
    this.sha256,
    this.notes = '',
  });

  /// Número da versão (o mesmo `versionCode` do APK).
  final int build;
  final String apkUrl;
  final int? sizeBytes;

  /// Soma SHA-256 do APK (minúsculas), quando o GitHub informa.
  final String? sha256;
  final String notes;
}

/// Lê o número da versão da etiqueta da Release (`apk-12` → 12).
int? buildFromTag(String? tag) {
  final match = RegExp(r'^apk-(\d+)$').firstMatch((tag ?? '').trim());
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// Converte a resposta de `releases/latest` da API do GitHub. Devolve `null`
/// se a Release não tem o arquivo `guardiao.apk` ou a etiqueta é de outro
/// tipo.
AppUpdate? parseRelease(Map<String, Object?> json) {
  final build = buildFromTag(json['tag_name'] as String?);
  if (build == null) return null;
  final assets = (json['assets'] as List?) ?? const [];
  for (final raw in assets) {
    if (raw is! Map) continue;
    if (raw['name'] != 'guardiao.apk') continue;
    final url = raw['browser_download_url'] as String?;
    if (url == null || !url.startsWith('https://')) continue;
    final digest = raw['digest'] as String?;
    return AppUpdate(
      build: build,
      apkUrl: url,
      sizeBytes: (raw['size'] as num?)?.toInt(),
      sha256: (digest != null && digest.startsWith('sha256:'))
          ? digest.substring(7).toLowerCase()
          : null,
      notes: ((json['body'] as String?) ?? '').trim(),
    );
  }
  return null;
}
