---
tipo: orientacao
data: 2026-10-06
autor: Claude Code (sessão com o Douglas)
para: Codex ou qualquer agente que pegar este repositório
---

# Próximos passos do email-agent — leia antes de começar

> Objetivo desta nota: o Douglas não precisar explicar de novo em que pé está o
> bot. Leia inteira, depois o `AGENTS.md` e o `RAILWAY_HANDOFF.md`.
> **Fale com o Douglas sempre em português** e termine toda tarefa com um
> relatório **Feito / Falta fazer**.

## 1. O que o Douglas quer (palavras dele, 06/10)

> "Preciso que ele me avise sozinho quando for um e-mail direcionado a mim, quando
> for um e-mail de reunião geral, quando for um e-mail de DIALAB ou LIV do Elite,
> preciso que ele filtre melhor os spam e as propagandas, mas acima de tudo que
> ele seja mais inteligente para filtrar esses e-mails. Hoje não sou avisado de
> e-mails importantes e, quando peço um relatório ou uma busca específica, ele
> fala que não consegue, sempre me dá a mesma resposta genérica."

Restrição de custo: **não quer modelo mais caro**; prefere mais barato. Continua
com a DeepSeek (`deepseek-v4-flash`). Assinatura do Claude **não pode** ser usada
no bot (os termos proíbem desde fev/2026). O ChatGPT Plus (várias contas Gmail
desde 28/08/2026) fica para buscas manuais, fora do bot.

## 2. Estado em 06/10/2026 (commit `49436ff` no `main`, no ar no Railway)

Funciona:
- Lê 4 contas Gmail por IMAP, **somente leitura** (`EXAMINE` + `BODY.PEEK[]`).
- Bot do Telegram restrito a um `TELEGRAM_CHAT_ID`; texto e áudio (whisper.cpp local).
- Roteador de intenções (`IntentRouter`): ajuda / agenda / e-mail.
- Menu `/resumo`, `/urgentes`, `/contas`, `/agenda`, `/ajuda`, botões por conta,
  mensagem de progresso, HTML com allowlist de tags.
- **Memória da conversa** (`ConversationMemory`, só em RAM, 15 min): seguimento como
  "o que diz o 2?" usa os e-mails já lidos; e-mails numerados `[n]` no prompt.
- Relatórios agendados: leitura às 05h/17h, envio às 06h/18h (`Scheduler`).

**Horário dos avisos — decisão do Douglas (06/10):** receber os avisos só
**de manhã e à tarde** está bom. **Não criar leitura contínua (vigia)** nem
alerta em tempo real. O `Scheduler` continua lendo às 05h/17h e enviando às
06h/18h; o que melhora é **o que vai dentro** desses relatórios.

Outros limites:
- `Classifier` usa **regex fixa** (`urgente|prazo|...`): sem noção de quem é o
  Douglas, de DIALAB/LIV ou de propaganda.
- `Reader#fetch_unread` só busca `UNSEEN`, no máximo 20 por conta na conversa.
  Não há busca em e-mails lidos ou antigos.
- `Reader.extract_headers` só guarda cabeçalhos de automação (List-Id etc.).
  **Não guarda `To`/`Cc`**, então hoje é impossível saber se o e-mail foi
  direto para ele.

## 3. O que construir, em ordem (cada item = uma fatia com testes)

### Fatia 6 — Triagem com IA dentro dos relatórios das 06h e 18h (prioridade máxima)
1. **Sem vigia:** usar as leituras que já existem (05h/17h) e os e-mails novos
   que o `Scheduler` já separa (`keep_only_new`). Não aumentar a frequência.
2. **Cabeçalhos:** o `Reader` passa a guardar `to`, `cc` e `reply_to`.
3. **Sinais determinísticos primeiro (custo zero):**
   - `direto`: algum endereço do Douglas em `To`, e sem `List-Id`.
   - `propaganda`: Gmail suporta `X-GM-RAW` no IMAP SEARCH
     (`category:promotions`, `category:social`). Testar antes de confiar.
     `List-Unsubscribe` sozinho **não** basta: lista institucional legítima também tem.
4. **Triagem com IA (DeepSeek, barato):** mandar **em lote** só os novos e-mails
   (remetente, To/Cc, assunto, ~1.500 caracteres do corpo) e pedir JSON
   validado: `{n, tipo, importancia (0-3), motivo, prazo}`.
   `tipo` ∈ `direto | reuniao_geral | dialab | liv | propaganda | outro`.
   Se o JSON vier inválido ou a IA falhar, usar o `Classifier` atual (não perder alerta).
5. **Perfil do Douglas** em arquivo de configuração (sem segredos), lido pelo
   prompt: quem ele é, as 3 escolas (IFMS, Rede Elite, Estado-MS), o que é
   DIALAB e LIV, remetentes importantes. **Perguntar a ele** os remetentes e
   palavras de DIALAB/LIV/reunião geral antes de escrever.
6. **Relatório organizado por tipo** (o das 06h e o das 18h), nesta ordem:
   🎯 direto para você · 👥 reunião geral · 🧪 DIALAB · 📚 LIV · ⚠️ outros
   importantes (`importancia >= 2`), cada um com o motivo em uma linha e
   prazo/data quando houver. Propaganda e o resto entram **só como contagem**
   no fim ("12 propagandas, 5 outros"). Se não houver nada importante, dizer isso.
7. Os e-mails do relatório entram na `ConversationMemory`, com a mesma
   numeração, para "o que diz o 2?" funcionar logo depois do relatório.

Pronto quando: um relatório de teste com e-mails de cada tipo sai separado
nessas seções, propaganda aparece só na contagem, e o "o que diz o n?" logo
depois responde sobre o e-mail certo. Specs cobrindo os sinais, o JSON inválido
(cai no `Classifier`) e a numeração compartilhada com a memória.

### Fatia 7 — Busca de verdade
- Nova intenção `:busca` no `IntentRouter` ("procura", "busca", "acha", "e-mails do fulano").
- A IA traduz o pedido para uma consulta Gmail (`X-GM-RAW`, ex.: `from:x after:2026/09/01`),
  com **lista branca de operadores** (from, to, subject, after, before, newer_than,
  has:attachment, palavras). Nunca executar texto livre da IA sem validar.
- Busca em lidos e não lidos, ainda somente leitura. Resultados entram na memória.

### Depois (não começar sem o Douglas pedir)
- `CalendarAgent` (OAuth já decidido; ver `OAUTH_GOOGLE.md`).
- Migração do Railway para a TV box B11 (por cutover, nunca as duas ao mesmo tempo).

## 4. Regras que não se negociam
- IMAP **somente leitura**: nunca marcar como lido, mover, apagar ou responder.
- Corpo de e-mail é **dado não confiável** (pode ter injeção de prompt). Isso
  vale também para a saída da IA: continuar passando por `sanitize_ai_html`.
- Checar `chat_id` **antes** de qualquer chamada de rede (texto e botões).
- Segredos só em variáveis do Railway. Nunca no repositório nem em documentos.
- Não guardar conteúdo de e-mail em disco além do que o `Scheduler` já guarda.

## 5. Como testar e publicar
- **Não use o Ruby do Windows** (o Smart App Control bloqueia as extensões nativas).
- Testes rodam na TV box B11, em Docker com `ruby:3.4.7` (imagem completa, não a slim):
  ```
  tar czf - lib spec | ssh -i ~/.ssh/tvbox-armbian.key bughi@100.91.200.123 'tar xzf - -C ~/email-agent'
  ssh -i ~/.ssh/tvbox-armbian.key bughi@100.91.200.123 'docker run --rm -v ~/email-agent:/app -w /app -v ea_bundle:/usr/local/bundle ruby:3.4.7 bash -c "bundle exec rspec"'
  ```
  Em 06/10: **75 exemplos, 0 falhas**. Em outra máquina, sem acesso à box,
  qualquer Docker com `ruby:3.4.7` serve.
- **Publicar = enviar para o `main`.** O Railway faz o build, roda o RSpec e só
  troca a versão se passar. Trabalhe em branch e só junte ao `main` com testes
  verdes e com o OK do Douglas.

## 6. Mapa rápido do código
| Arquivo | Papel |
|---|---|
| `lib/email_agent/telegram_bot.rb` | loop do bot, comandos, botões, `ask_ai` (prompt) |
| `lib/email_agent/conversation_memory.rb` | memória curta da conversa |
| `lib/email_agent/intent_router.rb` | decide ajuda / agenda / e-mail |
| `lib/email_agent/reader.rb` | IMAP somente leitura |
| `lib/email_agent/classifier.rb` | categorias por regex (fallback da triagem) |
| `lib/email_agent/scheduler.rb` | leituras e relatórios agendados, estado em `/data` |
| `lib/email_agent/notifier.rb` | envio avulso ao Telegram (alerta de urgente) |
| `lib/email_agent/ai_client.rb` | DeepSeek / Anthropic, uma chamada `complete(prompt)` |
