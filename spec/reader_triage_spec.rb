# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe EmailAgent::Reader do
  it "preserva o nome do remetente para reconhecer coordenacao e gestao" do
    mail = Mail.read_from_string("From: Coordenacao Pedagogica <equipe@escola.example.com>\r\nSubject: Aviso\r\n\r\nCorpo")

    expect(described_class.summarize(mail)).to include(from: "equipe@escola.example.com", from_name: "Coordenacao Pedagogica")
  end

  it "preserva os destinatarios To, Cc e Reply-To como enderecos" do
    mail = Mail.read_from_string("From: x@example.com\r\n" \
      "To: Douglas <douglas@example.com>, colega@example.com\r\n" \
      "Cc: copia@example.com\r\nReply-To: resposta@example.com\r\n" \
      "List-Id: <escola.example.com>\r\nSubject: Aviso\r\n\r\nCorpo")

    expect(described_class.summarize(mail)[:headers]).to include(
      to: %w[douglas@example.com colega@example.com],
      cc: ["copia@example.com"], reply_to: ["resposta@example.com"],
      list_id: "<escola.example.com>"
    )
  end

  describe "categorias Gmail em leitura somente leitura" do
    let(:account) { EmailAgent::Account.new(name: "Work", host: "imap.gmail.com", user: "douglas@example.com", password: "test") }
    let(:imap) { instance_double(Net::IMAP) }

    before do
      allow(Net::IMAP).to receive(:new).and_return(imap)
      allow(imap).to receive(:login)
      allow(imap).to receive(:examine)
      allow(imap).to receive(:capable?).with("X-GM-EXT-1").and_return(true)
      allow(imap).to receive(:search).with(["UNSEEN"]).and_return([41, 42, 43])
      allow(imap).to receive(:search).with(["UNSEEN", "X-GM-RAW", "category:promotions"]).and_return([41])
      allow(imap).to receive(:search).with(["UNSEEN", "X-GM-RAW", "category:social"]).and_return([42])
      allow(imap).to receive(:fetch).and_return([double(attr: {"BODY[]" => "Subject: Test\r\n\r\nBody"})])
      allow(imap).to receive(:disconnected?).and_return(false)
      allow(imap).to receive(:logout)
      allow(imap).to receive(:disconnect)
    end

    it "usa X-GM-RAW somente quando o servidor confirma suporte" do
      emails = described_class.new(account).fetch_unread

      expect(emails.map { |email| email[:gmail_categories] }).to eq([[:promotions], [:social], []])
      expect(imap).to have_received(:examine).with("INBOX")
      expect(imap).to have_received(:fetch).with(41, "BODY.PEEK[]")
      expect(imap).not_to have_received(:fetch).with(anything, "BODY[]")
    end

    it "continua lendo se o servidor recusa X-GM-RAW, sem confiar em sinal parcial" do
      allow(imap).to receive(:search).with(["UNSEEN", "X-GM-RAW", "category:social"])
        .and_raise(Net::IMAP::BadResponseError.new(
          Net::IMAP::TaggedResponse.new("A1", "BAD", Net::IMAP::ResponseText.new(nil, "unsupported"), "")
        ))

      emails = described_class.new(account).fetch_unread

      expect(emails.size).to eq(3)
      expect(emails.map { |email| email[:gmail_categories] }).to eq([[], [], []])
    end

    it "nao faz buscas de categoria quando a extensao esta ausente" do
      allow(imap).to receive(:capable?).and_return(false)

      described_class.new(account).fetch_unread

      expect(imap).not_to have_received(:search).with(["UNSEEN", "X-GM-RAW", anything])
    end
  end
end
