# frozen_string_literal: true

module EmailAgent
  # Tira acento e caixa antes de qualquer comparacao de texto.
  #
  # No Telegram e em muito e-mail as pessoas escrevem "reuniao", "amanha",
  # "convocacao". Decompor em NFD e remover as marcas combinantes (\p{Mn})
  # deixa "convocação" e "convocacao" com a mesma forma; downcase e strip
  # fecham a normalizacao.
  #
  # Usado pelo IntentRouter (roteamento de intencao) e pelo Classifier
  # (regras de categoria). As duas familias de regex sao escritas sem acento
  # de proposito, contando com esta funcao no outro lado — sem ela, um
  # "convocação" real nunca casaria com o padrao "convocacao".
  module TextNormalizer
    def self.normalize(text)
      text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.strip
    end
  end
end
