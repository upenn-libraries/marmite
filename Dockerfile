FROM ruby:2.6.6

ENV RACK_ENV production

RUN apt-get update && apt-get install -qq -y --no-install-recommends \
        build-essential \
        default-libmysqlclient-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock /usr/src/app/

RUN bundle install

COPY . /usr/src/app

EXPOSE 9292

CMD ["bundle", "exec", "rackup"]
