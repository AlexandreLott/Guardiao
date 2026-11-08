# Configurar o Firebase

Leva cerca de 15 minutos e usa o plano gratuito (Spark).

## 1. Criar o projeto

1. Entre em https://console.firebase.google.com com a conta do grupo e crie o projeto **guardiao-gamer** (pode desligar o Google Analytics).
2. Em **Build → Authentication → Sign-in method**, ative **E-mail/senha** e **Anônimo**.
3. Em **Build → Firestore Database**, crie o banco em **modo de produção** (região `southamerica-east1`, São Paulo).
4. Em **Firestore → Regras**, cole o conteúdo de `firebase/firestore.rules` e publique.

## 2. Registrar os apps

Em **Configurações do projeto → Seus apps**, registre:

| Onde roda | Plataforma | ID do pacote |
| --- | --- | --- |
| Celular (responsável **e** filho) | Android | `br.edu.guardiaogamer.guardiao` |
| Computador | **Web** | qualquer apelido (o Windows usa a configuração de um app web) |

É um app só, então o mesmo registro Android serve para o celular do responsável e o do filho. Cada registro tem um **App ID** próprio (`1:123456789:android:abc...`). A **chave de API**, o **ID do projeto** e o **ID do remetente** (messagingSenderId) são os mesmos nos dois.

> Se você já tinha registrado `guardiao_parent` e `guardiao_child` na versão anterior, pode apagá-los: não são mais usados.

> Não é preciso baixar `google-services.json`: o app lê as chaves por `--dart-define`.

## 3. Rodar

```
cd apps/guardiao

# Celular Android (qualquer função)
flutter run \
  --dart-define=FIREBASE_API_KEY=<chave> \
  --dart-define=FIREBASE_APP_ID=<app id do Android> \
  --dart-define=FIREBASE_PROJECT_ID=guardiao-gamer \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<remetente>

# Computador Windows (use o App ID do app Web)
flutter run -d windows \
  --dart-define=FIREBASE_API_KEY=<chave> \
  --dart-define=FIREBASE_APP_ID=<app id do app web> \
  --dart-define=FIREBASE_PROJECT_ID=guardiao-gamer \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<remetente>
```

No Windows é preciso ter o Visual Studio 2022 com a carga "Desenvolvimento para desktop com C++". O primeiro build baixa o SDK C++ do Firebase e demora.

## 4. Testar o pareamento

1. No primeiro aparelho, escolha **Sou o responsável**, crie a conta e toque em **Adicionar aparelho**: aparece um código como `K7M2-9QXA`.
2. No segundo aparelho, escolha **Este aparelho é do filho** e digite o código, ou use **Receber código por Bluetooth** (os dois precisam ser Android; veja `ARQUITETURA.md`).
3. O responsável vê o aparelho entrar na lista e, em segundos, a lista de aplicativos.
4. No filho (Android), libere as três permissões que o app pede (acesso ao uso, aparecer sobre outros apps, avisos).
5. No app do responsável, toque em um aplicativo, defina um limite ou bloqueio e confira no aparelho do filho. Depois de usar o app, o tempo aparece no responsável em até 30 segundos.

## Problemas comuns

- **"Esse tipo de login não está ativado"**: ative E-mail/senha e Anônimo no passo 1.
- **"Não foi possível usar esse código"**: o código expira em 10 minutos e vale uma vez. Gere outro. Se persistir, confira se as regras do passo 1 foram publicadas.
- **"Missing or insufficient permissions" ao ver o uso**: as regras do passo 1 mudaram (nova coleção `usage`). Cole de novo o conteúdo atual de `firebase/firestore.rules` e publique.
- **Bluetooth não acha o aparelho**: confira se o Bluetooth está ligado nos dois, se a permissão foi concedida e se o filho está na tela “Receber código por Bluetooth”.
- **O bloqueio não aparece no Android**: abra o app do filho e confira se o cartão de permissões sumiu. Em alguns celulares (Xiaomi, Samsung) também é preciso tirar o app da economia de bateria.
- **A lista de apps não chega**: abra o app do filho com internet; ele envia a lista ao abrir e a cada 6 horas.

## Antes de ir para produção (não faz parte do marco 2)

- Ativar o **App Check** para impedir o uso da API por apps de terceiros.
- Definir alertas de orçamento no Google Cloud.
- Assinar o app com chave própria (hoje o build de release usa a chave de debug).
