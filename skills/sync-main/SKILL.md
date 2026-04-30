---
name: sync-main
description: Use only when explicitly invoked to safely identify and stage the active task changes intended for main, preserve unrelated tracked and untracked edits, rebase onto origin/main, aggressively self-resolve one clearly-fixable conflict set, validate the result, and push main to origin without force-pushing.
---

# Sync Main

Use this skill only after the user explicitly invokes `$sync-main`. Do not use it implicitly for general git help, feature branches, PR workflows, or branch cleanup.

## Outcome

Safely move `main` forward by:
- staging only the active task changes and committing that snapshot,
- preserving unrelated tracked and untracked working-tree edits,
- rebasing onto `origin/main`,
- making at most one serious self-repair pass per rebase stop,
- validating touched code,
- and pushing `main` to `origin` without force.

## Guardrails

- Target `origin/main`. A checked-out local `main` branch is fine, and detached `HEAD` is also acceptable in Codex worktrees. Stop if the current named branch is anything other than `main`.
- Never force-push.
- Never use `git pull`; use fetch plus rebase.
- Never discard user changes with `reset`, `checkout --`, `restore --source`, `clean`, or blanket `ours`/`theirs` conflict strategies.
- Do not automatically commit unrelated or pre-existing unstaged changes.
- If no files are staged yet, infer the active task files from the current thread and worktree, then stage only the files that clearly belong to this task.
- Preserve unrelated tracked and untracked edits with the helper's dedicated stash-and-restore flow.
- Stop if a merge, cherry-pick, revert, or other git sequencer operation is already in progress.
- Stop if the merge is not obviously correct and the work touches migrations, schemas, contracts, auth, payments, or other high-risk logic.

## Workflow

### 1. Preflight

- Check `git status --short --branch`.
- If a rebase is already in progress, switch to the continuation flow instead of creating a new commit.
- If a merge, cherry-pick, revert, or other git sequencer operation is already in progress, stop and explain.
- If the current named branch is neither `main` nor detached `HEAD`, stop and explain.

### Staging policy

- If relevant files are already staged, treat the staged snapshot as the commit scope.
- If nothing is staged, inspect the current thread, recent edits, and `git status` to infer which files clearly belong to the active task.
- Stage only the obvious task files. Do not stage unrelated pre-existing changes, opportunistic cleanups, or files whose relevance is ambiguous.
- Prefer whole-file staging when the file is clearly part of the task. Use partial staging only when the file mixes task work with unrelated edits and the split is straightforward and safe.
- Untracked files may be staged when they are clearly part of the active task, such as a new skill, helper script, test, or generated artifact required by the task.
- If the working tree contains mixed changes and no clear task boundary exists, stop and ask instead of guessing.
- After staging, re-check the staged diff and use that staged snapshot as the commit scope for the rest of the workflow.

### Commit message policy

- If the user provided a commit message, use it unless it is materially misleading for the staged diff.
- If the user did not provide a commit message, base it only on the content being committed. Do not describe unstaged, untracked, or temporarily preserved unrelated changes unless they also become part of this commit.
- Write a single-line imperative subject, usually under 72 characters.
- Describe the actual staged code change, not the git process. Do not mention rebase, conflict resolution, stash preservation, or push steps unless those are the real user-visible changes being committed.
- Prefer specific nouns and verbs tied to the touched code, such as the feature, bug, module, endpoint, or test area that changed.
- If the staged diff spans multiple unrelated concerns and no honest single subject fits, stop and ask the user to restage or provide the message explicitly.

### 2. Start the deterministic flow

For a fresh run, use the helper script:

```bash
.agents/skills/sync-main/scripts/sync_main.sh start "<commit message>"
```

The script:
- verifies branch and staged state,
- refuses to run while another git sequencer operation is already active,
- commits the staged snapshot only,
- runs `git fetch origin main`,
- preserves unrelated tracked and untracked changes in a dedicated stash,
- runs `git rebase origin/main`,
- restores the preserved changes after the rebase,
- and stops cleanly if conflicts need judgment.

### 3. Resolve conflicts aggressively

When the rebase stops:
- Inspect conflicted files with `git diff --name-only --diff-filter=U` and read the surrounding code before editing.
- Prefer semantic merges that preserve both the task-specific intent and upstream fixes when they can coexist.
- Regenerate derived files, lockfiles, snapshots, or generated code instead of hand-merging them when that is safer.
- Use tight, local fixes. Do not rewrite nearby logic unless the conflict requires it.
- Run targeted validation after edits. Favor the smallest useful checks first, such as focused tests, typechecks, lint, or a small build step covering the touched files.
- Make at most one serious self-repair pass for the current conflict set. If that pass does not produce a coherent, validated result, stop and ask for help.

### 4. Continue or stop

After resolving and validating:

```bash
.agents/skills/sync-main/scripts/sync_main.sh continue
```

If a later rebase stop produces a new conflict set, repeat the same policy once for that stop.

If restoring the preserved unrelated changes creates conflicts after the rebase, treat that as another conflict set and follow the same aggressive-but-bounded policy.

Stop and ask for help when:
- the conflict is ambiguous,
- validation still fails after one serious repair pass,
- continuing would drop or rewrite user intent,
- or the changes involve high-risk logic that cannot be validated confidently.

### 5. Push and report

Once the rebase completes:

```bash
.agents/skills/sync-main/scripts/sync_main.sh push
```

Do not push until any preserved unrelated changes have been restored cleanly or their pending restore state has been resolved explicitly.

In the final report:
- say whether preserved unrelated changes were restored cleanly or needed manual conflict resolution,
- list files that required manual conflict resolution,
- summarize validation that was run,
- and note whether the push succeeded.
