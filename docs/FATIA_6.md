# Fatia 6 — triagem nos relatórios agendados

Implementação enviada ao `main`, com publicação no Railway autorizada pelo Douglas em 06/10/2026. O envio ao `main` aciona o deploy; RSpec e a verificação do Whisper executam na construção da imagem final e precisam passar antes de ativar a versão.

As leituras permanecem às 05h/17h, com envio às 06h/18h. `Scheduler#keep_only_new` precede a triagem: mensagens já vistas não são reenviadas à IA. Cada lote contém no máximo 20 mensagens, com remetente, To/Cc, assunto, data, sinais determinísticos e até 1.500 caracteres do corpo.

O JSON exige exatamente `n`, `tipo`, `importancia`, `motivo` e `prazo` por mensagem. Números ausentes, repetidos ou fora do lote, tipos desconhecidos, valores malformados e falhas da API fazem o lote usar o Classifier local. Um prazo urgente não é ocultado pelo sinal Gmail no fallback.

O Reader preserva `to`, `cc` e `reply_to`. Categorias promotions/social são consultadas somente em `imap.gmail.com` quando o servidor anuncia `X-GM-EXT-1`. As duas buscas precisam funcionar; falhas descartam o sinal parcial. `List-Unsubscribe` sozinho não implica propaganda. IMAP continua usando `EXAMINE` e `BODY.PEEK[]`.

O relatório mostra, nesta ordem, direto para você, reunião geral, DIALAB, LIV e outros com importância >= 2. Motivo e prazo/data são escapados para HTML. Propaganda e outros informativos entram apenas na contagem. Relatórios longos são divididos sem cortar entradas ou tags.

Após o envio bem-sucedido, só os e-mails exibidos entram na ConversationMemory, por 15 minutos, com os mesmos números do relatório. Uma leitura nova remove os números antigos de todas as contas em cache. O estado já usado pelo Scheduler guarda cabeçalhos e triagem como objetos JSON; não foi criado armazenamento adicional de conteúdo de e-mail.

## Perfil configurado

`config/douglas.json` contém as respostas do Douglas e o contexto profissional consultado no Persona-Vault local (`E:\Work\Obsidian Claud\Persona-Vault`). Não há aliases adicionais nem uma lista inventada de endereços prioritários: `addresses` e `important_senders` ficam vazios, e os endereços das contas são incorporados em runtime.

O contexto docente usa `_ESTADO_ATUAL.md`, `Semanas/2026-W41.md`, `01-Turmas/_Turmas.md`, `01-Turmas/_Pasta-Professor.md` e `01-Turmas/IFMS/Comunicacao-Tecnica/estado-da-disciplina.md` do vault. IFMS: Química 2, Química Analítica e Comunicação Técnica; Elite: Ciências, Biologia, DIALAB e LIV; Estado-MS: Química nas escolas Geni e Pedro Afonso. A ementa de Linguagem de IA está pendente no vault e não foi usada para presumir uma disciplina atual.

- DIALAB: a sigla é o marcador principal confirmado pelo Douglas. Sugestões auxiliares: trilhas, formação docente, guia do professor e letramento em IA; sozinhas não classificam a mensagem como DIALAB.
- LIV: Laboratório de Inteligência de Vida. Além da sigla/nome, aceita bem-estar, saúde mental e cuidados com contexto escolar. Termos genéricos de saúde em promotions/social não ativam essa regra contextual.
- Reuniões gerais: professores, coordenação e escola inteira, incluindo encontros pedagógicos.
- Remetentes: coordenação/gestão/direção têm prioridade pelo nome do remetente ou local-part do endereço. Uma simples menção no corpo ou no domínio não identifica um gestor. O nome do remetente é preservado pelo Reader e enviado à IA.
- Urgência: responder hoje, prazo próximo, convocação e alteração/mudança de horário. Sinais específicos do perfil elevam importância a 3; remetentes prioritários elevam a pelo menos 2. A IA pode manter propaganda como propaganda, sem promover anúncios por esses termos.
- Propaganda: ocultar anúncios e newsletters comerciais, sem exceções solicitadas. O fallback continua conservador para não perder urgências detectadas pelo Classifier.

O arquivo, sem credenciais, é um objeto JSON com estes campos:

| Campo | Conteúdo |
|---|---|
| `name` / `context` | Quem é o Douglas e seu contexto de trabalho |
| `schools` | IFMS, Rede Elite e Estado-MS |
| `addresses` | Aliases opcionais; as contas configuradas já são incorporadas |
| `important_senders` | Endereços completos dos remetentes prioritários |
| `important_roles` | Coordenação, gestão, direção e nomes desses cargos |
| `urgent_keywords` / `preferences` | Critérios de urgência e preferências confirmadas |
| `topics.dialab` / `topics.liv` / `topics.reuniao_geral` | Descrição, palavras fortes e, para LIV, palavras/contexto escolar |

É possível definir outro caminho com `TRIAGE_PROFILE_PATH`. Perfil ausente ou JSON inválido preserva os endereços das contas e o funcionamento do bot.

## Verificação e publicação

RSpec deve rodar com Docker `ruby:3.4.7` na B11, conforme `PROXIMOS_PASSOS.md`. A verificação cobre sinais, falhas/validação do JSON, limites dos lotes, persistência após reinício, HTML, tamanho de mensagens e a referência ao mesmo e-mail entre relatório e conversa.

Verificado em 06/10/2026 na B11, após configurar o perfil: **121 exemplos, 0 falhas** com `bundle exec rspec`; `bundle exec standardrb` nos 17 arquivos Ruby alterados terminou sem infrações.

`bundle exec ruby examples/preview_triage_report.rb` imprime um relatório com dados fictícios e todos os tipos, sem acessar IA, Gmail ou Telegram. As buscas Gmail são verificadas com doubles nos specs e pela confirmação de suporte em runtime; ainda falta observar um relatório com Gmail e DeepSeek reais.

Para publicar, a especificação exige testes verdes e OK do Douglas antes de juntar ao `main`, que dispara o deploy do Railway. A fatia 7 (busca de mensagens lidas/antigas) continua fora deste trabalho.

O contêiner de pré-publicação do Railway recusou a criação por esperar `/data`, mesmo com o volume existente vinculado e pronto. As verificações passaram para o estágio final do Dockerfile; nenhum teste foi dispensado. O volume de produção e o estado do agendador permanecem no serviço.
