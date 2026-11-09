# Guardião

Aplicativo de controle parental para jogos e aplicativos em celulares e computadores. Desenvolvido no Projeto A3 da unidade curricular Exploração Digital e Fundamentos Tecnológicos.

## Visão geral

O Guardião é um único aplicativo Flutter (`apps/guardiao`). No primeiro acesso, o usuário informa a função do aparelho:

| Função | Perfil | Funcionalidades |
| --- | --- | --- |
| **Responsável** | Pai, mãe ou responsável legal | Cria a conta, vincula os aparelhos dos filhos lendo o QR (ou digitando o código) exibido por eles, consulta os aplicativos instalados, define limites diários ou bloqueios e acompanha o tempo de uso dos últimos sete dias. |
| **Filho** | Aparelho da criança ou do adolescente | Exibe o QR de vínculo, envia a lista de aplicativos, mede o tempo de uso e bloqueia o aplicativo quando o limite diário é atingido. |

A função fica registrada no aparelho e pode ser alterada pelo menu da conta. A alteração encerra a sessão antes, de modo que um aparelho nunca permaneça com o login do outro perfil.

## Estrutura do repositório

```
apps/guardiao/           aplicativo (Flutter: Android e Windows)
packages/guardiao_core/  modelos, pareamento, acesso ao Firebase e tema
firebase/                regras de segurança do Firestore e testes das regras
docs/                    arquitetura e configuração do Firebase
```

## Estado atual (marco 3)

Funcionalidades implementadas e testadas:

- Seleção da função do aparelho no primeiro acesso, com possibilidade de revisão posterior.
- Conta do responsável (e-mail e senha) e autenticação anônima no aparelho do filho.
- Vínculo por QR gerado pelo aparelho do filho (celular ou computador), com código alfanumérico de 8 caracteres como alternativa (validade de 10 minutos, uso único). Um responsável pode vincular vários aparelhos. O processo não exige domínio nem servidor próprio, pois o vínculo é intermediado pelo Firebase.
- Inventário de aplicativos instalados, com o ícone de cada aplicativo no Android (PackageManager) e a inicial do nome no Windows (registro do sistema).
- Medição real do tempo de uso: no Android, pelas estatísticas de uso do sistema; no Windows, pelo programa em primeiro plano, desconsiderando períodos de inatividade.
- Bloqueio efetivo: no Android, um serviço exibe a tela de “tempo esgotado” sobre o aplicativo e retorna ao início; no Windows, o processo é encerrado. As regras são mantidas no próprio aparelho e continuam válidas sem conexão com a internet.
- Relatório de uso para o responsável (dia atual e últimos sete dias) e painel de tempo utilizado e restante para o filho.
- Atualização dentro do aplicativo (Android): ao detectar uma versão mais recente, o app exibe um aviso, baixa o APK da Release, verifica sua integridade (SHA-256) e abre o instalador do Android para confirmação.
- Aviso de tentativa de burla: o responsável é notificado quando o filho retira uma permissão (acesso ao uso, sobreposição, notificações), desativa a proteção contra desinstalação, o serviço de acompanhamento para, ou o aparelho fica sem comunicação por 45 minutos (indício de desinstalação). A verificação ocorre em segundo plano nos dois aparelhos (WorkManager, a cada 15 minutos, sem custo adicional) e a desinstalação passa a exigir a desativação prévia do administrador do dispositivo.
- Regras de segurança do Firestore validadas em emulador (53 testes) e testes automatizados do aplicativo e do pacote compartilhado.

Limitações conhecidas (detalhadas em [docs/ARQUITETURA.md](../docs/ARQUITETURA.md)):

- O tempo de uso só é enviado ao responsável enquanto o aplicativo do filho está aberto; o bloqueio, por outro lado, opera em segundo plano.
- A desinstalação não pode ser comunicada pelo próprio aparelho: o responsável é avisado quando o administrador do dispositivo é desativado (etapa que a precede) ou, na ausência de sinal por 45 minutos. O aviso chega com atraso de cerca de 15 a 30 minutos e depende de o filho ativar a *Proteção contra desinstalação* na tela inicial do aplicativo. A Google Play restringe o uso do administrador do dispositivo.
- A leitura do QR pela câmera está disponível apenas em Android e iOS; no Windows, o responsável informa o código.
- A leitura por câmera e o bloqueio nativo foram verificados por simulação e, no caso do bloqueio, em um aparelho real. A validação completa em dispositivos físicos segue o roteiro de [docs/ARQUITETURA.md](../docs/ARQUITETURA.md).
- A atualização dentro do aplicativo não está disponível no Windows.

## Instalação no Android

O APK é compilado pelo GitHub (workflow **Compilar APK**, em *Actions*) e publicado em uma Release do repositório:

**[Baixar o APK mais recente](https://github.com/AlexandreLott/Guardiao/releases/latest)**

1. No celular Android, acesse o link e baixe o arquivo `guardiao.apk`.
2. Abra o arquivo e, se solicitado, autorize a instalação de aplicativos de fontes desconhecidas para o navegador ou gerenciador de arquivos utilizado.
3. Abra o Guardião e selecione a função do aparelho.

**Atualizações.** Após a primeira instalação, o aplicativo verifica a existência de nova versão ao ser aberto e a cada 6 horas. Ao tocar em **Atualizar**, o download é realizado dentro do aplicativo e o Android solicita a confirmação da instalação. Na primeira vez, o sistema também pede autorização para que o Guardião instale aplicativos. A atualização só é aceita entre versões assinadas com a mesma chave (veja abaixo).

### Publicação de nova versão (equipe)

Acesse *Actions → Compilar APK → Run workflow*. Cada execução publica uma Release `apk-N`, em que **N** é o número da versão comparado pelo aplicativo com o da versão instalada. Antes da primeira execução, cadastre os segredos em *Settings → Secrets and variables → Actions*:

- Firebase: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID` e `FIREBASE_MESSAGING_SENDER_ID` (consulte [docs/CONFIGURAR-FIREBASE.md](../docs/CONFIGURAR-FIREBASE.md)).
- Assinatura: `KEYSTORE_BASE64` (arquivo `.jks` codificado em base64) e `KEYSTORE_PASSWORD` (senha; o alias da chave é `guardiao`).

A chave de assinatura não deve ser versionada e precisa ser armazenada em local seguro. Caso ela seja alterada, o Android recusa a atualização e é necessário desinstalar o aplicativo e instalá-lo novamente.

## Execução sem Firebase (modo demonstração)

Sem as chaves do Firebase, o aplicativo opera com dados de exemplo mantidos em memória no próprio aparelho (não há comunicação entre aparelhos).

```
cd apps/guardiao && flutter run
# responsável: demo@guardiao.app / demo1234
# filho: selecione "filho" e exiba o QR; o responsável de exemplo já possui um aparelho vinculado
# para vincular o notebook de exemplo, informe no responsável o código DEMX-2345
```

## Execução com Firebase

Siga [docs/CONFIGURAR-FIREBASE.md](../docs/CONFIGURAR-FIREBASE.md) e execute com as chaves do projeto:

```
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=...
```

As chaves são fornecidas em tempo de compilação e não fazem parte do código-fonte. Os identificadores do Firebase presentes no aplicativo são públicos por natureza; a proteção dos dados é feita pelas regras do Firestore. Por o repositório ser público, recomenda-se restringir a chave de API ao pacote do aplicativo no Google Cloud.

## Testes

```
cd packages/guardiao_core && flutter test     # modelos, pareamento, backend em memória, uso
cd apps/guardiao && flutter test              # telas, QR (câmera simulada), medição de uso, atualização
cd firebase/tests && npm install && npm test  # regras do Firestore (emulador)
```

Versões utilizadas: Flutter 3.47, Dart 3.13, Firebase Auth 7 e Cloud Firestore 7.

## Privacidade

O aplicativo trata somente os dados necessários ao seu funcionamento: nome do aparelho, nomes e ícones dos aplicativos instalados, minutos de uso por aplicativo e regras definidas pelo responsável. Não são coletados conteúdo de conversas, localização nem dados de pagamento. O monitoramento é transparente para a criança: no Android, uma notificação permanente informa que o acompanhamento está ativo. A base legal é o consentimento do responsável (LGPD, art. 14).

## Uso de inteligência artificial

O projeto contou com o apoio de uma ferramenta de IA generativa (Claude, da Anthropic) na escrita e organização do código do aplicativo (Flutter, serviços Android e regras do Firebase), dos testes e da documentação. O conteúdo foi revisado, executado e testado pela equipe, e as decisões de projeto (funcionalidades, pareamento por QR, política de privacidade) foram tomadas pelos integrantes. O registro detalhado de cada uso está no Registro de Uso de IA do diário técnico do projeto.
