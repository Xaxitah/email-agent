# frozen_string_literal: true

module EmailAgent
  class Classifier
    # Quantos caracteres do corpo entram na classificacao.
    #
    # Threads longas arrastam palavras de mensagens citadas la embaixo: um
    # "urgente" de tres semanas atras marcava a resposta nova como urgente.
    # Olhar so o inicio do corpo corta esse falso positivo.
    BODY_SCAN_CHARS = 600

    # Cabecalhos que identificam envio automatico ou de lista
    # (RFC 3834, RFC 2919, RFC 2369).
    #
    # Substituem a antiga regra por remetente `no-reply@.*`, que casava com
    # praticamente toda comunicacao institucional automatica — boleto,
    # convocacao, prazo de diario — e a silenciava antes de qualquer outra
    # avaliacao. Cabecalho e o sinal correto; endereco nao e.
    AUTOMATION_HEADERS = %i[list_id list_unsubscribe auto_submitted].freeze

    # Precedence: bulk/list/junk marca envio em massa.
    # "auto_reply" fica de fora de proposito: e resposta automatica
    # individual (ferias, ausencia), nao correspondencia de lista.
    BULK_PRECEDENCE = /\A\s*(bulk|list|junk)\s*\z/i

    # Os padroes sao escritos SEM acento de proposito. `scannable_text` passa o
    # texto pelo `TextNormalizer` (NFD + remove \p{Mn}), entao "convocação" e
    # "convocacao" chegam aqui na mesma forma. Antes, so a forma acentuada
    # casava e muita gente escreve sem acento — a classificacao falhava calada.
    RULES = {
      urgente: /urgente|prazo|deadline|imediato|atencao\s?urgente|responda\s?hoje|vence\s?hoje|vencimento\s?amanha/i,
      academico: /nota|frequencia|diario|plano de aula|bncc|aluno|turma|disciplina|boletim|avaliacao/i,
      administrativo: /portaria|memorando|oficio|edital|convocacao|reuniao|comunicado|resolucao/i,
      financeiro: /pagamento|boleto|fatura|cobranca|pix|transferencia|extrato/i
    }.freeze

    # Nao existe mais categoria :spam. As contas sao todas Gmail, e o filtro do
    # Google roda antes: o que e spam nem chega na INBOX que o agente le. As
    # regras que existiam aqui casavam com "unsubscribe" e "newsletter" no
    # corpo — presentes em quase todo e-mail de lista legitimo — e marcavam
    # como spam mensagens boas, curto-circuitando ate a checagem de urgencia.
    def self.classify(mail_summary)
      text = scannable_text(mail_summary)

      categories = RULES.filter_map do |category, pattern|
        category if text.match?(pattern)
      end

      # :automatico e aditivo, nunca terminal. Uma notificacao automatica pode
      # perfeitamente carregar um prazo; marca-la sem silenciar e o objetivo.
      categories << :automatico if automated?(mail_summary[:headers])

      categories.empty? ? [:geral] : categories
    end

    def self.automated?(headers)
      headers = headers.to_h
      return true if AUTOMATION_HEADERS.any? { |key| present?(headers[key]) }

      BULK_PRECEDENCE.match?(headers[:precedence].to_s)
    end

    def self.scannable_text(mail_summary)
      subject = mail_summary[:subject].to_s
      body = mail_summary[:body].to_s.slice(0, BODY_SCAN_CHARS).to_s

      # Corta o corpo em BODY_SCAN_CHARS ANTES de normalizar — o guardiao do
      # corpo continua medindo o texto original.
      TextNormalizer.normalize("#{subject} #{body}")
    end

    def self.present?(value)
      !value.to_s.strip.empty?
    end
    private_class_method :present?
  end
end
