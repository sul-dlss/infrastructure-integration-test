# DOR integration test

## Installation

This script depends on having firefox downloaded

1. `bundle install`
1. `curl https://github.com/mozilla/geckodriver/releases/download/v0.26.0/geckodriver-v0.26.0-macos.tar.gz`
1. `tar -zxvf geckodriver-v0.26.0-macos.tar.gz`
1. `export PATH=$PATH:$(pwd)`


## Run

`bundle exec rspec`

You will be prompted to put in your credentials and then to approve a duo push.
