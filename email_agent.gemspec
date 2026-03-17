# frozen_string_literal: true

require_relative "lib/email_agent/version"

Gem::Specification.new do |spec|
  spec.name = "email_agent"
  spec.version = EmailAgent::VERSION
  spec.authors = ["Xaxitah"]
  spec.email = ["xaxita@msn.com"]

  spec.summary = "Agente para gerenciamento de e-mail institucional"
  spec.description = "Gem que automatiza leitura, classificacao e resposta de e-mails institucionais via IMAP/SMTP"
  spec.homepage = "https://github.com/Xaxitah/email-agent"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Xaxitah/email-agent"
  spec.metadata["changelog_uri"] = "https://github.com/Xaxitah/email-agent/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencias de runtime
  spec.add_dependency "net-imap"
  spec.add_dependency "net-smtp"
  spec.add_dependency "mail", "~> 2.8"
  spec.add_dependency "dotenv"

  # Dependencias de desenvolvimento
  spec.add_dependency "rspec"
  spec.add_dependency "standard"
end
