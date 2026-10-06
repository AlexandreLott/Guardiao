# Proposta do Projeto

> Rascunho vivo: revisem, ajustem o que quiserem e transcrevam para a ficha oficial (Anexo 4) com nomes, RA e as decisões finais do grupo.

{% hint style="warning" %}
**Proposta reescrita em 30/09/2026.** O tema original (bloqueio de bets) ficou obsoleto com a proibição federal das apostas online (item 3). Esta versão troca o tema para **controle parental de jogos eletrônicos**, mantendo a mesma estrutura de 16 itens. O grupo ainda precisa validar coletivamente se topa seguir com o novo tema (ver "Próximos passos" no final).
{% endhint %}

## 1. Nome do projeto

**Nome (proposto, a confirmar com o grupo):** Guardião Gamer — Controle Parental para Jogos

**Frase curta:** Ferramenta que ajuda pais e responsáveis a definir e aplicar limites de tempo de tela para jogos eletrônicos no computador e no celular dos filhos, com relatório de uso e um painel de acompanhamento.

## 2. Integrantes do grupo

* Alexandre Lott de Alcântara Bizarria - 326116123 - alexandre.lott10@gmail.com
* Christian Lorran da Silva Batista - 32622936 - Christianlorransen@gmail.com
* Lucas Pires Franco - 32628258 - lucasfranco21112007@gmail.com
* Luiz Philipe Alves dos Santos - 326212120 - luizphilipecontato@gmail.com
* Rafael Felipe de Paula - 326213249 - rafaeldepaula663@gmail.com.br
* Victor Gabriel Dutra de Abreu - 32624533 - victorestudante922@gmail.com

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

**Desejáveis (próximas etapas, fora do escopo da demo)**

* Painel remoto de verdade, acessado de outro dispositivo do responsável, sincronizado pela nuvem;
* Bloqueio automático por faixa etária/classificação indicativa (alinhado à Lei Felca);
* Notificação ao responsável quando o limite é atingido ou há tentativa de burlar o bloqueio;
* Agenda de horários permitidos (ex.: sem jogos em horário escolar).

## 8. Uso de inteligência artificial e automação

* IA pode ajudar a sugerir limites de tempo de referência por faixa etária, sempre citando a fonte da recomendação — nunca substituindo orientação médica/pedagógica;
* Automação gera o relatório semanal de uso a partir dos dados registrados no dispositivo;

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

Ver o Registro de Uso de IA para o log detalhado (ferramenta, prompt, resultado, correções).

## 15. Referências consultadas

* BRASIL. _Lei nº 15.211, de 29 de dezembro de 2025_ — "ECA Digital"/"Lei Felca", altera o ECA para reforçar a proteção de crianças e adolescentes no ambiente digital. [planalto.gov.br](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/l15211.htm). Acesso em: 30 set. 2026.
* BRASIL. _Lei nº 13.709/2018 (LGPD)_, art. 14 — tratamento de dados pessoais de crianças e adolescentes. [lgpd-brasil.info](https://lgpd-brasil.info/capitulo_02/artigo_14). Acesso em: 30 set. 2026.
* AGÊNCIA GOV. _Presidente Lula assina medida provisória que proíbe as bets no Brasil_, 25 set. 2026. [agenciagov.ebc.com.br](https://agenciagov.ebc.com.br/noticias/202609/presidente-lula-assina-medida-provisoria-que-proibe-as-bets-no-brasil). Acesso em: 30 set. 2026.
* CNN BRASIL. _Lei Felca proíbe LoL e outros jogos para menores no Brasil; entenda_, 2026. [cnnbrasil.com.br](https://www.cnnbrasil.com.br/tecnologia/lei-felca-proibe-lol-e-outros-jogos-para-menores-no-brasil-entenda/). Acesso em: 30 set. 2026.
* JORNAL DA USP. _Uso problemático de videogames entre jovens do Brasil é maior que a média de outros países_, 2026. [jornal.usp.br](https://jornal.usp.br/ciencias/uso-problematico-de-video-games-entre-jovens-do-brasil-e-maior-que-a-media-de-outros-paises/). Acesso em: 30 set. 2026.

_Complementem com outras fontes usadas na pesquisa._

## 16. Divisão de funções

_(mantida do projeto anterior — revisem se muda com o novo escopo)_

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
* Confirmar o nome final do produto (proposto: "Guardião Gamer");
* Revisar o protótipo interativo antes da demonstração de segunda-feira;
* Dividir responsabilidades para a próxima etapa (sincronização remota real, bloqueio por classificação indicativa);
* Transferir para o Anexo 4 e a ficha oficial quando o grupo validar o novo tema.
