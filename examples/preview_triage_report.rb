# frozen_string_literal: true

# Apenas dados ficticios; nao acessa IMAP, IA nem Telegram.
require_relative "../lib/email_agent"

subjects = {
  direto: "Pedido direto ao Douglas",
  reuniao_geral: "Reuniao geral da equipe",
  dialab: "Comunicado DIALAB",
  liv: "Material LIV",
  outro: "Prazo administrativo",
  propaganda: "Oferta comercial"
}
emails = subjects.map do |type, subject|
  {
    subject: subject, from: "exemplo@escola.invalid", categories: [:geral],
    triage: {tipo: type, importancia: (type == :propaganda) ? 0 : 2,
             motivo: "Exemplo ficticio de aviso para revisao.", prazo: (type == :reuniao_geral) ? "07/10, 14h (exemplo)" : nil}
  }
end
emails << {subject: "Informativo", triage: {tipo: :outro, importancia: 1, motivo: "Informativo", prazo: nil}}

report = EmailAgent::ScheduledReport.new("Conta de exemplo" => {emails: emails, error: nil})
puts report.messages("Relatorio de teste da fatia 6").join("\n\n")
