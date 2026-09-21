# Proposta do Projeto

> Rascunho vivo: revisem, ajustem o que quiserem e transcrevam para a ficha oficial (Anexo 4) com nomes, RA e as decisões finais do grupo.

## 1. Nome do projeto

**Nome:** Bet Blocker — Bloqueio e Apoio contra Apostas Digitais

**Frase curta:** Ferramenta que bloqueia o acesso a sites e aplicativos de apostas no próprio dispositivo do usuário e oferece apoio no momento do impulso de apostar.

## 2. Integrantes do grupo

Alexandre Lott de Alcântara Bizarria - 326116123 - alexandre.lott10@gmail.com
Christian Lorran da Silva Batista - 32622936 - Christianlorransen@gmail.com
Lucas Pires Franco - 32628258 - lucasfranco21112007@gmail.com
Luiz Philipe Alves dos Santos - 326212120 - luizphilipecontato@gmail.com
Rafael Felipe de Paula - 326213249 - rafaeldepaula663@gmail.com.br
Victor Gabriel Dutra de Abreu - 32624533 - victorestudante922@gmail.com

## 3. Problema ou oportunidade identificada

**Problema:** as apostas esportivas on-line ("bets") cresceram de forma muito rápida no Brasil e vêm gerando um problema financeiro e comportamental relevante: parte dos apostadores tem dificuldade de controlar o próprio impulso de apostar, mesmo sabendo do risco.

**Dados que sustentam o problema:**

* Segundo estudo da Confederação Nacional do Comércio (CNC), os brasileiros gastaram cerca de **R$ 30 bilhões por mês** em apostas on-line em março de 2026, crescimento de cerca de **500% desde janeiro de 2023**. ([fonte](https://movimentoeconomico.com.br/economia/varejo/2026/04/29/cnc-bets-drenam-r-30-bi-por-mes-e-e-levam-270-mil-familias-a-inadimplencia/))
* O mesmo estudo estima **R$ 143 bilhões** desviados do varejo entre jan/2023 e mar/2026, e cerca de **268 mil famílias** em inadimplência severa (atrasos acima de 90 dias) associada às apostas.
* Grupos mais vulneráveis: homens, famílias de baixa renda (até 5 salários mínimos), pessoas com 35+ anos e ensino médio completo.
* O governo já reconhece o problema: em dezembro de 2025 o Ministério da Fazenda lançou a **Plataforma Centralizada de Autoexclusão**, que bloqueia todas as bets licenciadas de uma vez. ([fonte](https://alertagov.com.br/2026/07/plataforma-de-autoexclusao-bloqueia-todas-as-bets-de-uma-so-vez-a-pedido-do-proprio-usuario/))

**Por que ainda existe espaço para este projeto:** a autoexclusão oficial exige login gov.br (nível prata/ouro), leva até 72h para ativar, não pode ser revertida antes do prazo, e só cobre casas de apostas licenciadas — não bloqueia sites/apps estrangeiros ou não regulamentados. Além disso, ela só impede login/cadastro; não ajuda a pessoa a lidar com o impulso no momento em que ele acontece.

## 4. Área de aplicação

Saúde (bem-estar comportamental/financeiro) e Segurança Digital, com relação direta a Serviços Públicos — a solução se posiciona como **complementar** à política pública de jogo responsável já existente, não como concorrente.

## 5. Público-alvo e usuários

* **Público-alvo:** pessoas maiores de 18 anos que já apostam ou já tiveram dificuldade de controlar o comportamento em apostas on-line.
* **Usuário principal:** a própria pessoa, que instala e configura o bloqueio no seu dispositivo.
* **Usuário secundário:** um "parceiro de confiança" (familiar/amigo), que pode opcionalmente receber um aviso quando houver tentativa de acesso bloqueada — sempre com consentimento explícito do usuário.

**Cuidados de acessibilidade:** linguagem simples e acolhedora (sem julgamento moral), bom contraste na tela de pausa, funcionar bem em celulares de entrada.

## 6. Descrição da solução

Antes: o usuário cadastra, uma única vez, a lista de sites/apps de apostas a bloquear (lista sugerida + adição manual). Durante: ao tentar abrir um item bloqueado, aparece uma tela de pausa (tempo de espera curto + pergunta de reflexão + acesso a um chatbot de apoio) antes de decidir se quer prosseguir. Depois: um painel privado mostra quantas tentativas foram registradas na semana, para o próprio usuário acompanhar seu progresso.

## 7. Principais funcionalidades

**Essenciais**

* Cadastro da lista de sites/apps a bloquear;
* Bloqueio efetivo no navegador (extensão);
* Tela de pausa com tempo de espera e mensagem de reflexão;
* Painel privado com número de tentativas bloqueadas por semana.

**Desejáveis**

* Chatbot de apoio com IA no momento do impulso;
* Notificação opcional ao parceiro de confiança (sempre opt-in);
* Registro do gatilho da tentativa (estresse, tédio, cobrança financeira...);
* Lista fixa de contatos de apoio especializado.

## 8. Uso de inteligência artificial e automação

* IA generativa alimenta o chatbot de apoio, com regras fixas de segurança (abaixo);
* Automação (Make/Zapier) dispara a notificação ao parceiro de confiança quando configurada;
* IA pode observar, de forma agregada e sem expor conteúdo pessoal, os horários mais frequentes das tentativas, para sugerir mensagens de apoio mais úteis.

> **Regra de segurança obrigatória do chatbot:** nunca se apresentar como terapeuta, nunca dar conselho financeiro, e sempre indicar contatos de apoio especializado (CVV, Jogadores Anônimos) quando o texto sugerir sofrimento intenso, desespero ou dívidas graves. Toda resposta deve deixar claro que pode estar errada e que não substitui ajuda profissional.

## 9. Informações utilizadas pela solução

* **Fornecidas pelo usuário:** lista de sites/apps a bloquear; contato do parceiro de confiança (dado pessoal, só com consentimento).
* **Geradas pela solução:** data/hora das tentativas bloqueadas (sem conteúdo de navegação); mensagens com o chatbot; contagem semanal.
* **Não será coletado:** dados bancários, dados de apostas reais, histórico de navegação além do necessário, documentos pessoais.

O usuário pode apagar todo o seu histórico a qualquer momento; nada é compartilhado com o parceiro de confiança além do que ele mesmo autorizar.

## 10. Tecnologias e ferramentas escolhidas

* Extensão de navegador simples para o bloqueio (lista de domínios);
* Chatbot no-code com IA (ex.: Voiceflow, Landbot ou agente configurado);
* Make/Zapier para a automação de notificação;
* Planilha/Airtable para registrar tentativas (dados fictícios nos testes);
* Looker Studio (ou o próprio Airtable) para o painel semanal.

Justificativa: ferramentas gratuitas/baixo custo, sem exigir programação avançada, permitem colaboração entre o grupo e são suficientes para demonstrar o conceito no prazo do projeto.

## 11. Viabilidade e escopo inicial

**Será desenvolvido (MVP):**

* Extensão que bloqueia uma lista pré-definida de sites de apostas;
* Tela de pausa com tempo de espera e reflexão;
* Chatbot básico (roteirizado + IA), com as regras do item 8;
* Painel simples com dados fictícios.

**Não será desenvolvido nesta etapa:**

* Bloqueio em nível de sistema operacional no celular (restrições técnicas fortes de iOS/Android para apps de terceiros) — o grupo demonstra o conceito via navegador e, se possível, um mockup para celular;
* Integração bancária real;
* Qualquer diagnóstico clínico de vício — a ferramenta é apoio, não tratamento.

## 12. Impactos esperados

**Positivos:** barreira imediata e prática (sem esperar 72h), cobre sites não regulamentados, fortalece a rede de apoio da pessoa, pode ser adotado por bancos/ONGs no futuro.

**Negativos e riscos:** o bloqueio é autoimposto (o usuário pode desativar a qualquer momento); não substitui tratamento profissional; o recurso do parceiro de confiança pode virar vigilância se não for sempre opt-in e reversível.

## 13. Aspectos éticos, de privacidade e segurança

* **Ética:** sem julgamento moral a quem aposta; chatbot transparente sobre ser IA e suas limitações; respostas revisadas pelo grupo antes de consideradas prontas.
* **Privacidade (LGPD):** consentimento explícito antes de ativar a notificação ao parceiro; finalidade clara; exclusão de histórico a qualquer momento.
* **Segurança:** dados fictícios em todos os testes; sem nomes reais no painel de demonstração; PIN para desativar o bloqueio (fricção saudável contra desativação por impulso).

## 14. Forma de utilização da IA durante o projeto

_(diferente do item 8: aqui é como o grupo usou IA para desenvolver a proposta/protótipo)_

* Pesquisa: dados sobre bets, autoexclusão e Lei 14.790/2023;
* Planejamento: organização do escopo e das funcionalidades essenciais x desejáveis;
* Prototipação: sugestões de texto para a tela de pausa e roteiro inicial do chatbot (revisadas com cuidado, por ser tema sensível);
* Desenvolvimento: apoio na programação da extensão e automações;
* Documentação: organização deste espaço e revisão de textos.

Ver o [Registro de Uso de IA](registro-de-uso-de-ia.md) para o log detalhado (ferramenta, prompt, resultado, correções).

## 15. Referências consultadas

* BRASIL. _Lei nº 14.790, de 29 de dezembro de 2023_ — regulamenta as bets no Brasil. [zugnopena.com.br](https://www.zugnopena.com.br/br/lei-14-790-2023-regulamentacao-das-bets). Acesso em: 13 set. 2026.
* CONFEDERAÇÃO NACIONAL DO COMÉRCIO (CNC). _Estudo sobre o impacto das bets na inadimplência das famílias brasileiras_, 2026. [movimentoeconomico.com.br](https://movimentoeconomico.com.br/economia/varejo/2026/04/29/cnc-bets-drenam-r-30-bi-por-mes-e-e-levam-270-mil-familias-a-inadimplencia/). Acesso em: 13 set. 2026.
* MINISTÉRIO DA FAZENDA / SECRETARIA DE PRÊMIOS E APOSTAS. _Plataforma Centralizada de Autoexclusão de Apostas_, dez. 2025. [alertagov.com.br](https://alertagov.com.br/2026/07/plataforma-de-autoexclusao-bloqueia-todas-as-bets-de-uma-so-vez-a-pedido-do-proprio-usuario/). Acesso em: 13 set. 2026.

_Complementem com outras fontes usadas na pesquisa._

## Conclusão

_(a preencher ao final do projeto — síntese dos resultados alcançados)_

## Próximos passos

* Validar coletivamente se o grupo topa seguir com este tema (é sensível — todos precisam se sentir confortáveis);
* Decidir o tom final da comunicação e ajustar o que quiserem;
* Dividir responsabilidades por etapa;
* Transferir para o Anexo 4 e a ficha oficial;
* Começar o cronograma (Anexo 1) e manter este espaço atualizado como diário técnico.
