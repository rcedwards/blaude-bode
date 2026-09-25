---
name: tailcat
description: >
  Use when both ends of a connection are machines the user or a teammate can run a command on,
  and they need to talk directly but one is behind NAT, a firewall, or a network with no inbound
  ports, with no Tailscale or VPN already linking them. Covers: a teammate reaching my localhost
  dev server, API, or database; sending a file, logs, crash dump, or build artifact to another
  machine too big for Slack or when AirDrop won't work; a shell on or files from a home machine,
  lab box, CI runner, or cloud VM with no public IP; reaching a device on a remote LAN (Android
  adb, a NAS, an internal web UI) through a machine on that network; piping stdout between hosts.
  Also use when the user says "tailcat" or pastes a "tc..." address. When the other end is a
  third-party service or anyone who cannot install software (Stripe or GitHub webhooks, OAuth
  redirects, a public link), the request is for a public URL tunnel, not this skill.
---

# tailcat

## Overview

One side runs a server and prints a tailcat address (`tc...`, ~150 chars, case-sensitive). The
other side passes that address to a client command. Traffic is WireGuard-encrypted end to end,
bootstraps through a DERP relay, then upgrades to direct UDP when NAT traversal works. No root, no
routing or DNS changes. Installed with `brew install tailcat`.

Full docs: `tailcat readme`. Per-command flags: `tailcat <subcommand> --help`. Prefer these over
the GitHub README, which tracks main and documents features (`perf`, `serve` port mappings like
`5555:10.0.0.5:5555`) that v0.7.0 does not have. Check `tailcat version` if a documented command
fails.

## Check first: does the other end run tailcat?

tailcat only connects two machines that both run the tailcat CLI. It has no public URL. Stop and
use something else when:

- The other end is a third-party service or a person who won't install software (Stripe or
  GitHub webhooks, OAuth redirects, a link a client clicks, a phone browser): recommend a public
  tunnel such as ngrok or cloudflared instead.
- The machines already share a Tailscale tailnet or VPN: connect over it directly.
- The access must be permanent and multi-user: set up real Tailscale or a VPN instead of saved
  tailcat keys.

## When to use

| Problem | Recipe |
|---------|--------|
| Teammate needs to hit my local dev server or API | I run `serve <port>`; they run `forward <tc> <port>` or `browse <tc>` |
| Teammate needs my local Postgres/MySQL/Redis | I run `serve 5432`; they run `forward <tc> 15432:5432` and point their client at localhost |
| Send a large file, log bundle, or build artifact | Receiver runs `recv ~/inbox`; sender runs `cp <file> <tc>:` |
| Pull files off a remote box | Remote runs `serve files` in the directory; I run `ls`/`cp <tc>:path .` |
| Shell on a machine with no public IP (home server, CI runner, VM) | Remote runs `serve --ssh-authorized-keys=user@github ssh`; I run `ssh <tc>` |
| Reach a device on someone else's LAN (Android `adb`, NAS, router UI) | A machine on that LAN runs `serve exit-node`; I run `forward <tc> 5555:<device-ip>:5555`, then `adb connect 127.0.0.1:5555` |
| Stream command output to another host | Receiver runs `tailcat > out`; sender runs `<cmd> \| tailcat <tc>` |
| Run a CLI tool against a remote private network | Remote runs `serve exit-node`; I run `socks <tc> curl http://10.0.0.5/` |

Every recipe needs some private channel (DM, call) to pass the address.

## The address is a credential

The default address embeds a pre-shared key, so anyone holding it can connect. Treat it like a
password: share it only over private channels, and never paste it into commits, tickets, public
Slack channels, or DNS. Confirm with the user before running any of these, since each grants
broad access:

- `serve no-auth-ssh`: a shell as the current user for whoever has the address.
- `serve exit-node`: access to the server's whole network.
- `serve all`, `serve files --files=<dir>:rw`, `forward --bind=0.0.0.0`.
- Publishing an address in a DNS TXT record. Only safe with `serve --allow=<nodekey>` or
  `serve --ssh-authorized-keys=... ssh`.

## Running a server from an agent

Servers block until killed, and the address prints to stderr. Run the server in the background
and read the address from a file:

```bash
TAILCAT_ADDR_FILE=/path/addr tailcat serve 8080 &
# poll until /path/addr is non-empty, then use "$(cat /path/addr)"
```

Plain `tailcat` (no args) accepts a single connection, writes it to stdout, and exits. Ports
listed to `serve` proxy to the same port on localhost.

## Quick reference

| Goal | Server side | Client side |
|------|-------------|-------------|
| Pipe stdin/stdout | `tailcat > out` | `echo hi \| tailcat <tc>` |
| Expose local ports | `tailcat serve 8080,3306` | `tailcat forward <tc> 18080:8080 3306` |
| Open a web app | `tailcat serve 80` | `tailcat browse <tc>` |
| Reach a LAN host | `tailcat serve exit-node` | `tailcat forward <tc> 13306:10.0.0.5:3306` |
| SSH with keys | `tailcat serve --ssh-authorized-keys=user@github ssh` | `tailcat ssh <tc> [cmd]` |
| Receive files | `tailcat recv ~/inbox` | `tailcat cp file.pdf <tc>:` |
| Offer files | `tailcat serve files` | `tailcat ls -l <tc>`, `tailcat cp <tc>:f .` |
| Run a command per connection | `tailcat serve exec -- cmd` | `tailcat <tc> 80 < /dev/null` |
| Connectivity check | any server | `tailcat ping --until-direct <tc>` |
| SOCKS for another tool | any server | `tailcat socks <tc> curl http://server.tailcat:8081/` |
| Inspect an address | | `tailcat parse <tc>` |

`recv` renames each upload to `<name>.<timestamp>.<suffix>.<ext>`, so don't script against the
original filename; pass `--accept-dirs` to keep names (it lets senders probe existing names).
`forward` local port `0` picks a free port. Listeners bind `127.0.0.1` by default.

## Keys

- Default: ephemeral key per server run. The address dies when the process exits.
- `tailcat genkey --key=default` saves a key; plain `serve` then reuses it silently, and the
  startup line says "saved key". Use `--key=new` for a one-off ephemeral address.
- Client identity for `--allow` lists: `tailcat genkey --client --key=client-default`, then
  `tailcat printpub`.
- `tailcat genkey --list` / `--delete --key=<name>`.
- On macOS keys live in `~/Library/Application Support/tailcat/keys/`, not `~/.config`.

## Common mistakes

- Lowercasing or line-wrapping the address. Browsers lowercase hostnames, so `socks` with a
  `tc...` hostname works in curl but not browsers; use `forward` or `browse` instead.
- Assuming a direct path. Slow transfers usually mean traffic is relayed through rate-limited
  DERP; `ping --until-direct` shows which path is in use.
- Forgetting a saved `default` key exists, then sharing an address that previous recipients can
  still use.
- Expecting compression: SFTP transfers are uncompressed, so compress large files first.
