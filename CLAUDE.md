# Repository Guidance

This repo stores shared skill and agent source files for Claude Code and Codex.

- Edit `skills/*/SKILL.md` and `agents/*/AGENT.md` as the canonical source.
- Do not edit `dist/` directly.
- Re-run `./build.sh` after changing bodies that Codex consumes.
- Re-run `./install.sh --host claude` after adding or removing Claude-visible files.

## Claude-specific notes

- Skills are installed as symlinked source directories under `~/.claude/skills/`.
- Agents are installed as symlinked markdown files under `~/.claude/agents/`.
- Frontmatter fields such as `allowed-tools`, `requires`, `hooks`, `model`, and `tools` are preserved for Claude.

## Cross-host notes

- Keep markdown bodies shared unless the distinction is unavoidable.
- Codex strips Claude-only frontmatter, so required operational steps should also be described in the body when they matter for correctness.
- Prefer extending `build.sh` and `install.sh` instead of creating duplicate Claude-only and Codex-only source files.
