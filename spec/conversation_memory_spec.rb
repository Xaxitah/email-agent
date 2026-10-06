# frozen_string_literal: true

require_relative "spec_helper"

# Fatia 5 — memoria da conversa.
#
# O caso que originou esta fatia: depois de um resumo, "e o 3, o que diz?"
# voltava a perguntar qual conta ler e o bot respondia algo generico, porque
# cada mensagem era tratada como a primeira.
RSpec.describe EmailAgent::ConversationMemory do
  let(:agora) { [Time.at(1_000_000)] }
  let(:memoria) { described_class.new(ttl: 900, max_turns: 2, clock: -> { agora[0] }) }

  def passar(segundos)
    agora[0] += segundos
  end

  it "devolve as trocas recentes na ordem e esquece as mais antigas" do
    memoria.record_turn("um", "r1")
    memoria.record_turn("dois", "r2")
    memoria.record_turn("tres", "r3")

    expect(memoria.turns.map { |t| t[:pedido] }).to eq(%w[dois tres])
  end

  it "esquece a conversa depois do prazo" do
    memoria.record_turn("um", "r1")
    passar(901)

    expect(memoria.turns).to be_empty
  end

  it "guarda os e-mails por conta e devolve so as contas pedidas e frescas" do
    memoria.store_results("A" => {emails: [1], error: nil}, "B" => {emails: [2], error: nil})

    expect(memoria.cached_results(%w[B])).to eq("B" => {emails: [2], error: nil})
    passar(901)
    expect(memoria.cached_results(%w[A B])).to be_empty
  end

  it "nao guarda conta que deu erro, para que seja lida de novo" do
    memoria.store_results("A" => {emails: [], error: "timeout"})

    expect(memoria.cached_results(%w[A])).to be_empty
  end

  it "lembra as contas da ultima consulta enquanto ela esta fresca" do
    memoria.store_results("A" => {emails: [], error: nil})
    expect(memoria.last_accounts).to eq(%w[A])

    passar(901)
    expect(memoria.last_accounts).to be_nil
  end
end

RSpec.describe "EmailAgent::TelegramBot memoria da conversa" do
  let(:manager) { instance_double(EmailAgent::Manager, account_names: ["Alpha Work", "Beta Personal"]) }
  let(:ai) { instance_double(EmailAgent::AiClient) }
  let(:prompts) { [] }
  let(:resultado) do
    {"Alpha Work" => {emails: [{from: "x@a", subject: "Reuniao geral", date: "hoje", categories: [:geral]}], error: nil}}
  end

  def build_bot
    bot = EmailAgent::TelegramBot.allocate
    bot.instance_variable_set(:@chat_id, "123")
    bot.instance_variable_set(:@manager, manager)
    bot.instance_variable_set(:@ai_client, ai)
    bot.instance_variable_set(:@voice_transcriber, nil)
    allow(ai).to receive(:complete) do |prompt, **|
      prompts << prompt
      "resposta"
    end
    allow(bot).to receive(:send_action)
    allow(bot).to receive(:send_message).and_return(true)
    allow(bot).to receive(:send_message_with_id).and_return(1)
    allow(bot).to receive(:edit_message).and_return(true)
    bot
  end

  def texto(conteudo)
    {"message" => {"chat" => {"id" => 123}, "text" => conteudo}}
  end

  it "responde o seguimento sem perguntar a conta e sem reler o IMAP" do
    bot = build_bot
    expect(manager).to receive(:check_all).once.and_return(resultado)

    bot.send(:handle_update, texto("resuma os emails da alpha"))
    bot.send(:handle_update, texto("e o 1, o que diz?"))

    expect(prompts.size).to eq(2)
    expect(prompts.last).to include("Conversa recente", "resuma os emails da alpha", "e o 1, o que diz?")
  end

  it "numera os e-mails para que possam ser citados depois" do
    bot = build_bot
    allow(manager).to receive(:check_all).and_return(resultado)

    bot.send(:handle_update, texto("resuma os emails da alpha"))

    expect(prompts.last).to include('"n":1')
  end

  it "mantem a numeracao global no fallback mesmo quando a primeira conta tem mais de 10 e-mails" do
    bot = build_bot
    first = Array.new(11) { {subject: "Primeira", categories: [:geral]} }
    data = {"Alpha" => {emails: first}, "Beta" => {emails: [{subject: "Segunda conta", categories: [:geral]}]}}
    allow(ai).to receive(:complete).and_raise(IOError, "indisponivel")

    expect(bot.send(:ask_ai, "resuma", data)).to include("[12] <b>Segunda conta</b>")
  end

  it "rele as caixas quando o pedido diz para atualizar" do
    bot = build_bot
    expect(manager).to receive(:check_all).twice.and_return(resultado)

    bot.send(:handle_update, texto("resuma os emails da alpha"))
    bot.send(:handle_update, texto("atualiza a alpha"))
  end

  it "rele as caixas quando o pedido vem de comando de barra" do
    bot = build_bot
    expect(manager).to receive(:check_all).once.and_return(resultado)

    bot.send(:handle_update, texto("resuma os emails da alpha"))
    bot.send(:handle_update, texto("/resumo"))

    # /resumo nao diz a conta: pede a escolha pelo teclado em vez de usar o cache.
    expect(bot.instance_variable_get(:@pending_request)).to include("Resuma")
  end

  it "le so a conta que falta quando a outra ja esta na memoria" do
    bot = build_bot
    expect(manager).to receive(:check_all).with(hash_including(account_names: ["Alpha Work"])).and_return(resultado)
    expect(manager).to receive(:check_all).with(hash_including(account_names: ["Beta Personal"]))
      .and_return("Beta Personal" => {emails: [], error: nil})

    bot.send(:handle_update, texto("resuma os emails da alpha"))
    bot.send(:handle_update, texto("compare alpha e beta"))
  end
end
