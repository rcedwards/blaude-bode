---
name: bearcli
description: >
  Read and write notes in the Bear app (macOS) from the command line using bearcli. Use when the
  user asks to find, read, create, edit, tag, pin, archive, trash, or restore a Bear note, search
  Bear notes, manage attachments on a note, or otherwise wants "Bear" (the notes app) content
  looked up or changed. Also use when the user says "bearcli", "my Bear notes", "search Bear", or
  references a note by title that sounds like a personal note rather than a code file.
---

# bearcli

## Overview

`bearcli` reads and writes notes in the Bear app's local database. It runs on the binary bundled
inside the app: `/Applications/Bear.app/Contents/MacOS/bearcli`, and is also on `PATH` as `bearcli`
after Bear has been installed. There's a separate `mcp-server` subcommand for MCP clients (Claude
Desktop) — ignore it here; this skill is for direct CLI invocation.

Every note is identified by `<note-id>` or `-t/--title <title>` (case-insensitive), mutually
exclusive. Most commands accept `--format tsv|csv|json` (default tsv) and `--fields f1,f2` or
`--fields all`. Read commands never mutate state; write commands (`create`, `append`, `edit`,
`overwrite`, `tags add/remove`, `pin add/remove`, `trash`, `archive`, `restore`, `attachments
add/delete`) print nothing on success — the exit code is the signal (0 success, 1 business error,
64 usage error). Use `--format json` on a read first if you need to confirm what a write will
touch.

Get the full reference any time with `bearcli help all` or `bearcli help <subcommand>`.

## Quick workflow

1. Find the note: `bearcli search "<query>"` or `bearcli list --tag <tag>` to get its id/title.
2. Read before writing: `bearcli cat` (raw content) or `bearcli show` (structured fields) to see
   current state, and `bearcli outline` if you'll target a specific section.
3. Write with the narrowest tool that does the job — `tags add`/`pin add` for metadata, `append`
   for adding, `edit` for a targeted find/replace, `overwrite` only when replacing a whole note or
   section.
4. Confirm with a follow-up `cat`/`show` if the result matters.

## Finding notes

```bash
bearcli list                                    # all notes, sorted pinned,modified
bearcli list --tag work --sort modified:desc
bearcli list --count                            # just the match count

bearcli search "meeting notes"                  # free text
bearcli search "@today @todo"                   # Bear search syntax (dates, tasks, tags...)
bearcli search "@todo" --format json --fields id,title,matches
```

Search syntax highlights: `#tag`, `!#tag` (exact, no children), `#*/tag` (subtags only),
`@today`/`@last7days`/`@date(2026-01-01)`, `@todo`/`@done`/`@task`, `@tagged`/`@untagged`,
`@pinned`, `@images`/`@files`/`@code`, `-` to negate any term. Full syntax:
https://bear.app/faq/how-to-search-notes-in-bear/

## Reading notes

```bash
bearcli cat <id>                                # raw content, no escaping
bearcli cat --title "Mars"
bearcli show <id> --format json --fields all    # structured metadata (not content by default)
bearcli outline <id>                            # every section's address + byte range
bearcli search-in <id> --string "TODO"          # exact-match occurrences within one note
```

`show`'s default fields are `id, title, tags`; pass `--fields all,content` to include the body.
`cat --format json` returns `{"content":"...", "hash":"..."}` — that hash is what `overwrite`'s
`--base` checks against, so read before an `overwrite` if the note might have changed elsewhere.

## Section addressing

Many commands take `--section <address>` to scope to one part of a note instead of the whole
thing. An address is one or more heading lines (with `#` markers, written as they appear), joined
by `\n` when a heading name repeats and needs an ancestor to disambiguate, optionally ending with
a 1-based index. A trailing `preamble` line addresses a section's lead text above its first
subheading.

```
"## Install"               a uniquely-named section
"# Setup\n## Install"      the ## Install under # Setup, when it repeats elsewhere
"# Build\n## Install\n2"   the 2nd ## Install under # Build
"## Install\npreamble"     the lead text of ## Install, above its first subheading
```

Run `bearcli outline <id>` to get exact, copyable addresses instead of guessing — a missing or
ambiguous address comes back with a helpful error suggesting what to retry with.

## Creating and writing

```bash
bearcli create "My Note" --content "Body text" --tags "work,draft"
printf "line1\nline2" | bearcli create "My Note"        # --content reads stdin when omitted

bearcli append <id> --content "New paragraph"            # default: end of note
bearcli append <id> --section "## Tasks" --content "- [ ] New task"

bearcli edit <id> --find "TODO" --replace "DONE"
bearcli edit <id> --find "## Notes" --insert-after "\nNew line"
bearcli edit <id> --find "obsolete paragraph\n" --delete
bearcli edit <id> --find "cat" --replace "dog" --all --word --ignore-case

bearcli overwrite <id> --content "# Title\nBody"          # whole note; unconditional without --base
bearcli overwrite <id> --section "## Tasks" --base <hash> --content "## Tasks\nRewritten body"
```

`edit` finds an exact string and replaces/inserts-around/deletes it; repeat `--find` with a
following action for atomic batch edits (all apply or none do). `--section` confines every `--find`
so a string that recurs elsewhere in the note still resolves uniquely. `overwrite` replaces the
whole note or one section (heading included) — pass `--base <hash>` from a prior `cat --format
json` if another edit landing concurrently should abort the write; CLI callers may omit it.
Both `edit` and `overwrite` reject a change that would silently drop an attachment unless you pass
`--force` (the rejection message names the files).

Text arguments (`--content`, `--find`, `--replace`, etc.) interpret `\n \t \r \\`; **stdin does
not** — pipe pre-formatted text in as-is.

## Tags, pins, attachments, lifecycle

```bash
bearcli tags list                               # every tag in use
bearcli tags list <id>                          # tags on one note
bearcli tags add <id> work "work/meetings"
bearcli tags remove <id> draft
bearcli tags rename work job
bearcli tags delete draft                       # removes from all notes, incl. nested children

bearcli pin list                                # every pin context in use
bearcli pin add <id> global work                # "global" = All Notes pin, else tag names
bearcli pin remove <id> global

bearcli attachments list <id>
cat photo.jpg | bearcli attachments add <id> --filename photo.jpg
bearcli attachments add-url <id> --url https://example.com/photo.jpg
bearcli attachments delete <id> --filename photo.jpg      # also strips the markdown link
bearcli attachments save <id> --filename photo.jpg > photo.jpg

bearcli trash <id>                              # soft-delete, restorable
bearcli archive <id>                            # hidden from active list, restorable
bearcli restore <id>                            # back to active from trash or archive
```

## Interacting with the running app

```bash
bearcli app open <id>                           # brings Bear to foreground with the note open
bearcli app open --title "Mars" --header "Moons" --edit
bearcli app get-selection                       # what the user currently has selected in Bear
```

## Output formats

- `--format tsv` (default): no header, `\n \r \t \\` escaped.
- `--format csv`: RFC 4180 with header row.
- `--format json`: one JSON document, including errors (`{"error":{"code":...,"message":...}}` on
  stdout) — use this when you need to parse the result programmatically.
- `--fields f1,f2` or `--fields all` selects columns; content is excluded from `all` (add it
  explicitly: `--fields all,content`).
- Empty results: `[]` with `--format json`, "No notes found." on stderr otherwise, exit 0 either
  way — don't treat an empty match as an error.
