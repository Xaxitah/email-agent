# frozen_string_literal: true

module EmailAgent
  class Account
    attr_reader :name, :user, :host, :port, :password

    def initialize(name:, host:, user:, password:, port: 993)
      @name = name
      @host = host
      @port = port.to_i
      @user = user
      @password = password
      @imap = nil
    end

    def connect
      @imap = Net::IMAP.new(@host, port: @port, ssl: true)
      @imap.login(@user, @password)
      puts "[#{@name}] Conectado como #{@user}"
      self
    rescue => e
      puts "[#{@name}] ERRO ao conectar: #{e.message}"
      nil
    end

    def fetch_unread(mailbox: "INBOX", limit: 10)
      @imap.select(mailbox)
      ids = @imap.search(["NOT", "SEEN"])
      ids = ids.last(limit) if ids.length > limit

      ids.map do |id|
        data = @imap.fetch(id, "RFC822").first
        Mail.new(data.attr["RFC822"])
      end
    rescue => e
      puts "[#{@name}] ERRO ao buscar e-mails: #{e.message}"
      []
    end

    def disconnect
      @imap&.logout
      @imap&.disconnect
      puts "[#{@name}] Desconectado."
    rescue => e
      puts "[#{@name}] Erro ao desconectar: #{e.message}"
    end
  end
end
