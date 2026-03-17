#!/usr/bin/env ruby
require_relative "../lib/email_agent"

puts "============================================"
puts "  EMAIL AGENT - Verificador Multi-Conta"
puts "============================================"
puts ""

manager = EmailAgent::Manager.new
manager.report
