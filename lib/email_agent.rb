# frozen_string_literal: true

require "dotenv/load"
require "net/imap"
require "mail"
require_relative "email_agent/version"
require_relative "email_agent/account"
require_relative "email_agent/reader"
require_relative "email_agent/classifier"
require_relative "email_agent/manager"
require_relative "email_agent/notifier"
require_relative "email_agent/ai_client"
require_relative "email_agent/voice_transcriber"
require_relative "email_agent/scheduler"

module EmailAgent
  class Error < StandardError; end
end
require_relative "email_agent/telegram_bot"
