# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe EmailAgent do
  it "has a version number" do
    expect(EmailAgent::VERSION).not_to be nil
  end

  it "classifies urgent email" do
    summary = {from: "direcao@example.com", subject: "Prazo urgente", body: "Responda hoje"}

    expect(EmailAgent::Classifier.classify(summary)).to include(:urgente)
  end
end

# Regressoes dos tres defeitos corrigidos em 2026-08-30. Cada teste aqui trava
# um comportamento que estava escondendo e-mail importante do usuario.
RSpec.describe EmailAgent::Classifier do
  describe "no-reply senders" do
    it "still evaluates a deadline sent from a no-reply address" do
      summary = {
        from: "no-reply@ifms.edu.br",
        subject: "Prazo para lancamento do diario",
        body: "Vence hoje."
      }

      # Antes: `no-reply@.*` devolvia [:sistema] e a mensagem sumia do radar.
      expect(EmailAgent::Classifier.classify(summary)).to include(:urgente)
    end

    it "marks bulk mail from headers instead of guessing by address" do
      summary = {
        from: "noreply@example.com",
        subject: "Boletim da semana",
        body: "Novidades",
        headers: {list_id: "<news.example.com>"}
      }

      expect(EmailAgent::Classifier.classify(summary)).to include(:automatico)
    end

    it "does not treat a personal auto-reply as bulk mail" do
      summary = {
        from: "colega@example.com",
        subject: "Ausencia",
        body: "Estou de ferias",
        headers: {precedence: "auto_reply"}
      }

      expect(EmailAgent::Classifier.classify(summary)).not_to include(:automatico)
    end

    it "keeps automation additive so an automated deadline still surfaces" do
      summary = {
        from: "sistema@example.com",
        subject: "Boleto disponivel",
        body: "Vencimento amanha",
        headers: {precedence: "bulk"}
      }

      categories = EmailAgent::Classifier.classify(summary)

      expect(categories).to include(:automatico)
      expect(categories).to include(:financeiro)
    end
  end

  describe "quoted threads" do
    it "ignores urgency quoted deep in an old reply" do
      summary = {
        from: "colega@example.com",
        subject: "Re: combinado",
        body: "Fechado, obrigado.\n\n" + ("-" * 900) + "\nEm 01/08, alguem escreveu: era urgente"
      }

      # Antes: casava no corpo inteiro e marcava a resposta nova como urgente.
      expect(EmailAgent::Classifier.classify(summary)).to eq([:geral])
    end

    it "still catches urgency stated near the top of the body" do
      summary = {
        from: "direcao@example.com",
        subject: "Reuniao",
        body: "Responda hoje, por favor."
      }

      expect(EmailAgent::Classifier.classify(summary)).to include(:urgente)
    end
  end

  it "survives a summary without headers" do
    summary = {from: "a@b.com", subject: "Ola", body: "Tudo bem?"}

    expect { EmailAgent::Classifier.classify(summary) }.not_to raise_error
    expect(EmailAgent::Classifier.classify(summary)).to eq([:geral])
  end
end
