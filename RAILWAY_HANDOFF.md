# Railway handoff

Atualizado em 2026-08-15.

## Contexto

- Projeto Railway: `successful-miracle`
- Ambiente: `production`
- Servico: `email-agent`
- Repositorio/fonte: `Xaxitah/email-agent`, branch `main`
- Nenhum segredo esta registrado neste documento.

## Estado atual

- Deployment ativo: `473c5aad-0e47-4843-8917-afd800f5db5d` (`SUCCESS`).
- `ACCOUNT_COUNT=4`; `ACCOUNT_1_*` ate `ACCOUNT_4_*` possuem nome, host, usuario e senha.
- A suite roda como pre-deploy e passou com `21 examples, 0 failures`.
- A integracao DeepSeek esta implantada com modelo `deepseek-v4-flash` e leitura do corpo habilitada com limite de 4.000 caracteres por mensagem.
- `DEEPSEEK_API_KEY` esta configurada nas variaveis protegidas do Railway; o valor nao e armazenado no repositorio.
- Mensagens de voz estao habilitadas com `whisper.cpp` v1.9.1 e o modelo multilingue `base`, processados localmente no Railway.
- Audios sao limitados a 120 segundos e 8 MB; somente o `TELEGRAM_CHAT_ID` autorizado pode iniciar o download e a transcricao.
- O agendador economico roda dentro do mesmo servico: leituras silenciosas as 05h e 17h, com relatorios de novos emails as 06h e 18h no fuso `America/Asuncion`.
- O estado idempotente do agendador fica em `/data/scheduler-state.json` no volume persistente Railway.
- O workspace avisa ao atingir US$ 5 de computacao e interrompe os servicos ao atingir US$ 10, os menores valores aceitos atualmente pelo Railway.

## Diagnosticos resolvidos

1. O deployment `7ce9e11f-b9c4-49c4-abc8-55bfb3bbb7e1` reutilizou o commit antigo `e810d43` e terminou em `CRASHED`. Esse commit tinha `lib/email_agent/telegram_bot.rb` truncado na linha 146.
2. O redeploy com `--from-source` usou o commit correto `a1a54a7`, deployment `cf46fa8e-4fdd-4ef5-b231-d36241675b72`, mas terminou em `FAILED` durante o build.
3. Causa do segundo erro: o builder legado Nixpacks executou `bundle install` antes de copiar `email_agent.gemspec`, gerando `There are no gemspecs at /app`.

## Correcoes implantadas

- `railway.toml` usa Railpack e executa RSpec antes de ativar um deployment.
- `railpack.json` copia o gemspec e a versao antes de `bundle install`.
- O bot carrega dinamicamente todas as contas configuradas e mostra seus nomes no log de inicializacao.
- DeepSeek e Anthropic usam um cliente unico; sem chave, ha fallback para o resumo local.
- FFmpeg, `whisper-cli`, o modelo `ggml-base.bin` e suas bibliotecas sao verificados antes de ativar cada deployment.

## Proximo passo

1. Confirmar que o deployment iniciado pelo GitHub passa com a variavel protegida da DeepSeek.
2. Enviar ao bot: `resuma os emails de todas as contas`.
3. Enviar uma mensagem de voz ao bot, por exemplo: `resuma os emails urgentes de todas as contas`.
