# openclaw-remote-bootstrap-openclaw-skill

Bootstrap **OpenClaw** on a remote server over SSH (Linux or macOS): install the OpenClaw CLI, run `openclaw onboard` in **non-interactive** mode, optionally install the daemon (systemd/launchd), then run basic health checks.

This repo is primarily intended to be used as an OpenClaw **skill**.

## Contents

- `SKILL.md` — skill metadata + how to use
- `scripts/remote_bootstrap.sh` — the actual SSH bootstrap script

## Quick start

From the machine where you have SSH access to the target server:

```bash
# Example: Anthropic API key auth
export ANTHROPIC_API_KEY="..."

bash skills/openclaw-remote-bootstrap/scripts/remote_bootstrap.sh \
  --host user@server.example.com \
  --port 22 \
  --identity ~/.ssh/id_ed25519 \
  --auth-choice apiKey \
  --gateway-port 18789 \
  --gateway-bind loopback
```

### Supported auth examples

- `--auth-choice apiKey` + `--anthropic-api-key ...` (or `ANTHROPIC_API_KEY` env)
- `--auth-choice gemini-api-key` + `--gemini-api-key ...` (or `GEMINI_API_KEY` env)
- `--auth-choice synthetic-api-key` + `--synthetic-api-key ...` (or `SYNTHETIC_API_KEY` env)

For other auth modes, run `openclaw onboard --help` on the target and extend the script accordingly.

## What it does

1. SSH to the target
2. Detect OS (`Linux`/`Darwin`) and ensure `curl` exists
3. Install OpenClaw CLI via:
   - preferred: `curl -fsSL https://openclaw.bot/install.sh | bash`
   - fallback: `npm install -g openclaw@latest`
4. Run:

```bash
openclaw onboard --non-interactive --mode local \
  --auth-choice ... \
  --gateway-port ... \
  --gateway-bind ... \
  --install-daemon --daemon-runtime node \
  --skip-skills
```

5. Verify:

```bash
openclaw gateway status
openclaw status
openclaw health
```

## Security notes

- Default is `--gateway-bind loopback` to avoid exposing the control UI/network surface.
- Do **not** paste API keys into chat logs. Prefer environment variables.
- If you must expose the gateway externally, use a VPN/Tailscale or a properly configured reverse proxy.

## License

TBD (pick one before wider distribution: MIT/Apache-2.0 recommended).
