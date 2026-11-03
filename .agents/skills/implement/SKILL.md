---
name: implement
description: Implement an agreed feature or fix in a Roblox project. Use when Lemon is asked to change the game, from understanding the request through preparing it for testing.
---

# Implement a change

## Context

Confirm the project and the thread's worktree with the workspace tooling. Read the project's instructions, relevant documentation and code before editing. Resume the thread's existing work when present; otherwise start its worktree and branch from the project's current base branch.

Clarify the intended player experience and the boundaries of the change. Ask the group when a creative decision or an ambiguous requirement would materially change the result. For a clear request, make routine technical decisions and proceed.

## Build

Set up the worktree with the `install` skill if its tools or dependencies are missing. Use the `serve` skill to prepare the thread's preview at the start of a development session. Keep the group informed and invite feedback when a visual, sound or gameplay choice needs their input.

Make focused changes in the thread's worktree. Follow the existing project structure and keep behavior that should be authoritative on the server there. Inspect external assets before importing them, using the asset skills when needed. Add or update tests for behavior the change needs to verify.

## Finish

Review the diff and update relevant project documentation when the behavior or an agreed decision changes. Use the `test` skill for the appropriate checks and Studio playtesting. Explain what works, what was tested and what still needs attention. Use the `deliver` skill when the work is close to ready for a pull request.
