FROM ruby:3.4.1

WORKDIR /app

COPY Gemfile \
    Gemfile.lock \
    LICENSE.txt \
    README.md \
    /app/

COPY lib/ /app/lib/
COPY views/ /app/views/
COPY exe/ /app/exe/

RUN bundle install

EXPOSE 4567

ENTRYPOINT [ "/app/exe/trmnlp", "serve", "/plugin", "-b", "0.0.0.0" ]
