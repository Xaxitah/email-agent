# frozen_string_literal: true

module EmailAgent
  class ScheduledReport
    SECTIONS = {
      direto: "🎯 Direto para você",
      reuniao_geral: "👥 Reunião geral",
      dialab: "🧪 DIALAB",
      liv: "📚 LIV",
      outro: "⚠️ Outros importantes"
    }.freeze
    MAX_MESSAGE_CHARS = 3800

    attr_reader :memory_results

    def initialize(results)
      @results = results
      @rows = results.flat_map do |account, data|
        next [] if data[:error]

        Array(data[:emails]).map { |email| [account, email] }
      end
      @visible = SECTIONS.keys.flat_map do |type|
        @rows.select { |_account, email| email[:triage][:tipo] == type && (type != :outro || email[:triage][:importancia] >= 2) }
      end
      @visible = @visible.each_with_index.map { |(account, email), index| [account, email.merge(report_number: index + 1)] }
      @memory_results = results.to_h do |account, data|
        [account, data.merge(emails: @visible.filter_map { |name, email| email if name == account })]
      end
    end

    def messages(title)
      heading = "📬 <b>#{escape(title)}</b>"
      blocks = []
      SECTIONS.each do |type, label|
        rows = @visible.select { |_account, email| email[:triage][:tipo] == type }
        rows.each_with_index do |(account, email), index|
          section = index.zero? ? "<b>#{label}</b>\n" : ""
          blocks << "#{section}#{render_email(account, email)}"
        end
      end
      blocks << "Nenhum e-mail importante nas contas consultadas." if @visible.empty?
      @results.each do |account, data|
        blocks << "⚠️ #{escape(account.to_s.slice(0, 100))}: erro ao consultar a conta." if data[:error]
      end
      propaganda = @rows.count { |_account, email| email[:triage][:tipo] == :propaganda }
      others = @rows.size - @visible.size - propaganda
      blocks << "#{count(propaganda, "propaganda")}, #{count(others, "outro")}."

      # Nao cortar tags HTML nem uma entrada no meio ao respeitar o teto Telegram.
      parts = [heading]
      blocks.each do |block|
        if parts.last.length + block.length + 2 > MAX_MESSAGE_CHARS
          parts << "#{heading} (continuação)"
        end
        parts[-1] += "\n\n#{block}"
      end
      parts
    end

    private

    def render_email(account, email)
      decision = email[:triage]
      lines = ["[#{email[:report_number]}] <b>#{escape(email[:subject].to_s.slice(0, 160))}</b>",
        "#{escape(account.to_s.slice(0, 60))} · #{escape(email[:from].to_s.slice(0, 120))}",
        escape(one_line(decision[:motivo], 240))]
      deadline = one_line(decision[:prazo], 120)
      lines << "Prazo/data: #{escape(deadline)}" unless deadline.empty?
      lines.join("\n")
    end

    def one_line(text, limit)
      text.to_s.gsub(/[\r\n]+/, " ").slice(0, limit)
    end

    def count(number, noun)
      "#{number} #{noun}#{"s" unless number == 1}"
    end

    def escape(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
