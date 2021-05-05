FROM ruby:2.6.6

ENV RACK_ENV production

EXPOSE 9292

RUN apt-get update && apt-get install -qq -y --no-install-recommends \
        build-essential \
        default-libmysqlclient-dev && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/src/app

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock /usr/src/app/

RUN bundle install

COPY . /usr/src/app

CMD ["bundle", "exec", "rackup"]
