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

      uids.each do |uid|
        raw = imap.fetch(uid, "BODY.PEEK[]").first.attr["BODY[]"]
        mail = Mail.read_from_string(raw)

        summary = self.class.summarize(mail)
        summary[:uid] = uid
        summary[:categories] = Classifier.classify(summary)
        emails << summary
      end

      emails
    ensure
      disconnect_safely(imap)
    end

    def self.summarize(mail)
      {
        message_id: safe_encode(mail.message_id),
        from: mail.from&.first,
        subject: safe_encode(mail.subject),
        date: mail.date,
        body: safe_encode(extract_body(mail))
      }
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
