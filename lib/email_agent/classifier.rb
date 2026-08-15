# frozen_string_literal: true

module EmailAgent
  class Classifier
    # Remetentes que sempre são ignorados (alertas de sistema, no-reply)
    IGNORED_SENDERS = /
      no-reply@accounts\.google\.com |
      noreply@.*\.google\.com        |
      security@.*\.google\.com       |
      info@accounts\.google\.com     |
      no-reply@.*                    |
      noreply@.*
    /xi

    # Regras de SPAM — deve vir ANTES de urgente para evitar falsos positivos
    SPAM_PATTERNS = /
      tele\s?sena         |  # Tele Sena não é urgente!
      promoção            |
      desconto            |
      grátis              |
      clique\s?aqui       |
      oferta\s?especial   |
      ganhe\s?agora       |
      você\s?foi\s?selecionado |
      unsubscribe         |
      newsletter
    /xi

    # Regras por categoria
    RULES = {
      urgente: /urgente|prazo|deadline|imediato|atenção\s?urgente|responda\s?hoje|vence\s?hoje|vencimento\s?amanhã/i,
      academico: /nota|frequencia|diário|plano de aula|bncc|aluno|turma|disciplina|boletim|avaliação/i,
      administrativo: /portaria|memorando|ofício|edital|convocação|reunião|comunicado|resolução/i,
      financeiro: /pagamento|boleto|fatura|cobrança|pix|transferência|extrato/i
    }.freeze

    def self.classify(mail_summary)
      from = mail_summary[:from].to_s
      subject = mail_summary[:subject].to_s
      body = mail_summary[:body].to_s
      text = "#{subject} #{body}"

      # Remetentes ignorados viram :sistema
      return [:sistema] if from.match?(IGNORED_SENDERS)

      # Spam must not also trigger urgent notifications.
      return [:spam] if text.match?(SPAM_PATTERNS)

      # Retorna todas as categorias relevantes que batem
      categories = RULES.filter_map do |category, pattern|
        category if text.match?(pattern)
      end

      categories.empty? ? [:geral] : categories
    end
  end
end
