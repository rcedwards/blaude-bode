# Repository Guidance

This repo is the source of truth for shared Claude/Codex skills and subagents.

- Edit source files in `skills/*/SKILL.md` and `agents/*/AGENT.md`.
- Do not hand-edit generated files in `dist/`.
- Run `./build.sh` after changing skill or agent bodies so Codex artifacts stay current.
- Run `./install.sh --host claude` or `./install.sh --host codex` to refresh local symlinks after adding or removing files.
- Run `./test.sh` when changing source layout, build logic, or install behavior.
- Run `./bin/install-git-hooks` once per clone if you want staged canonical edits to auto-run `./build.sh` before commit.
- Commit and push every change in this repo and in `private/` as soon as it is done. Never leave skill or agent edits uncommitted at the end of a task.

## Skills

- Skill frontmatter is authored for Claude first, then transformed for Codex.
- Create or migrate skills in canonical source roots: use `skills/<name>/` for public/shared skills and `private/skills/<name>/` for private skills when the private sub-repo is present.
- Keep the markdown body tool-agnostic unless a host-specific distinction is necessary.
- `name` and `description` are required for every skill.
- The skill directory name must match frontmatter `name`.
- Claude hooks stay in frontmatter under `hooks:`.
- Codex does not execute hooks automatically. If a hook is important, the skill body should still make the required step explicit.
- Keep supporting files inside the same skill directory as `SKILL.md`.

## Subagents

- Agent definitions live in `agents/*/AGENT.md`.
- Keep the system prompt shared across tools in the markdown body.
- The agent directory name must match frontmatter `name`.
- Put Codex-only runtime settings under the `codex:` block.
- Put Claude-only runtime settings in top-level frontmatter fields such as `model` and `tools`.

## Structure

- `skills/`: canonical shared skill definitions
- `private/skills/`: canonical private skill definitions, when the private sub-repo is present
- `agents/`: canonical shared agent definitions
- `private/agents/`: canonical private agent definitions, when the private sub-repo is present
- `bin/`: reusable shell helpers installed into `~/.local/bin`
- `.githooks/`: optional repo-local git hooks for refreshing generated Codex artifacts
- `dist/codex/`: generated Codex artifacts only

## Editing expectations

- Preserve compatibility for both hosts when changing file formats.
- Prefer improving the build/install pipeline over duplicating host-specific source files.
- Prefer `bin/` or files co-located with a skill/agent before introducing a new top-level distribution mechanism.
- If you add new metadata, document whether Claude, Codex, or both consume it.
