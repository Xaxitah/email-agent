#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/email_agent"

transcriber = EmailAgent::VoiceTranscriber.from_env(
  token: ENV.fetch("TELEGRAM_BOT_TOKEN", "verification-only")
)

if transcriber
  transcriber.verify_installation!
  puts "Whisper local: binario e modelo encontrados."
else
  puts "Whisper local: verificacao ignorada porque a transcricao esta desabilitada."
end
