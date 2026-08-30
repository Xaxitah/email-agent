# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe EmailAgent::TextNormalizer do
  it "remove o acento decompondo em NFD" do
    expect(described_class.normalize("Convocação")).to eq("convocacao")
    expect(described_class.normalize("reunião amanhã")).to eq("reuniao amanha")
  end

  it "baixa a caixa e apara as bordas" do
    expect(described_class.normalize("  OFÍCIO  ")).to eq("oficio")
  end

  it "sobrevive a nil" do
    expect(described_class.normalize(nil)).to eq("")
  end
end
