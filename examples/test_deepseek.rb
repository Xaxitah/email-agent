#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/email_agent"

client = EmailAgent::AiClient.from_env
unless client&.provider == "deepseek"
  warn "Configure AI_PROVIDER=deepseek e DEEPSEEK_API_KEY antes de executar este teste."
  exit 1
end

puts "Testando DeepSeek com o modelo #{client.model}..."
response = client.complete(
  "Responda somente com: DeepSeek conectado com sucesso.",
  max_tokens: 40
)
puts response
