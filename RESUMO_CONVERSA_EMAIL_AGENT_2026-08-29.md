# Resumo da conversa — Email Agent

Data do registro: 29/08/2026  
Projeto local: `E:\Work\Obsidian Claud\email-agent`  
Repositorio: `https://github.com/Xaxitah/email-agent`

## Objetivo geral

Construir um agente pessoal que consulte quatro contas de email, produza resumos com IA, aceite comandos de texto ou audio pelo Telegram e, futuramente, sugira e confirme compromissos antes de grava-los em uma agenda secundaria da conta Google `douglas-bughi`.

## Decisoes de arquitetura

- Usar um unico bot do Telegram, com roteamento interno entre `EmailAgent` e o futuro `CalendarAgent`.
- Manter um unico servico no Railway para reduzir consumo.
- Executar o agendador dentro do processo do bot, sem Postgres e sem servicos Cron adicionais.
- Guardar o estado do agendador em um volume persistente montado em `/data`.
- Nunca armazenar chaves, senhas ou tokens no GitHub ou em documentos do projeto.
- Pedir confirmacao no Telegram antes de criar compromissos no Google Calendar.

## Funcionalidades implementadas

### Email e Telegram

- Quatro contas de email configuradas por variaveis protegidas no Railway.
- Consulta IMAP em modo somente leitura, usando `EXAMINE` e `BODY.PEEK[]`, sem marcar mensagens como lidas.
- Classificacao de mensagens e identificacao de urgencias.
- Resumos manuais pelo Telegram, com selecao de uma conta ou de todas as contas.
- Restricao do bot ao `TELEGRAM_CHAT_ID` autorizado.
- Transcricao local de mensagens de voz com `whisper.cpp`, sem enviar audio a um provedor externo.

### DeepSeek

- Cliente da API DeepSeek integrado ao bot.
- Modelo configurado: `deepseek-v4-flash`.
- A chave `DEEPSEEK_API_KEY` foi cadastrada como variavel protegida no Railway; seu valor nao esta no repositorio.
- Teste real concluido com a resposta: `DeepSeek conectado com sucesso.`
- O envio do corpo dos emails para a IA pode ser controlado por `AI_INCLUDE_EMAIL_BODY` e limitado por `AI_EMAIL_BODY_MAX_CHARS`.
- O prompt trata o conteudo dos emails como dado nao confiavel e instrui a IA a ignorar comandos encontrados dentro das mensagens.

### Relatorios programados

- Fuso horario: `America/Asuncion`.
- Leituras silenciosas: 05h e 17h.
- Relatorios no Telegram: 06h e 18h.
- Limite de leitura programada: ate 200 mensagens por conta em cada verificacao.
- Janela de recuperacao apos reinicio: 180 minutos.
- O estado persistente identifica emails ja processados e evita relatorios duplicados.
- Nas consultas programadas, alertas urgentes separados ficam desabilitados para que o bot envie apenas o relatorio no horario definido.

## Railway

- Projeto: `successful-miracle`.
- Ambiente: `production`.
- Servico: `email-agent`.
- Uma replica ativa.
- Volume: `email-agent-volume`, montado em `/data`.
- Ultimo deployment confirmado nesta conversa: `08138137-f41e-4151-a0e8-39ae0d5fe632`, com status `SUCCESS` e instancia `RUNNING`.
- O build foi migrado de Railpack para `Dockerfile`, evitando uma falha do mecanismo de build-secrets ao adicionar a chave da DeepSeek.
- A imagem usa build em duas etapas: compiladores ficam somente na etapa de construcao, mantendo a imagem final menor.
- A verificacao anterior passou com 21 testes e validacao do Whisper.

## Custos e protecoes

- Plano Railway Hobby: US$ 5 mensais, incluindo US$ 5 de consumo.
- Estimativa inicial para uso pessoal: aproximadamente US$ 0,40 a US$ 1,00 por mes de recursos, sem garantia, pois depende do volume de emails e audios.
- Alerta de consumo do workspace configurado em US$ 5.
- Limite rigido configurado em US$ 10, menor valor aceito pelo Railway para esse tipo de limite.
- A DeepSeek e cobrada separadamente conforme os tokens utilizados.
- Google Calendar e Tasks devem permanecer dentro das cotas gratuitas para esse volume pessoal.

## GitHub

- Alteracoes principais sincronizadas com a branch `main`.
- Commit de funcionalidades: `15d0e3c` — IA, voz, seguranca e relatorios programados.
- Commit de migracao para Docker: `bc68dda`.
- Commit de correcao do build Docker: `36a0990`.
- Nenhuma credencial real foi incluida nos commits.

## Problema identificado no CalendarAgent

Ao receber o pedido:

> pode adicionar a minha agenda por favor os dois cafe pedagogicos com 2 lembretes cada, um no domingo e outro pela manha do dia do evento as 11h

o bot perguntou qual conta de email deveria consultar. Isso ocorreu porque o codigo implantado ainda encaminha todas as mensagens para o fluxo do `EmailAgent`; o roteador e o `CalendarAgent` ainda nao foram implementados.

## Decisao sobre autenticacao Google

Uma API key comum do Google nao e suficiente para criar ou editar eventos privados. O caminho escolhido e OAuth 2.0 com acesso offline, conectado a conta `douglas-bughi`.

Variaveis previstas no Railway:

```text
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
GOOGLE_REFRESH_TOKEN
GOOGLE_CALENDAR_ID
```

Esses valores devem permanecer somente nas variaveis protegidas do Railway e nunca devem ser enviados por chat ou adicionados ao GitHub.

## Proximos passos

1. Implementar o roteador de intencoes para distinguir comandos de email, agenda e tarefas.
2. Configurar OAuth 2.0 do Google Calendar com permissao minima e acesso offline.
3. Criar uma agenda secundaria na conta `douglas-bughi` e guardar seu identificador em `GOOGLE_CALENDAR_ID`.
4. Fazer o bot procurar nos emails os dados dos dois cafes pedagogicos.
5. Exibir no Telegram titulo, data, horario, local e lembretes propostos.
6. Criar os eventos apenas depois da confirmacao explicita do usuario.
7. Adicionar suporte a tarefas e atualizacoes recebidas por email ou Telegram.

## Observacao de seguranca

Este documento registra somente nomes de variaveis, identificadores tecnicos e decisoes de arquitetura. Ele nao contem senhas de email, token do Telegram, chave da DeepSeek nem credenciais OAuth do Google.
