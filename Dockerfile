ARG RUBY_VERSION=3.4.1
# ----- BUILD -----

FROM ruby:${RUBY_VERSION}-slim AS builder

WORKDIR /app

# Install build dependencies for C extensions
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ./lib/trmnlp/

COPY Gemfile \
    Gemfile.lock \
    trmnl_preview.gemspec \
    ./

COPY /lib/ /app/lib/

RUN bundle install

# ----- RUN -----

FROM ruby:${RUBY_VERSION}-slim AS runner

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    imagemagick \
    firefox-esr \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy installed gems from builder
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
COPY templates/ /app/templates/

EXPOSE 4567
git
WORKDIR /plugin
ENTRYPOINT [ "/app/bin/trmnlp" ]
