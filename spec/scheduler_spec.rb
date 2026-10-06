# frozen_string_literal: true

require "tmpdir"
require_relative "spec_helper"

RSpec.describe EmailAgent::Scheduler do
  let(:manager) { instance_double(EmailAgent::Manager) }
  let(:reports) { [] }
  let(:state_path) { File.join(Dir.mktmpdir, "scheduler.json") }
  let(:clock) { -> { @now } }
  let(:scheduler) do
    described_class.new(
      manager: manager,
      on_report: ->(results, period) {
        reports << [results, period]
        true
      },
      state_path: state_path,
      clock: clock
    )
  end

  def results_for(*emails)
    {"Work" => {emails: emails, error: nil}}
  end

  def email(message_id, subject)
    {
      message_id: message_id,
      uid: 1,
      from: "sender@example.com",
      subject: subject,
      date: "2026-08-15 04:30",
      body: "Body",
      categories: [:geral]
    }
  end

  it "scans at 05h and sends the persisted new-email report at 06h only once" do
    allow(manager).to receive(:check_all).and_return(results_for(email("one@example.com", "Primeiro")))

    @now = Time.local(2026, 8, 15, 5, 0)
    scheduler.tick
    scheduler.tick

    expect(manager).to have_received(:check_all).with(limit: 200, notify_urgent: false).once
    expect(reports).to be_empty

    @now = Time.local(2026, 8, 15, 6, 0)
    scheduler.tick
    scheduler.tick

    expect(reports.size).to eq(1)
    expect(reports.first[1]).to eq("05")
    expect(reports.first[0]["Work"][:emails].first[:subject]).to eq("Primeiro")
  end

  it "does not repeat a message already seen in the morning scan" do
    same = email("same@example.com", "Mesmo email")
    allow(manager).to receive(:check_all).and_return(results_for(same))

    @now = Time.local(2026, 8, 15, 5, 0)
    scheduler.tick
    @now = Time.local(2026, 8, 15, 6, 0)
    scheduler.tick
    @now = Time.local(2026, 8, 15, 17, 0)
    scheduler.tick
    @now = Time.local(2026, 8, 15, 18, 0)
    scheduler.tick

    expect(reports.last[0]["Work"][:emails]).to be_empty
  end

  it "recovers pending state after a process restart" do
    allow(manager).to receive(:check_all).and_return(results_for(email("restart@example.com", "Persistido")))
    @now = Time.local(2026, 8, 15, 5, 0)
    scheduler.tick

    restarted = described_class.new(
      manager: manager,
      on_report: ->(results, period) {
        reports << [results, period]
        true
      },
      state_path: state_path,
      clock: clock
    )
    @now = Time.local(2026, 8, 15, 6, 0)
    restarted.tick

    expect(reports.first[0]["Work"][:emails].first[:subject]).to eq("Persistido")
  end

  it "faz a triagem somente dos novos e-mails nas leituras de 05h e 17h" do
    triage = instance_double(EmailAgent::Triage)
    allow(triage).to receive(:classify) { |results| results }
    scheduled = described_class.new(manager: manager, triage: triage,
      on_report: ->(*_) { true }, state_path: state_path, clock: clock)
    same = email("same", "Mesmo")
    fresh = email("fresh", "Novo")
    allow(manager).to receive(:check_all).and_return(results_for(same), results_for(same, fresh))

    @now = Time.local(2026, 10, 6, 5, 0)
    scheduled.tick
    @now = Time.local(2026, 10, 6, 12, 0)
    scheduled.tick
    @now = Time.local(2026, 10, 6, 17, 0)
    scheduled.tick

    expect(triage).to have_received(:classify).with(results_for(same)).once
    expect(triage).to have_received(:classify).with(results_for(fresh)).once
    expect(manager).to have_received(:check_all).twice
  end

  it "preserva cabecalhos, importancia numerica e triagem apos reiniciar" do
    triage = EmailAgent::Triage.new(ai_client: nil,
      profile: EmailAgent::TriageProfile.new({"addresses" => ["douglas@example.com"]}))
    original = email("one", "Prazo urgente").merge(
      headers: {to: ["douglas@example.com"], cc: ["colega@example.com"], reply_to: ["resposta@example.com"]},
      gmail_categories: [:promotions]
    )
    allow(manager).to receive(:check_all).and_return(results_for(original))
    scheduled = described_class.new(manager: manager, triage: triage,
      on_report: ->(*_) { true }, state_path: state_path, clock: clock)
    @now = Time.local(2026, 10, 6, 5, 0)
    scheduled.tick
    restarted = described_class.new(manager: manager,
      on_report: ->(results, _) {
        reports << results
        true
      }, state_path: state_path, clock: clock)
    @now = Time.local(2026, 10, 6, 6, 0)
    restarted.tick

    item = reports.first["Work"][:emails].first
    expect(item[:headers]).to eq(original[:headers])
    expect(item[:gmail_categories]).to eq([:promotions])
    expect(item[:triage]).to include(tipo: :direto, importancia: 3, source: :fallback)
  end

  it "mantem o relatorio pendente quando o Telegram falha" do
    allow(manager).to receive(:check_all).and_return(results_for(email("one", "Primeiro")))
    attempts = 0
    scheduled = described_class.new(manager: manager,
      on_report: ->(*_) {
        attempts += 1
        attempts > 1
      }, state_path: state_path, clock: clock)
    @now = Time.local(2026, 10, 6, 5, 0)
    scheduled.tick
    @now = Time.local(2026, 10, 6, 6, 0)
    scheduled.tick
    scheduled.tick
    scheduled.tick

    expect(attempts).to eq(2)
  end
end
