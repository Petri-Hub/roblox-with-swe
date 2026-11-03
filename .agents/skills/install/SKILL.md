---
name: install
description: Set up or repair the toolchain and dependencies for the roblox-with-swe project in the current worktree. Use when starting development or when this project's tools or packages are missing.
---

# Install the project

## Workspace

Set up the thread's own worktree. Use the workspace layout and Git to confirm its path and project before installing anything. Do not install into the primary checkout or another thread's worktree.

```text
# /home/lemon/workspace — example project and thread

workspace/
├── projects/
│   └── roblox-with-swe/ # primary checkout
│
└── sessions/
    └── roblox-with-swe/
        └── 2026-11-05-123456-car-sounds/ # this thread's worktree
```

## Toolchain

The sandbox supplies Rokit. The project keeps its tool and dependency choices in these files:

| File | Purpose |
|---|---|
| `rokit.toml` | Pins the project's Roblox development tools. |
| `wally.toml` | Declares the project's packages. |
| `wally.lock` | Records the resolved package versions. |

From the worktree root:

```sh
# Install the project-pinned tools.
rokit install

# Install the project dependencies.
wally install
```

Run the second command only after the first succeeds. Wally creates ignored package directories in this worktree, including `DevPackages` for the tests. Each worktree needs its own project dependencies.
