# frozen_string_literal: true

# Script para configurar o bot do Telegram no .env
# Uso: ruby examples/setup_telegram.rb

require "net/http"
require "uri"
require "json"
require "dotenv/load"
require "io/console"

ENV_FILE = File.expand_path("../.env", __dir__)

puts "=" * 60
puts "  CONFIGURACAO DO BOT TELEGRAM"
puts "=" * 60
puts ""
puts "Antes de continuar:"
puts "  1. Abra o Telegram e acesse @BotFather"
puts "  2. Se o token anterior foi exposto, revogue-o:"
puts "     Mande /mybots → selecione o bot → API Token → Revoke"
puts "  3. Copie o novo token"
puts "  4. Mande qualquer mensagem ('oi') pro seu bot"
puts ""

print "Cole o token do bot aqui: "
token = $stdin.noecho(&:gets).to_s.chomp.strip
puts

if token.empty?
  puts "Token não pode ser vazio!"
  exit 1
end

puts "\n🔍 Buscando Chat ID... (certifique-se de ter mandado 'oi' pro bot)"

uri = URI("https://api.telegram.org/bot#{token}/getUpdates")
response = Net::HTTP.get(uri)
data = JSON.parse(response)

unless data["ok"]
  puts "❌ Token inválido ou erro na API: #{data["description"]}"
  exit 1
end

if data["result"].empty?
  puts "❌ Nenhuma mensagem encontrada."
  puts "   → Abra o Telegram, encontre seu bot e mande 'oi'"
  puts "   → Depois rode esse script novamente"
  exit 1
end

chat = data["result"].last.dig("message", "chat")
chat_id = chat&.fetch("id")
chat_name = chat&.fetch("first_name", chat&.fetch("title", "?"))

puts "✅ Chat ID encontrado: #{chat_id} (#{chat_name})"

# Testa enviando uma mensagem
puts "\n📤 Enviando mensagem de teste..."
test_uri = URI("https://api.telegram.org/bot#{token}/sendMessage")
test_params = {
  chat_id: chat_id.to_s,
  text: "✅ Email Agent conectado com sucesso!\n\nVou te notificar sobre e-mails urgentes e enviar resumos diários.",
  parse_mode: "HTML"
}
test_resp = Net::HTTP.post_form(test_uri, test_params)
test_data = JSON.parse(test_resp.body)

if test_data["ok"]
  puts "✅ Mensagem de teste enviada! Verifique o Telegram."
else
  puts "⚠️  Mensagem não enviada: #{test_data["description"]}"
end

# Salva no .env
puts "\n💾 Salvando no .env..."
env_content = File.read(ENV_FILE)

# Remove linhas antigas do Telegram se existirem
env_content.gsub!(/^TELEGRAM_BOT_TOKEN=.*\n?/, "")
env_content.gsub!(/^TELEGRAM_CHAT_ID=.*\n?/, "")

# Adiciona as novas
env_content += "\nTELEGRAM_BOT_TOKEN=#{token}\n"
env_content += "TELEGRAM_CHAT_ID=#{chat_id}\n"

File.write(ENV_FILE, env_content)
puts "✅ .env atualizado com token e chat_id!"
puts ""
puts "Agora rode: ruby examples/test_run.rb"
puts "=" * 60
