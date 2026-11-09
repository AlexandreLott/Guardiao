# Arquitetura

## Visão geral

O Guardião é um único aplicativo (`apps/guardiao`). A função do aparelho (responsável ou filho) é escolhida no primeiro acesso e armazenada localmente; as demais telas variam conforme essa escolha.

```
 Aparelho do filho (Android/Windows)        Firebase                         Aparelho do responsável (Android/Windows)
 ┌─────────────────────────────────┐   ┌──────────────────────────────┐   ┌──────────────────────────────────────┐
 │ login anônimo                   │   │ Authentication               │   │ login e-mail/senha                    │
 │ gera o QR e o código de reserva ├──►│ pairRequests/{código}        │◄──┤ lê o QR (câmera) ou digita o código   │
 │ espera o vínculo                │◄──┤ devices/{idDoAparelho}       │◄──┤ confere e vincula (lote)              │
 │ envia a lista de apps           ├──►│  ├ apps/{idDoApp}            │──►│ vê os apps instalados                 │
 │ recebe as regras, mede e bloqueia│◄──┤  ├ rules/{idDoApp}           │◄──┤ define limite / bloqueio              │
 │ envia o tempo de uso            ├──►│  └ usage/{dia}_{idDoApp}     │──►│ vê o uso de hoje e da semana          │
 └─────────────────────────────────┘   └──────────────────────────────┘   └──────────────────────────────────────┘
```

Um responsável pode ter **vários aparelhos de filhos** (cada um é um documento em `devices` com o mesmo `parentUid`).

O código compartilhado fica em `packages/guardiao_core`:

- `GuardianBackend` é a interface usada pelo app. Tem duas implementações: `FirebaseBackend` (produção) e `MemoryBackend` (testes e modo demonstração).
- O aplicativo nunca acessa o Firestore diretamente, o que permite testar todas as telas sem conexão com a internet.

## Escolha da função

`GuardiaoApp` (`lib/app.dart`) lê a função de `RoleStore` (SharedPreferences). Sem função, mostra `RoleScreen`; com função, abre `ParentFlow` ou `ChildGate`. Trocar de função **sai da conta antes** (`signOut`) e apaga a escolha: assim um aparelho nunca fica com a sessão do outro lado (por exemplo, um login de responsável no aparelho do filho).

## Pareamento (o filho gera o QR)

1. O aparelho do filho (celular **ou** computador) entra de forma anônima e cria `pairRequests/{código}` com `deviceId` (o uid dele), nome, plataforma, validade de 10 minutos e `used: false`. O código é gerado ali mesmo, com 8 caracteres de um alfabeto de 31 símbolos (sem 0, O, 1, I, L), cerca de 8 × 10¹¹ combinações, o que torna inviável adivinhar um código dentro dos 10 minutos.
2. A tela mostra o **QR** (`guardiao://pair?code=K7M29QXA`, feito com `qr_flutter`) e o código por escrito. Ao expirar, gera outro sozinho; ao sair da tela, apaga o pedido.
3. O responsável (conta com e-mail e senha) lê o QR com a câmera (`mobile_scanner`, Android/iOS) ou digita o código (único caminho no Windows). O app faz uma **prévia** (`previewPairRequest`, só leitura) e mostra o nome e a plataforma do aparelho para ele conferir (e renomear).
4. Ao tocar em *Vincular*, um único lote marca o pedido como usado (`used: true`, `parentUid`) e cria `devices/{deviceId}` com o `parentUid`, o `parentLabel` (e-mail parcialmente escondido, como `ma***@gmail.com`) e o nome.
5. O aparelho do filho observa o próprio documento (`watchOwnDevice`) e avança sozinho para a tela principal, onde aparece “Responsável: ma***@gmail.com”.
6. As regras de segurança conferem as duas pontas do lote: o pedido existe, não foi usado, não expirou, pertence ao aparelho indicado e a plataforma bate. Se algo falhar, nada é gravado.

Não há necessidade de domínio nem de servidor próprio: o QR contém apenas o código, e o vínculo é efetuado pelo Firebase. Um responsável pode vincular quantos aparelhos desejar repetindo o processo. A leitura do QR por câmera não está disponível no Windows; nessa plataforma, o responsável informa o código (o aparelho do filho no Windows exibe o QR normalmente).

## Quem pode o quê (regras do Firestore)

| Dado | Responsável (dono) | Aparelho do filho | Outros |
| --- | --- | --- | --- |
| `pairRequests/{código}` | lê um pedido por vez e o “queima” (uma vez, antes de expirar) | cria o próprio pedido e o apaga | nada (sem listagem) |
| `devices/{id}` | cria (no vínculo), lê, renomeia, remove | lê e atualiza só `lastSeen` | nada |
| `devices/{id}/apps/*` | lê, limpa ao remover | escreve (só no próprio aparelho) | nada |
| `devices/{id}/rules/*` | lê e escreve (limite de 0 a 1440 min) | só lê | nada |
| `devices/{id}/usage/*` | lê e apaga | lê e escreve (minutos de 0 a 1440, só no próprio aparelho) | nada |

Os testes em `firebase/tests/rules.test.mjs` cobrem cada linha dessa tabela, incluindo as tentativas de burla (reusar código, código expirado, aparelho de outro filho, criar o aparelho sem queimar o pedido, escrever regra ou uso pelo lado errado).

## Lista de apps instalados

- **Android**: um canal de plataforma (`MainActivity.kt`) consulta o `PackageManager` por apps com ícone de lançamento, os mesmos do menu do celular. Usa `<queries>` no manifesto e dispensa a permissão `QUERY_ALL_PACKAGES`, que a Google Play restringe.
- **Windows**: o app lê as chaves "Uninstall" do registro por PowerShell e descarta atualizações e redistribuíveis. O executável vem do `DisplayIcon` quando existe; é por ele que o uso é medido.

- **Ícones**: o Android desenha o ícone de cada app em 96×96 px, comprime em WebP e envia em base64 junto com o app (campo `icon`; ícones acima de ~30 mil caracteres são ignorados). O Windows não envia ícone e mostra a letra inicial.

A sincronização roda ao abrir o app e a cada 6 horas e só grava o que mudou. Um sinal de vida (`lastSeen`) é enviado a cada 10 minutos.

## Tempo de uso e bloqueio

As regras (`rules/*`) chegam ao aparelho do filho pelo Firestore e são **copiadas para o próprio aparelho**. Quem mede e bloqueia usa essa cópia, então o bloqueio funciona sem internet e com o app fechado (Android).

**Android**
- `UsageReader` pede ao `UsageStatsManager` os eventos do dia; `UsageMath` (código puro, com testes JUnit) transforma em minutos por app: só um app fica em primeiro plano por vez, trocar de tela dentro do mesmo app não perde tempo, e tela apagada ou desligamento fecham a sessão.
- `MonitorService` é um serviço em primeiro plano (aviso fixo na barra) que confere a cada 3 s qual app está na tela. Se ele tem regra e o limite acabou (ou foi bloqueado), `BlockOverlay` cobre a tela com “tempo esgotado” e o aparelho volta ao início.
- `BootReceiver` religa o serviço quando o aparelho reinicia.
- Três permissões especiais, pedidas na tela do filho com botões diretos para cada configuração do sistema: **acesso ao uso**, **aparecer sobre outros apps** e **avisos** (Android 13+).

**Windows**
- `WindowsUsageMonitor` olha a cada 2 s qual programa está na frente (`GetForegroundWindow` por FFI), soma o tempo por `.exe` e **não conta** quando o teclado e o mouse estão parados há mais de 2 minutos. O total do dia é guardado em disco e zera na virada do dia.
- Ao estourar o limite (ou se o programa está bloqueado), encerra o processo com `taskkill` (apenas nomes simples de `.exe`; nunca o próprio Guardião).

**Envio ao responsável**: a cada 30 s, enquanto o app do filho está aberto, os minutos de hoje por app vão para `usage/{dia}_{app}` (só o que mudou). O responsável vê o total de hoje, a média e as barras dos últimos 7 dias e o uso de cada app.

## Atualização dentro do app (Android)

`lib/update/` consulta a API pública do GitHub (`releases/latest`) ao abrir o app e a cada 6 horas. A etiqueta `apk-N` vira o número da versão (`versionCode`); se for maior que o instalado, é exibida a barra de aviso com o botão **Atualizar**. O aplicativo baixa o `guardiao.apk` para o cache, confere tamanho e SHA-256 informados pelo GitHub e entrega o arquivo ao instalador do Android por `FileProvider` (a confirmação do usuário é exigida pelo Android). Requer a permissão “instalar apps desconhecidos” para o próprio app e que o APK novo seja assinado com a mesma chave (`KEYSTORE_*` no workflow). No Windows, não há atualização automática.

## Roteiro de validação em dispositivos reais

Os testes automáticos utilizam simulações (sem câmera nem Android físico). Antes da apresentação, recomenda-se validar o fluxo com dois aparelhos Android (ou um Android e um notebook):

1. Instalar o aplicativo nos dois aparelhos, selecionar *responsável* em um e *filho* no outro e criar a conta no primeiro.
2. No filho, o QR é exibido. No responsável, acessar *Adicionar aparelho → Escanear QR* (conceder a câmera), apontar para o QR e tocar em *Vincular*. Verificar que o aparelho do filho avança automaticamente. Repetir com um segundo aparelho de filho (por exemplo, o notebook) para validar o vínculo múltiplo.
3. No filho, conceder *acesso ao uso* e *sobreposição a outros aplicativos*.
4. No responsável, definir limite de 1 minuto para um jogo instalado. Abrir o jogo no filho: após 1 minuto de uso, a tela de bloqueio deve aparecer e o aparelho deve retornar ao início.
5. Com o Guardião aberto no filho, o responsável deve visualizar o uso do dia em até 30 s.

## Decisões e limites conhecidos

- **Autenticação anônima no filho**: a criança não precisa de senha, mas o aparelho só obtém acesso aos dados após o uso de um código válido.
- **Windows**: o Firebase utiliza a configuração de um aplicativo web, conforme documentado em `CONFIGURAR-FIREBASE.md`.
- **Ícones dos aplicativos**: enviados apenas pelo Android, reduzidos para 96×96 px e comprimidos, para limitar o volume no Firestore. No Windows, o aplicativo exibe a inicial do nome.
- **Envio do uso condicionado ao aplicativo aberto**: o bloqueio local não depende disso, mas o relatório sim. O envio em segundo plano exigiria executar o Flutter no serviço (WorkManager), o que está previsto para uma etapa futura.
- **Desinstalação**: nada impede a criança de desinstalar o aplicativo ou revogar as permissões. No Android, isso exigiria o modo de administrador do dispositivo, previsto para uma etapa futura.
- **Dois jogos simultâneos** (tela dividida): o Android informa apenas um aplicativo em primeiro plano; o outro não é contabilizado.
- **Encerramento no Windows**: o processo é finalizado de imediato e o progresso do jogo pode ser perdido; um aviso prévio é uma melhoria prevista.
