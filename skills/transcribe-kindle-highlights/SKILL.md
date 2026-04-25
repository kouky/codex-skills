---
name: transcribe-kindle-highlights
description: Transcribe user-selected Kindle highlights into Google Docs or Markdown files by reading visible Kindle for Mac pages or annotation panels and writing generated text to the requested destination. Use when Codex is asked to move Kindle highlights, notes, or highlighted passages into a Google Doc, a Markdown notes folder, or one Markdown file per chapter, especially with constraints such as a specific book, chapter, page range, Kindle location range, or target document/directory. This skill is for visual transcription of the user's own highlights, not Kindle export, copy, DRM bypass, database extraction, or full-book transcription.
---

# Transcribe Kindle Highlights

## Overview

Use Kindle only as a read-only visual source. Read visible highlighted text from Kindle screenshots/pages/annotations, generate a clean transcription, write it to Google Docs or Markdown files, and verify the final output for duplicates and scope errors.

Prefer Google Chrome for Google Docs because it exposes the document editor more reliably than Firefox.

## Required Job Ticket

Collect or infer these before doing a large run:

- `Book`: title or visible identifying information.
- `Scope`: chapter, page range, Kindle location range, or clear start/end markers.
- `Source view`: Kindle page view, Notebook/Annotations side panel, or both.
- `Target`: Google Doc title and browser, or Markdown output directory/file path.
- `Output format`: page-labelled paragraphs unless the user requests bullets, a table, or another format.
- `Boundary rule`: stop exactly at the requested page/location/end marker.

Ask a concise clarification only when scope or target is genuinely ambiguous. If the user names an open Google Doc, Markdown directory, or visible Kindle scope, proceed.

## Safety Boundaries

- Do not use Kindle copy, Kindle export, local Kindle databases, DRM bypasses, browser console workarounds, or hidden files.
- Do not transcribe unhighlighted book text except for short headings or page labels needed to orient the user's highlights.
- Do not infer missing words from memory or external sources. Mark uncertain text as `[unclear]` or ask the user to zoom/navigate.
- The clipboard may be used only for Codex-generated transcription text and Google Docs verification text, never to copy from Kindle.
- If a site asks for login, CAPTCHA, 2FA, permissions, sharing changes, or other risky actions, follow the normal confirmation policy.

## Workflow

1. Inspect the open Kindle window and target Google Doc. Confirm the doc title, browser, book, and visible scope.
2. Navigate Kindle visually through the requested scope. Use page view and/or the Annotations panel to see highlighted passages and page numbers.
3. Build an internal transcription with page labels. Preserve punctuation and capitalization when visible; normalize obvious line wraps.
4. Record uncertainty inline with `[unclear]`; do not silently guess.
5. Choose the output path:
   - For Google Docs, set the clipboard to the generated transcription with `pbcopy` or equivalent local tooling.
   - For Markdown, write one `.md` file per chapter unless the user requests otherwise.
6. For Google Docs, prefer Chrome. Focus the `Document content` text-entry area, then paste with `Command+V`.
7. For Markdown, create a slugged chapter file name such as `chapter-01-synthetic-example.md`; use `apply_patch` for manual file edits.
8. Verify the result by reading the Google Docs content back or reading the Markdown file, then checking:
   - one expected header
   - expected page labels/counts
   - no duplicated pasted blocks
   - no highlights outside the requested scope
   - Google Docs saved status when visible, or the Markdown file exists at the expected path
9. If the Google Docs paste duplicated or landed in the wrong place, replace the document contents with one clean generated block and verify again.

## Output Template

Use this default Google Docs shape:

```text
<Book or chapter title> (<scope>)

p. <page> - <highlight text>

p. <page> - <highlight text>

Note: <only include if useful, e.g. pages with no visible highlights or uncertainty>
```

Use this default Markdown shape, one file per chapter. Use page-labelled paragraphs by default; do not use list markers (`-`, `*`, or numbered items) unless the user explicitly requests bullets, a table, or another list format.

```markdown
## Chapter 1: Synthetic Example Chapter

_Source: Synthetic Example Book. Scope: pp. 31-36._

**p. 31** - This fabricated sample highlight shows the requested Markdown shape without quoting a real book.

**p. 32** - A second invented highlight can demonstrate page-labelled paragraphs while staying clearly synthetic.

> Note: Only include notes when useful, e.g. pages with no visible highlights or uncertainty.
```

## Practical Notes

- Chrome usually exposes Google Docs as `Document content`; Firefox may require more focus recovery.
- When verifying, do not leave the whole document selected if the user is likely to keep editing; press a safe arrow key or Escape after verification.
- For longer jobs, work in batches by chapter or page range and verify each batch before continuing. For Markdown, append or replace only the chapter file being worked on.
- Give short progress updates naming the page range completed and any uncertainty.
