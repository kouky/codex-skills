# Codex Skills

Personal Codex skills packaged for local installation and GitHub publishing.

## Skills

| Skill | Description |
| --- | --- |
| `sync-main` | Safely move `main` forward after explicit `$sync-main` invocation by committing the active task snapshot, preserving unrelated edits, rebasing onto `origin/main`, resolving one clearly-fixable conflict set, validating, and pushing without force. |
| `transcribe-kindle-highlights` | Transcribe user-selected Kindle highlights into Google Docs or Markdown by reading visible Kindle for Mac pages or annotations, without using Kindle copy/export, local databases, or DRM workarounds. |

## Install Locally

From the repository root, install all skills with symlinks:

```bash
./install
```

Install one skill:

```bash
./install sync-main
```

Copy instead of symlinking:

```bash
./install --copy sync-main
```

List available skills:

```bash
./install --list
```

Installing a skill replaces any same-named entry in `~/.codex/skills`. Keep local edits in this repository, not in the installed copy.

Restart Codex after adding or updating skills so the skill list refreshes.
