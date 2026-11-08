# Guardião Gamer — aplicativo

Controle parental para jogos no celular e no computador (Projeto A3, UC Exploração Digital e Fundamentos Tecnológicos).

É **um único aplicativo Flutter** (`apps/guardiao`). No primeiro acesso ele pergunta de quem é o aparelho:

| Função | Quem escolhe | O que o app faz |
| --- | --- | --- |
| **Sou o responsável** | Pai, mãe ou responsável | Cria a conta, gera o código de pareamento (ou envia por Bluetooth), vê os apps instalados, define limite diário ou bloqueio e acompanha o tempo de uso da última semana |
| **Este aparelho é do filho** | A criança (ou o responsável, ao configurar o aparelho dela) | Vincula com o código, envia a lista de apps, **mede o tempo de uso e bloqueia** o app quando o limite acaba |

A escolha fica guardada no aparelho e pode ser trocada pelo menu da conta (isso sai da conta antes, para um aparelho nunca ficar com o login do outro lado).

```
apps/guardiao/           o aplicativo (Flutter: Android + Windows)
packages/guardiao_core/  modelos, pareamento, acesso ao Firebase, tema
firebase/                regras de segurança do Firestore + testes das regras
docs/                    arquitetura e configuração do Firebase
```

## Estado atual (marco 2)

Funciona e está testado:

- Escolha da função do aparelho no primeiro acesso, com opção de voltar e trocar.
- Conta do responsável (e-mail e senha) e login anônimo do aparelho do filho.
- Pareamento por código de 8 caracteres (vale 10 minutos, uso único) **ou por Bluetooth** (Android): o filho fica visível, o responsável toca no aparelho e o código é enviado; o filho confirma vendo quem está pedindo. O vínculo em si é feito pelo Firebase, então não é preciso domínio nem servidor próprio.
- Lista de apps instalados (Android: PackageManager; Windows: registro do sistema).
- **Tempo de uso real**: Android pelas estatísticas de uso do sistema; Windows pelo programa em primeiro plano (não conta quando o computador está parado).
- **Bloqueio de verdade**: no Android um serviço cobre o app com uma tela de “tempo esgotado” e volta ao início; no Windows o programa é encerrado. Os limites ficam salvos no aparelho, então valem mesmo sem internet.
- O responsável vê o uso de hoje por app e um resumo dos últimos 7 dias; o filho vê quanto já usou e quanto resta.
- Regras de segurança do Firestore testadas no emulador.

Limites conhecidos (veja `docs/ARQUITETURA.md`):

- O tempo de uso só chega ao responsável quando o app do filho está aberto (o bloqueio, não: ele roda em segundo plano).
- Nada impede a criança de desinstalar o app (falta o modo administrador do aparelho).
- Bluetooth: só entre dois Androids; o Windows não participa.
- Bluetooth e bloqueio nativo foram compilados e testados por simulação, mas **precisam ser provados em celulares de verdade** (veja o roteiro em `docs/ARQUITETURA.md`).

## Rodar sem Firebase (modo demonstração)

Sem chaves do Firebase o app abre com dados de exemplo, na memória do próprio aparelho (um aparelho não conversa com o outro).

```
cd apps/guardiao && flutter run
# responsável: demo@guardiaogamer.app / demo1234
# filho: código DEMX-2345
```

## Rodar com Firebase (aparelhos conversando)

Siga [docs/CONFIGURAR-FIREBASE.md](docs/CONFIGURAR-FIREBASE.md) e rode com as chaves:

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
cd packages/guardiao_core && flutter test     # modelos, pareamento, backend em memória, uso
cd apps/guardiao && flutter test              # telas, Bluetooth (simulado), medição de uso
cd firebase/tests && npm install && npm test  # regras do Firestore (emulador)
```

Versões usadas: Flutter 3.47, Dart 3.13, Firebase Auth 7, Cloud Firestore 7.

## Privacidade

O app guarda só o necessário: nome do aparelho, nomes dos apps instalados, minutos de uso por app e as regras do responsável. Não coleta conversas, localização nem dados de pagamento. A criança vê tudo que é monitorado (a notificação fixa do Android avisa que o acompanhamento está ligado). Base legal: consentimento do responsável (LGPD, art. 14).
