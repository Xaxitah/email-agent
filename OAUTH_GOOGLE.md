# OAuth do Google para o CalendarAgent

Passo a passo para obter `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`,
`GOOGLE_REFRESH_TOKEN` e `GOOGLE_CALENDAR_ID`.

Este documento nao contem nenhuma credencial e nunca deve conter.

---

## Antes de comecar: duas decisoes que ja estao tomadas

**Conta:** use `douglasbughi@gmail.com`.
As contas `ifms.edu.br` e `ensinoelite.com.br` sao Google Workspace, e o
administrador da instituicao pode bloquear apps de terceiros nao verificados.
Numa conta pessoal ninguem pode barrar voce.

**Escopo: somente `calendar.events`.**
Nao adicione nenhum escopo do Gmail neste projeto. `calendar.events` e um
escopo *sensivel*; qualquer escopo do Gmail (`gmail.modify` e afins) e
*restrito*, e escopo restrito exige auditoria de seguranca de terceiro para
publicar — inviavel para uso pessoal.

A rotulagem de e-mail **nao precisa de OAuth**: o IMAP do Gmail suporta a
extensao `X-GM-LABELS` com as credenciais que o agente ja usa.

---

## 1. Google Cloud Console

Em <https://console.cloud.google.com>, logado como `douglasbughi@gmail.com`:

1. **Criar projeto** — nome sugerido: `email-agent`

2. **APIs e Servicos → Biblioteca** → buscar **"Google Calendar API"** → **Ativar**

3. **APIs e Servicos → Tela de consentimento OAuth**
   - Tipo de usuario: **Externo**
   - Nome do app, e-mail de suporte e e-mail de contato do desenvolvedor

4. **Escopos** → *Adicionar ou remover escopos* → adicionar manualmente:

   ```
   https://www.googleapis.com/auth/calendar.events
   ```

   Somente esse.

5. **Publicar o app → "Em producao"**

   > **Este passo nao pode ser pulado.** Um app em status *"Testing"* recebe
   > refresh token que **expira em 7 dias** — o agente pararia toda semana
   > pedindo novo consentimento. Publicar sem verificacao e normal para app
   > pessoal: voce vera um aviso uma unica vez na tela de consentimento.

6. **Credenciais → Criar credenciais → ID do cliente OAuth**
   - Tipo de aplicativo: **App para computador**
   - Copie o **Client ID** e o **Client Secret**

---

## 2. Google Agenda

Crie uma **agenda secundaria** — sugestao de nome: `Agente`.

Nunca aponte o agente para a agenda principal. Se algo der errado, o dano
fica confinado a uma agenda descartavel.

---

## 3. Rodar o script

O script vive em `examples/google_oauth_setup.rb`.

O Google so aceita `127.0.0.1` como redirecionamento de app Desktop. Como o
script roda na box e o navegador esta no PC, um tunel SSH liga os dois.

**Terminal 1 — abrir o tunel e entrar na box:**

```bash
ssh -i ~/.ssh/tvbox-armbian.key -L 8765:127.0.0.1:8765 root@192.168.0.147
```

**Dentro dessa sessao:**

```bash
export GOOGLE_CLIENT_ID="cole-aqui.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="cole-aqui"
export OAUTH_PORT=8765
cd /opt/email-agent && ruby examples/google_oauth_setup.rb
```

O script imprime uma URL. Abra no navegador do PC e autorize.

Se aparecer *"O Google nao verificou este app"*, clique em **Avancado** e
depois em **Acessar (nao seguro)**. E esperado: voce e o autor e o unico
usuario.

Ao final ele imprime:

- `GOOGLE_REFRESH_TOKEN=...`
- a lista das suas agendas com os respectivos `GOOGLE_CALENDAR_ID`

---

## 4. Guardar as variaveis

Nas variaveis protegidas do ambiente — Railway hoje, `.env` com permissao
`600` quando migrar para a box:

```
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
GOOGLE_REFRESH_TOKEN
GOOGLE_CALENDAR_ID
```

Nunca no GitHub, nunca em documento, nunca em chat.

---

## Armadilhas conhecidas

| Sintoma | Causa | Solucao |
|---|---|---|
| Token para de funcionar depois de ~7 dias | App ficou em *"Testing"* | Publicar em *"Em producao"* |
| Veio `access_token` mas nao `refresh_token` | Ja existia consentimento ativo | Revogar em <https://myaccount.google.com/permissions> e rodar de novo |
| `redirect_uri_mismatch` | Cliente criado como *Web* em vez de *Desktop* | Recriar como **App para computador** |
| Navegador nao abre o `127.0.0.1:8765` | Tunel SSH nao esta ativo | Conferir o `-L 8765:127.0.0.1:8765` |
| Pedem auditoria de seguranca | Algum escopo do Gmail entrou no projeto | Remover; manter so `calendar.events` |

O script ja cuida de dois detalhes que costumam morder quem faz na mao: envia
`access_type=offline` **junto com** `prompt=consent` (sem os dois o Google nao
devolve refresh token) e valida o parametro `state` no redirecionamento.
