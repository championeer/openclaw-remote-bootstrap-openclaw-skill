---
name: openclaw-remote-bootstrap
description: Bootstrap OpenClaw on a remote server over SSH (Linux or macOS): install the OpenClaw CLI, run `openclaw onboard` in non-interactive mode to generate basic config, install the daemon (systemd/launchd), and perform health/status checks. Use when asked to SSH into a machine and install/configure OpenClaw, or when you need a repeatable, parameterized remote setup script.
---

# OpenClaw remote bootstrap (SSH)

Use the bundled script to install OpenClaw and run the onboarding wizard non-interactively.

## Inputs you must collect

- SSH target: `user@host` (and optional `port`, `identity_file`)
- OS hint (optional): `linux|macos` (script auto-detects)
- Auth choice + key (pick one):
  - `apiKey` + `ANTHROPIC_API_KEY` (recommended)
  - `gemini-api-key` + `GEMINI_API_KEY`
  - `synthetic-api-key` + `SYNTHETIC_API_KEY`
  - Other auth choices supported by `openclaw onboard --help`
- Gateway basics:
  - `gateway_port` (default 18789)
  - `gateway_bind` (`loopback` by default; use `0.0.0.0` only if you know what you’re doing)
- Whether to install daemon: default yes (`--install-daemon`) and runtime `node`

## Quick start

From the machine running this agent:

```bash
bash skills/openclaw-remote-bootstrap/scripts/remote_bootstrap.sh \
  --host user@server.example.com \
  --port 22 \
  --identity ~/.ssh/id_ed25519 \
  --auth-choice apiKey \
  --anthropic-api-key "$ANTHROPIC_API_KEY" \
  --gateway-port 18789 \
  --gateway-bind loopback
```

## What the script does

1. Connect via SSH and detect OS/package manager.
2. Ensure basic prerequisites (`curl`, optional `brew`/`apt`).
3. Install OpenClaw CLI (preferred: `curl -fsSL https://openclaw.bot/install.sh | bash`; fallback: `npm install -g openclaw@latest`).
4. Run:

```bash
openclaw onboard --non-interactive \
  --mode local \
  --auth-choice <...> \
  --gateway-port <...> \
  --gateway-bind <...> \
  --install-daemon \
  --daemon-runtime node \
  --skip-skills
```

5. Verify:

```bash
openclaw gateway status
openclaw status
openclaw health
```

## Notes / guardrails

- Prefer `gateway_bind=loopback` unless you have a reverse proxy/VPN/Tailscale plan.
- Secrets should be passed as env vars or flags; never paste them into chat logs.
- If onboarding fails, re-run with `--json` and inspect the error output.
