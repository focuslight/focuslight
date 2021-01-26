FROM ruby:2.7.2
RUN apt-get update && apt-get install -y \
    build-essential \
    default-mysql-client \
    libsqlite3-dev \
    rrdtool librrd-dev

WORKDIR /app

ADD Gemfile /app/Gemfile
ADD Gemfile.lock /app/Gemfile.lock
ADD focuslight.gemspec /app/focuslight.gemspec
ADD lib/focuslight/version.rb /app/lib/focuslight/version.rb
RUN gem install bundler
RUN bundle install
ADD . /app
RUN rm -rf /var/lib/apt/lists/*
