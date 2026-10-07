ARG RUBY_VERSION=4.0.6
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
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ./lib/trmnlp/

COPY Gemfile \
    Gemfile.lock \
    trmnl_preview.gemspec \
    ./

COPY /lib/ /app/lib/

RUN bundle install

# geckodriver, which Selenium drives Firefox through. Without one in the image, Selenium downloads it
# on every run that draws a screen. The build takes the latest release, which is the one Mozilla
# keeps working with the current Firefox, and the runner stage starts Firefox on it once, so an
# image whose two do not work together is never built.
ARG TARGETARCH
RUN case "$TARGETARCH" in arm64) arch=linux-aarch64 ;; *) arch=linux64 ;; esac && \
    latest="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/mozilla/geckodriver/releases/latest)" && \
    version="${latest##*/}" && \
    curl -fsSL "https://github.com/mozilla/geckodriver/releases/download/$version/geckodriver-$version-$arch.tar.gz" | \
    tar -xz -C /usr/local/bin geckodriver

# ----- RUN -----

FROM ruby:${RUBY_VERSION}-slim-trixie AS runner

# Install runtime dependencies.
# python3, node and php-cli are bundled so serverless transforms
# (lib/trmnlp/transform_backend/subprocess.rb) can shell out to the
# author's chosen runtime without a sidecar container. imagemagick on
# trixie ships IM7 (the `magick` binary trmnlp's PNG quantizer needs).
# zbar-tools reads QR codes for `trmnlp test`'s have_qr_code.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    imagemagick \
    firefox-esr \
    python3 \
    php-cli \
    libfaketime \
    zbar-tools \
    && rm -rf /var/lib/apt/lists/*

# Node from its own image: Debian's is 20, and only Node 24 sends fetch through HTTPS_PROXY, which
# `trmnlp test` mocks a transform's requests with.
COPY --from=node:24-trixie-slim /usr/local/bin/node /usr/local/bin/node

WORKDIR /app

# Copy installed gems from builder
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=builder /usr/local/bin/geckodriver /usr/local/bin/geckodriver
# Named here so Selenium takes it as it is. Found on the PATH only, Selenium still asks GitHub for
# the latest release on every start.
ENV SE_GECKODRIVER=/usr/local/bin/geckodriver

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

# Start Firefox once on the geckodriver above. The build fails here when they do not work together.
RUN ruby -r/app/lib/trmnlp/firefox_driver -e 'TRMNLP::FirefoxDriver.build.quit' && rm -rf /root/.cache /root/.mozilla /tmp/*

# Put trmnlp on PATH so it is callable as a bare command in an
# interactive shell, not only via the ENTRYPOINT.
RUN ln -s /app/bin/trmnlp /usr/local/bin/trmnlp

EXPOSE 4567
WORKDIR /plugin
ENTRYPOINT [ "/app/bin/trmnlp" ]
