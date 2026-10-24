# Guardião Gamer — Instalar o Alpha (demonstração)

O alpha 0.1 do **Guardião Gamer** é um aplicativo web instalável (PWA). Ele instala no celular (Android e iPhone) e no PC (Windows, Mac e Linux) a partir de um link, funciona sem internet depois da primeira abertura e não precisa de loja de aplicativos.

> **Atenção:** **O que é real e o que é simulado.** O alpha é o protótipo funcional: o tempo de jogo é simulado pelo botão "Simular 10 min jogando (demo)", o bloqueio acontece dentro do próprio app (ele não bloqueia jogos de verdade no Android ou no Windows) e a sincronização entre o celular da criança e o painel do responsável ainda não existe. Os dados ficam salvos só no aparelho em que o app foi aberto.

## Escolha o caminho

| Caminho | Serve para | Precisa de internet | Dificuldade |
| --- | --- | --- | --- |
| **1. Link (GitHub Pages)** — recomendado | Celular e PC, instala como app | Só na primeira abertura | Fácil |
| **2. Kit offline (.zip)** | PC, sem internet nenhuma | Não | Fácil |
| **3. Arquivo único (.html)** | Qualquer aparelho, plano C | Não | Fácil |
| **4. Mesmo Wi-Fi (servidor no PC)** | Celular sem GitHub | Wi-Fi local | Médio |

## Passo 0 — Link do alpha (já publicado)

O alpha fica num repositório público separado, só com os arquivos do app e sem dados pessoais do grupo: [AlexandreLott/guardiao-gamer-alpha](https://github.com/AlexandreLott/guardiao-gamer-alpha). O GitHub Pages já está ligado nele e o endereço é **https://alexandrelott.github.io/guardiao-gamer-alpha/**

Não há nada para preparar antes da demonstração: basta abrir o endereço no aparelho e seguir os passos do sistema (Android, iPhone ou PC) abaixo.

Para publicar uma versão nova do alpha, abra o repositório público, clique em **Add file → Upload files**, envie os arquivos novos com os mesmos nomes e confirme com **Commit changes**. O Pages atualiza em 1 a 3 minutos.

> **Nota:** O repositório principal do projeto (Bet-Blocker) é privado, e o GitHub Pages não funciona em repositório privado no plano gratuito. Por isso o alpha mora no repositório separado. Se o link não abrir, use os caminhos 2, 3 ou 4.


## Android (Chrome)

1. Abra https://alexandrelott.github.io/guardiao-gamer-alpha/ no Chrome.
2. Toque no menu **⋮** e em **Instalar app** (em alguns celulares aparece como **Adicionar à tela inicial**).
3. Confirme. O ícone do Guardião Gamer aparece na tela inicial e o app abre em tela cheia.
4. Abra o app uma vez com internet. Depois disso ele funciona até em modo avião.

## iPhone e iPad (Safari)

1. Abra https://alexandrelott.github.io/guardiao-gamer-alpha/ no **Safari** (outros navegadores não instalam no iPhone).
2. Toque no botão **Compartilhar** e em **Adicionar à Tela de Início**.
3. Toque em **Adicionar**. O app abre em tela cheia pelo ícone novo.

## PC (Chrome ou Edge)

1. Abra https://alexandrelott.github.io/guardiao-gamer-alpha/.
2. Clique no ícone de instalar no fim da barra de endereço (um monitor com uma seta) e em **Instalar**. Se o ícone não aparecer, use o menu **⋮ → Salvar e compartilhar → Instalar Guardião Gamer** (Chrome) ou **⋯ → Aplicativos → Instalar este site como um aplicativo** (Edge).
3. O app abre numa janela própria e ganha atalho no menu Iniciar e na área de trabalho.

O Firefox no computador não instala PWA; nele, basta abrir o link e usar normalmente.

## Kit offline para o PC (sem internet)

1. Baixe o arquivo [**Guardiao-Gamer-alpha-offline.zip**](https://github.com/AlexandreLott/guardiao-gamer-alpha/raw/main/downloads/Guardiao-Gamer-alpha-offline.zip) (pasta `downloads/` do repositório público do alpha) e extraia **a pasta inteira** (botão direito → *Extrair tudo*).
2. Dê dois cliques em **Abrir-no-PC.bat**. O app abre numa janela própria, sem barra de endereço (usa o Edge ou o Chrome que já estão no computador).
3. Se o Windows avisar sobre o arquivo (SmartScreen), clique em **Mais informações → Executar assim mesmo**. Se preferir não usar o `.bat`, dê dois cliques em `index.html`.

## Arquivo único (plano C)

O arquivo [**Guardiao-Gamer-alpha.html**](https://github.com/AlexandreLott/guardiao-gamer-alpha/raw/main/downloads/Guardiao-Gamer-alpha.html) tem tudo dentro dele. Copie para o aparelho (cabo, Drive, WhatsApp) e abra no Chrome. Funciona e guarda os dados, mas não vira app instalado, e alguns celulares abrem arquivos baixados de forma diferente. Use só como reserva.

## Mesmo Wi-Fi (servidor no PC)

1. No PC, abra a pasta `app` e abra um terminal nela (no Windows: *Shift + botão direito → Abrir no Terminal*).
2. Rode `python -m http.server 8000` (precisa do Python instalado).
3. Descubra o IP do PC com `ipconfig` (campo *Endereço IPv4*, por exemplo 192.168.0.15).
4. No celular, conectado na mesma rede, abra `http://192.168.0.15:8000` (troque pelo seu IP). Se o firewall perguntar, permita o acesso em rede privada.

Nesse modo o app funciona, mas o botão de instalar não aparece (o navegador exige HTTPS). Dá para criar um atalho pelo menu do Chrome em **Adicionar à tela inicial**.

## Roteiro de demonstração (5 minutos)

1. Antes de começar, entre em **Responsável** (PIN **1234**) e toque em **Restaurar dados de exemplo**.
2. **Início:** mostre o tempo total de tela de hoje e os jogos monitorados. O Roblox já aparece como *Esgotado*.
3. No **Free Fire**, toque em *Simular 10 min jogando* duas vezes. Ao bater o limite, a **tela de bloqueio** aparece sozinha, sem botão de continuar.
4. Volte e abra **Responsável**. Digite um PIN errado (1111) para mostrar a proteção e depois o **1234**.
5. No painel, mude o limite do Fortnite e mostre **Zerar o tempo de hoje**.
6. Abra o **Relatório**: gráfico semanal, total, média e dias no limite.
7. Toque no botão **+** e cadastre um jogo (por exemplo, Brawl Stars, 30 min). Ele aparece na lista.
8. Para fechar, ligue o **modo avião** e abra o app de novo: ele continua funcionando.

## Checklist da véspera

* Instalar no celular e no PC **com internet** e abrir o app pelo menos uma vez.
* Testar em **modo avião** nos dois aparelhos.
* Deixar o kit offline e o arquivo `.html` no Drive e em um pendrive.
* Carregar a bateria, aumentar o brilho e ativar o modo *Não perturbe*.
* Gravar a tela do celular fazendo o roteiro inteiro, como vídeo de reserva.
* Combinar quem apresenta cada etapa e ensaiar uma vez.

## Problemas comuns

* **Não aparece a opção de instalar:** o navegador só oferece com HTTPS, então use o link do GitHub Pages (caminho 1), em Chrome, Edge ou Safari e fora de aba anônima. Abra a página duas vezes se ainda não aparecer.
* **Os dados sumiram:** limpar os dados do site no navegador apaga o que o app guardou. Use **Restaurar dados de exemplo** no painel do responsável.
* **O app não atualiza depois de uma nova versão:** abra com internet e feche e abra de novo. Se persistir, desinstale e instale outra vez.
* **O tempo "voltou" a zero:** é proposital. A cada novo dia o tempo usado é zerado, como no limite diário real.
* **A tela do celular aparece com a moldura de telefone:** isso só acontece em telas largas (PC e tablet). No celular o app ocupa a tela toda.

## Limites do alpha e próximos passos

* O tempo de jogo é simulado, e o bloqueio acontece só dentro do app.
* O PIN de demonstração é fixo (1234), e os dados ficam apenas no aparelho.
* Não é um APK nem está em loja de aplicativos.
* Para a versão real, os próximos passos são: app Android nativo que mede o uso de cada jogo e cobre a tela quando o limite acaba, um agente para Windows que acompanha os processos dos jogos, e um serviço de sincronização para o painel do responsável em outro aparelho.
