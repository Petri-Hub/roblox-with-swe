<h1 align="center">🧪 roblox-with-swe</h1>

<br>

<h3 align="center">A Roblox game built like a software project.<br>Code, tests, collaboration, and releases—explored on Linux</h3>

<p align="center">
  <img alt="Time spent" src="https://img.shields.io/endpoint?url=https%3A%2F%2Flab-wakapi.petri.zip%2Fapi%2Fcompat%2Fshields%2Fv1%2FPetri%2Fproject%3Aroblox-with-swe%2Finterval%3Aall_time&label=time%20spent&logo=wakatime&logoColor=white&color=blue&cacheSeconds=3600" />
</p>

<br>

## About

> **TL;DR:** a proof of concept for bringing software engineering to Roblox on Linux: source-controlled places, linting, automated regression tests, GitHub Flow, playtest previews, and eventually staging and production releases. Friends will build together through branches and reviewed pull requests, using Discord to discuss ideas and ask an agent to help implement them. That agent will be a new Hermes profile in my personal agent pepper, running in my homelab and contributing through the same tests and review process. This game is the first place to try that shared workflow.

## Contents

- [How it works](#how-it-works)
- [Software engineering in Roblox](#software-engineering-in-roblox)
- [Work on the project](#work-on-the-project)
- [Technologies](#technologies)
- [Roadmap](#roadmap)
- [Repository layout](#repository-layout)
- [Related projects](#related-projects)
- [References](#references)

## How it works

<p align="center">
  <img src="assets/how-it-works.svg" alt="Current workflow: source files and pinned tools feed Rojo, which builds or syncs a place for Studio through Vinegar. StyLua and Selene check the source. Planned workflow: friends use Discord to reach a Hermes profile in pepper, contributions become GitHub pull requests, Jest Roblox adds regression tests, and GitHub Actions publishes staging and production places." />
</p>

The solid paths work today: edit files, use Rojo to build or sync the place, and playtest in Roblox Studio through Vinegar. StyLua and Selene already run locally. The dashed paths are the next experiments: regression tests, CI, releases, and contributions through Discord. The [editable Excalidraw source](assets/how-it-works.excalidraw) lives beside the image.

## Software engineering in Roblox

| Practice | Tool | What it means here |
|---|---|---|
| Source of truth | Git, Luau, Rojo project files, and model JSON | Scripts and the parts of the world we can describe as data live in files that can be reviewed and changed together. |
| Reproducible toolchain | Rokit | The repository pins the versions of Rojo, Wally, StyLua, and Selene. |
| Dependency management | Wally | `wally.toml` declares packages; `wally.lock` records the resolved versions. Jest Roblox is already installed as a development dependency. |
| Formatting | StyLua and pre-commit | Luau gets a consistent style before it enters Git. |
| Static analysis | Selene | Linting catches suspicious Luau code without launching the game. |
| Regression testing | Jest Roblox | Tests will exercise behavior in a Roblox environment so later changes cannot silently break it. The runner and first test are still to come. |
| Local integration | Rojo, Roblox Studio, and Vinegar | Rojo turns files into a place or syncs changes into Studio; Studio lets us see and play what we built on Linux. |
| Collaboration | GitHub Flow | Branches and pull requests will make changes visible to the group before they are merged. |
| Continuous integration and delivery | GitHub Actions and Roblox Open Cloud | Planned checks will validate changes, run suitable engine tests, and publish separate staging and production places. |
| AI collaboration | A Hermes profile in pepper | Planned Discord access will let friends work with an agent that contributes through the same repository and review process. |

The tools have different jobs. Rojo moves files into Roblox's DataModel; it does not decide whether the code is correct. Selene checks code without running it; Jest will check behavior by running it. A successful build is therefore only one part of a trustworthy change.

## Work on the project

With Rokit installed, run these commands from the repository root:

```bash
rokit install
wally install --locked
make format-check
make lint
mkdir -p dist
make build
```

`make build` writes `dist/development.rbxlx`. Open that file in Roblox Studio, start `make serve`, then connect the Rojo Studio plugin to see file changes as you make them. On Linux, Studio runs through Vinegar; the Rojo plugin is installed in Studio separately from the command-line tool.

The existing `build-staging` and `build-production` Make targets only produce place files with different names. They do not publish anything yet.

## Technologies

<table align="center">
  <tr>
    <td align="center" width="112"><img src="https://cdn.simpleicons.org/robloxstudio" width="48" height="48" alt="Roblox Studio" /><br>Roblox Studio</td>
    <td align="center" width="112"><img src="https://cdn.simpleicons.org/luau" width="48" height="48" alt="Luau" /><br>Luau</td>
    <td align="center" width="112"><img src="https://raw.githubusercontent.com/vinegarhq/vinegar/master/data/icons/vinegar.svg" width="48" height="48" alt="Vinegar" /><br>Vinegar</td>
    <td align="center" width="112"><img src="https://api.iconify.design/material-icon-theme/rojo.svg" width="48" height="48" alt="Rojo" /><br>Rojo</td>
    <td align="center" width="112"><img src="https://api.iconify.design/catppuccin/rokit.svg" width="48" height="48" alt="Rokit" /><br>Rokit</td>
    <td align="center" width="112"><img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/wally.svg" width="48" height="48" alt="Wally" /><br>Wally</td>
  </tr>
  <tr>
    <td align="center" width="112"><img src="https://api.iconify.design/catppuccin/stylua.svg" width="48" height="48" alt="StyLua" /><br>StyLua</td>
    <td align="center" width="112"><img src="https://kampfkarren.github.io/selene/favicon.png" width="48" height="48" alt="Selene" /><br>Selene</td>
    <td align="center" width="112"><img src="https://cdn.simpleicons.org/precommit" width="48" height="48" alt="pre-commit" /><br>pre-commit</td>
    <td align="center" width="112"><img src="https://cdn.simpleicons.org/jest" width="48" height="48" alt="Jest" /><br>Jest Roblox</td>
    <td align="center" width="112"><img src="https://cdn.simpleicons.org/github/9198A1" width="48" height="48" alt="GitHub" /><br>GitHub</td>
  </tr>
</table>

## Roadmap

What is working now:

- ✅ Pin the local toolchain with Rokit.
- ✅ Build a place from source files and sync it into Studio with Rojo.
- ✅ Run Roblox Studio through Vinegar on Linux.
- ✅ Describe a small piece of the world as a Rojo model JSON file.
- ✅ Format Luau with StyLua and run it from pre-commit.
- ✅ Lint Luau with Selene.
- ✅ Add Wally and lock Jest Roblox as a development dependency.

What comes next:

- ❌ Add a small gameplay behavior worth testing.
- ❌ Set up a Rojo test place and run regression tests with Jest.
- ❌ Add Luau LSP for editor feedback and type-aware code navigation.
- ❌ Run formatting, linting, builds, and tests in GitHub Actions.
- ❌ Try Open Cloud Luau Execution for engine tests in CI.
- ❌ Publish separate staging and production places through the Roblox API.
- ❌ Try scripted Studio playtests, including whether Vinegar can run them unattended on Linux.
- ❌ Establish GitHub Flow with friends and document contribution rules.
- ❌ Add a Hermes profile in pepper that opens PRs from Discord.

## Repository layout

```sh
.
├── assets/
│   ├── how-it-works.excalidraw  # editable workflow diagram
│   └── how-it-works.svg         # diagram shown above
│
├── src/
│   ├── client/                  # client-side Luau
│   ├── server/                  # server-side Luau
│   ├── shared/                  # shared modules
│   └── world/                   # world objects for Rojo
│
├── default.project.json         # files mapped into the Roblox DataModel
├── Makefile                     # local development commands
│
├── rokit.toml                   # pinned development tools
├── wally.toml                   # package declarations
├── wally.lock                   # resolved package versions
│
├── .stylua.toml                 # formatter configuration
├── selene.toml                  # linter configuration
└── .pre-commit-config.yaml      # formatting hook
```

## License

This repository is licensed under the [MIT License](LICENSE).

## Related projects

- [pepper](https://github.com/Petri-Hub/pepper): my personal agent; the planned Hermes profile for this project will be documented there.
- [lab](https://github.com/Petri-Hub/lab): my homelab, where pepper and the new profile will run.

## References

- [Roblox Creator Hub](https://create.roblox.com/docs): engine, Studio, and publishing documentation
- [Rojo](https://rojo.space/docs/): file-to-DataModel mapping, building, and live sync
- [Rokit](https://github.com/rojo-rbx/rokit): versioned development tools
- [Wally](https://github.com/UpliftGames/wally): packages, manifest, and lockfile
- [StyLua](https://github.com/JohnnyMorganz/StyLua): Luau formatting
- [Selene](https://kampfkarren.github.io/selene/): Luau linting
- [Jest Roblox](https://roblox.github.io/jest-roblox/): test runner and assertions
- [Luau LSP](https://github.com/JohnnyMorganz/luau-lsp): editor analysis and Rojo sourcemaps
- [Vinegar](https://vinegarhq.org/): Roblox Studio on Linux
- [Studio testing modes](https://create.roblox.com/docs/studio/testing-modes): playtests and scripted tests
- [Open Cloud Luau Execution](https://create.roblox.com/docs/cloud/reference/features/luau-execution): engine code execution for automation
- [Place publishing API](https://create.roblox.com/docs/cloud/guides/usage-place-publishing): automated place releases
- [GitHub Flow](https://docs.github.com/en/get-started/using-github/github-flow): branch and pull request collaboration
- [GitHub Actions](https://docs.github.com/en/actions): CI and deployment workflows
- [Wakapi](https://wakapi.dev): time tracking for this project and the badge above
