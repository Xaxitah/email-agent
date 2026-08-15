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
      on_report: ->(results, period) { reports << [results, period]; true },
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
      on_report: ->(results, period) { reports << [results, period]; true },
      state_path: state_path,
      clock: clock
    )
    @now = Time.local(2026, 8, 15, 6, 0)
    restarted.tick

    expect(reports.first[0]["Work"][:emails].first[:subject]).to eq("Persistido")
  end
end
