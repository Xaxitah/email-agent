# frozen_string_literal: true

require "tmpdir"
require_relative "spec_helper"

RSpec.describe EmailAgent::TriageProfile do
  around do |example|
    Dir.mktmpdir do |directory|
      @path = File.join(directory, "profile.json")
      example.run
    end
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("TRIAGE_PROFILE_PATH", anything).and_return(@path)
    allow(ENV).to receive(:fetch).with("ACCOUNT_COUNT", 0).and_return("2")
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ACCOUNT_1_USER").and_return("Douglas@example.com")
    allow(ENV).to receive(:[]).with("ACCOUNT_2_USER").and_return("douglas@escola.example.com")
  end

  it "le o arquivo configurado e combina aliases com as contas, sem senhas" do
    File.write(@path, JSON.generate({"addresses" => ["alias@example.com"], "name" => "Douglas", "schools" => ["IFMS"]}))

    profile = described_class.from_env

    expect(profile.addresses).to eq(%w[alias@example.com douglas@example.com douglas@escola.example.com])
    expect(profile.to_h).to include("name" => "Douglas", "schools" => ["IFMS"])
    expect(profile.to_h.keys).not_to include("password", "api_key")
  end

  it "usa os enderecos configurados mesmo sem perfil ou com JSON invalido" do
    expect(described_class.from_env.addresses).to include("douglas@example.com")
    ["invalido", "[]"].each do |invalid|
      File.write(@path, invalid)
      expect(described_class.from_env.addresses).to include("douglas@example.com")
    end
  end

  it "compara termos completos sem acento e nao confunde LIV com livro" do
    profile = described_class.new({"topics" => {
      "liv" => {"keywords" => ["LIV"]}, "reuniao_geral" => {"keywords" => ["reuniao geral"]}
    }})

    expect(profile.topic_for(subject: "Livro de apoio")).to be_nil
    expect(profile.topic_for(subject: "LIV: material")).to eq(:liv)
    expect(profile.topic_for(subject: "Reunião geral")).to eq(:reuniao_geral)
  end
end
