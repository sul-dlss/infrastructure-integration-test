[![Build Status](https://travis-ci.org/sul-dlss/infrastructure-integration-test.svg?branch=master)](https://travis-ci.org/sul-dlss/infrastructure-integration-test)

# DOR integration test

This script drives a browser to do some integration testing of the SDR as a system.

## Installation

This script depends on having Firefox downloaded.

1. `bundle install`
1. Download geckodriver `curl -L --output geckodriver-v0.26.0-macos.tar.gz https://github.com/mozilla/geckodriver/releases/download/v0.26.0/geckodriver-v0.26.0-macos.tar.gz`
1. Uncompress it `tar -zxvf geckodriver-v0.26.0-macos.tar.gz`
1. Put geckodriver on the path `export PATH=$PATH:$(pwd)`

## Run

You must be on VPN in order to run this script.

`bundle exec rspec`

You will be prompted to put in your credentials and then to approve a duo push.

## Add New Tests

Please use the integration-testing APO and collection when feasible:
- integration-testing APO: qc410yz8746
- integration-testing collection: bc778pm9866
