#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: claude-code-consult.sh <plan|solution|stuck|raw> [options] [prompt]

Options:
  --file <path>       Attach a file with line numbers. May be repeated.
  --file <path:N-M>   Attach only line range N-M from a file.
  --model <model>     Pass a specific model to claude.
  --effort <level>    Pass a reasoning effort level to claude.
  -h, --help          Show this help.

If prompt arguments are omitted, the script reads the prompt from stdin.
EOF
}

tool_path="${CLAUDE_BIN:-$(command -v claude || true)}"
if [[ -z "$tool_path" ]]; then
  echo "Missing executable: claude" >&2
  exit 1
fi

mode="${1:-}"
if [[ -z "$mode" || "$mode" == "-h" || "$mode" == "--help" ]]; then
  usage
  exit 0
fi
shift

case "$mode" in
  plan | solution | stuck | raw) ;;
  *)
    echo "Unknown mode: $mode" >&2
    usage >&2
    exit 1
    ;;
esac

status_output="$("$tool_path" auth status 2>/dev/null || true)"
if [[ "$status_output" != *'"loggedIn": true'* ]]; then
  cat >&2 <<'EOF'
Claude CLI is not authenticated in this process.

Run `claude auth status` in the same environment where this command will run.
If Claude works in your normal terminal but fails here, the current process likely
cannot see the authenticated Claude session. In Codex, rerun the command outside
the sandbox or with escalated permissions instead of repeating login blindly.
EOF
  exit 1
fi

declare -a files=()
model="${CLAUDE_MODEL:-}"
effort="${CLAUDE_EFFORT:-}"

while (($#)); do
  case "$1" in
    --file)
      if (($# < 2)); then
        echo "Missing value for --file" >&2
        exit 1
      fi
      files+=("$2")
      shift 2
      ;;
    --model)
      if (($# < 2)); then
        echo "Missing value for --model" >&2
        exit 1
      fi
      model="$2"
      shift 2
      ;;
    --effort)
      if (($# < 2)); then
        echo "Missing value for --effort" >&2
        exit 1
      fi
      effort="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if (($#)); then
  prompt="$*"
else
  prompt="$(cat)"
fi

if [[ -z "${prompt//[[:space:]]/}" ]]; then
  echo "Prompt is required." >&2
  exit 1
fi

case "$mode" in
  plan)
    template=$'You are reviewing an implementation plan as a senior engineer.\nFocus on missing steps, bad assumptions, hidden risks, sequencing problems, and simpler alternatives.\nReturn:\n1. Overall verdict\n2. Risks or gaps\n3. Recommended plan changes\n'
    ;;
  solution)
    template=$'You are critiquing a proposed technical solution as a senior engineer.\nFocus on correctness risks, edge cases, design tradeoffs, maintainability concerns, and better alternatives when warranted.\nReturn:\n1. Main concerns\n2. Tradeoffs\n3. Recommended changes or alternatives\n'
    ;;
  stuck)
    template=$'You are helping unblock a narrowly scoped engineering problem.\nUse the provided symptoms and attempts to infer likely root causes, the most informative next checks, and fast ways to disprove weak hypotheses.\nReturn:\n1. Most likely causes\n2. Best next debugging steps\n3. Signals that would confirm or eliminate each cause\n'
    ;;
  raw)
    template=$'Answer the question directly and concisely. Prefer concrete critique, tradeoffs, and next steps over generic advice.\n'
    ;;
esac

final_prompt="$template"$'\nUser context:\n'"$prompt"

if ((${#files[@]})); then
  final_prompt+=$'\n\nReferenced files:\n'
  for file_path in "${files[@]}"; do
    file_spec="$file_path"
    range_spec=""
    resolved_path="$file_path"

    if [[ "$file_path" =~ ^(.+):([0-9]+)-([0-9]+)$ ]]; then
      resolved_path="${BASH_REMATCH[1]}"
      range_spec="${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
    fi

    if [[ ! -r "$resolved_path" ]]; then
      echo "Unreadable file: $resolved_path" >&2
      exit 1
    fi

    if [[ -n "$range_spec" ]]; then
      start_line="${range_spec%-*}"
      end_line="${range_spec#*-}"
      if ((start_line > end_line)); then
        echo "Invalid line range for $resolved_path: $range_spec" >&2
        exit 1
      fi
      file_contents="$(sed -n "${start_line},${end_line}p" "$resolved_path" | nl -ba -v "$start_line")"
      final_prompt+=$'\n=== '"$resolved_path:$range_spec"$' ===\n```text\n'"$file_contents"$'\n```\n'
      continue
    fi

    line_count="$(wc -l < "$resolved_path" | tr -d ' ')"
    if ((line_count > 400)); then
      cat >&2 <<EOF
Refusing to inline $resolved_path because it has $line_count lines.
Pass a focused slice instead, for example:
  --file $resolved_path:40-120
EOF
      exit 1
    fi

    file_contents="$(nl -ba "$resolved_path")"
    final_prompt+=$'\n=== '"$resolved_path"$' ===\n```text\n'"$file_contents"$'\n```\n'
  done
fi

cmd=("$tool_path" "--print" "--output-format" "text")
if [[ -n "$model" ]]; then
  cmd+=("--model" "$model")
fi
if [[ -n "$effort" ]]; then
  cmd+=("--effort" "$effort")
fi

exec "${cmd[@]}" "$final_prompt"
