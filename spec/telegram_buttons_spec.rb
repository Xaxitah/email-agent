# frozen_string_literal: true

require_relative "spec_helper"

# Fatia 3 — roteador de intencoes e botoes inline.
#
# O caso que originou esta fatia: "pode adicionar a minha agenda os dois cafes
# pedagogicos" ia parar no leitor de IMAP, e o bot respondia perguntando qual
# conta de e-mail consultar. Os testes abaixo travam o caminho certo.
RSpec.describe EmailAgent::IntentRouter do
  it "manda para a agenda o pedido que quebrou em producao" do
    texto = "pode adicionar a minha agenda por favor os dois cafe pedagogicos com 2 lembretes cada"

    expect(described_class.route(texto)).to eq(:agenda)
  end

  it "mantem no e-mail um pedido que apenas fala de reuniao" do
    expect(described_class.route("resuma os emails sobre a reuniao de sexta")).to eq(:email)
  end

  it "ignora acento, porque no Telegram se digita sem" do
    expect(described_class.route("marque uma reunião amanhã")).to eq(:agenda)
    expect(described_class.route("marque uma reuniao amanha")).to eq(:agenda)
  end

  it "reconhece consulta sobre compromissos ja marcados" do
    expect(described_class.route("o que eu tenho amanhã")).to eq(:agenda)
    expect(described_class.route("quais meus compromissos")).to eq(:agenda)
  end

  it "trata comando de barra como ajuda" do
    expect(described_class.route("/menu")).to eq(:ajuda)
    expect(described_class.route("/start")).to eq(:ajuda)
  end

  it "cai no e-mail por padrao, para nao regredir o que ja funcionava" do
    expect(described_class.route("consulte todas")).to eq(:email)
    expect(described_class.route("tem algo urgente?")).to eq(:email)
  end

  it "nao deixa a preposicao 'por' fingir uma acao de agenda" do
    expect(described_class.route("por que a reuniao atrasou?")).to eq(:email)
  end
end

RSpec.describe "EmailAgent::TelegramBot botoes" do
  let(:manager) { instance_double(EmailAgent::Manager, account_names: ["Alpha Work", "Beta Personal"]) }
  let(:enviadas) { [] }

  def build_bot
    bot = EmailAgent::TelegramBot.allocate
    bot.instance_variable_set(:@chat_id, "123")
    bot.instance_variable_set(:@manager, manager)
    bot.instance_variable_set(:@ai_client, nil)
    bot.instance_variable_set(:@voice_transcriber, nil)
    allow(bot).to receive(:send_action)
    allow(bot).to receive(:answer_callback)
    allow(bot).to receive(:send_message) { |*args| enviadas << args; true }
    bot
  end

  def texto(chat_id, conteudo)
    {"message" => {"chat" => {"id" => chat_id}, "text" => conteudo}}
  end

  def botao(data, chat_id: 123)
    {"callback_query" => {"id" => "cb-1", "data" => data, "message" => {"chat" => {"id" => chat_id}}}}
  end

  def teclado(chamada)
    chamada[2][:inline_keyboard].flatten.map { |b| b[:callback_data] }
  end

  it "nao le e-mail nenhum quando o pedido e de agenda" do
    bot = build_bot
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, texto(123, "agende uma reuniao na quinta"))

    expect(enviadas.last[1]).to include("CalendarAgent ainda nao esta")
  end

  it "responde /menu com os tres botoes de acao" do
    bot = build_bot

    bot.send(:handle_update, texto(123, "/menu"))

    expect(teclado(enviadas.last)).to eq(["menu:resumo", "menu:urgentes", "menu:agenda"])
  end

  it "oferece um botao por conta mais 'todas' quando a conta e ambigua" do
    bot = build_bot
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, texto(123, "resuma meus emails"))

    expect(enviadas.last[1]).to include("Alpha Work", "Beta Personal")
    expect(teclado(enviadas.last)).to eq(["conta:0", "conta:1", "conta:todas"])
    expect(bot.instance_variable_get(:@pending_request)).to eq("resuma meus emails")
  end

  it "responde o pedido original quando o botao escolhe a conta" do
    bot = build_bot
    bot.instance_variable_set(:@pending_request, "tem algo urgente?")
    expect(manager).to receive(:check_all).with(limit: 20, account_names: ["Alpha Work"], notify_urgent: false).and_return({})

    bot.send(:handle_update, botao("conta:0"))

    expect(bot.instance_variable_get(:@pending_request)).to be_nil
  end

  it "usa todas as contas quando o botao e 'todas'" do
    bot = build_bot
    expect(manager).to receive(:check_all).with(limit: 20, account_names: nil, notify_urgent: false).and_return({})

    bot.send(:handle_update, botao("conta:todas"))
  end

  # Uma consulta manual devolve o resumo pedido e nada mais. Sem notify_urgent:
  # false o Manager dispararia tambem os alertas de urgente do Notifier —
  # mensagem duplicada no Telegram para o mesmo pedido.
  it "nao dispara alertas de urgente separados numa consulta manual" do
    bot = build_bot
    expect(manager).to receive(:check_all).with(hash_including(notify_urgent: false)).and_return({})

    bot.send(:handle_update, botao("conta:todas"))
  end

  it "ignora clique vindo de chat nao autorizado" do
    bot = build_bot
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, botao("conta:todas", chat_id: 999))

    expect(bot).not_to have_received(:answer_callback)
    expect(enviadas).to be_empty
  end

  it "nao le conta nenhuma com callback fora do formato esperado" do
    bot = build_bot
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, botao("conta:abc"))

    expect(enviadas.last[1]).to include("Nao reconheci")
  end

  it "recusa indice de conta que nao existe" do
    bot = build_bot
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, botao("conta:7"))

    expect(enviadas.last[1]).to include("nao existe mais")
  end

  it "manda o botao de resumo de volta pelo fluxo de e-mail" do
    bot = build_bot
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, botao("menu:resumo"))

    expect(bot.instance_variable_get(:@pending_request)).to include("Resuma")
    expect(teclado(enviadas.last)).to eq(["conta:0", "conta:1", "conta:todas"])
  end

  it "responde o botao de agenda com o aviso, sem tocar no IMAP" do
    bot = build_bot
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, botao("menu:agenda"))

    expect(enviadas.last[1]).to include("CalendarAgent ainda nao esta")
  end

  # Comandos de barra registrados em setMyCommands na inicializacao.
  it "registra o menu de comandos do Telegram na inicializacao" do
    bot = build_bot
    bot.instance_variable_set(:@token, "T0KEN")
    chamada = nil
    allow(Net::HTTP).to receive(:post_form) { |uri, form| chamada = [uri.to_s, form]; nil }

    bot.send(:set_my_commands)

    expect(chamada[0]).to end_with("botT0KEN/setMyCommands")
    nomes = JSON.parse(chamada[1][:commands]).map { |entry| entry["command"] }
    expect(nomes).to eq(%w[resumo urgentes contas agenda ajuda])
  end

  it "trata /resumo como pedido de resumo pelo fluxo de e-mail" do
    bot = build_bot
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, texto(123, "/resumo"))

    expect(bot.instance_variable_get(:@pending_request)).to eq("Resuma meus e-mails nao lidos.")
    expect(teclado(enviadas.last)).to eq(["conta:0", "conta:1", "conta:todas"])
  end

  it "trata /urgentes reaproveitando o alvo do botao inline" do
    bot = build_bot

    bot.send(:handle_update, texto(123, "/urgentes"))

    expect(bot.instance_variable_get(:@pending_request)).to eq("Liste apenas os e-mails urgentes.")
  end

  it "responde /contas com a lista de contas, sem tocar no IMAP" do
    bot = build_bot
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, texto(123, "/contas"))

    expect(enviadas.last[1]).to include("Alpha Work", "Beta Personal")
  end

  it "responde /agenda com o aviso do CalendarAgent, sem tocar no IMAP" do
    bot = build_bot
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, texto(123, "/agenda"))

    expect(enviadas.last[1]).to include("CalendarAgent ainda nao esta")
  end

  it "trata /ajuda com o menu de tres botoes" do
    bot = build_bot

    bot.send(:handle_update, texto(123, "/ajuda"))

    expect(teclado(enviadas.last)).to eq(["menu:resumo", "menu:urgentes", "menu:agenda"])
  end
end
