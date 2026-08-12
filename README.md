# Email Agent

Worker Ruby somente leitura para consultar mensagens não lidas via IMAP e responder pelo Telegram. O agente não marca, apaga, move nem responde e-mails.

## Requisitos

- Ruby 3.1 ou superior
- Bundler
- Bot do Telegram
- Senha de aplicativo ou credencial IMAP específica; nunca use a senha principal

## Configuração local

```powershell
Copy-Item .env.example .env
bundle install
ruby examples/test_run.rb
ruby examples/bot_run.rb
```

Preencha `.env` localmente. Esse arquivo é ignorado pelo Git. Para múltiplas contas, aumente `ACCOUNT_COUNT` e repita `ACCOUNT_2_*`, `ACCOUNT_3_*` etc.

Variáveis obrigatórias:

- `ACCOUNT_COUNT`
- `ACCOUNT_N_NAME`, `ACCOUNT_N_HOST`, `ACCOUNT_N_PORT`
- `ACCOUNT_N_USER`, `ACCOUNT_N_PASSWORD`
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

`ANTHROPIC_API_KEY` é opcional. Sem ela, o bot produz um resumo determinístico local. Com ela, envia somente remetente, assunto, data e categorias para geração do resumo; o corpo do e-mail não é enviado.

## Railway

1. Crie um projeto a partir deste repositório GitHub.
2. Cadastre as variáveis acima em **Variables**; não envie `.env`.
3. O comando de início já está definido em `railway.toml`.
4. Verifique nos logs a mensagem de inicialização do bot.
5. Envie uma mensagem ao bot e confirme que apenas o `TELEGRAM_CHAT_ID` autorizado recebe resposta.

O processo usa long polling e deve ser implantado como worker, sem domínio público.

## Verificação

```powershell
bundle exec rspec
bundle exec standardrb
```

Antes da implantação, revogue qualquer token ou senha que já tenha sido publicado, compartilhado em conversa ou incluído em commit.
