# Implementação do app (marco 2)

Depois do primeiro marco, o projeto passou a ter um **único aplicativo** em vez de dois. No primeiro acesso, a pessoa escolhe se o aparelho é do responsável ou do filho, e o app mostra só as telas dessa função. Também entraram o vínculo por QR gerado pelo aparelho do filho, a medição do tempo de uso e o bloqueio de verdade quando o limite acaba. O código continua em Flutter, com Firebase.

{% hint style="info" %}
**Em uma frase:** o responsável define um limite por aplicativo; o aparelho do filho mede o tempo de uso, bloqueia o app quando o limite acaba e informa ao responsável quanto foi usado no dia.
{% endhint %}

## Um app, duas funções

|           | Aparelho do filho | Aparelho do responsável |
| --------- | ----------------- | ----------------------- |
| Quem usa  | A criança ou o adolescente | Pai, mãe ou responsável |
| Sistemas  | Android e Windows | Android e Windows |
| O que faz | Mostra o QR de vínculo, envia os apps instalados, mede o uso e bloqueia ao passar do limite | Cria a conta, lê o QR de cada filho, define limite ou bloqueio e vê o uso do dia |

A escolha da função é guardada no aparelho e pode ser trocada pelo menu da conta (ou na tela de vínculo, antes de vincular). Trocar a função sai da conta antes, para não misturar os dados.

## Como funciona o vínculo

Quem gera o código é o **aparelho do filho**, seja celular ou computador:

1. No aparelho do filho, o app mostra um **QR** e, embaixo, o código de reserva de 8 caracteres, como `K7M2-9QXA`. Ele vale 10 minutos, é de uso único e se renova sozinho.
2. No aparelho do responsável, em **Adicionar aparelho**, o app lê o QR com a câmera (Android) ou o responsável digita o código (é o caminho no Windows).
3. O app mostra o nome e o tipo do aparelho para o responsável **conferir** (e trocar o nome, se quiser) e só vincula depois do toque em **Vincular**.
4. O aparelho do filho percebe o vínculo e avança sozinho para a tela principal, onde aparece quem é o responsável (e-mail parcialmente escondido).

Um responsável pode vincular **vários aparelhos de filhos**, repetindo o processo. Não é preciso domínio nem servidor próprio: o QR carrega só o código, e o vínculo de verdade acontece pelo Firebase, protegido pelas regras de segurança.

## Medição e bloqueio

- **Android:** o tempo de cada app vem das estatísticas de uso do sistema (o usuário concede uma permissão especial). Um serviço em primeiro plano confere o app aberto a cada 3 segundos e, quando o limite acaba ou o app está bloqueado, cobre a tela e leva o filho para a tela inicial. As regras ficam guardadas no aparelho, então o bloqueio funciona mesmo sem internet e com o app fechado, e volta sozinho depois que o aparelho reinicia.
- **Windows:** o app descobre a janela em primeiro plano, soma o tempo por programa (sem contar quando o computador está parado por mais de 2 minutos) e encerra o programa quando o limite acaba.
- **Para o responsável:** a tela do aparelho mostra o total do dia e o tempo de cada app, mais um resumo dos últimos 7 dias. O aparelho do filho envia esses minutos a cada 30 segundos enquanto o app dele está aberto.

## O que já funciona e está testado

| Funcionalidade | Situação |
| -------------- | -------- |
| Um único app, com escolha de função no primeiro acesso | Pronto |
| Conta do responsável e entrada anônima do aparelho do filho | Pronto |
| Vínculo por QR gerado pelo filho, com vários aparelhos por responsável | Pronto na lógica e nas telas; leitura pela câmera ainda sem teste em aparelhos |
| Lista de apps, limite diário e bloqueio por app em tempo real | Pronto |
| Cálculo do tempo de uso (Android) e do bloqueio | Pronto, com testes automáticos |
| Uso do dia e da semana visível para o responsável | Pronto |
| Regras de segurança do banco (vínculo, uso e regras) | Pronto, 45 testes no emulador do Firebase |
| Modo demonstração, sem internet | Pronto |

Há testes automáticos no núcleo compartilhado (37), nas telas do app, no cálculo de uso em Android e nas regras de segurança (45). O app também compila como APK Android.

## O que não foi testado

{% hint style="warning" %}
A leitura do QR pela câmera, a medição de uso e o bloqueio só foram verificados por simulação e compilação. Nenhum aparelho real foi usado ainda, e o código do Windows foi apenas analisado, sem ser executado. Um roteiro de teste em campo está em docs/ARQUITETURA.md, no repositório.
{% endhint %}

- O projeto já está registrado no Firebase (autenticação, banco e regras publicadas). Falta apenas rodar o app com as chaves em aparelhos de verdade, como explica docs/CONFIGURAR-FIREBASE.md.
- O app do Windows não foi compilado (isso exige um computador com Windows e Visual Studio).

## Limites conhecidos

- O responsável só recebe o uso do dia enquanto o app do filho está aberto. Com o app fechado, o bloqueio continua funcionando, mas o relatório não é atualizado.
- Ainda não há proteção contra a criança desinstalar o app.
- A câmera para ler o QR existe só no Android; no Windows o responsável digita o código.
- O app do responsável no iPhone continua fora do escopo.

## Pontos para o grupo decidir

- Quem será o dono do projeto no Firebase (a conta do grupo, não uma conta pessoal) e quem recebe os avisos de cobrança.
- O que acontece quando a criança desinstala o app: apenas o responsável é avisado, ou o aparelho passa a contar como "sem proteção".
- Se o responsável poderá definir horários permitidos (por exemplo, sem jogos em horário de aula).
- O nome final do aplicativo.

## Privacidade

O app guarda o mínimo necessário: o nome do aparelho, os nomes dos aplicativos instalados, as regras definidas pelo responsável e os minutos de uso de cada aplicativo por dia. O QR carrega apenas o código de vínculo, que expira em 10 minutos. Não coleta conversas, localização nem dados de pagamento, e a criança vê tudo o que é monitorado. A base legal continua sendo o consentimento do responsável, conforme o art. 14 da LGPD.

Veja também: [Proposta do Projeto](proposta-do-projeto.md), [Protótipo](prototipo-guardiao-gamer.md) e [Auditoria do Projeto](auditoria-do-projeto-24-10-2026.md).
