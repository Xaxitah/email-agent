# frozen_string_literal: true

module EmailAgent
  # Decide para qual agente uma mensagem do Telegram deve ir.
  #
  # Ate esta fatia o `TelegramBot#process_command` mandava tudo para o fluxo
  # de e-mail. O pedido real "pode adicionar a minha agenda os dois cafes
  # pedagogicos" caia no leitor IMAP e o bot respondia perguntando qual conta
  # consultar. O roteador corta esse caminho errado antes de qualquer acesso
  # a rede.
  #
  # E uma funcao pura: entra texto, sai simbolo. Sem IO, sem estado, sem
  # dependencia de ENV — por isso da para testar tudo sem mock.
  module IntentRouter
    INTENTS = %i[ajuda agenda email].freeze

    # Comandos de barra e pedidos explicitos de ajuda.
    HELP = %r{\A/(start|help|ajuda|menu)\b|\b(menu|ajuda|o que voce faz|como funciona)\b}

    # Verbos que criam ou alteram um compromisso, seguidos de perto por um
    # substantivo de agenda.
    #
    # Exigir o verbo — e nao so o substantivo — e proposital: "resuma os
    # e-mails sobre a reuniao" continua sendo pedido de e-mail. A janela de
    # 40 caracteres cobre o miolo comum ("adicionar a minha agenda") sem
    # deixar o verbo casar com um substantivo tres oracoes adiante.
    AGENDA_ACTION = /
      \b(?:agendar|agende|marcar|marque|remarcar|remarque|desmarcar|desmarque|
         adicionar|adicione|criar|crie|cadastrar|cadastre|colocar|coloque|
         anotar|anote|lembrar|lembre|salvar|salve)\b
      [^.!?]{0,40}
      \b(?:agenda|calendario|compromisso|compromissos|evento|eventos|lembrete|
         lembretes|reuniao|reunioes)\b
    /x

    # Consultas sobre a agenda que ja existe.
    AGENDA_QUERY = /
      \b(?:minha\s+agenda|na\s+agenda|da\s+agenda|meus\s+compromissos|
         proximo\s+compromisso|proximos\s+compromissos|
         o\s+que\s+(?:eu\s+)?tenho\s+(?:hoje|amanha|essa\s+semana|na\s+semana))\b
    /x

    def self.route(text)
      normalized = normalize(text)

      return :ajuda if HELP.match?(normalized)
      return :agenda if AGENDA_ACTION.match?(normalized) || AGENDA_QUERY.match?(normalized)

      # Padrao historico: antes desta fatia tudo ia para o e-mail. Manter o
      # e-mail como default evita regredir pedidos que ja funcionavam.
      :email
    end

    # Normalizacao (tira acento e caixa) vive em TextNormalizer, compartilhada
    # com o Classifier. As regras acima sao escritas sem acento de proposito.
    def self.normalize(text)
      TextNormalizer.normalize(text)
    end
  end
end
