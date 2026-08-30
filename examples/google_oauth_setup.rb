# frozen_string_literal: true

# Obtem um refresh token do Google para o CalendarAgent.
#
# Uso:
#   export GOOGLE_CLIENT_ID="...apps.googleusercontent.com"
#   export GOOGLE_CLIENT_SECRET="..."
#   ruby examples/google_oauth_setup.rb
#
# O script sobe um servidor local em 127.0.0.1, imprime a URL de consentimento,
# recebe o codigo de autorizacao no redirecionamento e o troca por tokens.
# Nada e enviado para fora do seu computador alem das chamadas ao proprio Google.
#
# O refresh token impresso no final e uma credencial: guarde nas variaveis
# protegidas do ambiente, nunca no repositorio.

require "socket"
require "net/http"
require "uri"
require "json"
require "securerandom"

AUTH_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
CALENDAR_LIST = "https://www.googleapis.com/calendar/v3/users/me/calendarList"

# Escopo minimo: criar e editar eventos. Nao le e-mail, nao apaga agenda,
# nao acessa contatos. Escopo "sensivel", nao "restrito" — nao exige auditoria.
SCOPE = "https://www.googleapis.com/auth/calendar.events"

def fetch_env(name)
  value = ENV[name].to_s.strip
  if value.empty?
    abort "Falta a variavel #{name}. Defina-a antes de rodar (veja o cabecalho deste arquivo)."
  end
  value
end

client_id = fetch_env("GOOGLE_CLIENT_ID")
client_secret = fetch_env("GOOGLE_CLIENT_SECRET")

# OAUTH_PORT fixa a porta. Necessario quando o script roda numa maquina
# diferente do navegador — ex.: rodando na box e acessando por tunel SSH:
#   ssh -L 8765:127.0.0.1:8765 root@<box>
# O Google so aceita loopback (127.0.0.1 / localhost) como redirect de app
# Desktop, entao o tunel e o que faz o navegador do PC alcancar o script.
requested_port = ENV.fetch("OAUTH_PORT", "0").to_i
server = TCPServer.new("127.0.0.1", requested_port)
port = server.addr[1]
redirect_uri = "http://127.0.0.1:#{port}"
state = SecureRandom.hex(16)

auth_url = "#{AUTH_ENDPOINT}?" + URI.encode_www_form(
  client_id: client_id,
  redirect_uri: redirect_uri,
  response_type: "code",
  scope: SCOPE,
  # access_type=offline + prompt=consent sao o que fazem o Google devolver
  # um refresh token. Sem os dois, voce recebe apenas um access token de 1h.
  access_type: "offline",
  prompt: "consent",
  state: state
)

puts
puts "=" * 72
puts "Abra esta URL no navegador, logado na conta que vai receber a agenda:"
puts
puts auth_url
puts
puts "=" * 72
puts
puts "Se aparecer o aviso \"O Google nao verificou este app\", clique em"
puts "Avancado e depois em \"Acessar <nome do app> (nao seguro)\". Esse aviso e"
puts "esperado num app pessoal nao verificado — voce e o autor e o unico usuario."
puts
puts "Aguardando o redirecionamento em #{redirect_uri} ..."

client = server.accept
request_line = client.gets.to_s
query = request_line.split(" ")[1].to_s
params = URI.decode_www_form(URI(query).query.to_s).to_h

body = if params["error"]
  "Autorizacao negada: #{params["error"]}"
elsif params["state"] != state
  "Parametro state nao confere. Possivel adulteracao — nada foi trocado."
else
  "Autorizacao recebida. Pode fechar esta aba e voltar ao terminal."
end

client.print "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n#{body}"
client.close
server.close

abort("\n#{body}") unless params["code"] && params["state"] == state

puts "\nTrocando o codigo por tokens..."

response = Net::HTTP.post_form(URI(TOKEN_ENDPOINT), {
  code: params["code"],
  client_id: client_id,
  client_secret: client_secret,
  redirect_uri: redirect_uri,
  grant_type: "authorization_code"
})

tokens = JSON.parse(response.body)

unless response.is_a?(Net::HTTPSuccess) && tokens["refresh_token"]
  puts "\nFalhou. Resposta do Google:"
  puts JSON.pretty_generate(tokens)
  puts
  puts "Se veio access_token mas nao refresh_token, o Google ja tinha um"
  puts "consentimento ativo para este app. Revogue em"
  puts "https://myaccount.google.com/permissions e rode de novo."
  exit 1
end

puts
puts "=" * 72
puts "GOOGLE_REFRESH_TOKEN=#{tokens["refresh_token"]}"
puts "=" * 72
puts
puts "Guarde essa linha nas variaveis protegidas do ambiente."
puts "Ela nao deve ir para o GitHub, nem para chat, nem para documento."
puts

# Lista as agendas para voce descobrir o GOOGLE_CALENDAR_ID sem cacar na interface.
uri = URI(CALENDAR_LIST)
req = Net::HTTP::Get.new(uri)
req["Authorization"] = "Bearer #{tokens["access_token"]}"
list = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

if list.is_a?(Net::HTTPSuccess)
  puts "Agendas disponiveis nesta conta:"
  puts
  JSON.parse(list.body).fetch("items", []).each do |cal|
    marker = cal["primary"] ? " (principal)" : ""
    puts "  #{cal["summary"]}#{marker}"
    puts "    GOOGLE_CALENDAR_ID=#{cal["id"]}"
    puts
  end
  puts "Use o id da agenda secundaria que voce criou para o agente,"
  puts "nunca o da principal — assim um erro nunca atinge sua agenda real."
else
  puts "Nao consegui listar as agendas (HTTP #{list.code})."
  puts "Pegue o id em Google Agenda > Configuracoes da agenda > Integrar agenda."
end
