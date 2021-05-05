FROM ruby:2.6.6-alpine

ENV RACK_ENV production

RUN apk add --no-cache build-base libcurl mariadb-dev

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

EXPOSE 9292

CMD ["bundle", "exec", "rackup"]
