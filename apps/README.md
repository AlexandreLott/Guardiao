# Guardião Gamer — aplicativos

Controle parental para jogos no celular e no computador (Projeto A3, UC Exploração Digital e Fundamentos Tecnológicos).

São dois aplicativos Flutter que conversam por um backend Firebase:

| App | Quem usa | Onde roda | O que faz |
| --- | --- | --- | --- |
| **Filho** (`apps/child`) | A criança | Android e Windows | Vincula o aparelho com um código, envia a lista de apps instalados e mostra o tempo restante de cada app |
| **Responsável** (`apps/parent`) | Pai, mãe ou responsável | Android e Windows (iPhone previsto) | Cria a conta, gera o código de pareamento, vê os apps instalados e define limite diário ou bloqueio por app |

```
apps/child/              app do filho (Flutter: Android + Windows)
apps/parent/             app do responsável (Flutter: Android + iOS)
packages/guardiao_core/  modelos, pareamento, acesso ao Firebase, tema (usado pelos dois)
firebase/                regras de segurança do Firestore + testes das regras
docs/                    arquitetura e configuração do Firebase
```

## Estado atual (marco 1)

Funciona e está testado:

- Conta do responsável (e-mail e senha) e login anônimo do aparelho do filho.
- Pareamento por código de 8 caracteres que vale 10 minutos e só pode ser usado uma vez.
- App do filho lê os apps instalados (Android: PackageManager; Windows: registro do sistema) e envia ao responsável.
- Responsável vê os aparelhos, os apps de cada um, busca por nome e define **limite diário** ou **bloqueio**; a regra aparece no app do filho em tempo real.
- Remover o aparelho no app do responsável desvincula o filho.
- Regras de segurança do Firestore (30 testes no emulador).

Ainda **não** existe (próximos marcos):

- Medir o tempo de uso de cada app (Android: estatísticas de uso; Windows: janela em primeiro plano). Por isso o tempo restante ainda não diminui.
- Bloquear de fato o app quando o limite acaba (Android: serviço de acessibilidade; Windows: encerrar o processo ou cobrir a tela).
- Relatório de tempo de tela no app do responsável, ícones dos apps, notificações, app do responsável no iPhone.

## Rodar sem Firebase (modo demonstração)

Sem chaves do Firebase os dois apps abrem com dados de exemplo, na memória do próprio aparelho (não conversam entre si).

```
cd apps/parent && flutter run            # entre com demo@guardiaogamer.app / demo1234
cd apps/child  && flutter run            # use o código DEMX-2345
```

## Rodar com Firebase (os dois apps conversando)

Siga [docs/CONFIGURAR-FIREBASE.md](../docs/CONFIGURAR-FIREBASE.md) e rode com as chaves:

```
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=...
```

As chaves ficam fora do código (nada secreto no repositório).

## Testes

```
cd packages/guardiao_core && flutter test     # 22 testes (modelos, pareamento, backend em memória)
cd apps/child  && flutter test                # 12 testes (leitura de apps, fluxo de pareamento)
cd apps/parent && flutter test                # 11 testes (login, aparelhos, limites, pareamento)
cd firebase/tests && npm install && npm test  # 30 testes das regras do Firestore (emulador)
```

Versões usadas: Flutter 3.47, Dart 3.13, Firebase Auth 7, Cloud Firestore 7.

## Privacidade

O app guarda só o necessário: nome do aparelho, nomes dos apps instalados e as regras do responsável. Não coleta conversas, localização nem dados de pagamento. A criança vê tudo que é monitorado. Base legal: consentimento do responsável (LGPD, art. 14).
