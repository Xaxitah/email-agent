# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module EmailAgent
  class Notifier
    TELEGRAM_API = "https://api.telegram.org/bot"

    def initialize
      @token = ENV.fetch("TELEGRAM_BOT_TOKEN", "").strip
      @chat_id = ENV.fetch("TELEGRAM_CHAT_ID", "").strip
      @enabled = !@token.empty? && !@chat_id.empty?
    end

    def enabled?
      @enabled
    end

    # Envia qualquer texto pro Telegram
    def send_message(text)
      return false unless enabled?

      uri = URI("#{TELEGRAM_API}#{@token}/sendMessage")
      params = {chat_id: @chat_id, text: text, parse_mode: "HTML"}

      response = Net::HTTP.post_form(uri, params.transform_values(&:to_s))
      JSON.parse(response.body)["ok"]
    rescue => e
      warn "[Notifier] Erro ao enviar mensagem: #{e.message}"
      false
    end

    # Notifica e-mails urgentes de uma conta
    def notify_urgent(account_name, emails)
      return unless enabled? && emails.any?

      lines = ["🚨 <b>E-mails URGENTES — #{account_name}</b>"]
      emails.first(5).each_with_index do |email, i|
        lines << "#{i + 1}. <b>#{escape(email[:subject])}</b>"
        lines << "   De: #{escape(email[:from])}"
        lines << "   #{escape(email[:date])}"
      end
      lines << "\n<i>Total: #{emails.size} urgente(s)</i>" if emails.size > 1

      send_message(lines.join("\n"))
    end

    # Envia resumo completo de todas as contas
    def send_summary(results)
      return unless enabled?

      total_emails = results.values.sum { |r| r[:emails]&.size || 0 }
      total_urgent = results.values.sum { |r| (r[:emails] || []).count { |e| e[:categories].include?(:urgente) } }

      lines = ["📊 <b>Resumo do Email Agent</b>", "🕐 #{Time.now.strftime("%d/%m/%Y %H:%M")}"]
      lines << "━" * 30

      results.each do |account_name, data|
        emails = data[:emails] || []
        urgent = emails.count { |e| e[:categories].include?(:urgente) }
        academic = emails.count { |e| e[:categories].include?(:academico) }

        status = data[:error] ? "❌ Erro" : "✅ OK"
        lines << "\n<b>#{escape(account_name)}</b> #{status}"

        if data[:error]
          lines << "   ⚠️ #{escape(data[:error])}"
        elsif emails.empty?
          lines << "   📭 Nenhum e-mail não lido"
        else
          lines << "   📧 #{emails.size} não lido(s)"
          lines << "   🚨 #{urgent} urgente(s)" if urgent > 0
          lines << "   📚 #{academic} acadêmico(s)" if academic > 0
        end
      end

      lines << "\n━" * 30
      lines << "📨 <b>Total: #{total_emails} e-mail(s) | #{total_urgent} urgente(s)</b>"

      send_message(lines.join("\n"))
    end

    # Verifica o Chat ID a partir do token atual
    def self.fetch_chat_id(token)
      uri = URI("#{TELEGRAM_API}#{token}/getUpdates")
      response = Net::HTTP.get(uri)
      data = JSON.parse(response)

      if data["ok"] && data["result"].any?
        chat = data["result"].last.dig("message", "chat")
        puts "Chat ID encontrado: #{chat["id"]}" if chat
        chat&.fetch("id")
      else
        puts "Nenhuma mensagem encontrada. Mande 'oi' pro bot primeiro!"
        nil
      end
    rescue => e
      warn "Erro ao buscar Chat ID: #{e.message}"
      nil
    end

    private

    def escape(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
