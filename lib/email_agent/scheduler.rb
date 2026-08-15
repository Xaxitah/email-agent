# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "time"

module EmailAgent
  class Scheduler
    SCAN_HOURS = [5, 17].freeze
    REPORT_HOURS = {6 => 5, 18 => 17}.freeze

    def self.from_env(manager:, on_report:)
      return nil unless env_true?("SCHEDULE_ENABLED", default: true)

      new(
        manager: manager,
        on_report: on_report,
        state_path: ENV.fetch("SCHEDULE_STATE_PATH", "/data/scheduler-state.json"),
        email_limit: ENV.fetch("SCHEDULE_EMAIL_LIMIT", 200).to_i.clamp(1, 1000),
        catchup_minutes: ENV.fetch("SCHEDULE_CATCHUP_MINUTES", 180).to_i.clamp(1, 720)
      )
    end

    def self.env_true?(name, default: false)
      value = ENV.fetch(name, default ? "true" : "false").strip.downcase
      %w[1 true yes sim].include?(value)
    end

    def initialize(manager:, on_report:, state_path:, email_limit: 200, catchup_minutes: 180, clock: -> { Time.now })
      @manager = manager
      @on_report = on_report
      @state_path = state_path
      @email_limit = email_limit
      @catchup_minutes = catchup_minutes
      @clock = clock
      @state = load_state
    end

    def tick
      now = @clock.call
      SCAN_HOURS.each { |hour| run_scan_if_due(now, hour) }
      REPORT_HOURS.each { |report_hour, scan_hour| run_report_if_due(now, report_hour, scan_hour) }
    rescue => e
      warn "[Scheduler] Erro: #{e.message}"
      false
    end

    private

    def run_scan_if_due(now, hour)
      key = slot_key(now, "scan", hour)
      return unless due?(now, hour)
      return if @state["runs"].key?(key)

      results = @manager.check_all(limit: @email_limit, notify_urgent: false)
      filtered = keep_only_new(results, now)
      @state["pending"][pending_key(now, hour)] = serialize_results(filtered)
      @state["runs"][key] = now.iso8601
      prune_state(now)
      save_state
      puts "[Scheduler] Leitura das #{format("%02d", hour)}h concluida."
    rescue => e
      warn "[Scheduler] Falha na leitura das #{format("%02d", hour)}h: #{e.message}"
    end

    def run_report_if_due(now, report_hour, scan_hour)
      key = slot_key(now, "report", report_hour)
      return unless due?(now, report_hour)
      return if @state["runs"].key?(key)

      stored = @state["pending"][pending_key(now, scan_hour)]
      return unless stored

      sent = @on_report.call(deserialize_results(stored), format("%02d", scan_hour))
      raise "Telegram recusou o relatorio" unless sent

      @state["runs"][key] = now.iso8601
      @state["pending"].delete(pending_key(now, scan_hour))
      prune_state(now)
      save_state
      puts "[Scheduler] Relatorio das #{format("%02d", report_hour)}h enviado."
    rescue => e
      warn "[Scheduler] Falha no relatorio das #{format("%02d", report_hour)}h: #{e.message}"
    end

    def keep_only_new(results, now)
      results.each_with_object({}) do |(account_name, data), filtered|
        emails = data[:emails] || []
        known = @state["seen"].fetch(account_name, [])
        known_ids = known.to_h { |item| [item["id"], true] }
        new_emails = emails.reject { |email| known_ids.key?(fingerprint(account_name, email)) }

        emails.each do |email|
          id = fingerprint(account_name, email)
          next if known_ids.key?(id)

          known << {"id" => id, "seen_at" => now.iso8601}
          known_ids[id] = true
        end

        @state["seen"][account_name] = known.last(2000)
        filtered[account_name] = {emails: new_emails, error: data[:error]}
      end
    end

    def fingerprint(account_name, email)
      source = email[:message_id].to_s.strip
      source = [email[:uid], email[:from], email[:subject], email[:date]].join("|") if source.empty?
      Digest::SHA256.hexdigest("#{account_name}|#{source}")
    end

    def serialize_results(results)
      results.transform_values do |data|
        {
          "error" => data[:error],
          "emails" => (data[:emails] || []).map do |email|
            email.transform_keys(&:to_s).transform_values do |value|
              value.is_a?(Array) ? value.map(&:to_s) : value.to_s
            end
          end
        }
      end
    end

    def deserialize_results(results)
      results.transform_values do |data|
        {
          error: data["error"],
          emails: data.fetch("emails", []).map do |email|
            email.transform_keys(&:to_sym).tap do |item|
              item[:categories] = Array(item[:categories]).map(&:to_sym)
            end
          end
        }
      end
    end

    def due?(now, hour)
      scheduled = Time.local(now.year, now.month, now.day, hour, 0, 0)
      now >= scheduled && now < scheduled + (@catchup_minutes * 60)
    end

    def slot_key(now, kind, hour)
      "#{kind}:#{now.strftime("%Y-%m-%d")}:#{format("%02d", hour)}"
    end

    def pending_key(now, hour)
      "#{now.strftime("%Y-%m-%d")}:#{format("%02d", hour)}"
    end

    def load_state
      return empty_state unless File.file?(@state_path)

      parsed = JSON.parse(File.read(@state_path))
      empty_state.merge(parsed)
    rescue => e
      warn "[Scheduler] Estado ignorado por estar invalido: #{e.message}"
      empty_state
    end

    def save_state
      directory = File.dirname(@state_path)
      FileUtils.mkdir_p(directory)
      temporary = "#{@state_path}.tmp"
      File.write(temporary, JSON.pretty_generate(@state))
      File.rename(temporary, @state_path)
    end

    def empty_state
      {"seen" => {}, "pending" => {}, "runs" => {}}
    end

    def prune_state(now)
      cutoff = (now - (14 * 86_400)).strftime("%Y-%m-%d")
      @state["runs"].delete_if { |key, _value| key.split(":")[1] < cutoff }
      @state["pending"].delete_if { |key, _value| key.split(":").first < cutoff }
    end
  end
end
