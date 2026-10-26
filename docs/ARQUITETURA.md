# Arquitetura

## Visão geral

```
 App do responsável (Android)            Firebase                     App do filho (Android / Windows)
 ┌──────────────────────────┐   ┌──────────────────────────┐   ┌──────────────────────────────────┐
 │ login e-mail/senha       │   │ Authentication           │   │ login anônimo                     │
 │ gera código de pareamento├──►│ pairings/{código}        │◄──┤ digita o código, "queima" ele     │
 │ lista aparelhos          │◄──┤ devices/{idDoAparelho}   │◄──┤ cria o próprio documento          │
 │ vê apps instalados       │◄──┤  ├ apps/{idDoApp}        │◄──┤ envia a lista de apps instalados  │
 │ define limite / bloqueio ├──►│  └ rules/{idDoApp}       ├──►│ mostra o tempo restante           │
 └──────────────────────────┘   │ Firestore + regras       │   └──────────────────────────────────┘
                                └──────────────────────────┘
```

O código compartilhado fica em `packages/guardiao_core`:

- `GuardianBackend` é a interface que os dois apps usam. Tem duas implementações: `FirebaseBackend` (produção) e `MemoryBackend` (testes e modo demonstração).
- Os apps nunca falam com o Firestore diretamente, então dá para testar todas as telas sem internet.

## Pareamento

1. O responsável (conta com e-mail e senha) cria `pairings/{código}` com `parentUid`, validade de 10 minutos e `used: false`.
2. O aparelho do filho entra de forma anônima, lê o código e, em um único lote, marca o código como usado (`used: true`, `deviceId`) e cria `devices/{uid}` apontando para o responsável.
3. As regras de segurança conferem as duas pontas do lote: o código existe, não foi usado, não expirou e pertence ao responsável indicado no aparelho. Se qualquer coisa falhar, nada é gravado.

O código tem 8 caracteres de um alfabeto de 31 símbolos (sem 0, O, 1, I, L), cerca de 8 × 10¹¹ combinações, o que torna inviável adivinhar um código dentro dos 10 minutos de validade.

## Quem pode o quê (regras do Firestore)

| Dado | Responsável (dono) | Aparelho do filho | Outros |
| --- | --- | --- | --- |
| `pairings/{código}` | cria e apaga os seus | lê um código e o marca como usado, uma vez | nada |
| `devices/{id}` | lê, renomeia, remove | lê e atualiza só `lastSeen` | nada |
| `devices/{id}/apps/*` | lê, limpa ao remover | escreve (só no próprio aparelho) | nada |
| `devices/{id}/rules/*` | lê e escreve (limite de 0 a 1440 min) | só lê | nada |

Os 30 testes em `firebase/tests/rules.test.mjs` cobrem cada linha dessa tabela, incluindo as tentativas de burla (reusar código, código expirado, apontar para outro responsável, escrever regra pelo aparelho do filho).

## Lista de apps instalados

- **Android**: um canal de plataforma (`MainActivity.kt`) consulta o `PackageManager` por apps com ícone de lançamento, os mesmos do menu do celular. Usa `<queries>` no manifesto e dispensa a permissão `QUERY_ALL_PACKAGES`, que a Google Play restringe.
- **Windows**: o app lê as chaves "Uninstall" do registro por PowerShell e descarta atualizações e redistribuíveis. O executável vem do `DisplayIcon` quando existe, e será a base para medir o uso de cada programa.

A sincronização roda ao abrir o app e a cada 6 horas e só grava o que mudou. Um sinal de vida (`lastSeen`) é enviado a cada 10 minutos.

## Decisões e limites conhecidos

- **Login anônimo no filho**: a criança não precisa de senha, mas o aparelho só ganha acesso depois de usar um código válido.
- **Windows**: o Firebase usa a configuração de um app web; está documentado em `CONFIGURAR-FIREBASE.md`.
- **Ícones dos apps** não são enviados (pesariam no Firestore). O app do responsável mostra a letra inicial colorida.
- **Segurança do aparelho do filho**: nada impede ainda que a criança desinstale o app. No Android isso vai exigir o administrador do dispositivo no próximo marco.
- **Tempo restante**: o app do filho já calcula `limite - usado`, mas o "usado" é zero até a medição de uso existir.
