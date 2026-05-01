#!/usr/bin/env bash

frontmatter_get() {
  local file="$1" path="$2"

  awk -v path="$path" '
    function indent_count(s) {
      match(s, /^[ \t]*/)
      return RLENGTH
    }

    function trim(s) {
      sub(/^[ \t]+/, "", s)
      sub(/[ \t]+$/, "", s)
      return s
    }

    function decode_scalar(s, first, last) {
      s = trim(s)
      first = substr(s, 1, 1)
      last = substr(s, length(s), 1)

      if (first == "\"" && last == "\"") {
        s = substr(s, 2, length(s) - 2)
        gsub(/\\\\/, "\001", s)
        gsub(/\\"/, "\"", s)
        gsub(/\\n/, "\n", s)
        gsub(/\\t/, "\t", s)
        gsub(/\\r/, "\r", s)
        gsub(/\\f/, "\f", s)
        gsub(/\\b/, "\b", s)
        gsub(/\001/, "\\", s)
        return s
      }

      if (first == "'"'"'" && last == "'"'"'") {
        s = substr(s, 2, length(s) - 2)
        gsub(/'\'''\''/, "'"'"'", s)
        return s
      }

      sub(/[ \t]+#.*/, "", s)
      return trim(s)
    }

    function flush_block() {
      if (block_style == "|") {
        sub(/\n$/, "", block_value)
      }
      print block_value
      found = 1
    }

    BEGIN {
      split(path, path_parts, /\./)
      depth = length(path_parts)
      key1 = path_parts[1]
      key2 = path_parts[2]
      in_frontmatter = 0
      frontmatter_done = 0
      in_parent = 0
      collecting_block = 0
      block_style = ""
      block_value = ""
      block_indent = 0
      found = 0
    }

    /^[ \t]*---[ \t]*$/ {
      if (!in_frontmatter) {
        in_frontmatter = 1
        next
      }

      if (!frontmatter_done) {
        frontmatter_done = 1
        if (collecting_block) {
          flush_block()
        }
        exit
      }
    }

    !in_frontmatter || frontmatter_done {
      next
    }

    {
      line = $0

      while (1) {
        if (collecting_block) {
          current_indent = indent_count(line)

          if (line ~ /^[ \t]*$/) {
            block_value = block_value "\n"
            break
          }

          if (current_indent >= block_indent) {
            text = substr(line, block_indent + 1)

            if (block_style == "|") {
              block_value = block_value text "\n"
            } else {
              if (block_value == "" || substr(block_value, length(block_value), 1) == "\n") {
                block_value = block_value text
              } else {
                block_value = block_value " " text
              }
            }
            break
          }

          flush_block()
          exit
        }

        current_indent = indent_count(line)

        if (depth == 2) {
          if (!in_parent) {
            if (current_indent == 0 && line ~ ("^" key1 ":[ \t]*$")) {
              in_parent = 1
            }
            break
          }

          if (current_indent == 0 && line !~ /^[ \t]*$/) {
            in_parent = 0
            break
          }

          trimmed = trim(line)
          if (trimmed ~ ("^" key2 ":[ \t]*")) {
            value = trimmed
            sub(("^" key2 ":[ \t]*"), "", value)

            if (value == "|" || value == ">") {
              collecting_block = 1
              block_style = value
              block_value = ""
              block_indent = current_indent + 2
              break
            }

            print decode_scalar(value)
            found = 1
            exit
          }

          break
        }

        if (current_indent != 0) {
          break
        }

        if (line ~ ("^" key1 ":[ \t]*")) {
          value = line
          sub(("^" key1 ":[ \t]*"), "", value)

          if (value == "|" || value == ">") {
            collecting_block = 1
            block_style = value
            block_value = ""
            block_indent = 2
            break
          }

          print decode_scalar(value)
          found = 1
          exit
        }

        break
      }
    }

    END {
      if (!found && collecting_block) {
        flush_block()
      }
    }
  ' "$file"
}

frontmatter_get_list() {
  local file="$1" path="$2"

  awk -v path="$path" '
    function indent_count(s) {
      match(s, /^[ \t]*/)
      return RLENGTH
    }

    function trim(s) {
      sub(/^[ \t]+/, "", s)
      sub(/[ \t]+$/, "", s)
      return s
    }

    function decode_scalar(s, first, last) {
      s = trim(s)
      first = substr(s, 1, 1)
      last = substr(s, length(s), 1)

      if (first == "\"" && last == "\"") {
        s = substr(s, 2, length(s) - 2)
        gsub(/\\\\/, "\001", s)
        gsub(/\\"/, "\"", s)
        gsub(/\\n/, "\n", s)
        gsub(/\\t/, "\t", s)
        gsub(/\\r/, "\r", s)
        gsub(/\\f/, "\f", s)
        gsub(/\\b/, "\b", s)
        gsub(/\001/, "\\", s)
        return s
      }

      if (first == "'"'"'" && last == "'"'"'") {
        s = substr(s, 2, length(s) - 2)
        gsub(/'\'''\''/, "'"'"'", s)
        return s
      }

      sub(/[ \t]+#.*/, "", s)
      return trim(s)
    }

    BEGIN {
      split(path, path_parts, /\./)
      depth = length(path_parts)
      key1 = path_parts[1]
      key2 = path_parts[2]
      in_frontmatter = 0
      frontmatter_done = 0
      in_parent = 0
      collecting = 0
      item_indent = -1
    }

    /^[ \t]*---[ \t]*$/ {
      if (!in_frontmatter) {
        in_frontmatter = 1
        next
      }

      if (!frontmatter_done) {
        frontmatter_done = 1
        exit
      }
    }

    !in_frontmatter || frontmatter_done {
      next
    }

    {
      line = $0
      current_indent = indent_count(line)
      trimmed = trim(line)

      if (depth == 2) {
        if (!in_parent) {
          if (current_indent == 0 && line ~ ("^" key1 ":[ \t]*$")) {
            in_parent = 1
          }
          next
        }

        if (current_indent == 0 && line !~ /^[ \t]*$/) {
          exit
        }

        if (!collecting) {
          if (trimmed ~ ("^" key2 ":[ \t]*$")) {
            collecting = 1
            item_indent = current_indent + 2
          }
          next
        }
      } else {
        if (!collecting) {
          if (current_indent == 0 && line ~ ("^" key1 ":[ \t]*$")) {
            collecting = 1
            item_indent = 2
          }
          next
        }
      }

      if (trimmed == "") {
        next
      }

      if (current_indent < item_indent) {
        exit
      }

      if (current_indent == item_indent && trimmed ~ /^-[ \t]*/) {
        sub(/^-[ \t]*/, "", trimmed)
        print decode_scalar(trimmed)
        next
      }

      exit
    }
  ' "$file"
}

frontmatter_body() {
  awk '
    BEGIN { in_frontmatter = 0; frontmatter_done = 0 }
    /^[ \t]*---[ \t]*$/ && !frontmatter_done {
      if (!in_frontmatter) {
        in_frontmatter = 1
        next
      }

      frontmatter_done = 1
      next
    }

    in_frontmatter && !frontmatter_done { next }
    { print }
  ' "$1"
}

require_field() {
  local file="$1" field="$2" value="$3"
  if [[ -z "$value" ]]; then
    echo "ERROR: missing required frontmatter field '$field' in $file" >&2
    exit 1
  fi
}

frontmatter_validate_excluded_hosts() {
  local file="$1" excluded_host

  while IFS= read -r excluded_host; do
    [[ -z "$excluded_host" ]] && continue

    case "$excluded_host" in
      claude | codex) ;;
      *)
        echo "ERROR: invalid excluded_hosts value '$excluded_host' in $file (valid: claude, codex)" >&2
        return 1
        ;;
    esac
  done < <(frontmatter_get_list "$file" "excluded_hosts")
}

frontmatter_host_is_excluded() {
  local file="$1" host="$2" excluded_host

  while IFS= read -r excluded_host; do
    [[ "$excluded_host" == "$host" ]] && return 0
  done < <(frontmatter_get_list "$file" "excluded_hosts")

  return 1
}
