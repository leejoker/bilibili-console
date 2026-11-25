FROM ruby:latest

ADD ./ /app/

RUN bundle install && rake install
