#!/usr/bin/env ruby

puts "============================================"
puts "  EMAIL AGENT - Configuracao de Contas"
puts "============================================"
puts ""

print "Quantas contas deseja configurar? "
count = gets.chomp.to_i

if count < 1
  puts "Nenhuma conta configurada. Saindo."
  exit
end

lines = ["# Configuracao gerada pelo setup", "ACCOUNT_COUNT=#{count}", ""]

count.times do |i|
  n = i + 1
  puts ""
  puts "--- Conta #{n} de #{count} ---"

  print "  Nome da conta (ex: IFMS, Gmail, Elite): "
  name = gets.chomp

  print "  Servidor IMAP (ex: imap.gmail.com): "
  host = gets.chomp

  print "  Porta IMAP [993]: "
  port = gets.chomp
  port = "993" if port.empty?

  print "  Seu e-mail: "
  user = gets.chomp

  print "  Senha (ou senha de app): "
  password = gets.chomp

  lines << "# Conta #{n} - #{name}"
  lines << "ACCOUNT_#{n}_NAME=#{name}"
  lines << "ACCOUNT_#{n}_HOST=#{host}"
  lines << "ACCOUNT_#{n}_PORT=#{port}"
  lines << "ACCOUNT_#{n}_USER=#{user}"
  lines << "ACCOUNT_#{n}_PASSWORD=#{password}"
  lines << ""
end

env_path = File.join(__dir__, "..", ".env")
File.write(env_path, lines.join("\n"))

puts ""
puts "============================================"
puts "  #{count} conta(s) salva(s) em .env"
puts "  Para testar: ruby examples/test_run.rb"
puts "============================================"
