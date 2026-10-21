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
    -*)
      echo "Unknown option: $1 (use -- before a dash-leading prompt)" >&2
      exit 1
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
    range_spec=""
    resolved_path="$file_path"

    if [[ "$file_path" =~ ^(.+):([0-9]+)-([0-9]+)$ ]]; then
      resolved_path="${BASH_REMATCH[1]}"
      range_spec="${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
    fi

    if [[ ! -f "$resolved_path" || ! -r "$resolved_path" ]]; then
      echo "Unreadable file: $resolved_path" >&2
      exit 1
    fi

    if [[ -n "$range_spec" ]]; then
      start_digits="${range_spec%-*}"
      end_digits="${range_spec#*-}"
      if [[ ${#start_digits} -gt 9 || ${#end_digits} -gt 9 ]]; then
        echo "Invalid line range for $resolved_path: $range_spec" >&2
        exit 1
      fi
      start_line=$((10#$start_digits))
      end_line=$((10#$end_digits))
      if ((start_line < 1 || start_line > end_line || end_line - start_line >= 400)); then
        echo "Invalid line range for $resolved_path: $range_spec" >&2
        exit 1
      fi
      file_contents="$(sed -n "${start_line},${end_line}p" "$resolved_path" | nl -ba -v "$start_line")"
      if [[ -z "$file_contents" ]]; then
        echo "Empty line range for $resolved_path: $range_spec" >&2
        exit 1
      fi
      final_prompt+=$'\n=== '"$resolved_path:$range_spec"$' ===\n```text\n'"$file_contents"$'\n```\n'
      continue
    fi

    line_count="$(awk 'END { print NR }' "$resolved_path")"
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

tool_path="${CLAUDE_BIN:-$(command -v claude || true)}"
if [[ -z "$tool_path" ]]; then
  echo "Missing executable: claude" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Missing executable: python3 (required to parse Claude auth status)" >&2
  exit 1
fi
help_output="$("$tool_path" --help)"
for required_option in --safe-mode --tools --no-session-persistence; do
  if [[ "$help_output" != *"$required_option"* ]]; then
    echo "Claude CLI lacks $required_option; update the CLI before consulting." >&2
    exit 1
  fi
done

# Parse JSON rather than depending on auth status whitespace.
status_output="$("$tool_path" auth status 2>/dev/null || true)"
if ! printf '%s' "$status_output" | python3 -I -c 'import json, sys; sys.exit(0 if json.load(sys.stdin).get("loggedIn") is True else 1)' 2>/dev/null; then
  cat >&2 <<'EOF'
Claude authentication could not be verified in this process.
Run `claude auth status` in the same environment. If Claude works in your normal
terminal, retry with the required sandbox permissions rather than logging in again.
EOF
  exit 1
fi

# Consultation uses the supplied packet, without tools or local customizations.
cmd=("$tool_path" "--print" "--output-format" "text"
  "--safe-mode" "--tools" "" "--no-session-persistence")
if [[ -n "$model" ]]; then
  cmd+=("--model" "$model")
fi
if [[ -n "$effort" ]]; then
  cmd+=("--effort" "$effort")
fi

"${cmd[@]}" <<<"$final_prompt"
