# Project Guidelines

infrastructure-integration-test is a suite of feature specs that drive a browser, mostly to interact with user facing SDR applications, occasionally to interact with SDR via command line tools such as `ssh`. The intent is to simulate realistic SDR usage scenarios, and to exercise as much of the core SDR functionality as possible. Compared to unit tests within the various SDR applications, the focus here is on interacting with deployed applications, especially in ways that cross service boundaries, to verify that our own applications are interacting successfully with each other, and with external services such as cloud compute and storage. This allows us to confirm that code changes work as intended and do not introduce new bugs.

## Architecture

The test suite uses Capybara feature specs to drive a browser, on a developer laptop, against SDR applications. The test suite uses the browser to do things such as accessioning and versioning objects of different types. This is done through many different applications, including but not limited to: Preassembly, Argo, H3 (hungry-hungry-hippo, the self deposit app). There are also interactions via the command-line with sdr-api and dor-services-app, mostly to stage or update content, but sometimes to check the state of something, to confirm operation as expected.

## Testing Notes

Sometimes a test fails because the UI has changed compared to the most recent test expectations. In this case, the test should be updated.

Sometimes a test fails because it has caught a bug introduced by a code change. Typically, the correct thing to do is to fix the bug. Sometimes, the correct thing to do is to temporarily ignore the test failure or to temporarily comment out the expectation.

Sometimes a test fails because Capybara driven interactions with the browser can be flaky, possibly because of Capybara having trouble detecting DOM mutations. In this case, the test should be re-run for as long as it looks like the failures are due to flakiness.

Sometimes a test fails because of networking issues, possibly from the test suite to the applications and services it's interacting with, possibly between SDR services that interact to provide users with functionality. In this case, a developer should inquire with ops if it looks like the issue is previously undetected inter-service connection trouble. The developer should troubleshoot their network connection if it seems the issue is between the laptop running the test suite, and the rest of the world.
