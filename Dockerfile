FROM ruby:latest

ADD ./ /app/

RUN gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/ && bundle install && rake install
