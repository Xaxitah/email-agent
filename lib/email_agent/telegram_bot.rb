# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module EmailAgent
  class TelegramBot
    TELEGRAM_API  = "https://api.telegram.org/bot"
    ANTHROPIC_API = "https://api.anthropic.com/v1/messages"

    def initialize
      @token         = ENV.fetch("TELEGRAM_BOT_TOKEN")
      @chat_id       = ENV.fetch("TELEGRAM_CHAT_ID")
      @anthropic_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
      @manager       = Manager.new
      @offset        = 0
    end

    def run
      puts "🤖 Claudin no Telegram — aguardando mensagens..."
      puts "   API Claude: #{@anthropic_key ? '✅ configurada' : '⚠️  ausente (modo simples)'}"
      loop do
        get_updates.each { |update| handle_update(update) }
        sleep 2
      rescue Interrupt
        puts "\n👋 Bot encerrado."
        break
      rescue StandardError => e
        warn "Erro no loop: #{e.message}"
        sleep 5
        retry
      end
    end

    private

    def get_updates
      uri = URI("#{TELEGRAM_API}#{@token}/getUpdates")
      uri.query = URI.encode_www_form(offset: @offset, timeout: 30)
      data = JSON.parse(Net::HTTP.get_response(uri).body)
      return [] unless data["ok"]

      updates = data["result"]
      @offset = updates.last["update_id"] + 1 if updates.any?
      updates
    rescue StandardError => e
      warn "Erro ao buscar updates: #{e.message}"
      []
    end

    def handle_update(update)
      message = update.dig("message")
      return unless message

      chat_id = message.dig("chat", "id").to_s
      text    = message.dig("text").to_s.strip

      unless chat_id == @chat_id.to_s
        warn "⚠️  Mensagem ignorada de chat_id desconhecido: #{chat_id}"
        return
      end

      puts "📨 [#{Time.now.strftime('%H:%M')}] #{text}"
      send_action(chat_id, "typing")

      contas  = @anthropic_key ? detectar_contas_claude(text) : filtrar_contas(text)
      results = @manager.check_all(limit: 20)
      results = results.select { |nome, _| contas.include?(nome) } if contas
      resposta = @anthropic_key ? ask_claude(text, results) : resposta_simples(results)

      send_message(chat_id, resposta)
    end

    def send_message(chat_id, text)
      uri = URI("#{TELEGRAM_API}#{@token}/sendMessage")
      Net::HTTP.post_form(uri, {
        chat_id:    chat_id,
        text:       text,
        parse_mode: "HTML"
      })
    rescue StandardError => e
      warn "Erro ao enviar mensagem: #{e.message}"
    end

    def send_action(chat_id, action)
      uri = URI("#{TELEGRAM_API}#{@token}/sendChatAction")
      Net::HTTP.post_form(uri, { chat_id: chat_id, action: action })
    rescue StandardError
      nil
    end

    def detectar_contas_claude(texto)
      contas_disponiveis = ["IFMS", "Rede Elite", "Google Douglas", "Bughipr"]

      prompt = <<~PROMPT
        O Douglas tem 4 contas de e-mail:
        - "IFMS" → trabalho no IFMS
        - "Rede Elite" → trabalho no colégio Elite
        - "Google Douglas" → pessoal douglasbughi@gmail.com
        - "Bughipr" → pessoal bughipr@gmail.com

        Com base na mensagem abaixo, quais contas ele quer consultar?
        Mensagem: "#{texto}"

        Responda APENAS com os nomes separados por vírgula.
        Se quiser todas, responda: TODAS
        Exemplos: "IFMS", "IFMS, Rede Elite", "Google Douglas, Bughipr", "TODAS"
      PROMPT

      uri  = URI(ANTHROPIC_API)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.read_timeout = 10

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"]      = "application/json"
      req["x-api-key"]         = @anthropic_key
      req["anthropic-version"] = "2023-06-01"
      req.body = JSON.generate({
        model:      "claude-haiku-4-5-20251001",
        max_tokens: 50,
        messages:   [{ role: "user", content: prompt }]
      })

      resposta = JSON.parse(http.request(req).body).dig("content", 0, "text").to_s.strip
      return nil if resposta.upcase.include?("TODAS")

      detectadas = resposta.split(",").map(&:strip).select { |c| contas_disponiveis.include?(c) }
      detectadas.empty? ? nil : detectadas
    rescue StandardError => e
      warn "Erro ao detectar contas: #{e.message}"
      nil
    end

    def filtrar_contas(texto)
      t = texto.downcase
      return nil if t.match?(/semana|tudo|todas|geral/)

      contas = []
      contas << "IFMS"           if t.match?(/\bif\b|ifms/)
      contas << "Rede Elite"     if t.match?(/elite/)
      contas += ["IFMS", "Rede Elite"] if t.match?(/trabalho/)
      contas << "Google Douglas" if t.match?(/\bdb\b|douglasbughi/)
      contas << "Bughipr"        if t.match?(/\bbughi\b|bughipr/)
      contas += ["Google Douglas", "Bughipr"] i