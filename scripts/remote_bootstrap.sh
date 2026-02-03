#!/usr/bin/env bash
set -euo pipefail

HOST=""
PORT="22"
IDENTITY=""
AUTH_CHOICE=""
ANTHROPIC_API_KEY=""
GEMINI_API_KEY=""
SYNTHETIC_API_KEY=""
GATEWAY_PORT="18789"
GATEWAY_BIND="loopback"
INSTALL_DAEMON="1"
DAEMON_RUNTIME="node"
SKIP_SKILLS="1"

usage() {
  cat <<'EOF'
Usage:
  remote_bootstrap.sh --host user@host [--port 22] [--identity ~/.ssh/id_ed25519]
                     --auth-choice <apiKey|gemini-api-key|synthetic-api-key|...>
                     [--anthropic-api-key XXX] [--gemini-api-key XXX] [--synthetic-api-key XXX]
                     [--gateway-port 18789] [--gateway-bind loopback|0.0.0.0]

Examples:
  ANTHROPIC_API_KEY=... bash remote_bootstrap.sh --host ubuntu@1.2.3.4 --auth-choice apiKey
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2;;
    --port) PORT="$2"; shift 2;;
    --identity) IDENTITY="$2"; shift 2;;
    --auth-choice) AUTH_CHOICE="$2"; shift 2;;
    --anthropic-api-key) ANTHROPIC_API_KEY="$2"; shift 2;;
    --gemini-api-key) GEMINI_API_KEY="$2"; shift 2;;
    --synthetic-api-key) SYNTHETIC_API_KEY="$2"; shift 2;;
    --gateway-port) GATEWAY_PORT="$2"; shift 2;;
    --gateway-bind) GATEWAY_BIND="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [[ -z "$HOST" || -z "$AUTH_CHOICE" ]]; then
  usage
  exit 2
fi

# Allow env-var injection
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-${ANTHROPIC_API_KEY:-}}"
GEMINI_API_KEY="${GEMINI_API_KEY:-${GEMINI_API_KEY:-}}"
SYNTHETIC_API_KEY="${SYNTHETIC_API_KEY:-${SYNTHETIC_API_KEY:-}}"

SSH_OPTS=("-p" "$PORT" "-o" "StrictHostKeyChecking=accept-new")
if [[ -n "$IDENTITY" ]]; then
  SSH_OPTS+=("-i" "$IDENTITY")
fi

# Build remote env export (avoid leaking keys in shell history as much as possible)
REMOTE_ENV=()
case "$AUTH_CHOICE" in
  apiKey)
    if [[ -z "$ANTHROPIC_API_KEY" ]]; then
      echo "Missing --anthropic-api-key (or ANTHROPIC_API_KEY env var) for auth-choice=apiKey" >&2
      exit 2
    fi
    REMOTE_ENV+=("ANTHROPIC_API_KEY=$(printf %q "$ANTHROPIC_API_KEY")")
    ;;
  gemini-api-key)
    if [[ -z "$GEMINI_API_KEY" ]]; then
      echo "Missing --gemini-api-key (or GEMINI_API_KEY env var) for auth-choice=gemini-api-key" >&2
      exit 2
    fi
    REMOTE_ENV+=("GEMINI_API_KEY=$(printf %q "$GEMINI_API_KEY")")
    ;;
  synthetic-api-key)
    if [[ -z "$SYNTHETIC_API_KEY" ]]; then
      echo "Missing --synthetic-api-key (or SYNTHETIC_API_KEY env var) for auth-choice=synthetic-api-key" >&2
      exit 2
    fi
    REMOTE_ENV+=("SYNTHETIC_API_KEY=$(printf %q "$SYNTHETIC_API_KEY")")
    ;;
  *)
    # For other auth choices, rely on explicit flags below.
    ;;
esac

REMOTE_SCRIPT=$(cat <<'EOS'
set -euo pipefail

log() { printf "[openclaw-bootstrap] %s\n" "$*"; }

OS="$(uname -s)"
log "OS=$OS"

ensure_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! ensure_cmd curl; then
  log "Installing curl..."
  if ensure_cmd apt-get; then
    sudo apt-get update -y
    sudo apt-get install -y curl ca-certificates
  elif ensure_cmd brew; then
    brew install curl
  else
    log "No supported package manager found to install curl. Install curl and re-run."; exit 1
  fi
fi

if ! ensure_cmd openclaw; then
  log "Installing OpenClaw CLI via install.sh"
  curl -fsSL https://openclaw.bot/install.sh | bash
fi

if ! ensure_cmd openclaw; then
  log "Fallback: installing OpenClaw via npm"
  if ensure_cmd npm; then
    npm install -g openclaw@latest
  else
    log "npm not found. Install Node/npm (or rerun after adding npm)."; exit 1
  fi
fi

log "OpenClaw version: $(openclaw version 2>/dev/null || true)"

# Build onboard command
ONBOARD=(openclaw onboard --non-interactive --mode local \
  --auth-choice "$AUTH_CHOICE" \
  --gateway-port "$GATEWAY_PORT" \
  --gateway-bind "$GATEWAY_BIND")

case "$AUTH_CHOICE" in
  apiKey)
    ONBOARD+=(--anthropic-api-key "$ANTHROPIC_API_KEY")
    ;;
  gemini-api-key)
    ONBOARD+=(--gemini-api-key "$GEMINI_API_KEY")
    ;;
  synthetic-api-key)
    ONBOARD+=(--synthetic-api-key "$SYNTHETIC_API_KEY")
    ;;
  *)
    log "Auth choice '$AUTH_CHOICE' may require additional flags; edit script invocation if needed."
    ;;
esac

if [[ "$INSTALL_DAEMON" == "1" ]]; then
  ONBOARD+=(--install-daemon --daemon-runtime "$DAEMON_RUNTIME")
fi
if [[ "$SKIP_SKILLS" == "1" ]]; then
  ONBOARD+=(--skip-skills)
fi

log "Running onboarding..."
"${ONBOARD[@]}" --json || (log "Onboard failed"; exit 1)

log "Verifying services..."
openclaw gateway status || true
openclaw status || true
openclaw health || true

log "Done. Control UI (if loopback): http://127.0.0.1:$GATEWAY_PORT/"
EOS
)

# shellcheck disable=SC2029
ssh "${SSH_OPTS[@]}" "$HOST" \
  "${REMOTE_ENV[*]} AUTH_CHOICE=$(printf %q "$AUTH_CHOICE") GATEWAY_PORT=$(printf %q "$GATEWAY_PORT") GATEWAY_BIND=$(printf %q "$GATEWAY_BIND") INSTALL_DAEMON=$(printf %q "$INSTALL_DAEMON") DAEMON_RUNTIME=$(printf %q "$DAEMON_RUNTIME") SKIP_SKILLS=$(printf %q "$SKIP_SKILLS") bash -s" \
  <<<"$REMOTE_SCRIPT"
