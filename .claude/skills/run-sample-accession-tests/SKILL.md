---
name: run-sample-accession-tests
description: Run the SDR sample_accession integration-testing path (register an APO/Collection, register test objects, accession and re-accession via Preassembly) as an agent-driven browser session instead of the RSpec/Capybara suite. Use when asked to run, extend, or reason about the sample_accession integration tests using an LLM agent + Playwright MCP rather than bin/rspec.
---

# run-sample-accession-tests

Follow the conventions defined in [../../../.agents/skills/run-sample-accession-tests/SKILL.md](../../../.agents/skills/run-sample-accession-tests/SKILL.md), and run the individual scenarios in [../../../.agents/skills/run-sample-accession-tests/scenarios/](../../../.agents/skills/run-sample-accession-tests/scenarios/) in the order that file specifies. Do not duplicate or reimplement those conventions here — this file exists only so Claude's skill-discovery mechanism finds its way to them.
