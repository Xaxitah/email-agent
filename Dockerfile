FROM ruby:3.4.7-slim-bookworm

ENV BUNDLE_PATH=/usr/local/bundle

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    ffmpeg \
    libgomp1 \
    libjemalloc2 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock email_agent.gemspec ./
COPY lib/email_agent/version.rb lib/email_agent/version.rb
RUN gem install --no-document bundler:2.6.9 \
  && bundle install

COPY . .
RUN sh bin/install_whisper \
  && bundle exec ruby examples/verify_voice.rb

CMD ["bundle", "exec", "ruby", "examples/bot_run.rb"]
