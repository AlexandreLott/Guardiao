# Configuração do Firebase

Procedimento com duração aproximada de 15 minutos, no plano gratuito (Spark).

## 1. Criação do projeto

1. Acesse https://console.firebase.google.com com a conta da equipe e crie o projeto **guardiao-gamer** (o identificador do projeto é mantido por não ser alterável; o Google Analytics pode ser desativado).
2. Em **Build → Authentication → Sign-in method**, ative os provedores **E-mail/senha** e **Anônimo**.
3. Em **Build → Firestore Database**, crie o banco em **modo de produção** (região `southamerica-east1`, São Paulo).
4. Em **Firestore → Regras**, cole o conteúdo de `firebase/firestore.rules` e publique. Sempre que `firestore.rules` mudar (por exemplo, ao incluir os avisos de burla), publique novamente.

## 2. Registro dos aplicativos

Em **Configurações do projeto → Seus apps**, registre:

| Onde executa | Plataforma | Identificador |
| --- | --- | --- |
| Celular (responsável e filho) | Android | `br.edu.guardiaogamer.guardiao` |
| Computador | **Web** | qualquer apelido (o Windows utiliza a configuração de um app web) |

O aplicativo é único; portanto, o mesmo registro Android atende ao celular do responsável e ao do filho. Cada registro possui um **App ID** próprio (`1:123456789:android:abc...`). A **chave de API**, o **ID do projeto** e o **ID do remetente** (messagingSenderId) são os mesmos nos dois registros.

> Não é necessário baixar o arquivo `google-services.json`: o aplicativo recebe as chaves por `--dart-define`.

## 3. Execução

```
cd apps/guardiao

# Celular Android (qualquer função)
flutter run \
  --dart-define=FIREBASE_API_KEY=<chave> \
  --dart-define=FIREBASE_APP_ID=<app id do Android> \
  --dart-define=FIREBASE_PROJECT_ID=guardiao-gamer \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<remetente>

# Computador Windows (utilize o App ID do app Web)
flutter run -d windows \
  --dart-define=FIREBASE_API_KEY=<chave> \
  --dart-define=FIREBASE_APP_ID=<app id do app web> \
  --dart-define=FIREBASE_PROJECT_ID=guardiao-gamer \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<remetente>
```

No Windows, é necessário o Visual Studio 2022 com a carga de trabalho "Desenvolvimento para desktop com C++". A primeira compilação baixa o SDK C++ do Firebase e leva mais tempo.

## 4. Teste do vínculo

1. No aparelho do filho (celular ou computador), selecione **Este aparelho é do filho**. O aplicativo exibe um **QR** e, abaixo, o código alternativo, como `K7M2-9QXA` (validade de 10 minutos).
2. No aparelho do responsável, selecione **Sou o responsável**, crie a conta e toque em **Adicionar aparelho**. Aponte a câmera para o QR (ou informe o código, no Windows), confira o nome do aparelho e toque em **Vincular**. Repita o procedimento para cada aparelho de filho.
3. O aparelho do filho avança automaticamente para a tela principal; o responsável visualiza o aparelho na lista e, em instantes, a lista de aplicativos.
4. No aparelho do filho (Android), conceda as três permissões solicitadas: acesso ao uso, sobreposição a outros aplicativos e notificações.
5. No aplicativo do responsável, selecione um aplicativo e defina um limite ou bloqueio. Após o uso no aparelho do filho, o tempo é exibido ao responsável em até 30 segundos.

## 5. APK para instalação no Android (GitHub Actions)

O repositório contém o workflow **Compilar APK** (`.github/workflows/build-apk.yml`), que compila o aplicativo com as chaves da equipe e publica o arquivo `guardiao.apk` em uma Release.

1. No GitHub, acesse o repositório → **Settings → Secrets and variables → Actions → New repository secret** e crie seis segredos:

| Nome | Valor |
| --- | --- |
| `FIREBASE_API_KEY` | chave de API do aplicativo registrado |
| `FIREBASE_APP_ID` | App ID do app **Android** (`1:247599409292:android:...`) |
| `FIREBASE_PROJECT_ID` | `guardiao-gamer` |
| `FIREBASE_MESSAGING_SENDER_ID` | `247599409292` |
| `KEYSTORE_BASE64` | arquivo `guardiao.jks` codificado em base64 (chave de assinatura do aplicativo) |
| `KEYSTORE_PASSWORD` | senha da chave (alias `guardiao`) |

2. Acesse **Actions → Compilar APK → Run workflow**. A execução leva cerca de 8 minutos.
3. O arquivo fica disponível em **Releases** (`/releases/latest`).

Sem os segredos, o workflow é interrompido com um aviso. A chave de assinatura é o que permite ao Android aceitar uma versão nova sobre a anterior (inclusive pela atualização dentro do aplicativo): o arquivo `.jks` e a senha devem ser guardados em local seguro e jamais versionados. Se a chave for alterada, é necessário desinstalar o aplicativo e instalá-lo novamente. A numeração decorre da execução do workflow: a Release `apk-N` corresponde à versão `N`, e o aplicativo só oferece atualização quando `N` é superior ao número instalado.

## Problemas comuns

- **"Esse tipo de login não está ativado"**: ative E-mail/senha e Anônimo conforme o passo 1.
- **"O código expirou" ou "já foi usado"**: o código vale por 10 minutos e pode ser usado uma única vez. No aparelho do filho, o QR se renova automaticamente; também é possível tocar em *Gerar novo código*. Se o problema persistir, confirme que as regras do passo 1 foram publicadas.
- **"Missing or insufficient permissions" ao consultar o uso**: as regras publicadas estão desatualizadas. Cole novamente o conteúdo atual de `firebase/firestore.rules` e publique.
- **A câmera não abre ao ler o QR**: conceda a permissão de câmera ao aplicativo; sem câmera (ou no Windows), informe o código exibido abaixo do QR.
- **O bloqueio não aparece no Android**: abra o aplicativo do filho e verifique se o cartão de permissões foi concluído. Em alguns aparelhos (Xiaomi, Samsung), também é necessário remover o aplicativo da economia de bateria.
- **A lista de aplicativos não chega**: abra o aplicativo do filho com acesso à internet; ele envia a lista ao ser aberto e a cada 6 horas.

## Recomendações antes da produção

- Ativar o **App Check** para impedir o uso da API por aplicativos de terceiros.
- Restringir a chave de API do Firebase ao pacote e à assinatura do aplicativo no Google Cloud.
- Definir alertas de orçamento no Google Cloud.

## Opcional: limpeza de pedidos de vínculo antigos

O aplicativo remove o pedido de vínculo ao sair da tela, mas, se for encerrado de forma forçada, o documento permanece em `pairRequests` e deixa de valer após 10 minutos. Para a limpeza automática, crie em **Firestore → TTL** uma política na coleção `pairRequests` com o campo `expiresAt`.
