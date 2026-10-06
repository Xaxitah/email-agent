# frozen_string_literal: true

module EmailAgent
  # Memoria curta da conversa no Telegram.
  #
  # Antes dela cada mensagem era a primeira: "e o 3, o que diz?" nao tinha a
  # quem se referir, e toda pergunta voltava ao IMAP das quatro contas. Aqui
  # ficam, por alguns minutos, as ultimas trocas (para a IA entender o
  # seguimento) e os e-mails lidos de cada conta (para responder sem reler).
  #
  # Fica so em memoria, de proposito: o conteudo dos e-mails nao vai para o
  # volume /data, e um restart do servico simplesmente esquece a conversa.
  # So existe um chat autorizado, entao nao ha separacao por chat_id.
  class ConversationMemory
    TTL = 15 * 60
    MAX_TURNS = 6
    MAX_REPLY_CHARS = 1500

    def initialize(ttl: TTL, max_turns: MAX_TURNS, clock: -> { Time.now })
      @ttl = ttl
      @max_turns = max_turns
      @clock = clock
      @turns = []
      @accounts = {}
      @last_accounts = nil
    end

    # Trocas recentes, da mais antiga para a mais nova: [{pedido:, resposta:}].
    def turns
      @turns.select! { |turn| fresh?(turn[:at]) }
      @turns.map { |turn| turn.slice(:pedido, :resposta) }
    end

    def record_turn(pedido, resposta)
      @turns << {pedido: pedido.to_s, resposta: resposta.to_s.slice(0, MAX_REPLY_CHARS), at: @clock.call}
      @turns.shift while @turns.size > @max_turns
    end

    # Guarda o resultado do Manager#check_all por conta. Conta que deu erro
    # nao entra: na proxima pergunta ela e lida de novo.
    def store_results(results)
      now = @clock.call
      results.each do |name, data|
        next if data[:error]

        @accounts[name] = {data: data, at: now}
      end
      @last_accounts = results.keys
    end

    # So as contas pedidas que ainda estao frescas, na ordem pedida.
    def cached_results(account_names)
      account_names.each_with_object({}) do |name, cached|
        entry = @accounts[name]
        cached[name] = entry[:data] if entry && fresh?(entry[:at])
      end
    end

    # Contas da ultima consulta, enquanto ela estiver fresca. Serve para o
    # seguimento que nao repete o nome da conta ("e o segundo?").
    def last_accounts
      return nil unless @last_accounts
      return nil if cached_results(@last_accounts).empty?

      @last_accounts
    end

    def clear
      @turns.clear
      @accounts.clear
      @last_accounts = nil
    end

    private

    def fresh?(time)
      @clock.call - time < @ttl
    end
  end
end
