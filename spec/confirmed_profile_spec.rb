# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "perfil confirmado do Douglas" do
  let(:profile) { EmailAgent::TriageProfile.new(JSON.parse(File.read(EmailAgent::TriageProfile::DEFAULT_PATH))) }
  let(:triage) { EmailAgent::Triage.new(ai_client: nil, profile: profile) }

  def classify(subject:, **fields)
    triage.classify("Work" => {emails: [{subject: subject, body: "", headers: {}, from: "equipe@escola.example.com"}.merge(fields)]})["Work"][:emails].first[:triage]
  end

  it "carrega o contexto docente do vault sem aliases ou remetentes inventados" do
    expect(profile.to_h).to include("schools" => ["IFMS", "Rede Elite", "Estado-MS"], "addresses" => [], "important_senders" => [])
    expect(profile.to_h["context"]).to include("Química Analítica", "Comunicação Técnica", "Biologia", "Pedro Afonso")
  end

  it "identifica DIALAB pela sigla mesmo se o assunto nao tiver palavras do Classifier" do
    expect(classify(subject: "DiaLab: Trilha 3")).to include(tipo: :dialab, importancia: 2)
    expect(classify(subject: "Trilha 3", body: "Formacao docente")).to include(tipo: :outro, importancia: 1)
  end

  it "identifica LIV pela sigla e pelo nome completo" do
    ["LIV: material", "Laboratório de Inteligência de Vida"].each do |subject|
      expect(classify(subject: subject)).to include(tipo: :liv, importancia: 2)
    end
  end

  it "reconhece os termos de bem-estar quando associados a contexto escolar" do
    ["bem estar", "bem-estar", "saúde mental", "cuidados"].each do |term|
      expect(classify(subject: "Elite: #{term}")).to include(tipo: :liv, importancia: 2)
    end
  end

  it "nao transforma publicidade de saude em LIV" do
    expect(classify(subject: "Oferta de cuidados e saude mental", gmail_categories: [:promotions]))
      .to include(tipo: :propaganda)
    expect(classify(subject: "Oferta de bem-estar para professores", gmail_categories: [:promotions]))
      .to include(tipo: :propaganda)
  end

  it "considera reunioes de professores, coordenacao e toda a escola" do
    ["Reunião de professores", "Reunião de coordenação", "Reunião geral", "Reunião da escola"].each do |subject|
      expect(classify(subject: subject)).to include(tipo: :reuniao_geral, importancia: 2)
    end
  end

  it "prioriza nomes e enderecos de coordenacao e gestao sem exigir lista de remetentes" do
    expect(classify(subject: "Orientacoes", from_name: "Coordenação Pedagógica")).to include(importancia: 2)
    expect(classify(subject: "Orientacoes", from: "gestao@escola.example.com")).to include(importancia: 2)
    expect(classify(subject: "Orientacoes", from_name: "Direção Escolar")).to include(importancia: 2)
  end

  it "nao deduz remetente importante so pela palavra no corpo ou dominio" do
    expect(classify(subject: "Curso de gestao", body: "Conheca a coordenacao", from: "vendas@gestao.example.com"))
      .to include(importancia: 1)
  end

  it "eleva convocacao e alteracao de horario a urgencia" do
    ["Convocação", "Mudança de horário", "Alteração de horário"].each do |subject|
      expect(classify(subject: subject)).to include(importancia: 3)
    end
  end

  it "envia os nomes e os sinais de prioridade para a IA" do
    ai = instance_double(EmailAgent::AiClient)
    prompt = nil
    allow(ai).to receive(:complete) do |value, **|
      prompt = value
      JSON.generate([{n: 1, tipo: "outro", importancia: 1, motivo: "Orientacao institucional", prazo: nil}])
    end
    classified = EmailAgent::Triage.new(ai_client: ai, profile: profile).classify("Work" => {emails: [
      {subject: "Orientacoes", from_name: "Coordenação Pedagógica", from: "equipe@escola.example.com", headers: {}}
    ]})

    expect(prompt).to include('"from_name":"Coordenação Pedagógica"', '"remetente_importante":true', "ocultar")
    expect(classified["Work"][:emails].first[:triage][:importancia]).to eq(2)
  end
end
