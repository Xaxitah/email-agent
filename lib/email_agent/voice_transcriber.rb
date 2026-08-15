# frozen_string_literal: true

require "json"
require "net/http"
require "tmpdir"
require "timeout"
require "uri"

module EmailAgent
  class VoiceTranscriber
    TELEGRAM_API = "https://api.telegram.org/bot"
    TELEGRAM_FILE_API = "https://api.telegram.org/file/bot"

    class Error < StandardError; end

    def self.from_env(token:)
      return nil unless env_true?("VOICE_TRANSCRIPTION_ENABLED")

      root = File.expand_path("../..", __dir__)
      new(
        token: token,
        binary_path: ENV.fetch("WHISPER_BIN", File.join(root, "vendor/whisper/whisper-cli")),
        model_path: ENV.fetch("WHISPER_MODEL", File.join(root, "vendor/whisper/ggml-base.bin")),
        language: configured_value("VOICE_LANGUAGE", "pt"),
        max_seconds: ENV.fetch("VOICE_MAX_SECONDS", 120).to_i.clamp(1, 600),
        max_bytes: ENV.fetch("VOICE_MAX_BYTES", 8_388_608).to_i.clamp(1, 20_000_000),
        timeout_seconds: ENV.fetch("VOICE_TRANSCRIPTION_TIMEOUT", 180).to_i.clamp(10, 600),
        threads: ENV.fetch("WHISPER_THREADS", 2).to_i.clamp(1, 8)
      )
    end

    def self.env_true?(name)
      %w[1 true yes sim].include?(ENV.fetch(name, "").strip.downcase)
    end
    private_class_method :env_true?

    def self.configured_value(name, default)
      value = ENV.fetch(name, "").strip
      value.empty? ? default : value
    end
    private_class_method :configured_value

    def initialize(token:, binary_path:, model_path:, language:, max_seconds:, max_bytes:, timeout_seconds:, threads:)
      @token = token
      @binary_path = binary_path
      @model_path = model_path
      @language = language
      @max_seconds = max_seconds
      @max_bytes = max_bytes
      @timeout_seconds = timeout_seconds
      @threads = threads
    end

    def transcribe(file_id:, duration: nil, file_size: nil)
      raise Error, "Audio sem identificador do Telegram" if file_id.to_s.strip.empty?

      validate_media!(duration: duration, file_size: file_size)
      verify_installation!

      Dir.mktmpdir("email-agent-voice-") do |dir|
        input_path = File.join(dir, "input.audio")
        wav_path = File.join(dir, "input.wav")
        output_prefix = File.join(dir, "transcript")

        download_telegram_file(file_id, input_path)
        convert_to_wav(input_path, wav_path)
        run_whisper(wav_path, output_prefix)

        transcript_path = "#{output_prefix}.txt"
        raise Error, "Whisper nao gerou a transcricao" unless File.file?(transcript_path)

        transcript = File.read(transcript_path, encoding: "UTF-8").strip
        raise Error, "Nao foi possivel identificar fala no audio" if transcript.empty?

        transcript
      end
    end

    def verify_installation!
      raise Error, "whisper-cli nao encontrado" unless File.executable?(@binary_path)
      raise Error, "modelo Whisper nao encontrado" unless File.file?(@model_path)

      run_process(
        [@binary_path, "--version"],
        environment: whisper_environment,
        timeout: 10
      )
      true
    end

    private

    def validate_media!(duration:, file_size:)
      if duration && duration.to_i > @max_seconds
        raise Error, "Audio muito longo; o limite e #{@max_seconds} segundos"
      end
      if file_size && file_size.to_i > @max_bytes
        raise Error, "Audio muito grande; o limite e #{@max_bytes / 1_048_576} MB"
      end
    end

    def download_telegram_file(file_id, destination)
      info_uri = URI("#{TELEGRAM_API}#{@token}/getFile")
      info_response = Net::HTTP.post_form(info_uri, {file_id: file_id})
      info = JSON.parse(info_response.body)
      file_path = info.dig("result", "file_path").to_s
      raise Error, "Telegram nao forneceu o arquivo de audio" unless info["ok"] && !file_path.empty?

      download_uri = URI("#{TELEGRAM_FILE_API}#{@token}/#{file_path}")
      response = Net::HTTP.get_response(download_uri)
      raise Error, "Falha ao baixar audio do Telegram" unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Audio excedeu o limite de tamanho" if response.body.bytesize > @max_bytes

      File.binwrite(destination, response.body)
    rescue JSON::ParserError
      raise Error, "Telegram retornou uma resposta invalida"
    end

    def convert_to_wav(input_path, wav_path)
      run_process(
        ["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", input_path,
          "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", wav_path],
        timeout: [@timeout_seconds / 3, 30].max
      )
    rescue Error
      raise Error, "Nao foi possivel converter o audio"
    end

    def run_whisper(wav_path, output_prefix)
      command = [
        @binary_path,
        "--model", @model_path,
        "--file", wav_path,
        "--language", @language,
        "--threads", @threads.to_s,
        "--no-timestamps",
        "--no-prints",
        "--output-txt",
        "--output-file", output_prefix
      ]

      run_process(command, environment: whisper_environment, timeout: @timeout_seconds)
    rescue Error
      raise Error, "Falha ao transcrever o audio"
    end

    def whisper_environment
      library_path = File.dirname(@binary_path)
      {"LD_LIBRARY_PATH" => [library_path, ENV["LD_LIBRARY_PATH"]].compact.join(":")}
    end

    def run_process(command, environment: {}, timeout:)
      process_id = Process.spawn(environment, *command, out: File::NULL, err: File::NULL)
      status = nil

      begin
        Timeout.timeout(timeout) do
          _pid, status = Process.wait2(process_id)
        end
      rescue Timeout::Error
        Process.kill("TERM", process_id)
        Process.wait(process_id)
        raise Error, "Processamento de audio excedeu o tempo limite"
      end

      raise Error, "Processamento de audio falhou" unless status.success?
    rescue Errno::ENOENT
      raise Error, "Dependencia de audio nao encontrada"
    rescue Errno::ESRCH, Errno::ECHILD
      raise Error, "Processamento de audio foi interrompido"
    end
  end
end
