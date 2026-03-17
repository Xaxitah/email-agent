# frozen_string_literal: true

require_relative "../lib/email_agent"

puts "🚀 Iniciando Email Agent Bot..."
EmailAgent::TelegramBot.new.run
