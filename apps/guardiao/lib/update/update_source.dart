import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'update_models.dart';

/// De onde vem a informação da versão mais nova.
abstract class UpdateSource {
  /// A versão mais nova publicada, ou `null` se não há (ou não deu para ver).
  Future<AppUpdate?> latest();
}

/// Endereço da Release mais recente do repositório (público).
const githubLatestRelease =
    'https://api.github.com/repos/AlexandreLott/Guardiao/releases/latest';

/// Consulta a API pública do GitHub (sem login; limite de 60 consultas por hora
/// por rede, o que sobra).
class GithubUpdateSource implements UpdateSource {
  GithubUpdateSource({this.url = githubLatestRelease, HttpClient? client})
    : _client = client ?? HttpClient();

  final String url;
  final HttpClient _client;

  @override
  Future<AppUpdate?> latest() async {
    try {
      final request = await _client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('User-Agent', 'guardiao-app');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      final json = jsonDecode(body);
      return json is Map<String, Object?> ? parseRelease(json) : null;
    } on Object {
      return null; // sem internet, limite do GitHub etc.: tenta de novo depois
    }
  }
}

/// Fonte para testes e demonstração.
class FakeUpdateSource implements UpdateSource {
  FakeUpdateSource(this.update);
  AppUpdate? update;
  int calls = 0;

  @override
  Future<AppUpdate?> latest() async {
    calls++;
    return update;
  }
}
