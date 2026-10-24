# Guardião Gamer — Auditoria do Projeto (24/10/2026)

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
| O repositório não recebe arquivos pela sessão da IA (credencial do GitHub inválida) | **Pendente:** envio manual, no passo 0 do guia. As páginas do GitBook sincronizam sozinhas com a pasta `documentation/` do repositório |
| O link público do alpha ainda não existe | **Pendente:** depende do envio e de ligar o GitHub Pages (passo 0) |

## Pontos em aberto para o grupo decidir

* **Nome do produto:** "Guardião Gamer" ainda é proposta e precisa ser confirmado pelo grupo.
* **Tema:** o grupo ainda precisa validar coletivamente a mudança de tema.
* **Nome do repositório e do site:** continuam como "Bet-Blocker" (e `bet-blocker-docs`). Renomear muda o endereço do GitHub Pages, então vale deixar para depois da demonstração.
* **Projeto Flutter antigo (Bet Blocker):** obsoleto e nunca compilado por completo. Não foi incluído no repositório.
* **Protótipo no Claude Artifact:** o link é privado e só abre na conta de quem o publicou. Para o grupo e a banca, use o link do alpha.
* **Dados da proposta:** as fontes foram consultadas em 30/09/2026; vale reconferir os links antes da entrega oficial.
