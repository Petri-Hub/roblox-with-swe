---
name: serve
description: Start, reuse or stop a Rojo Share preview for the roblox-with-swe project. Use when a Discord thread needs to see its worktree in Roblox Studio.
---

# Serve the project

## Workspace

Serve the thread's own worktree. Use the workspace layout and Git to confirm its path and project before starting a preview. Do not serve the primary checkout or another thread's worktree.

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

## Preview

Rojo Share starts Rojo and a Cloudflare Quick Tunnel for the project. Check whether this thread already has a working preview and reuse it. If it does not, start one from the worktree root using a terminal session that can keep the process running:

```sh
# Start the thread's Studio preview.
rojo-share serve default.project.json
```

| Setting | Default | Purpose |
|---|---|---|
| `default.project.json` | — | The project file to sync with Studio. |
| `--rojo-port` | `34872` | Rojo's local port; concurrent previews need different available ports. |
| `--duration` | `1h` | How long the preview stays open. |

If the default port is in use, choose an available port with `--rojo-port`. Keep the process, port, worktree and expiry associated with this thread so you can check or stop the right preview later. Do not interrupt another thread's preview.

## Share

Wait for `Studio URL`, which Rojo Share prints after checking that Rojo responds through the tunnel. The earlier `Tunnel URL` does not confirm that the preview is ready. Send the Studio URL and expiry to the people in the thread, and explain how to connect the Rojo Studio plugin if needed. The URL gives its holder access to the development server while the preview is running; do not post it elsewhere.

If startup fails, tell the thread what happened and do not claim the preview is ready. Cloudflare can rate-limit tunnel creation; avoid repeated retries after a rate-limit error.

## Stop

Keep the preview running between replies. Stop this thread's Rojo Share process when the session explicitly ends or its worktree is removed; Rojo Share stops its Rojo and tunnel processes too. The preview also stops when its duration expires.
