# Arquitetura

## Visão geral

Um único aplicativo (`apps/guardiao`). A função do aparelho (responsável ou filho) é escolhida no primeiro acesso e guardada localmente; o resto do app muda conforme ela.

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
- O app nunca fala com o Firestore diretamente, então dá para testar todas as telas sem internet.

## Escolha da função

`GuardiaoApp` (`lib/app.dart`) lê a função de `RoleStore` (SharedPreferences). Sem função, mostra `RoleScreen`; com função, abre `ParentFlow` ou `ChildGate`. Trocar de função **sai da conta antes** (`signOut`) e apaga a escolha: assim um aparelho nunca fica com a sessão do outro lado (por exemplo, um login de responsável no aparelho do filho).

## Pareamento (o filho gera o QR)

1. O aparelho do filho (celular **ou** computador) entra de forma anônima e cria `pairRequests/{código}` com `deviceId` (o uid dele), nome, plataforma, validade de 10 minutos e `used: false`. O código é gerado ali mesmo, com 8 caracteres de um alfabeto de 31 símbolos (sem 0, O, 1, I, L), cerca de 8 × 10¹¹ combinações, o que torna inviável adivinhar um código dentro dos 10 minutos.
2. A tela mostra o **QR** (`guardiao://pair?code=K7M29QXA`, feito com `qr_flutter`) e o código por escrito. Ao expirar, gera outro sozinho; ao sair da tela, apaga o pedido.
3. O responsável (conta com e-mail e senha) lê o QR com a câmera (`mobile_scanner`, Android/iOS) ou digita o código (único caminho no Windows). O app faz uma **prévia** (`previewPairRequest`, só leitura) e mostra o nome e a plataforma do aparelho para ele conferir (e renomear).
4. Ao tocar em *Vincular*, um único lote marca o pedido como usado (`used: true`, `parentUid`) e cria `devices/{deviceId}` com o `parentUid`, o `parentLabel` (e-mail parcialmente escondido, como `ma***@gmail.com`) e o nome.
5. O aparelho do filho observa o próprio documento (`watchOwnDevice`) e avança sozinho para a tela principal, onde aparece “Responsável: ma***@gmail.com”.
6. As regras de segurança conferem as duas pontas do lote: o pedido existe, não foi usado, não expirou, pertence ao aparelho indicado e a plataforma bate. Se algo falhar, nada é gravado.

Não é preciso domínio nem servidor próprio: o QR carrega só o código; quem faz o vínculo é o Firebase. Um responsável vincula quantos aparelhos quiser repetindo o processo. A leitura do QR por câmera não existe no Windows; lá o responsável digita o código (o filho no Windows mostra o QR normalmente).

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

## Roteiro para provar em celulares de verdade

Nada disso roda no ambiente de desenvolvimento automático (sem câmera, sem Android físico); os testes automáticos usam simulações. Antes de apresentar, conferir com dois Androids (ou um Android e um notebook):

1. Instalar nos dois, escolher *responsável* em um e *filho* no outro, e criar conta no primeiro.
2. Filho: aparece o QR. Responsável: *Adicionar aparelho → Ler QR* (liberar a câmera), apontar para o QR e tocar em *Vincular*. Conferir que o filho avança sozinho. Repetir com um segundo aparelho de filho (por exemplo o notebook) para provar o vínculo múltiplo.
3. No filho, liberar *acesso ao uso* e *aparecer sobre outros apps*.
4. No responsável, definir 1 minuto de limite em um jogo instalado. Abrir o jogo no filho: depois de 1 minuto de uso a tela de bloqueio aparece e o aparelho volta ao início.
5. No filho, abrir o Guardião: em até 30 s o responsável vê o uso de hoje.

## Decisões e limites conhecidos

- **Login anônimo no filho**: a criança não precisa de senha, mas o aparelho só ganha acesso depois de usar um código válido.
- **Windows**: o Firebase usa a configuração de um app web; está documentado em `CONFIGURAR-FIREBASE.md`.
- **Ícones dos apps** não são enviados (pesariam no Firestore). O app mostra a letra inicial colorida.
- **Uso só chega ao responsável com o app do filho aberto**: o bloqueio local não depende disso, mas o relatório sim. Enviar em segundo plano exigiria rodar o Flutter no serviço (WorkManager), previsto para depois.
- **Desinstalação**: nada impede a criança de desinstalar o app ou de revogar as permissões. No Android isso exige o modo administrador do aparelho, previsto para depois.
- **Dois jogos ao mesmo tempo** (tela dividida): o Android informa um só em primeiro plano; o outro não é contado.
- **Encerrar no Windows** pode perder o progresso do jogo; um aviso antes do encerramento é uma melhoria natural.
