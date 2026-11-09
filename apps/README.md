# Guardião Gamer — aplicativo

Controle parental para jogos no celular e no computador (Projeto A3, UC Exploração Digital e Fundamentos Tecnológicos).

É **um único aplicativo Flutter** (`apps/guardiao`). No primeiro acesso ele pergunta de quem é o aparelho:

| Função | Quem escolhe | O que o app faz |
| --- | --- | --- |
| **Sou o responsável** | Pai, mãe ou responsável | Cria a conta, **lê o QR (ou digita o código) que o aparelho do filho mostra**, vincula quantos aparelhos quiser, vê os apps instalados, define limite diário ou bloqueio e acompanha o tempo de uso da última semana |
| **Este aparelho é do filho** | A criança (ou o responsável, ao configurar o aparelho dela) | **Mostra o QR de vínculo** (celular ou computador), envia a lista de apps, **mede o tempo de uso e bloqueia** o app quando o limite acaba |

A escolha fica guardada no aparelho e pode ser trocada pelo menu da conta (isso sai da conta antes, para um aparelho nunca ficar com o login do outro lado).

```
apps/guardiao/           o aplicativo (Flutter: Android + Windows)
packages/guardiao_core/  modelos, pareamento, acesso ao Firebase, tema
firebase/                regras de segurança do Firestore + testes das regras
docs/                    arquitetura e configuração do Firebase
```

## Estado atual (marco 3)

Funciona e está testado:

- Escolha da função do aparelho no primeiro acesso, com opção de voltar e trocar.
- Conta do responsável (e-mail e senha) e login anônimo do aparelho do filho.
- Pareamento por **QR gerado pelo aparelho do filho** (celular ou computador) com código de 8 caracteres de reserva (vale 10 minutos, uso único). O responsável lê o QR com a câmera (Android) ou digita o código (Windows), confere o aparelho e vincula. **Um responsável pode vincular vários aparelhos de filhos.** Não precisa de domínio nem de servidor próprio: o vínculo é feito pelo Firebase.
- Lista de apps instalados com o **ícone real de cada app** (Android: PackageManager; Windows: registro do sistema, com a letra inicial no lugar do ícone).
- **Tempo de uso real**: Android pelas estatísticas de uso do sistema; Windows pelo programa em primeiro plano (não conta quando o computador está parado).
- **Bloqueio de verdade**: no Android um serviço cobre o app com uma tela de “tempo esgotado” e volta ao início; no Windows o programa é encerrado. Os limites ficam salvos no aparelho, então valem mesmo sem internet.
- O responsável vê o uso de hoje por app e um resumo dos últimos 7 dias; o filho vê quanto já usou e quanto resta.
- **Atualização dentro do app (Android)**: quando sai uma versão nova, o app mostra uma barra “Há uma versão nova” com o botão **Atualizar**; ele baixa o APK da Release, confere a soma SHA-256 e abre o instalador do Android (basta confirmar). Não precisa baixar o APK por fora.
- Regras de segurança do Firestore testadas no emulador.

Limites conhecidos (veja `docs/ARQUITETURA.md`):

- O tempo de uso só chega ao responsável quando o app do filho está aberto (o bloqueio, não: ele roda em segundo plano).
- Nada impede a criança de desinstalar o app (falta o modo administrador do aparelho).
- Leitura do QR pela câmera só no Android/iOS; no Windows o responsável digita o código (o filho no Windows mostra o QR normalmente).
- Câmera/QR e bloqueio nativo foram compilados e testados por simulação, mas **precisam ser provados em celulares de verdade** (veja o roteiro em `docs/ARQUITETURA.md`).

## Instalar no Android (APK)

O APK é compilado pelo GitHub (workflow **Compilar APK**, em *Actions*) e fica numa Release do repositório:

**[Baixar o APK mais recente](https://github.com/AlexandreLott/Bet-Blocker/releases/latest)** (o repositório é público: não precisa de login).

1. No celular Android, abra o link e baixe o arquivo `guardiao-gamer.apk` da Release.
2. Abra o arquivo e permita *instalar apps desconhecidos* para o navegador ou o gerenciador de arquivos, se o Android pedir.
3. Abra o Guardião Gamer e escolha a função do aparelho.

**Atualizações:** depois da primeira instalação o app avisa sozinho quando há versão nova (confere ao abrir e a cada 6 horas). Toque em **Atualizar**, aguarde o download e confirme a instalação na tela do Android; na primeira vez o Android pede para permitir que o Guardião Gamer instale apps. Isso só funciona entre versões assinadas com a mesma chave (veja abaixo).

### Gerar uma versão nova (equipe)

*Actions → Compilar APK → Run workflow*. Cada execução publica a Release `apk-N`, em que **N é o número da versão** que o app compara com a instalada. Antes da primeira vez, cadastre os segredos em *Settings → Secrets and variables → Actions*:

- as 4 chaves do Firebase: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID` (veja [docs/CONFIGURAR-FIREBASE.md](../docs/CONFIGURAR-FIREBASE.md));
- a chave de assinatura: `KEYSTORE_BASE64` (o arquivo `.jks` em base64) e `KEYSTORE_PASSWORD` (a senha; o apelido da chave é `guardiao`).

A chave de assinatura **nunca vai para o repositório** e deve ser guardada com cuidado: se ela mudar, o Android recusa a atualização e é preciso desinstalar e instalar de novo.

## Rodar sem Firebase (modo demonstração)

Sem chaves do Firebase o app abre com dados de exemplo, na memória do próprio aparelho (um aparelho não conversa com o outro).

```
cd apps/guardiao && flutter run
# responsável: demo@guardiaogamer.app / demo1234
# filho: escolha "filho" e mostre o QR; o responsável de exemplo já tem um aparelho vinculado
# (para vincular o notebook de exemplo, no responsável digite o código DEMX-2345)
```

## Rodar com Firebase (aparelhos conversando)

Siga [docs/CONFIGURAR-FIREBASE.md](../docs/CONFIGURAR-FIREBASE.md) e rode com as chaves:

```
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=...
```

As chaves ficam fora do código (nada secreto no repositório). As chaves do Firebase no app são identificadores públicos de cliente; quem protege os dados são as regras do Firestore. Como o repositório é público, recomenda-se restringir a chave de API ao pacote do app no Google Cloud.

## Testes

```
cd packages/guardiao_core && flutter test     # modelos, pareamento, backend em memória, uso
cd apps/guardiao && flutter test              # telas, QR (câmera simulada), medição de uso
cd firebase/tests && npm install && npm test  # regras do Firestore (emulador)
```

Versões usadas: Flutter 3.47, Dart 3.13, Firebase Auth 7, Cloud Firestore 7.

## Privacidade

O app guarda só o necessário: nome do aparelho, nomes dos apps instalados, os ícones desses apps, minutos de uso por app e as regras do responsável. Não coleta conversas, localização nem dados de pagamento. A criança vê tudo que é monitorado (a notificação fixa do Android avisa que o acompanhamento está ligado). Base legal: consentimento do responsável (LGPD, art. 14).

## Uso de IA no projeto

Este projeto foi desenvolvido com apoio de uma ferramenta de IA generativa (Claude, da Anthropic), que ajudou a escrever e organizar o código do aplicativo (Flutter, serviços Android e regras do Firebase), os testes e a documentação. Todo o conteúdo foi revisado, executado e testado pela equipe, e as decisões do projeto (funções do app, pareamento por QR, regras de privacidade) foram tomadas pelos integrantes. Registrar isso aqui deixa claro o que foi gerado com ajuda de IA, conforme as orientações de integridade acadêmica da disciplina.
