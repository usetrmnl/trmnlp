ARG RUBY_VERSION=3.4.1
# ----- BUILD -----

FROM ruby:${RUBY_VERSION} AS builder

WORKDIR /app

RUN mkdir -p ./lib/trmnlp/

COPY Gemfile \
    Gemfile.lock \
    trmnl_preview.gemspec \
    ./

COPY /lib/ /app/lib/

RUN bundle install

# ----- RUN -----

FROM ruby:${RUBY_VERSION} AS runner

RUN apt-get update && apt-get install -y \
    imagemagick \
    firefox-esr

WORKDIR /app

COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

COPY Gemfile \
    Gemfile.lock \
    trmnl_preview.gemspec \
    LICENSE.txt \
    README.md \
    /app/

COPY lib/ /app/lib/
COPY web/ /app/web/
COPY bin/ /app/bin/

RUN bundle install

EXPOSE 4567

WORKDIR /plugin
ENTRYPOINT [ "/app/bin/trmnlp" ]
