ARG RUBY_VERSION=4.0.4
# ----- BUILD -----

# Pin the Debian suite explicitly (trixie) rather than letting `-slim` float
# to the next stable release — that keeps the apt-installed runtimes
# (imagemagick / python3 / nodejs / php-cli) on a known package archive
# instead of silently jumping a major version when Debian cuts a release.
FROM ruby:${RUBY_VERSION}-slim-trixie AS builder

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

FROM ruby:${RUBY_VERSION}-slim-trixie AS runner

# Install runtime dependencies.
# python3, nodejs, and php-cli are bundled so serverless transforms
# (lib/trmnlp/transform_backend/subprocess.rb) can shell out to the
# author's chosen runtime without a sidecar container. imagemagick on
# trixie ships IM7 (the `magick` binary trmnlp's PNG quantizer needs).
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    imagemagick \
    firefox-esr \
    python3 \
    nodejs \
    php-cli \
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
COPY db/ /app/db/

# Put trmnlp on PATH so it is callable as a bare command in an
# interactive shell, not only via the ENTRYPOINT.
RUN ln -s /app/bin/trmnlp /usr/local/bin/trmnlp

EXPOSE 4567
WORKDIR /plugin
ENTRYPOINT [ "/app/bin/trmnlp" ]
