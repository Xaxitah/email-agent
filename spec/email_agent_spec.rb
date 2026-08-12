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
