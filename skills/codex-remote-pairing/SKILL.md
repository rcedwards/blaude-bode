---
name: codex-remote-pairing
description: Pair ChatGPT mobile or another ChatGPT client with a remote Linux host running Codex Remote. Use when the user asks to enable Codex remote control, generate a manual pairing code, connect another device, or troubleshoot Codex remote pairing. Do not use for SSH setup that does not involve Codex Remote.
excluded_hosts:
  - claude
---

# Codex Remote Pairing

Pair the current Linux host with ChatGPT's Codex Remote interface. This is an experimental Codex
workflow, so inspect the installed CLI instead of assuming a particular command surface.

## Workflow

1. Confirm the prerequisites:

   ```bash
   codex --version
   codex login status
   ```

   Continue only when the login status says `Logged in using ChatGPT`. An API-key-only login is not
   sufficient. If authentication is missing, ask the user to complete `codex login`.

2. Inspect `codex remote-control --help`. Prefer the native commands when available:

   ```bash
   codex remote-control start --json
   codex remote-control pair --json
   ```

   Starting remote control and creating a pairing code write daemon state under `~/.codex`; request
   the required filesystem approval when the sandbox blocks those writes.

3. Return only the short `manualPairingCode`, host name or environment ID, and expiration time in
   the user's local timezone. Tell the user to enter it promptly in ChatGPT → Codex → Remote → Add
   connection → Manual pairing. Do not expose the long `pairingCode` unless explicitly requested.

4. Generate another code with `codex remote-control pair --json` when the user wants to connect an
   additional client. Do not stop or restart a healthy daemon merely to create another code.

## Compatibility Fallback

If `remote-control pair` is unavailable but the app-server control socket exists, run:

```bash
node scripts/manual-pair.js
```

The helper speaks the experimental app-server WebSocket protocol and prints the short code. Use it
only after the native command is unavailable. If neither the command nor socket exists, report the
installed Codex version and recommend upgrading rather than inventing another protocol path.

If start reports that the app server is not managed by the Codex daemon, an existing Desktop SSH
connection may own it. Let the user choose between disconnecting that Desktop session or using the
socket fallback; do not terminate their process without approval.

## Verification

After the user pairs, confirm that the host appears in their Remote list. For local diagnostics use
`codex login status`, the JSON result from `remote-control start`, and narrowly matched process
inspection. A missing process match alone does not disprove a healthy daemon when the JSON status is
`connected`.

For current supported connection flows and limitations, consult the official OpenAI Remote
connections documentation: https://learn.chatgpt.com/docs/remote-connections
