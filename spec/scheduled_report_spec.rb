# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "relatorio agendado com triagem" do
  let(:manager) { instance_double(EmailAgent::Manager, account_names: %w[Alpha Beta]) }
  let(:ai) { instance_double(EmailAgent::AiClient) }
  let(:sent) { [] }
  let(:prompts) { [] }

  def email(subject, tipo, importancia = 2, **extra)
    {from: "escola@example.com", subject: subject, body: "Conteudo de #{subject}", categories: [:geral],
     triage: {tipo: tipo, importancia: importancia, motivo: "Pedido: #{subject}", prazo: "07/10 as 14h"}}.merge(extra)
  end

  def results
    {
      "Alpha" => {emails: [email("OFERTA_OCULTA", :propaganda, 0), email("LIV-escola", :liv),
        email("Reuniao geral", :reuniao_geral), email("Outro importante", :outro), email("Informativo oculto", :outro, 1)], error: nil},
      "Beta" => {emails: [email("DIALAB-escola", :dialab), email("Pedido direto", :direto)], error: nil}
    }
  end

  def build_bot
    bot = EmailAgent::TelegramBot.allocate
    bot.instance_variable_set(:@chat_id, "123")
    bot.instance_variable_set(:@manager, manager)
    bot.instance_variable_set(:@ai_client, ai)
    bot.instance_variable_set(:@include_email_body, true)
    bot.instance_variable_set(:@email_body_max_chars, 4000)
    allow(ai).to receive(:complete) do |prompt, **|
      prompts << prompt
      "Resposta sobre [2]"
    end
    allow(bot).to receive(:send_message) do |*args|
      sent << args
      true
    end
    allow(bot).to receive(:send_action)
    allow(bot).to receive(:send_message_with_id).and_return(1)
    allow(bot).to receive(:edit_message).and_return(true)
    bot
  end

  it "organiza tipos na ordem pedida, com motivo, prazo e contagem dos ocultos" do
    bot = build_bot

    expect(bot.send(:send_scheduled_report, results, "05")).to be(true)

    text = sent.map { |args| args[1] }.join("\n")
    titles = ["🎯 Direto para você", "👥 Reunião geral", "🧪 DIALAB", "📚 LIV", "⚠️ Outros importantes"]
    expect(titles.map { |title| text.index(title) }).to eq(titles.map { |title| text.index(title) }.sort)
    expect(text).to include("[1]", "[2]", "[3]", "[4]", "[5]", "Pedido: Pedido direto", "07/10 as 14h", "1 propaganda, 1 outro")
    expect(text).not_to include("OFERTA_OCULTA", "Informativo oculto")
    expect(ai).not_to have_received(:complete)
  end

  it "responde o que diz o 2 com o e-mail certo, sem reler o IMAP" do
    bot = build_bot
    bot.send(:send_scheduled_report, results, "05")
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, {"message" => {"chat" => {"id" => 123}, "text" => "o que diz o 2?"}})

    data = JSON.parse(prompts.last.lines.find { |line| line.start_with?("{") })
    emails = data.values.flat_map { |item| item["emails"] }
    expect(emails.find { |item| item["n"] == 2 }).to include("subject" => "Reuniao geral", "body" => "Conteudo de Reuniao geral")
    expect(emails.find { |item| item["n"] == 1 }["subject"]).to eq("Pedido direto")
    expect(emails.map { |item| item["n"] }.sort).to eq((1..5).to_a)
    expect(prompts.last).to include("Relatorio da manha")
  end

  it "informa quando nao ha importante e ainda mostra contagens" do
    bot = build_bot
    bot.send(:send_scheduled_report, {"Alpha" => {emails: [email("Oferta", :propaganda, 0), email("Informativo", :outro, 1)]}}, "17")

    expect(sent.last[1]).to include("Relatorio da tarde", "Nenhum e-mail importante", "1 propaganda, 1 outro")
    expect(sent.last[1]).not_to include("[1]")
  end

  it "escapa assunto, motivo e prazo nao confiaveis no HTML" do
    bot = build_bot
    item = email("<script>Assunto</script>", :direto)
    item[:triage].merge!(motivo: '<a href="https://x">Pedido</a>', prazo: "<img>")
    bot.send(:send_scheduled_report, {"Alpha" => {emails: [item]}}, "05")

    expect(sent.last[1]).to include("&lt;script&gt;", "&lt;a href=", "&lt;img&gt;")
    expect(sent.last[1]).not_to include("<script>", "<a ", "<img>")
  end

  it "divide relatorios longos mantendo cada numero unico e abaixo do limite Telegram" do
    bot = build_bot
    many = Array.new(30) { |index| email("Pedido #{index} " + "x" * 200, :direto) }
    bot.send(:send_scheduled_report, {"Alpha" => {emails: many}}, "05")

    expect(sent.size).to be > 1
    expect(sent.map { |args| args[1].length }.max).to be <= 4000
    expect(sent.map { |args| args[1] }.join.scan(/\[(\d+)\]/).flatten.map(&:to_i)).to eq((1..30).to_a)
  end

  it "respeita o teto Telegram mesmo quando todo texto precisa ser escapado" do
    bot = build_bot
    item = email("&" * 200, :direto, 2, from: "&" * 160)
    item[:triage].merge!(motivo: "&" * 240, prazo: "&" * 120)
    bot.send(:send_scheduled_report, {"&" * 80 => {emails: [item]}}, "05")

    expect(sent.map { |args| args[1].length }.max).to be <= 4000
  end

  it "permite ler o trecho ja autorizado no relatorio mesmo sem corpos nas consultas manuais" do
    bot = build_bot
    bot.instance_variable_set(:@include_email_body, false)
    bot.send(:send_scheduled_report, results, "05")
    expect(manager).not_to receive(:check_all)

    bot.send(:handle_update, {"message" => {"chat" => {"id" => 123}, "text" => "o que diz o 2?"}})

    expect(prompts.last).to include('"body":"Conteudo de Reuniao geral"')
  end

  it "nao sobrescreve a memoria se o envio falhar" do
    bot = build_bot
    memory = bot.send(:memoria)
    memory.store_results("Alpha" => {emails: [email("Anterior", :direto)]})
    allow(bot).to receive(:send_message).and_return(false)

    expect(bot.send(:send_scheduled_report, results, "05")).to be(false)
    expect(memory.cached_results(["Alpha"])["Alpha"][:emails].first[:subject]).to eq("Anterior")
  end

  it "renumera a lista quando combina e-mails do relatorio com uma leitura nova" do
    bot = build_bot
    bot.send(:send_scheduled_report, results, "05")
    allow(manager).to receive(:account_names).and_return(%w[Alpha Beta Gamma])
    allow(manager).to receive(:check_all).with(hash_including(account_names: ["Gamma"]))
      .and_return("Gamma" => {emails: [email("Novo", :direto)]})

    bot.send(:handle_update, {"message" => {"chat" => {"id" => 123}, "text" => "resuma tudo"}})

    data = JSON.parse(prompts.last.lines.find { |line| line.start_with?("{") })
    expect(data.values.flat_map { |item| item["emails"].map { |email| email["n"] } }).to eq((1..6).to_a)
  end

  it "nao mistura numeros antigos de outra conta ao consultar todas apos atualizar uma" do
    bot = build_bot
    bot.send(:send_scheduled_report, results, "05")
    allow(manager).to receive(:check_all).with(hash_including(account_names: ["Alpha"]))
      .and_return("Alpha" => {emails: [email("Novo Alpha", :direto)], error: nil})
    bot.send(:handle_update, {"message" => {"chat" => {"id" => 123}, "text" => "atualiza Alpha"}})
    bot.send(:handle_update, {"message" => {"chat" => {"id" => 123}, "text" => "resuma tudo"}})

    data = JSON.parse(prompts.last.lines.find { |line| line.start_with?("{") })
    expect(data.values.flat_map { |item| item["emails"].map { |email| email["n"] } }).to eq((1..3).to_a)
  end
end
