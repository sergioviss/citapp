#!/bin/bash
export PATH="/home/zoe/.rbenv/shims:/home/zoe/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
cd /home/zoe/template_web_v8

echo "--- Ruby version ---"
ruby -v

echo "--- Bundle install ---"
bundle install

echo "--- Database prepare ---"
bin/rails db:prepare

echo "--- Rails version ---"
bin/rails -v
