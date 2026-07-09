[![CircleCI](https://circleci.com/gh/sul-dlss/infrastructure-integration-test/tree/main.svg?style=svg)](https://circleci.com/gh/sul-dlss/infrastructure-integration-test/tree/main)

# SDR Integration Tests

A set of Capybara tests that drive a browser to do inter-system integration testing of SDR in the stage or QA environment.

## Installation

The tests use Ruby 3.4.

The tests depend on having Firefox (default) or Chrome downloaded.

1. `bundle install`

See the `Other Configuration` section below for
- instructions on using Chrome
- tweaking default selenium browser settings.

## Prerequisites

1. Connect to Stanford VPN (full-tunnel or split-tunnel)
1. Ensure you have a valid, non-expired Kerberos ticket (use `klist` to verify, or run `kinit` to refresh)
1. Set up SSH per [DLSS developer best practices](https://github.com/sul-dlss/DeveloperPlaybook/blob/main/best-practices/ssh_configuration.md)
1. See the `Authentication Configuration` section below to set up necessary credentials:
- dor_services_app credentials
- etd credentials

## Run Tests

### Test type and order

There are 5 types of tests, run in this order (the order is enforced by `config.register_ordering(:global)` in `spec/spec_helper.rb`, based on each spec's `type:` metadata):

- registration
- accessioning
- sdr
- verify
- preassembly

Several specs depend on data saved by an earlier-type spec (e.g. a druid registered in a `registration` spec and used by an `accessioning` spec). This is persisted to `tmp/{today}_data.yml` via `spec/support/data_helpers.rb`, and loaded with `load_test_data`, which raises a clear error if the expected entry isn't there. Running the full suite (below) runs every type in the correct order automatically, so this is only a concern when filtering to a single type or running a spec individually — see the "Preassembly tests" section below for a concrete example.

By default, all of the integration tests run in the SDR stage environment:

`bin/rspec`

To test in the SDR QA environment, run tests with the `SDR_ENV` environment variable, like so:

```shell
SDR_ENV=qa bin/rspec
```

Each type of test can be run as a separate group with:

```
bin/rspec --tag type:[registration|accessioning|sdr|verify]
```

### Accessioning Quick Run

To run a minimal end-to-end accessioning path (register an APO and collection, register all the standard test objects, accession a plain image object via Preassembly, then re-accession it) without the more time consuming H3/GIS/OCR/media accessioning specs, use the `sample_accession` tag:

```
bin/rspec --tag sample_accession
```

### Rerun

If a run produces some failures, you can try and re-run just the latest failed examples with the command below.  This can be run again as needed.

`bin/rspec --only-failures`

Note that required ordering and dependencies may mean some specs still don't work, notably the re-accessioning test.  In other words, some tests depend on previous ones having succeeded.  So you may still need to start all over again.

### Preassembly tests

To run just the preassembly tests (skipping the other types), use the type tag.

```
bin/rspec --tag type:preassembly
```

or individually:

```
bin/rspec spec/features/preassembly/preassembly_gis_raster_accessioning_spec.rb  --tag type:preassembly
```

Note: `spec/features/preassembly/preassembly_reaccessioning_spec.rb` loads the druid saved by `spec/features/accessioning/preassembly_accessioning_spec.rb`, which in turn loads the druid saved by `spec/features/registration/03_register_objects_spec.rb`. Filtering to `--tag type:preassembly` skips both of those, so they must have already run successfully at least once the same day (e.g. via a plain `bin/rspec`, or `bin/rspec --tag type:accessioning` after registration has run) before running the reaccessioning spec on its own.

### Currently deprecated

If you would prefer to run the tests one by one and be prompted to move on to the next one you can use the following (but you will be prompted to login with Duo for each test):

```
bin/run
```

No matter which environment you run tests in, you may be prompted to type in your Stanford credentials and will then need to approve a multi-factor authentication push. If you tire of typing in your credentials, see the `Other Configuration` section below for help securely storing them.

When running the virtual_object_creation test, you can create more than two constituents by running as follows:

`SETTINGS__NUMBER_OF_CONSTITUENTS=11 bin/rspec`

or

Note: running the following tests indivually requires that `spec/features/registration/01_apo_registration_spec.rb` and `spec/features/registration/02_collection_registration_spec.rb` have been run at least once the same day.

```
SETTINGS__NUMBER_OF_CONSTITUENTS=11 bin/rspec spec/features/registration/03_register_objects_spec.rb:82

and

SETTINGS__NUMBER_OF_CONSTITUENTS=11 bin/rspec spec/features/accessioning/virtual_object_creation_spec.rb
```


## Add New Tests

Please use the integration-testing APO and collection when feasible:

* APO: druid:qc410yz8746 (available as `Settings.default_apo`)
* Collection: druid:bc778pm9866 (available as `Settings.default_collection`)

## Authentication Configuration

### Allow Credential Delegation

Configure your SSH client to allow delegation of Kerberos credentials (required for any tests that use `scp`), by adding the following to `~/.ssh/config` or wherever your system stores SSH configuration:

```
# Add to appropriate place, such as:
Host *.stanford.edu
  GSSAPIDelegateCredentials yes
```

### Stage Environment

For the stage environment, copy `config/settings.yml` to `config/settings/stage.local.yml`.  You will be adding stage environment specific settings here.

**NOTE**: `config/settings/stage.local.yml` is ignored by git and should remain so. Please do not add this file to version control.

### QA Environment

For the QA environment, copy `config/settings.yml` to `config/settings/qa.local.yml`.  You will be adding stage environment specific settings here.

**NOTE**: `config/settings/qa.local.yml` is ignored by git and should remain so. Please do not add this file to version control.

### Set Dor-Services-App Credentials

Some integration tests use the `dor-services-client` to interact with the `dor-services-app`. In order to successfully use the dor-services-client, you must first have a token. To generate dor-services-app tokens, see the [dor-services-app README](https://github.com/sul-dlss/dor-services-app#authentication). You'll need to generate separate tokens for each dor-services-app environment (stage, qa), and add them to `config/settings/stage.local.yml` and `config/settings/qa.local.yml`.  See `config/settings.yml` for the expected YAML syntax.

### Set ETD Credentials

In order to run `spec/features/etd_creation_spec.rb`, you need the ETD application's backdoor username and password for HTTP POST requests. You can get these from [Vault](https://consul.stanford.edu/display/systeam/Vault+for+Developers):

```shell
vault kv get puppet/application/hydra_etd/qa/username
vault kv get puppet/application/hydra_etd/qa/password
```

or

```shell
vault kv get puppet/application/hydra_etd/stage/username
vault kv get puppet/application/hydra_etd/stage/password
```

Add them to `config/settings/stage.local.yml` and `config/settings/qa.local.yml` respectively.  See `config/settings.yml` for the expected YAML syntax.

### Set Goobi Credentials

In order to run `spec/features/goobi_accessioning_spec.rb`, you need the Goobi application's integration username and password to login to the UI. Get these values from [Vault](https://consul.stanford.edu/display/systeam/Vault+for+Developers) and add them to `config/settings/stage.local.yml`.

```shell
vault kv get puppet/application/goobi/stage/username
vault kv get puppet/application/goobi/stage/password
```

This test cannot be run in QA, since there is no Goobi QA. So this configuration is only relevant for stage. See `config/settings.yml` for the expected YAML syntax.

### Problems with Authentication?

You may want to lower the timeout value of `Settings.timeouts.post_authentication_text` in `config/settings.local.yml`.

## Other Configuration

### Globus

The H3 Globus integration test uses your Globus account to upload files.  You may need to log into Globus at least once to have this ready to go.  During the test, you will also get a second auth request coming from the Globus login, which you need to accept.  Your H3 Globus endpoint ("/uploads/SUNETID/new") should also be empty when you start the test.  This should be true unless a previous integration run failed mid-way or you are actually in the middle of using Globus in qa/stage to accession content.  If necessary, just delete the "new" folder or the files within it manually in the Globus UI and then try again.

### Set SUNet Credentials

If you tire of typing in your SUNet credentials over and over, you may add them to `config/settings.local.yml` (ignored by git). Copy the dummy values from `config/settings.yml` to get started. Do *not* add this file to version control, if you do this!

### Use Chrome Browser

1. `bundle install`
1. Set `browser.driver` to `chrome` in `config/settings.local.yml`

### Change Browser Window Size

If you find you need to modify the default window size for either browser---*e.g.*, because the size is too small and causing responsive elements to disappear behind clickable menus---copy the default settings for `browser.height` and `browser.width` from `config/settings.yml` to `config/settings.local.yml` and modify them to meet your needs.

### Increase Timeout Values

If you are experiencing timeout errors when running tests, you may override the default timeout values by adding `timeouts.capybara`, `timeouts.bulk_action`, and/or `timeouts.workflow` in `config/settings.local.yml` depending on where you see timeouts.
