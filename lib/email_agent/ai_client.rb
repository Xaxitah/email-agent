# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module EmailAgent
  class AiClient
    DEEPSEEK_API = "https://api.deepseek.com/chat/completions"
    ANTHROPIC_API = "https://api.anthropic.com/v1/messages"

    attr_reader :provider, :model

    def self.from_env
      deepseek_key = ENV.fetch("DEEPSEEK_API_KEY", "").strip
      anthropic_key = ENV.fetch("ANTHROPIC_API_KEY", "").strip
      provider = ENV.fetch("AI_PROVIDER", "").strip.downcase
      provider = "deepseek" if provider.empty? && !deepseek_key.empty?
      provider = "anthropic" if provider.empty? && deepseek_key.empty? && !anthropic_key.empty?

      return nil if provider.empty?

      case provider
      when "deepseek"
        raise EmailAgent::Error, "DEEPSEEK_API_KEY deve ser configurada" if deepseek_key.empty?

        new(provider: provider, api_key: deepseek_key,
          model: configured_value("DEEPSEEK_MODEL", "deepseek-v4-flash"))
      when "anthropic"
        raise EmailAgent::Error, "ANTHROPIC_API_KEY deve ser configurada" if anthropic_key.empty?

        new(provider: provider, api_key: anthropic_key,
          model: configured_value("ANTHROPIC_MODEL", "claude-haiku-4-5-20251001"))
      else
        raise EmailAgent::Error, "AI_PROVIDER invalido: use deepseek ou anthropic"
      end
    end

    def self.configured_value(name, default)
      value = ENV.fetch(name, "").strip
      value.empty? ? default : value
    end
    private_class_method :configured_value

    def initialize(provider:, api_key:, model:)
      @provider = provider
      @api_key = api_key
      @model = model
    end

    def complete(prompt, max_tokens: 600)
      case provider
      when "deepseek"
        complete_deepseek(prompt, max_tokens: max_tokens)
      when "anthropic"
        complete_anthropic(prompt, max_tokens: max_tokens)
      end
    end

    private

    def complete_deepseek(prompt, max_tokens:)
      request = Net::HTTP::Post.new(URI(DEEPSEEK_API))
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@api_key}"
      request.body = JSON.generate({
        model: model,
        max_tokens: max_tokens,
        thinking: {type: "disabled"},
        messages: [{role: "user", content: prompt}]
      })

      data = perform_json_request(request, URI(DEEPSEEK_API))
      content = data.dig("choices", 0, "message", "content").to_s.strip
      raise "DeepSeek retornou uma resposta vazia" if content.empty?

      content
    end

    def complete_anthropic(prompt, max_tokens:)
      request = Net::HTTP::Post.new(URI(ANTHROPIC_API))
      request["Content-Type"] = "application/json"
      request["x-api-key"] = @api_key
      request["anthropic-version"] = "2023-06-01"
      request.body = JSON.generate({
        model: model,
        max_tokens: max_tokens,
        messages: [{role: "user", content: prompt}]
      })

      data = perform_json_request(request, URI(ANTHROPIC_API))
      content = data.dig("content", 0, "text").to_s.strip
      raise "Anthropic retornou uma resposta vazia" if content.empty?

      content
    end

    def perform_json_request(request, uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 30

      response = http.request(request)
      raise "#{provider} HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise "#{provider} retornou JSON invalido"
    end
  end
end
