# Implementação dos apps (marco 1)

Depois da reunião com o orientador, o Guardião Gamer passou a ter **dois aplicativos** que conversam pela internet. Esta página registra o que foi construído no primeiro marco da implementação real (código em Flutter, com Firebase), o que já está testado e o que ainda falta.

{% hint style="info" %}
**Em uma frase:** o responsável cria um código no app dele, digita no aparelho do filho, e a partir daí enxerga os aplicativos instalados lá e pode definir um limite diário ou um bloqueio para cada um.
{% endhint %}

## Os dois aplicativos

|           | App do filho                                                                                             | App do responsável                                                                         |
| --------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Quem usa  | A criança ou o adolescente                                                                               | Pai, mãe ou responsável                                                                    |
| Sistemas  | Android e Windows                                                                                        | Android (iPhone previsto)                                                                  |
| O que faz | Vincula o aparelho com um código, envia a lista de apps instalados e mostra o tempo restante de cada app | Cria a conta, gera o código de pareamento, vê os apps do filho e define limite ou bloqueio |

## Como funciona o pareamento

1. O responsável cria a conta (e-mail e senha) e toca em **Adicionar aparelho**. O app mostra um código de 8 caracteres, como `K7M2-9QXA`, que vale 10 minutos e só pode ser usado uma vez.
2. No aparelho do filho, ele digita o código e toca em **Vincular**.
3. Na hora, o aparelho aparece na lista do responsável e, em segundos, chega a lista de aplicativos instalados.
4. O responsável toca em um aplicativo, escolhe **limite diário** (de 15 minutos a 8 horas) ou **bloquear o dia todo**, e a regra aparece no app do filho em tempo real.
5. Se o responsável remover o aparelho, o app do filho volta a pedir o código.

O código usa letras e números sem caracteres confundíveis (sem 0, O, 1, I e L). São cerca de 850 bilhões de combinações, o que impede adivinhar um código no prazo de 10 minutos.

## O que já funciona e está testado

| Funcionalidade                                                                                     | Situação                                  |
| -------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| Conta do responsável (e-mail e senha) e entrada anônima do aparelho do filho                       | Pronto                                    |
| Pareamento por código com validade e uso único                                                     | Pronto                                    |
| Leitura dos apps instalados: Android pelo gerenciador de pacotes, Windows pelo registro do sistema | Pronto (veja os limites abaixo)           |
| Lista de apps no app do responsável, com busca e ordenação                                         | Pronto                                    |
| Limite diário e bloqueio por app, enviados ao filho em tempo real                                  | Pronto                                    |
| Remover aparelho (desvincula o filho)                                                              | Pronto                                    |
| Regras de segurança do banco: cada família só enxerga os próprios dados                            | Pronto, 30 testes no emulador do Firebase |
| Modo demonstração, sem internet, com dados de exemplo                                              | Pronto                                    |

Os testes automáticos somam 75: 22 do núcleo compartilhado, 12 do app do filho, 11 do app do responsável e 30 das regras de segurança. Os dois aplicativos também foram compilados como APK Android.

## O que ainda não existe

{% hint style="warning" %}
**Tempo de uso e bloqueio de verdade ficam para o próximo marco.** Hoje o app do filho mostra o limite e calcula o tempo restante, mas a contagem do tempo usado ainda não existe, então o tempo restante não diminui. Também não há ainda um relatório de tempo de tela no app do responsável.
{% endhint %}

* **Medir o tempo de cada app:** no Android, pelas estatísticas de uso do sistema (o usuário precisa conceder uma permissão especial); no Windows, acompanhando o programa em primeiro plano.
* **Bloquear o app quando o limite acaba:** no Android, com um serviço de acessibilidade que cobre a tela; no Windows, encerrando o processo ou cobrindo a tela.
* **Impedir que a criança desinstale o app:** no Android, com o recurso de administrador do dispositivo.
* **Ícones dos apps, notificações ao responsável e app do responsável no iPhone.**

## O que não foi testado

* Nenhum dos dois apps rodou em um **aparelho real** ainda: o ambiente de desenvolvimento não tem celular nem emulador. As telas e a lógica foram testadas de forma automática, e o Android foi compilado, mas a leitura real dos apps instalados (Android e Windows) precisa ser conferida em aparelho.
* A **conexão com o Firebase de verdade** só pode ser testada depois que o grupo criar o projeto no Firebase. O guia de configuração está no repositório, em `docs/CONFIGURAR-FIREBASE.md`. As regras de segurança, por outro lado, foram testadas no emulador do Firebase.
* O app do Windows não foi compilado (isso exige um computador com Windows e Visual Studio).

## Decisões tomadas

| Decisão                   | Escolha                               | Motivo                                                                      |
| ------------------------- | ------------------------------------- | --------------------------------------------------------------------------- |
| Tecnologia                | Flutter, com pequenos trechos nativos | Um único código para Android, Windows e iPhone; já estava na proposta       |
| Comunicação entre os apps | Firebase (Authentication e Firestore) | Entrada de usuários, banco em tempo real e plano gratuito prontos           |
| Primeiro marco            | Esqueleto, pareamento e lista de apps | É a base de todo o resto                                                    |
| Sistemas do filho         | Android e Windows                     | iPhone depende da API Screen Time da Apple e de conta paga de desenvolvedor |

## Pontos para o grupo decidir

* Quem será o dono do projeto no Firebase (a conta do grupo, não uma conta pessoal) e quem recebe os avisos de cobrança.
* O que acontece quando a criança desinstala o app: apenas o responsável é avisado, ou o aparelho passa a contar como "sem proteção".
* Se o responsável poderá definir horários permitidos (por exemplo, sem jogos em horário de aula) já no próximo marco.

## Privacidade

O app guarda o mínimo necessário: o nome do aparelho, os nomes dos aplicativos instalados e as regras definidas pelo responsável. Não coleta conversas, localização nem dados de pagamento, e a criança vê tudo o que é monitorado. A base legal continua sendo o consentimento do responsável, conforme o art. 14 da LGPD.

Veja também: [Proposta do Projeto](proposta-do-projeto.md), [Protótipo](prototipo-guardiao-gamer.md) e [Auditoria do Projeto](auditoria-do-projeto-24-10-2026.md).
