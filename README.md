# Codex Skills

Personal Codex skills packaged for local installation and GitHub publishing.

## Skills

- `transcribe-kindle-highlights`: Transcribe visible Kindle highlights into a target Google Doc or one Markdown file per chapter without using Kindle copy/export.

## Install Locally

From the repository root, install a skill by copying or symlinking its folder into `~/.codex/skills`.

```bash
mkdir -p "$HOME/.codex/skills"
ln -s "$(pwd)/skills/transcribe-kindle-highlights" "$HOME/.codex/skills/transcribe-kindle-highlights"
```

Restart Codex after adding or updating skills so the skill list refreshes.
