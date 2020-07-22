[![Build Status](https://travis-ci.org/sul-dlss/infrastructure-integration-test.svg?branch=master)](https://travis-ci.org/sul-dlss/infrastructure-integration-test)

# SDR Integration Tests

A set of Capybara tests that drive a browser to do inter-system integration testing of SDR in the staging or QA environment.

## Installation

The tests depend on having Firefox (default) or Chrome downloaded.

1. `bundle install`
1. `bundle exec rake webdrivers:geckodriver:update`

See the `Configuration` section below for instructions on using Chrome and on tweaking default browser settings.

## Prerequisites

1. Connect to Stanford VPN (full-tunnel or split-tunnel)
1. Ensure you have a valid, non-expired Kerberos ticket (use `klist` to verify, or run `kinit` to refresh)

See the `Configuration` section below for instructions on allowing SSH credential delegation.

## Run Tests

By default, the integration tests run in the SDR staging environment:

`bundle exec rspec`

To test in the SDR QA environment, run tests with the `SDR_ENV` environment variable, like so:

```shell
SDR_ENV=qa bundle exec rspec
```

No matter which environment you run tests in, you may be prompted to type in your Stanford credentials and will then need to approve a multi-factor authentication push. If you tire of typing in your credentials, see the `Configuration` section below for help securely storing them.

## Add New Tests

Please use the integration-testing APO and collection when feasible:

* APO: druid:qc410yz8746 (available as `Settings.default_apo`)
* Collection: druid:bc778pm9866 (available as `Settings.default_collection`)

## Configuration

### Allow Credential Delegation

Configure your SSH client to allow delegation of Kerberos credentials (required for any tests that use `scp`), by adding the following to `~/.ssh/config` or wherever your system stores SSH configuration:

```
# Add to appropriate place, such as:
Host *.stanford.edu
    GSSAPIDelegateCredentials yes
```

### Use Chrome Browser

1. `bundle install`
1. `bundle exec rake webdrivers:chromedriver:update`
1. Set `browser.driver` to `chrome` in `config/settings.local.yml`

### Change Browser Window Size

If you find you need to modify the default window size for either browser---*e.g.*, because the size is too small and causing responsive elements to disappear behind clickable menus---copy the default settings for `browser.height` and `browser.width` from `config/settings.yml` to `config/settings.local.yml` and modify them to meet your needs.

### Increase Timeout Values

If you are experiencing timeout errors when running tests, you may override the default timeout values by adding `timeouts.capybara`, `timeouts.bulk_action`, and/or `timeouts.workflow` in `config/settings.local.yml` depending on where you see timeouts.

### Set SUNet Credentials

If you tire of typing in your SUNet credentials over and over, you may add them to `config/settings.local.yml` (ignored by git). Copy the dummy values from `config/settings.yml` to get started. Do *not* add this file to version control, if you do this!

### Set ETD Credentials

In order to run the tests in `spec/features/create_etd_spec.rb`, you will need to specify credentials required to authenticate connections to the ETD application. This is environment-specific.

#### Staging Environment

For the staging environment, copy `config/settings.yml` to `config/settings/staging.local.yml` and set the ETD username and password to the [values expected in our staging environment](https://github.com/sul-dlss/shared_configs/blob/a90c636b968a1ede4886a61dadc799dd5d162fe1/config/settings/production.yml#L34-L35).

**NOTE**: `config/settings/staging.local.yml` is ignored by git and should remain so. Please do not add this file to version control.

#### QA Environment

For the QA environment, copy `config/settings.yml` to `config/settings/qa.local.yml` and set the ETD username and password to the [values expected in our QA environment](https://github.com/sul-dlss/shared_configs/blob/59ead7acbdf351930ad45922fd44e0f45810bf37/config/settings/production.yml#L16-L17).

**NOTE**: `config/settings/qa.local.yml` is ignored by git and should remain so. Please do not add this file to version control.
