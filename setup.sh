#!/bin/bash

# Copyright (c) 2021 leejoker
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

git pull
bundle install
gem build bilibili_console.gemspec
gem install bilibili_console-0.0.3.gem
echo "Install Over"
