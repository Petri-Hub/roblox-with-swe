---
name: deliver
description: Deliver a finished project change through a pull request, required checks and merge. Use when the thread's work is ready to leave its worktree.
---

# Deliver a change

## Prepare

Confirm the project, the thread's worktree, its branch and the project's base branch with the workspace tooling and project instructions. Review the diff, keep unrelated work out, and use the `test` and `document` skills where relevant. Address failed checks already run and report anything that could not be verified. The pull request's required CI checks run after the PR is opened.

Commit with a Conventional Commit and use the GitHub App authentication skill. Push the feature branch and open a pull request to the project's base branch when the change is close to ready. Do not push to a protected branch or force-push. Describe what changed, the checks performed and any remaining playtest limitations.

## Checks

Watch the required checks on the pull request's current changes. If more work is needed after opening it, close the PR while making and checking the changes, then reopen it when ready. Reopening triggers checks again. If the base branch changed, bring the feature branch up to date without discarding work or bypassing the project's rules, then wait for the checks again.

Merge the PR yourself once the required checks pass on the final changes and GitHub reports it meets the branch rules. No code review or separate approval is needed. If a required check fails, remains pending or the merge is blocked, explain the problem and resolve it before merging. Do not bypass branch protection or treat a skipped check as proof that it passed.

## After merge

Check whether the merge triggered a publishing workflow and report its actual result to the thread. Explain any remaining playtest limitations. Once the correct PR is merged, stop this thread's preview and remove its worktree. First check for uncommitted, untracked or unpushed work; preserve unexpected leftovers and tell Petri before removing anything. Do not stop or remove another thread's work.
