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

      imap = Net::IMAP.new(@account.host, port: @account.port, ssl: true)
      imap.login(@account.user, @account.password)
      imap.select("INBOX")

      uids = imap.search(["UNSEEN"]).last(limit)

      uids.each do |uid|
        raw = imap.fetch(uid, "RFC822").first.attr["RFC822"]
        mail = Mail.read_from_string(raw)

        summary = self.class.summarize(mail)
        summary[:categories] = Classifier.classify(summary)
        emails << summary
      end

      imap.logout
      imap.disconnect
      emails
    rescue StandardError => e
      raise e
    end

    def self.summarize(mail)
      {
        from:    mail.from&.first,
        subject: safe_encode(mail.subject),
        date:    mail.date,
        body:    safe_encode(extract_body(mail))
      }
    end

    def self.extract_body(mail)
      if mail.multipart?
        part = mail.parts.find { |p| p.content_type.start_with?("text/plain") }
        part&.body&.decoded || "(sem texto plano)"
      else
        mail.body.decoded
      end
    rescue StandardError => e
      "(erro ao ler corpo: #{e.message})"
    end

    def self.safe_encode(text)
      return "" if text.nil?
      text.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    end
  end
end