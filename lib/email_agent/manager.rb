# frozen_string_literal: true

module EmailAgent
  class Manager
    def initialize
      @accounts = load_accounts
      @notifier = Notifier.new
    end

    def check_all(limit: 10)
      results = {}

      @accounts.each do |account|
        puts "\n🔍 Verificando #{account.name}..."
        begin
          reader = Reader.new(account)
          emails = reader.fetch_unread(limit: limit)

          results[account.name] = {emails: emails, error: nil}

          # Notifica e-mails urgentes via Telegram
          if @notifier.enabled?
            urgent = emails.select { |e| e[:categories].include?(:urgente) }
            @notifier.notify_urgent(account.name, urgent) if urgent.any?
          end
        rescue => e
          results[account.name] = {emails: [], error: e.message}
          warn "  ❌ Erro em #{account.name}: #{e.message}"
        end
      end

      results
    end

    def report(limit: 10)
      results = check_all(limit: limit)

      puts "\n"
      puts "=" * 60
      puts "  EMAIL AGENT — RELATÓRIO"
      puts "  #{Time.now.strftime("%d/%m/%Y %H:%M:%S")}"
      puts "=" * 60

      results.each do |account_name, data|
        emails = data[:emails]
        puts "=" * 60
        if data[:error]
          puts "  #{account_name}: Nenhum e-mail nao lido!"
          puts "  ⚠️  Erro: #{data[:error]}"
        elsif emails.empty?
          puts "  #{account_name}: Nenhum e-mail nao lido!"
        else
          puts "  #{account_name} (#{emails.size} nao lidos):"
          puts "-" * 60
          emails.each do |email|
            tags = email[:categories].map { |c| c.to_s.upcase }.join(", ")
            puts "  [#{tags}] #{email[:subject]}"
            puts "    De: #{email[:from]} | #{email[:date]}"
          end
        end
      end

      puts ""
      puts "=" * 60

      # Envia resumo pro Telegram se habilitado
      if @notifier.enabled?
        puts "\n📱 Enviando resumo pro Telegram..."
        ok = @notifier.send_summary(results)
        puts ok ? "  ✅ Resumo enviado!" : "  ❌ Falha ao enviar resumo."
      else
        puts "\n💡 Telegram não configurado (TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID ausentes no .env)"
      end

      results
    end

    private

    def load_accounts
      count = ENV.fetch("ACCOUNT_COUNT", 0).to_i
      raise EmailAgent::Error, "ACCOUNT_COUNT deve ser maior que zero" if count < 1

      (1..count).map do |i|
        Account.new(
          name: ENV.fetch("ACCOUNT_#{i}_NAME"),
          host: ENV.fetch("ACCOUNT_#{i}_HOST"),
          port: ENV.fetch("ACCOUNT_#{i}_PORT", 993),
          user: ENV.fetch("ACCOUNT_#{i}_USER"),
          password: ENV.fetch("ACCOUNT_#{i}_PASSWORD")
        )
      end
    end
  end
end
