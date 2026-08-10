#!/usr/bin/env python3
"""Run-journal validation and Codex agent monitoring tools.

Invoked by absolute path from SKILL.md, so this stable entry point stays at the
top of ``scripts/``. Command coordination lives in ``codex_orchestrator.cli``.

Vendored from https://github.com/alexzh3/codex-orchestrator (MIT); see
``LICENSE.upstream``. Local change: the run root is ``.codex-consult/``.
"""

from __future__ import annotations

from codex_orchestrator.cli import main

if __name__ == "__main__":
    raise SystemExit(main())
