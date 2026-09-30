# Protótipo — Guardião Gamer 🎮

Protótipo funcional do **Guardião Gamer**, o app de controle parental para jogos (PC e celular). Diferente de uma tela estática, este protótipo já roda com dados de exemplo e reage a cliques de verdade: dá pra estourar um limite de jogo, entrar no painel do responsável com PIN e ver o relatório semanal mudar em tempo real.

{% hint style="success" %}
**Como testar:** abra o app interativo abaixo e clique no botão **"Simular 10 min jogando (demo)"** em qualquer jogo, algumas vezes seguidas, até o limite diário estourar — a tela de bloqueio da criança aparece automaticamente. Para ver o painel do responsável, toque em **Responsável** na barra inferior e digite o PIN de demonstração **1234**.

[Abrir o app interativo →](https://claude.ai/artifact/Eg3eVjQiXVJ1xnXvphdsYb)
{% endhint %}

## O que já funciona nesta versão

* **Limite de tempo por jogo/app** — cada jogo tem um limite diário configurável; a barra de progresso muda de cor e o status vira "Esgotado" quando o tempo acaba.
* **Bloqueio automático** — ao atingir o limite, a criança é levada para uma tela de bloqueio sem opção de burlar, liberada de novo só à meia-noite (ou por um ajuste do responsável).
* **Painel do responsável protegido por PIN** — permite ajustar o limite diário de cada jogo e redefinir o tempo usado hoje.
* **Relatório semanal de uso** — gráfico dos últimos 7 dias, total e média diária, dias em que o limite foi batido, e o jogo mais jogado da semana.
* **Cadastro de novos jogos/apps** — tela para adicionar um jogo à lista monitorada com ícone e limite diário.

{% tabs %}
{% tab title="🏠 Início" %}
**Tela inicial**

Lista os jogos monitorados no aparelho, cada um com o tempo usado hoje, o limite diário e uma barra de progresso (verde = dentro do limite, vermelha = esgotado). Um card no topo soma o tempo total de tela do dia. Cada jogo tem um botão **"Simular 10 min jogando (demo)"** só para esta demonstração — no app final esse tempo seria contado automaticamente pelo sistema operacional.
{% endtab %}

{% tab title="➕ Adicionar jogo" %}
**Novo jogo ou app**

Tela para cadastrar um jogo ou aplicativo na lista monitorada: nome, ícone e limite diário (30 min a 2h, ajustável depois no painel do responsável).
{% endtab %}

{% tab title="🔒 Bloqueio ativo" %}
**Visão da criança quando o tempo acaba**

Assim que um jogo atinge o limite diário, esta tela substitui o jogo automaticamente. Não existe botão de "continuar jogando" — o acesso só libera de novo à meia-noite ou se o responsável ajustar o limite pelo painel.
{% endtab %}

{% tab title="📊 Relatório semanal" %}
**Uso dos últimos 7 dias**

Gráfico de barras com os minutos jogados por dia, total da semana, média diária, quantidade de dias em que algum limite foi batido, e qual jogo teve mais uso — pensado para o responsável acompanhar sem precisar abrir cada jogo separadamente.
{% endtab %}

{% tab title="🔐 PIN do responsável" %}
**Acesso protegido**

O painel do responsável fica atrás de um PIN de 4 dígitos, para a criança não conseguir mudar os próprios limites. Nesta demonstração o PIN é **1234**.
{% endtab %}

{% tab title="⚙️ Painel do responsável" %}
**Ajustar limites e ver dispositivos**

Depois do PIN, o responsável pode alterar o limite diário de cada jogo individualmente, redefinir o tempo usado no dia (útil para esta demo) e ver qual dispositivo está sendo monitorado. A sincronização remota entre o celular da criança e o app do responsável em outro aparelho é a próxima etapa (v2) — nesta versão os dados são locais e de exemplo.
{% endtab %}
{% endtabs %}

## Padrões visuais usados

* **Cores primárias (M3):** roxo `#6750A4` (primary) e `#D0BCFF` (primary container)
* **Cores secundárias (M3):** verde `#386A20` (secondary) e `#9DD47E` (secondary container)
* **Tipografia:** Roboto / Roboto Flex, seguindo a escala tipográfica do Material Design 3
* **Ícones:** Material Symbols Outlined
* **Componentes:** cards com cantos arredondados, navegação inferior, barras de progresso e badges de status, seguindo os estados (filled, tonal) do M3

## Experiência completa (app interativo)

{% embed url="https://claude.ai/artifact/Eg3eVjQiXVJ1xnXvphdsYb" %}
App interativo Guardião Gamer
{% endembed %}

***

Veja também a [Proposta do Projeto](proposta-do-projeto.md) para o contexto completo do Guardião Gamer.
