# frozen_string_literal: true

require "net/imap"
require "mail"

module EmailAgent
  class Reader
    def initialize(account)
      @account = account
    end

    def fetch_unread(limit: 10)
      emails = []
      imap = nil

      imap = Net::IMAP.new(@account.host, port: @account.port, ssl: true)
      imap.login(@account.user, @account.password)
      # EXAMINE opens the mailbox read-only. BODY.PEEK[] fetches the complete
      # message without setting the \\Seen flag.
      imap.examine("INBOX")

      uids = imap.search(["UNSEEN"]).last(limit)
      gmail_categories = fetch_gmail_categories(imap, uids)

      uids.each do |uid|
        raw = imap.fetch(uid, "BODY.PEEK[]").first.attr["BODY[]"]
        mail = Mail.read_from_string(raw)

        summary = self.class.summarize(mail)
        summary[:uid] = uid
        summary[:gmail_categories] = gmail_categories.fetch(uid, [])
        summary[:categories] = Classifier.classify(summary)
        emails << summary
      end

      emails
    ensure
      disconnect_safely(imap)
    end

    # Cabecalhos que o Classifier usa para reconhecer envio automatico ou de
    # lista. Ficam no resumo para a classificacao nao ter que adivinhar pelo
    # endereco do remetente, que e um sinal ruim: comunicacao institucional
    # legitima sai de no-reply o tempo todo.
    AUTOMATION_HEADER_FIELDS = {
      list_id: "List-Id",
      list_unsubscribe: "List-Unsubscribe",
      precedence: "Precedence",
      auto_submitted: "Auto-Submitted"
    }.freeze

    def self.summarize(mail)
      {
        message_id: safe_encode(mail.message_id),
        from: mail.from&.first,
        from_name: safe_encode(mail[:from]&.display_names&.first),
        subject: safe_encode(mail.subject),
        date: mail.date,
        headers: extract_headers(mail),
        body: safe_encode(extract_body(mail))
      }
    end

    def self.extract_headers(mail)
      AUTOMATION_HEADER_FIELDS.transform_values do |field|
        safe_encode(mail[field]&.to_s)
      end.merge(%i[to cc reply_to].to_h do |field|
        [field, Array(mail.public_send(field)).map { |address| safe_encode(address) }]
      end)
    rescue
      {}
    end

    def self.extract_body(mail)
      if mail.multipart?
        part = mail.parts.find { |p| p.content_type.start_with?("text/plain") }
        part&.body&.decoded || "(sem texto plano)"
      else
        mail.body.decoded
      end
    rescue => e
      "(erro ao ler corpo: #{e.message})"
    end

    def self.safe_encode(text)
      return "" if text.nil?
      text.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    end

    private

    def fetch_gmail_categories(imap, uids)
      return {} if uids.empty?
      return {} unless @account.host.to_s.downcase == "imap.gmail.com"
      return {} unless imap.capable?("X-GM-EXT-1")

      categories = Hash.new { |hash, key| hash[key] = [] }
      %i[promotions social].each do |category|
        matches = imap.search(["UNSEEN", "X-GM-RAW", "category:#{category}"])
        (matches & uids).each { |uid| categories[uid] << category }
      end
      categories
    rescue Net::IMAP::Error
      # A capability alone is not proof: discard partial signals if SEARCH fails.
      {}
    end

    def disconnect_safely(imap)
      return unless imap

      imap.logout unless imap.disconnected?
    rescue
      nil
    ensure
      begin
        imap.disconnect unless imap.disconnected?
      rescue
        nil
      end
    end
  end
end
