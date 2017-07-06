
FROM ruby:2.4.0

MAINTAINER Kate Lynch <katherly@upenn.edu>

ENV RACK_ENV production

EXPOSE 9292

RUN apt-get update && apt-get install -qq -y --no-install-recommends \
         build-essential \
         libmysqlclient-dev

RUN mkdir -p /usr/src/app

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock /usr/src/app/

RUN bundle install

COPY . /usr/src/app

RUN rm -rf /var/lib/apt/lists/*

CMD ["bundle", "exec", "rackup"]