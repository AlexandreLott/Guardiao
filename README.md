# Guardião — Controle Parental

**Controle parental para jogos eletrônicos, no computador e no celular** — Projeto A3, UC Exploração Digital e Fundamentos Tecnológicos.

📲 **[Alpha instalável (celular e PC)](https://alexandrelott.github.io/guardiao-gamer-alpha/)** · 📖 **[Guia de instalação](docs/GUIA-DE-INSTALACAO.md)** · 📄 **[Documentação completa em PDF](docs/Guardiao-Gamer-Documentacao.pdf)** · 📚 Diário técnico online: [GitBook](https://bet-blocker.gitbook.io/bet-blocker-docs/)


🤖 **[Baixar o APK para Android](https://github.com/AlexandreLott/Guardiao/releases/latest)** — o arquivo `guardiao.apk` fica na Release mais recente (o repositório agora é público: o link abre sem login; depois da primeira instalação, o app avisa quando há versão nova e se atualiza sozinho). Como gerar e instalar: [README do app](apps/README.md#instalar-no-android-apk).


## Aplicativo (código-fonte)

O aplicativo real do Guardião é **um só app Flutter para Android e Windows** (pasta [apps/guardiao](apps/guardiao)), com dados na nuvem pelo Firebase. No primeiro acesso o aparelho escolhe se é do **responsável** ou do **filho**.

- **Vínculo por QR gerado pelo aparelho do filho** (celular ou computador): o responsável lê o QR com a câmera (ou digita o código de 8 caracteres), confere o aparelho e vincula. Um responsável pode vincular **vários aparelhos de filhos**. Não precisa de domínio nem de servidor próprio.
- Lista de apps instalados, **tempo de uso real** e **bloqueio de verdade** ao estourar o limite diário (Android e Windows).
- O responsável acompanha o uso de hoje e dos últimos 7 dias; o filho vê quanto já usou e quanto resta.
- Regras de segurança do Firestore testadas no emulador (53 testes), mais testes automáticos do app e do código compartilhado.
- Ícone real de cada app do filho aparece na lista do responsável (Android).
- **Aviso de tentativa de burla:** o responsável é notificado quando o filho retira uma permissão (acesso ao uso, sobreposição, notificações), desativa a proteção contra desinstalação ou para o serviço de acompanhamento, e o aparelho que fica 45 minutos sem sinal é destacado como "sem comunicação" (indício de desinstalação). A verificação roda em segundo plano nos dois aparelhos a cada ~15 minutos, sem custo (sem Cloud Functions), e o app do filho pede o **administrador do dispositivo**, o que faz o Android exigir a desativação dele antes de desinstalar.
- Atualização dentro do app (Android): o app avisa quando há versão nova, baixa o APK da Release, confere a integridade e abre o instalador; não precisa baixar o APK por fora.

Limites conhecidos: o QR pela câmera e o bloqueio nativo foram testados só por simulação (falta provar em celulares de verdade), o uso só chega ao responsável com o app do filho aberto, e o aviso de burla chega com atraso de cerca de 15 a 30 minutos. A desinstalação não pode ser comunicada pelo próprio aparelho: ela é detectada pela desativação prévia do administrador ou pela ausência de sinal por 45 minutos, e só vale depois que o filho ativa a "Proteção contra desinstalação" no app.

Para rodar e configurar: [README do app](apps/README.md) · [Arquitetura](docs/ARQUITETURA.md) · [Configurar o Firebase](docs/CONFIGURAR-FIREBASE.md). O alpha instalável acima continua sendo o protótipo web de demonstração.

> Este README espelha o diário técnico do projeto no GitBook. O repositório foi renomeado para `Guardiao` (o nome original era `Bet-Blocker`, do projeto anterior) e é **público**. O alpha instalável fica em um repositório público separado, [guardiao-gamer-alpha](https://github.com/AlexandreLott/guardiao-gamer-alpha), que tem o GitHub Pages ligado.

## Sobre o projeto

Ferramenta que ajuda pais e responsáveis a definir e aplicar limites de tempo de tela para jogos eletrônicos no computador e no celular dos filhos, com relatório de uso e um painel de acompanhamento — sem depender de cada jogo ter seu próprio sistema de controle parental.

> **Mudança de rumo (30/09/2026):** o projeto original ("Bet Blocker") ficou inviável da noite para o dia depois que o governo federal proibiu totalmente as apostas online no Brasil (Medida Provisória assinada em 25/09/2026 — [veja a notícia](https://agenciagov.ebc.com.br/noticias/202609/presidente-lula-assina-medida-provisoria-que-proibe-as-bets-no-brasil)). O grupo decidiu migrar para um tema com problema real e regulação também recente: **controle parental para jogos eletrônicos**, puxado pela nova Lei Felca / ECA Digital ([Lei 15.211/2025](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/l15211.htm)). Todo o histórico do projeto anterior continua registrado no Registro de Uso de IA.

Este repositório espelha o diário técnico do projeto (GitBook), conforme pede a ficha de inscrição: a proposta, as decisões tomadas, o protótipo e o uso de IA ao longo do desenvolvimento.

---

# Proposta do Projeto

> Rascunho vivo: o grupo deve revisar, ajustar e transcrever para a ficha oficial (Anexo 4) com nomes, RA e as decisões finais.

**Proposta reescrita em 30/09/2026.** O tema original (bloqueio de bets) ficou obsoleto com a proibição federal das apostas online (item 3). Esta versão troca o tema para **controle parental de jogos eletrônicos**, mantendo a mesma estrutura de 16 itens. O grupo ainda precisa validar coletivamente se topa seguir com o novo tema (ver "Próximos passos" no final).

## 1. Nome do projeto

**Nome (atualizado):** Guardião — Controle Parental (o nome proposto na época era "Guardião Gamer")

**Frase curta:** Ferramenta que ajuda pais e responsáveis a definir e aplicar limites de tempo de tela para jogos eletrônicos no computador e no celular dos filhos, com relatório de uso e um painel de acompanhamento.

## 2. Integrantes do grupo

* Alexandre Lott de Alcântara Bizarria
* Christian Lorran da Silva Batista
* Lucas Pires Franco
* Luiz Philipe Alves dos Santos
* Rafael Felipe de Paula
* Victor Gabriel Dutra de Abreu

## 3. Problema ou oportunidade identificada

**Problema:** o uso excessivo/problemático de jogos eletrônicos por crianças e adolescentes brasileiros é comum e, segundo pesquisa, maior do que a média internacional — e os pais têm poucas ferramentas práticas para aplicar limites de forma consistente entre jogos e dispositivos diferentes.

**Dados que sustentam o problema:**

* Estudo da USP (programa #Tamojunto 2.0, com mais de 7 mil estudantes de escolas públicas de SP e CE) encontrou que **85,85% dos adolescentes brasileiros jogam videogame**, e **28,17% preenchem os critérios de Transtorno do Jogo pela Internet (Internet Gaming Disorder)** — proporção maior que a média internacional. ([fonte](https://jornal.usp.br/ciencias/uso-problematico-de-video-games-entre-jovens-do-brasil-e-maior-que-a-media-de-outros-paises/))
* O perfil de maior risco: meninos, usuários de álcool/tabaco, envolvidos em bullying (vítimas ou autores) e com sintomas de hiperatividade/problemas de conduta.
* O próprio governo já reconhece a necessidade de mais controle nesse tema: a **Lei 15.211/2025 ("ECA Digital"/"Lei Felca")**, em vigor desde 17/03/2026, passou a exigir das plataformas verificação de idade mais rígida e ferramentas de controle parental — a ponto de jogos como League of Legends e Valorant terem mudado classificação indicativa e passado a exigir autorização de responsável para menores de 18 anos. ([fonte](https://www.cnnbrasil.com.br/tecnologia/lei-felca-proibe-lol-e-outros-jogos-para-menores-no-brasil-entenda/))

**Por que ainda existe espaço para este projeto:** o controle parental exigido pela Lei Felca é implementado **por cada plataforma/publisher separadamente** (ex.: só vale para os jogos da Riot, através do portal da própria Riot). Um responsável com filhos jogando em vários jogos diferentes (Roblox, Free Fire, Minecraft, Fortnite...) precisaria configurar cada um separadamente, se é que o jogo oferece essa opção. Não existe uma ferramenta única, no nível do dispositivo, que junte o controle de tempo de vários jogos/apps ao mesmo tempo — esse é o espaço que a proposta ocupa.

## 4. Área de aplicação

Educação e Saúde (bem-estar infantojuvenil), com relação direta à Proteção de Crianças e Adolescentes no ambiente digital (ECA Digital) — a solução se posiciona como **complementar** ao controle parental que cada plataforma já é obrigada a oferecer, unificando-o num só lugar.

## 5. Público-alvo e usuários

* **Público-alvo:** famílias com crianças e adolescentes (6 a 17 anos) que jogam em computador e/ou celular.
* **Usuário principal:** o pai/mãe/responsável, que instala o app no dispositivo da criança e configura os limites.
* **Usuário secundário:** a própria criança/adolescente, que usa o dispositivo já com as regras aplicadas, com uma tela simples mostrando quanto tempo ainda tem disponível.

**Cuidados de acessibilidade:** linguagem simples tanto para o painel dos pais quanto para a tela da criança (sem tom punitivo/de vigilância), bom contraste, funcionar bem em celulares de entrada e computadores mais antigos.

## 6. Descrição da solução

**Antes:** o responsável instala o app no dispositivo do filho, cadastra os jogos/apps a monitorar e define um limite diário de tempo (total e/ou por jogo específico).

**Durante:** ao atingir o limite, o jogo é bloqueado com uma tela de aviso mostrando quanto tempo foi usado e quando o acesso libera de novo (ex.: no dia seguinte).

**Depois:** o responsável acompanha, num painel protegido por PIN, quanto tempo foi jogado por dia e por jogo na semana, e pode ajustar os limites quando quiser.

## 7. Principais funcionalidades

**Essenciais (priorizadas para a demonstração de segunda-feira):**

* Limite de tempo diário por jogo/app;
* Tela de bloqueio ao esgotar o tempo do dia;
* Painel do responsável protegido por PIN (nesta versão, no mesmo dispositivo);
* Relatório de uso (tempo jogado por dia/jogo ao longo da semana).

**Desejáveis (próximas etapas, fora do escopo da demo):**

* Painel remoto de verdade, acessado de outro dispositivo do responsável, sincronizado pela nuvem;
* Bloqueio automático por faixa etária/classificação indicativa (alinhado à Lei Felca);
* Notificação ao responsável quando o limite é atingido ou há tentativa de burlar o bloqueio;
* Agenda de horários permitidos (ex.: sem jogos em horário escolar).

## 8. Uso de inteligência artificial e automação

* IA pode ajudar a sugerir limites de tempo de referência por faixa etária, sempre citando a fonte da recomendação — nunca substituindo orientação médica/pedagógica;
* Automação gera o relatório semanal de uso a partir dos dados registrados no dispositivo.

> **Regra de segurança obrigatória:** o app nunca deve fazer diagnóstico de vício em jogos, TDAH ou qualquer outra condição de saúde da criança — mostra só dados objetivos de tempo de uso, deixando a interpretação para a família e, se for o caso, para profissionais de saúde.

## 9. Informações utilizadas pela solução

* **Fornecidas pelo responsável:** lista de jogos/apps a monitorar, limites de tempo escolhidos, PIN de acesso ao painel.
* **Geradas pela solução:** tempo de uso por jogo/dia (dado pessoal da criança/adolescente).
* **Não será coletado:** conteúdo de conversas dentro dos jogos, geolocalização, dados de pagamento, dados de saúde, ou qualquer dado de terceiros com quem a criança joga online.

**Base legal:** consentimento do responsável legal, conforme **art. 14 da LGPD** (tratamento de dados de crianças e adolescentes exige consentimento específico de ao menos um dos pais/responsável). No MVP, os dados de uso ficam no próprio dispositivo/sob controle do responsável, sem envio a terceiros.

## 10. Tecnologias e ferramentas escolhidas

* Flutter (multiplataforma) para computador (Windows) e celular (Android) — reaproveitando parte da base de código já iniciada no projeto anterior (persistência de estado, estrutura de telas);
* Monitoramento do app/jogo em uso em primeiro plano, nativo por sistema operacional;
* Protótipo interativo em HTML/CSS/JS, com dados de exemplo, para a demonstração de segunda-feira;
* Gráficos do relatório semanal (SVG nativo, sem dependência externa).

Justificativa: ferramentas já dominadas pelo grupo, permitem reaproveitar arquitetura já construída e são suficientes para demonstrar o conceito no prazo do projeto.

## 11. Viabilidade e escopo inicial

**Será desenvolvido (MVP para a demonstração de segunda-feira):**

* Protótipo interativo com as 4 funcionalidades essenciais do item 7, com dados de exemplo (não são dados reais de nenhuma criança).

**Não será desenvolvido nesta etapa:**

* Sincronização remota real entre o dispositivo da criança e o do responsável (exigiria um backend próprio);
* Bloqueio automático por classificação indicativa;
* Detecção de burla técnica avançada (múltiplas contas, máquina virtual etc.).

## 12. Impactos esperados

**Positivos:** dá aos pais uma ferramenta única e multiplataforma, sem precisar configurar cada jogo separadamente; gera dados objetivos para conversas em família sobre uso de telas — alinhado à própria recomendação do estudo da USP ("pais devem jogar junto, conversar sobre o conteúdo e restringir a duração").

**Negativos e riscos:** pode gerar conflito familiar se usado de forma punitiva, sem diálogo; passa falsa sensação de segurança (não substitui acompanhamento humano); adolescentes mais velhos podem tentar contornar tecnicamente o bloqueio.

## 13. Aspectos éticos, de privacidade e segurança

* **Ética:** o app é ferramenta de apoio à mediação parental, não de vigilância total — mostra só tempo de uso, nunca conteúdo de conversas; a criança vê de forma transparente o que está sendo monitorado.
* **Privacidade (LGPD art. 14 + Lei 15.211/2025):** consentimento do responsável legal antes de qualquer coleta; dado tratado localmente no MVP; sem venda ou compartilhamento com terceiros.
* **Segurança:** PIN obrigatório para acessar/alterar o painel do responsável — a criança não deve conseguir mudar os próprios limites.

## 14. Forma de utilização da IA durante o projeto

_(diferente do item 8: aqui é como o grupo usou IA para desenvolver a proposta/protótipo)_

* Pesquisa: motivo do pivot (Medida Provisória que proibiu as bets), a Lei Felca/ECA Digital, o art. 14 da LGPD e dados sobre uso problemático de videogames no Brasil (estudo USP);
* Planejamento: redesenho do escopo e das funcionalidades essenciais para o novo tema;
* Prototipação: telas e fluxo do protótipo interativo de demonstração;
* Desenvolvimento: apoio na adaptação da base de código já existente do protótipo anterior;
* Documentação: reescrita deste espaço no GitBook.

Ver o Registro de Uso de IA abaixo para o log detalhado (ferramenta, prompt, resultado, correções).

## 15. Referências consultadas

* BRASIL. _Lei nº 15.211, de 29 de dezembro de 2025_ — "ECA Digital"/"Lei Felca", altera o ECA para reforçar a proteção de crianças e adolescentes no ambiente digital. [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/l15211.htm). Acesso em: 30 set. 2026.
* BRASIL. _Lei nº 13.709/2018 (LGPD)_, art. 14 — tratamento de dados pessoais de crianças e adolescentes. [lgpd-brasil.info](https://lgpd-brasil.info/capitulo_02/artigo_14). Acesso em: 30 set. 2026.
* AGÊNCIA GOV. _Presidente Lula assina medida provisória que proíbe as bets no Brasil_, 25 set. 2026. [agenciagov.ebc.com.br](https://agenciagov.ebc.com.br/noticias/202609/presidente-lula-assina-medida-provisoria-que-proibe-as-bets-no-brasil). Acesso em: 30 set. 2026.
* CNN BRASIL. _Lei Felca proíbe LoL e outros jogos para menores no Brasil; entenda_, 2026. [cnnbrasil.com.br](https://www.cnnbrasil.com.br/tecnologia/lei-felca-proibe-lol-e-outros-jogos-para-menores-no-brasil-entenda/). Acesso em: 30 set. 2026.
* JORNAL DA USP. _Uso problemático de videogames entre jovens do Brasil é maior que a média de outros países_, 2026. [jornal.usp.br](https://jornal.usp.br/ciencias/uso-problematico-de-video-games-entre-jovens-do-brasil-e-maior-que-a-media-de-outros-paises/). Acesso em: 30 set. 2026.

## 16. Divisão de funções

* Christian Lorran da Silva Batista - Pesquisa
* Rafael Felipe de Paula - Pesquisa
* Luiz Philipe Alves dos Santos - Documentação
* Victor Gabriel Dutra de Abreu - Documentação
* Lucas Pires Franco - Desenvolvimento
* Alexandre Lott de Alcântara Bizarria - Desenvolvimento

## Conclusão

_(a preencher ao final do projeto — síntese dos resultados alcançados)_

## Próximos passos

* Validar coletivamente com o grupo se topam seguir com o novo tema (controle parental de jogos);
* Nome final do produto: definido como "Guardião" (a proposta original era "Guardião Gamer");
* Instalar e testar o alpha nos aparelhos reais que serão levados à demonstração (guia de instalação);
* Enviar o pacote ao repositório e ligar o GitHub Pages (passo 0 do guia);
* Dividir responsabilidades para a próxima etapa (sincronização remota real, bloqueio por classificação indicativa);
* Transferir para o Anexo 4 e a ficha oficial quando o grupo validar o novo tema.

---

# Protótipo — Guardião Gamer

Protótipo funcional do **Guardião Gamer**, o app de controle parental para jogos (PC e celular). Já roda com dados de exemplo e reage a cliques: dá para estourar um limite de jogo, entrar no painel do responsável com PIN e ver o relatório semanal.

> **Como testar:** instale o alpha pelo [guia de instalação](#instalar-o-alpha-demonstração) ou abra [`app/index.html`](app/index.html) direto no navegador. Clique em **"Simular 10 min jogando (demo)"** em qualquer jogo até o limite diário estourar: a tela de bloqueio da criança aparece sozinha. Para o painel do responsável, toque em **Responsável** na barra inferior e digite o PIN de demonstração **1234**.

## O que já funciona nesta versão

* **Limite de tempo por jogo/app** — cada jogo tem um limite diário configurável; a barra de progresso muda de cor e o status vira "Esgotado" quando o tempo acaba.
* **Bloqueio automático** — ao atingir o limite, a criança é levada para uma tela de bloqueio sem opção de burlar, liberada de novo só à meia-noite (ou por um ajuste do responsável).
* **Painel do responsável protegido por PIN** — permite ajustar o limite diário de cada jogo e redefinir o tempo usado hoje.
* **Relatório semanal de uso** — gráfico dos últimos 7 dias, total e média diária, dias em que o limite foi batido, e o jogo mais jogado da semana.
* **Cadastro de novos jogos/apps** — tela para adicionar um jogo à lista monitorada com ícone e limite diário.
* **Instalável e offline (alpha 0.1)** — roda como aplicativo no celular e no PC e continua funcionando sem internet depois da primeira abertura.
* **Dados salvos no aparelho** — jogos e limites persistem ao fechar o app; a cada novo dia o tempo usado é zerado. O painel do responsável tem o botão "Restaurar dados de exemplo" para recomeçar a demonstração.

## As 6 telas

1. **Início** — lista os jogos monitorados, cada um com o tempo usado hoje, o limite diário e uma barra de progresso (verde = dentro do limite, vermelha = esgotado). Um card no topo soma o tempo total de tela do dia. Cada jogo tem um botão "Simular 10 min jogando (demo)" só para a demonstração — no app final esse tempo seria contado automaticamente pelo sistema operacional.
2. **Adicionar jogo** — cadastra um jogo ou aplicativo na lista monitorada: nome, ícone e limite diário (30 min a 2h, ajustável depois no painel do responsável).
3. **Bloqueio ativo** — visão da criança quando o tempo acaba: substitui o jogo automaticamente, sem botão de "continuar jogando".
4. **Relatório semanal** — gráfico de barras com os minutos jogados por dia, total da semana, média diária, dias em que algum limite foi batido e o jogo com mais uso.
5. **PIN do responsável** — o painel fica atrás de um PIN de 4 dígitos, para a criança não conseguir mudar os próprios limites (PIN da demonstração: **1234**).
6. **Painel do responsável** — ajusta o limite diário de cada jogo, redefine o tempo usado no dia e mostra o dispositivo monitorado. A sincronização remota entre o celular da criança e o app do responsável em outro aparelho é a próxima etapa (v2) — nesta versão os dados são locais e de exemplo.

## Padrões visuais usados

* **Cores primárias (Material Design 3):** roxo `#6750A4` (primary) e `#D0BCFF` (primary container)
* **Cores secundárias (M3):** verde `#386A20` (secondary) e `#9DD47E` (secondary container)
* **Tipografia:** Roboto Flex / Roboto quando instaladas no aparelho, com a fonte do sistema como reserva (o app não depende de internet)
* **Ícones:** conjunto Material embutido no app em SVG (funciona offline)
* **Componentes:** cards com cantos arredondados, navegação inferior, barras de progresso e badges de status

---

# Instalar o Alpha (demonstração)

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

> **Nota:** O alpha mora num repositório separado, criado quando o repositório principal ainda era privado. Se o link não abrir, use os caminhos 2, 3 ou 4.


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

---

# Auditoria do Projeto (24/10/2026)

Auditoria feita em **24/10/2026** sobre o GitBook, o protótipo e os arquivos do repositório. A parte do protótipo foi testada no navegador (Chromium sem interface), seguindo o roteiro completo de demonstração.

> **Atenção:** O que **não** foi testado: aparelhos físicos (Android e iPhone) e o Windows real com o `.bat`. O teste foi feito em navegador com tela de celular simulada. O grupo precisa instalar e testar nos aparelhos que vai levar à demonstração.

## Protótipo: defeitos achados e corrigidos

| Achado | Correção |
| --- | --- |
| Os ícones e as fontes vinham do Google Fonts, então o app quebrava sem internet | Ícones embutidos no próprio arquivo (SVG) e fonte do sistema como reserva |
| O botão **+** rolava junto com a lista e ficava em cima do selo dos cards | Botão fixo na tela e só visível no Início, com espaço no fim da lista |
| O número máximo do gráfico (210) ficava cortado no topo | Margem superior maior no gráfico |
| O total do relatório ("15h 10min") quebrava em duas linhas | Fonte menor e sem quebra de linha |
| Nomes de jogos digitados eram colocados na página sem tratamento (dava para inserir código no lugar do nome) | Todo texto digitado é tratado antes de aparecer |
| Os dados voltavam ao padrão ao recarregar a página | Dados salvos no aparelho; a cada novo dia o tempo usado é zerado |
| O rótulo da semana ("22–28 set.") ficava fixo e errado | Agora diz "Semana de exemplo" |
| A moldura de telefone aparecia dentro do celular de verdade | Em telas estreitas o app ocupa a tela inteira |
| O arquivo tinha a tag de título no lugar errado e não era instalável | Página reescrita com cabeçalho completo, manifesto, ícones e cache offline (PWA) |
| Faltava um jeito rápido de recomeçar a demonstração | Botão **Restaurar dados de exemplo** no painel do responsável |

**Verificações que passaram:** fluxo completo (simular uso, bloqueio, PIN errado e certo, mudar limite, cadastrar jogo, relatório); nenhum erro no console; manifesto e 4 ícones carregando; app funcionando com a internet desligada depois da primeira visita; tela de 390 px sem rolagem lateral; arquivo único funcionando aberto direto do disco.

## Documentação e repositório

| Achado | Situação |
| --- | --- |
| O PDF e o README estavam com data de 06/10 e sem guia de instalação | Atualizados nesta data, com o guia e esta auditoria |
| O Registro de Uso de IA não tinha as linhas de 06/10 e de 24/10 no GitBook | Linhas adicionadas (somente acréscimo, nada apagado) |
| A seção "Onde começar" não levava ao guia de instalação | Link adicionado |
| O repositório principal não recebia arquivos pela sessão da IA (credencial do GitHub inválida) | **Resolvido em 24/10:** README, pastas `app/`, `docs/` e `downloads/` enviadas pelo navegador já logado. As páginas do GitBook sincronizam sozinhas com a pasta `documentation/` |
| O link público do alpha não existia (o repositório principal é privado e o Pages não funciona nele) | **Resolvido em 24/10:** repositório público separado (`guardiao-gamer-alpha`) com GitHub Pages ligado |

## Pontos em aberto para o grupo decidir

* **Nome do produto:** na época da auditoria, "Guardião Gamer" ainda era proposta; o nome foi definido depois como "Guardião".
* **Tema:** o grupo ainda precisa validar coletivamente a mudança de tema.
* **Repositório principal agora público:** o README traz nomes, RAs e e-mails dos integrantes; o grupo precisa decidir se mantém esses dados à vista ou se os retira do README.
* **Nome do repositório e do site:** na época continuavam como "Bet-Blocker" (e `bet-blocker-docs`). O repositório do aplicativo já foi renomeado para `Guardiao`; o site do GitBook segue com o endereço antigo.
* **Projeto Flutter antigo (Bet Blocker):** obsoleto e nunca compilado por completo. Não foi incluído no repositório.
* **Protótipo no Claude Artifact:** o link é privado e só abre na conta de quem o publicou. Para o grupo e a banca, use o link do alpha.
* **Dados da proposta:** as fontes foram consultadas em 30/09/2026; vale reconferir os links antes da entrega oficial.

---

# Registro de Uso de IA

Tabela viva para registrar cada uso relevante de IA durante o desenvolvimento do projeto (item 14 da ficha).

**13/09/2026 — Pesquisa e proposta (Claude).** Finalidade: pesquisar dados sobre bets no Brasil, Lei 14.790 e autoexclusão oficial; estruturar a proposta nos 15 itens do Anexo 4. Prompt: "Ideia de um bloqueador de bets". Resultado: rascunho completo da proposta, com dados reais e referências. Revisão: o grupo deve revisar tom, confirmar dados e decidir se segue com o tema.

**12-21/09/2026 — Desenvolvimento e protótipo, tema Bet Blocker (Claude).** Finalidade: construir protótipo navegável no GitBook (abas com telas), depois evoluir para um app interativo funcional (HTML/CSS/JS) com pausa, chat de apoio e painel semanal simulados. Prompts: "Faça um protótipo funcional direto no GitBook", "transforme em app usável". Resultado: protótipo interativo publicado como Claude Artifact + telas nativas na página de protótipo; início de um app Flutter real (Android/Windows) para bloqueio de sites de apostas. Revisão: o grupo validou visualmente; o código Flutter ficou obsoleto com o pivot de tema.

**30/09/2026 — Pivot de tema, pesquisa e novo protótipo (Claude).** Finalidade: pesquisar o motivo do pivot (MP que proibiu as bets em 25/09/2026), a nova Lei Felca/ECA Digital, o art. 14 da LGPD e dados sobre uso problemático de videogames no Brasil (estudo USP); reescrever a Proposta do Projeto nos 16 itens para o novo tema; projetar e construir o primeiro protótipo interativo do **Guardião Gamer**. Prompt: "com a criação da lei que proibiu as bets online no brasil o nosso trabalho ficou obsoleto [...] vai se transformar em um controle parental para jogos no computador e no celular". Resultado: Proposta reescrita com dados e fontes reais; Registro de Uso de IA atualizado; primeiro protótipo interativo publicado para a demonstração. Revisão: o grupo precisa validar se topa seguir com o novo tema e confirmar o nome proposto.

**30/09/2026 — Protótipo funcional e revisão do GitBook (Claude).** Finalidade: a pedido de "já faça os primeiros modelos para uma demonstração na segunda-feira": construir o protótipo HTML/CSS/JS funcional do Guardião Gamer (clicável, com botão de simular uso, bloqueio automático ao estourar o limite, PIN funcional e relatório semanal com gráfico), reescrever a página de protótipo do GitBook e corrigir links quebrados/contagem de itens encontrados na revisão final. Resultado: protótipo interativo funcional; página de protótipo reescrita com descrição das 6 telas; corrigidos os links da seção "Onde começar" e a contagem de itens da proposta (15 → 16). Revisão: o grupo precisa testar o app interativo e validar as telas antes da demonstração.

**06/10/2026 — Espelho no GitHub (Claude).** Finalidade: espelhar a documentação do GitBook no README do repositório e guardar uma cópia em PDF. Prompt: "faça a alteração no projeto do github e toda a documentação faça um espelho no readme e na página inicial do github e também guarde a documentação em PDF lá". Resultado: README e PDF gerados a partir desta documentação; o envio ao repositório não foi possível na sessão por falta de acesso ao GitHub. Revisão: o grupo deve conferir se o conteúdo bate com o GitBook.

**24/10/2026 — Auditoria e alpha instalável (Claude).** Finalidade: auditar GitBook, protótipo e arquivos do projeto; transformar o protótipo em um alpha instalável (PWA) para a demonstração no celular e no PC; escrever o guia de instalação; atualizar GitBook, README e PDF. Prompt: "Audite tudo e me passe como instalar o alpha no meu celular ou pc para demonstração, atualize o gitbook e o github do projeto". Resultado: dez pontos do protótipo corrigidos ou melhorados (ícones offline, botão +, gráfico, texto sem tratamento, dados não salvos, entre outros); pacote com manifesto, ícones e cache offline; kit offline para Windows; repositório público só do alpha com GitHub Pages; guia de instalação e roteiro de demonstração; página de auditoria; README e PDF atualizados. Revisão: testado só em navegador com tela de celular simulada, então o grupo precisa testar nos aparelhos reais; arquivos enviados ao GitHub pelo navegador do usuário (já logado) e criado um repositório público separado para o link do alpha.

_05/11/2026–09/11/2026 — App real, pareamento por QR, APK e atualização dentro do app (Claude). Finalidade: escrever e testar o código do aplicativo Flutter (pareamento por QR, bloqueio no Android/Windows, ícones dos apps, atualização dentro do app), as regras do Firestore, o workflow que compila o APK e a documentação. Resultado: app com testes automáticos, APK assinado publicado em Release e documentação em `docs/`. Revisão: o grupo precisa testar em celulares reais e revisar o código; o bloqueio de um app foi confirmado funcionando em um celular pelo integrante que testou.

(adicionem uma linha por uso relevante — ferramenta, finalidade, prompt, resultado e o que precisou ser corrigido)_

**09/11/2026 — Aviso de tentativa de burla (Claude).** Finalidade: avisar o responsável quando o filho retirar permissões do app, desativar a proteção ou desinstalar o aplicativo. Prompt: "Quando o apk do filho foi desinstalado do celular não teve nenhum aviso ao aparelho responsável, preciso que avise qualquer tentativa de burlar, seja retirando as permissões ou desinstalando". Resultado: modelo de dados (situação das proteções e avisos), regras do Firestore (53 testes), verificação em segundo plano com WorkManager e notificações locais nos dois aparelhos, administrador do dispositivo no Android, telas de alerta para o responsável, testes automáticos e atualização da documentação; aplicativo compilado e publicado como Release `apk-4`. Revisão: o grupo deve validar em dois celulares reais (retirar a permissão, desativar o administrador e desinstalar), pois só houve testes automáticos e compilação; o aviso tem atraso de 15 a 30 minutos e a desinstalação só é detectada pelo administrador ou pela falta de sinal por 45 minutos.

**10/11/2026 — Novo design e painel do responsável (Claude).** Finalidade: aplicar ao aplicativo as 23 telas de design do projeto (nome Guardian, fonte Lexend, azul e laranja) e implementar o que elas pedem: rotinas, bloqueio geral, apps sempre liberados, créditos benéficos com aprovação, relatório de uso, PIN no painel do responsável e tela de bloqueio com atalhos. Prompt: "As telas de design do projeto, implemente para ficar assim". Resultado: sistema de design no pacote compartilhado, novas abas do responsável (Resumo, Apps, Rotinas, Créditos) e do filho (Início, Relatório, Créditos, Responsável), política de bloqueio espelhada em Kotlin, regras do Firestore para configuração e créditos (61 testes) e 107 testes do app. Revisão: o grupo deve conferir as telas em celulares reais contra o design; a tela "Novo jogo" não foi feita (o responsável já vê todos os apps instalados); o PIN é só uma trava contra uso por engano; o monitor do Windows ainda ignora rotinas, bloqueio geral e créditos.
