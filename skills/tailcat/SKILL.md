---
name: tailcat
description: >
  Pipe data, forward ports, SSH, copy files, or measure throughput between two machines with
  tailcat, a netcat-like CLI over Tailscale's WireGuard data plane with no Tailscale account or
  control plane. Use when the user says "tailcat", has a "tc..." address to connect to, wants to
  send a file or text to another machine, expose a local port or dev server to someone else, SSH
  into a machine behind NAT without opening ports, or reach a device on a remote LAN.
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
