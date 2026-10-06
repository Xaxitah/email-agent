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

## Resumos com DeepSeek

A IA é opcional. Sem uma chave, o bot produz um resumo determinístico local. Para usar a DeepSeek:

```env
AI_PROVIDER=deepseek
DEEPSEEK_API_KEY=sua-chave
DEEPSEEK_MODEL=deepseek-v4-flash
```

Por padrão, a IA recebe somente remetente, assunto, data e categorias. Para permitir que ela leia e resuma o conteúdo, habilite explicitamente:

```env
AI_INCLUDE_EMAIL_BODY=true
AI_EMAIL_BODY_MAX_CHARS=4000
```

O corpo é truncado por mensagem antes do envio. Ao habilitar essa opção, o conteúdo dos e-mails será transmitido à API da DeepSeek. Para testar apenas a conexão, sem acessar a caixa de entrada:

```powershell
ruby examples/test_deepseek.rb
```

`ANTHROPIC_API_KEY` e `ANTHROPIC_MODEL` continuam disponíveis como alternativa usando `AI_PROVIDER=anthropic`.

## Triagem nos relatórios agendados (fatia 6)

As leituras continuam às 05h/17h e os relatórios às 06h/18h. Somente os e-mails novos entram na triagem, em lotes de até 20 mensagens com até 1.500 caracteres de corpo por mensagem. Essa triagem e as perguntas sobre o relatório podem enviar esses trechos à IA mesmo com `AI_INCLUDE_EMAIL_BODY=false`; essa variável continua controlando o corpo nas demais consultas manuais.

O relatório mostra e-mails diretos, reuniões gerais, DIALAB, LIV e outros importantes, com motivo e prazo quando informado. Propaganda e outros informativos aparecem apenas como contagem. Os números `[n]` ficam na memória por 15 minutos para perguntas como “o que diz o 2?”. Se a IA falhar ou devolver JSON inválido, o Classifier preserva os avisos locais, inclusive urgências.

O perfil é lido de `config/douglas.json`, ou do caminho definido em `TRIAGE_PROFILE_PATH`. Ele contém o contexto docente consultado no Persona-Vault e as preferências confirmadas pelo Douglas: DIALAB pela sigla, LIV com termos de bem-estar em contexto escolar, reuniões das equipes e prioridade para coordenação/gestão. Os endereços `ACCOUNT_N_USER` são incorporados automaticamente, sem senhas nem aliases extras. Sem o arquivo, funciona a triagem genérica com os endereços das contas. Veja o [estado e a configuração da fatia 6](docs/FATIA_6.md).

Para ver um relatório com dados fictícios, sem acessar serviços externos:

```sh
bundle exec ruby examples/preview_triage_report.rb
```

## Comandos por audio no Telegram

O Railway pode transcrever mensagens de voz localmente com `whisper.cpp`; o audio nao e enviado a um servico externo de transcricao. O bot baixa o arquivo somente depois de validar o `TELEGRAM_CHAT_ID`, converte-o com FFmpeg, transcreve em portugues e usa o texto resultante como comando.

```env
VOICE_TRANSCRIPTION_ENABLED=true
VOICE_LANGUAGE=pt
VOICE_MAX_SECONDS=120
VOICE_MAX_BYTES=8388608
VOICE_TRANSCRIPTION_TIMEOUT=180
WHISPER_THREADS=2
```

O build instala `whisper.cpp` v1.9.1 e o modelo multilíngue `base`. Audios maiores que 2 minutos ou 8 MB sao recusados antes do processamento. Os arquivos temporarios sao apagados ao final de cada transcricao.

## Railway

1. Crie um projeto a partir deste repositório GitHub.
2. Cadastre as variáveis acima em **Variables**; não envie `.env`.
3. O comando de início já está definido em `railway.toml`.
4. Verifique nos logs as mensagens de inicialização da IA, do audio e das contas.
5. Envie uma mensagem ao bot e confirme que apenas o `TELEGRAM_CHAT_ID` autorizado recebe resposta.

Se o bot consultar apenas uma caixa, confira se `ACCOUNT_COUNT` corresponde à quantidade de blocos `ACCOUNT_N_*` cadastrados. Na inicialização, o log lista os nomes de todas as contas carregadas.

O processo usa long polling e deve ser implantado como worker, sem domínio público.

## Verificação

```powershell
bundle exec rspec
bundle exec standardrb
```

Antes da implantação, revogue qualquer token ou senha que já tenha sido publicado, compartilhado em conversa ou incluído em commit.
