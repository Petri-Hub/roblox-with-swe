---
name: test
description: Check changes in the roblox-with-swe project using its formatting, lint, build and Open Cloud tests, and coordinate Studio playtesting.
---

# Test the project

## Checks

Run checks from the thread's worktree after its tools and dependencies are installed. Choose checks relevant to the change and fix failures before delivery. These commands are defined by the project's `Makefile`:

```sh
# Check Luau formatting.
make format-check

# Check the Luau source and tests.
make lint

# Build the development place.
make build
```

For formatting changes, `make format-apply` updates Luau files in the current worktree. Review the resulting diff. These checks do not run the game or prove a feature works in Studio.

## Open Cloud

The project's Jest suite runs in Roblox Open Cloud:

```sh
# Run the automated tests in Open Cloud.
make test-on-ocale
```

Check that the test settings are present without printing their values. Open Cloud runs use a shared test place and limited resources. Before starting a local run, check whether another run is using it; coordinate with the group if the state is unclear. GitHub's CI concurrency does not coordinate local runs with CI. Avoid unnecessary duplicate runs, but do not skip the required PR checks.

## Studio

The sandbox cannot run Studio. Ask a collaborator to playtest visual, audio or interactive changes in the thread's preview. Explain what to check and what result you expect. Do not claim the playtest passed until the person confirms it.

## Results

Report which checks passed, failed or could not run, including a useful error summary without credentials. If a check fails, investigate and retry when appropriate. If it remains blocked, explain what is needed; never present a skipped or unavailable check as a pass.
