# frozen_string_literal: true

require "json"

module EmailAgent
  class TriageProfile
    DEFAULT_PATH = File.expand_path("../../config/douglas.json", __dir__)
    TOPICS = %w[dialab liv reuniao_geral].freeze

    attr_reader :addresses

    def self.from_env
      path = ENV.fetch("TRIAGE_PROFILE_PATH", DEFAULT_PATH)
      addresses = (1..ENV.fetch("ACCOUNT_COUNT", 0).to_i).filter_map do |n|
        ENV["ACCOUNT_#{n}_USER"]
      end
      data = File.file?(path) ? JSON.parse(File.read(path)) : {}
      new(data, addresses: addresses)
    rescue JSON::ParserError, ArgumentError, SystemCallError
      warn "[Triage] Perfil invalido; usando somente os enderecos das contas."
      new({}, addresses: addresses)
    end

    def initialize(data = {}, addresses: [])
      raise ArgumentError, "perfil deve ser um objeto JSON" unless data.is_a?(Hash)

      @data = data
      @addresses = (Array(data["addresses"]) + addresses).map { |address| address.to_s.strip.downcase }.reject(&:empty?).uniq
    end

    def to_h
      @data.merge("addresses" => addresses)
    end

    def important_sender?(sender)
      Array(@data["important_senders"]).any? { |address| address.to_s.strip.casecmp?(sender.to_s.strip) }
    end

    def important_email?(email)
      return true if important_sender?(email[:from])

      # Papéis são indícios no nome/local-part; não em qualquer menção no corpo.
      sender = "#{email[:from_name]} #{email[:from].to_s.split("@", 2).first}"
      matches_terms?(TextNormalizer.normalize(sender), @data["important_roles"])
    end

    def urgent?(email)
      matches_terms?(email_text(email), @data["urgent_keywords"])
    end

    def topic_for(email)
      text = email_text(email)
      context = "#{text} #{TextNormalizer.normalize("#{email[:from_name]} #{email[:from]}")}"
      promotional = (Array(email[:gmail_categories]).map(&:to_s) & %w[promotions social]).any?
      topics = @data["topics"].is_a?(Hash) ? @data["topics"] : {}
      TOPICS.find do |type|
        topic = topics[type].is_a?(Hash) ? topics[type] : {}
        matches_terms?(text, topic["keywords"]) ||
          (!promotional && matches_terms?(text, topic["contextual_keywords"]) && matches_terms?(context, topic["context_keywords"]))
      end&.to_sym
    end

    private

    def email_text(email)
      TextNormalizer.normalize("#{email[:subject]} #{email[:body].to_s.slice(0, 1500)}")
    end

    def matches_terms?(text, terms)
      Array(terms).any? do |keyword|
        word = TextNormalizer.normalize(keyword.to_s).strip
        !word.empty? && text.match?(/(?<![[:alnum:]])#{Regexp.escape(word)}(?![[:alnum:]])/)
      end
    end
  end
end
