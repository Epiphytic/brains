#!/usr/bin/env bash
# Start the brainstorm server and output connection info
# Usage: start-server.sh [--project-dir <path>] [--host <bind-host>] [--url-host <display-host>] [--port <port>] [--foreground] [--background]
#
# Starts server on a random high port by default, outputs JSON with URL.
# Each session gets its own directory to avoid conflicts.
#
# Port selection (in order of precedence):
#   1. --port N                               explicit one-shot override; no state tracking
#   2. ~/.config/brains/companion.json        if file has "start_port": N, uses N on first
#                                             run and increments by 1 on each subsequent run.
#                                             State persisted at ~/.local/state/brains/companion-next-port.txt
#   3. random ephemeral port (default)        49152..65535, no state
#
# If the chosen port is already in use, the server retries up to 9 additional
# ports (port..port+9). If all 10 fail, the server exits with an error.
#
# Options:
#   --project-dir <path>  Store session files under <path>/.superpowers/brainstorm/
#                         instead of /tmp. Files persist after server stops.
#   --host <bind-host>    Host/interface to bind (default: 127.0.0.1).
#                         Use 0.0.0.0 in remote/containerized environments.
#   --url-host <host>     Hostname shown in returned URL JSON.
#   --port <port>         Explicit port (1024-65535). Overrides config/state.
#   --foreground          Run server in the current terminal (no backgrounding).
#   --background          Force background mode (overrides Codex auto-foreground).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse arguments
PROJECT_DIR=""
FOREGROUND="false"
FORCE_BACKGROUND="false"
BIND_HOST="127.0.0.1"
URL_HOST=""
EXPLICIT_PORT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --host)
      BIND_HOST="$2"
      shift 2
      ;;
    --url-host)
      URL_HOST="$2"
      shift 2
      ;;
    --port)
      EXPLICIT_PORT="$2"
      shift 2
      ;;
    --foreground|--no-daemon)
      FOREGROUND="true"
      shift
      ;;
    --background|--daemon)
      FORCE_BACKGROUND="true"
      shift
      ;;
    *)
      echo "{\"error\": \"Unknown argument: $1\"}"
      exit 1
      ;;
  esac
done

# Port selection: explicit --port > companion.json start_port + state > random (server default)
PORT=""
if [[ -n "$EXPLICIT_PORT" ]]; then
  if ! [[ "$EXPLICIT_PORT" =~ ^[0-9]+$ ]] || (( EXPLICIT_PORT < 1024 || EXPLICIT_PORT > 65535 )); then
    echo "{\"error\": \"--port must be an integer between 1024 and 65535\"}"
    exit 1
  fi
  PORT="$EXPLICIT_PORT"
else
  CONFIG_FILE="${BRAINS_COMPANION_CONFIG:-$HOME/.config/brains/companion.json}"
  if [[ -f "$CONFIG_FILE" ]]; then
    START_PORT=$(node -e "try { const j=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); const p=Number(j.start_port); if(Number.isInteger(p) && p>=1024 && p<=65525) console.log(p); } catch {}" "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$START_PORT" && "$START_PORT" =~ ^[0-9]+$ ]]; then
      PORT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/brains"
      PORT_STATE_FILE="$PORT_STATE_DIR/companion-next-port.txt"
      mkdir -p "$PORT_STATE_DIR"
      NEXT_PORT="$START_PORT"
      if [[ -f "$PORT_STATE_FILE" ]]; then
        SAVED=$(cat "$PORT_STATE_FILE" 2>/dev/null)
        if [[ "$SAVED" =~ ^[0-9]+$ ]] && (( SAVED >= START_PORT && SAVED <= 65525 )); then
          NEXT_PORT="$SAVED"
        fi
      fi
      PORT="$NEXT_PORT"
      # Persist the incremented port for next invocation; wrap back to start_port near the ceiling.
      INCREMENTED=$((PORT + 1))
      if (( INCREMENTED > 65525 )); then
        INCREMENTED="$START_PORT"
      fi
      echo "$INCREMENTED" > "$PORT_STATE_FILE"
    fi
  fi
fi

if [[ -z "$URL_HOST" ]]; then
  if [[ "$BIND_HOST" == "127.0.0.1" || "$BIND_HOST" == "localhost" ]]; then
    URL_HOST="localhost"
  else
    URL_HOST="$BIND_HOST"
  fi
fi

# Some environments reap detached/background processes. Auto-foreground when detected.
if [[ -n "${CODEX_CI:-}" && "$FOREGROUND" != "true" && "$FORCE_BACKGROUND" != "true" ]]; then
  FOREGROUND="true"
fi

# Windows/Git Bash reaps nohup background processes. Auto-foreground when detected.
if [[ "$FOREGROUND" != "true" && "$FORCE_BACKGROUND" != "true" ]]; then
  case "${OSTYPE:-}" in
    msys*|cygwin*|mingw*) FOREGROUND="true" ;;
  esac
  if [[ -n "${MSYSTEM:-}" ]]; then
    FOREGROUND="true"
  fi
fi

# Generate unique session directory
SESSION_ID="$$-$(date +%s)"

if [[ -n "$PROJECT_DIR" ]]; then
  SESSION_DIR="${PROJECT_DIR}/.superpowers/brainstorm/${SESSION_ID}"
else
  SESSION_DIR="/tmp/brainstorm-${SESSION_ID}"
fi

STATE_DIR="${SESSION_DIR}/state"
PID_FILE="${STATE_DIR}/server.pid"
LOG_FILE="${STATE_DIR}/server.log"

# Create fresh session directory with content and state peers
mkdir -p "${SESSION_DIR}/content" "$STATE_DIR"

# Kill any existing server
if [[ -f "$PID_FILE" ]]; then
  old_pid=$(cat "$PID_FILE")
  kill "$old_pid" 2>/dev/null
  rm -f "$PID_FILE"
fi

cd "$SCRIPT_DIR"

# Resolve the harness PID (grandparent of this script).
# $PPID is the ephemeral shell the harness spawned to run us — it dies
# when this script exits. The harness itself is $PPID's parent.
OWNER_PID="$(ps -o ppid= -p "$PPID" 2>/dev/null | tr -d ' ')"
if [[ -z "$OWNER_PID" || "$OWNER_PID" == "1" ]]; then
  OWNER_PID="$PPID"
fi

# Foreground mode for environments that reap detached/background processes.
if [[ "$FOREGROUND" == "true" ]]; then
  echo "$$" > "$PID_FILE"
  env BRAINSTORM_DIR="$SESSION_DIR" BRAINSTORM_HOST="$BIND_HOST" BRAINSTORM_URL_HOST="$URL_HOST" BRAINSTORM_OWNER_PID="$OWNER_PID" ${PORT:+BRAINSTORM_PORT="$PORT"} node server.cjs
  exit $?
fi

# Start server, capturing output to log file
# Use nohup to survive shell exit; disown to remove from job table
nohup env BRAINSTORM_DIR="$SESSION_DIR" BRAINSTORM_HOST="$BIND_HOST" BRAINSTORM_URL_HOST="$URL_HOST" BRAINSTORM_OWNER_PID="$OWNER_PID" ${PORT:+BRAINSTORM_PORT="$PORT"} node server.cjs > "$LOG_FILE" 2>&1 &
SERVER_PID=$!
disown "$SERVER_PID" 2>/dev/null
echo "$SERVER_PID" > "$PID_FILE"

# Wait for server-started message (check log file)
for i in {1..50}; do
  if grep -q "server-started" "$LOG_FILE" 2>/dev/null; then
    # Verify server is still alive after a short window (catches process reapers)
    alive="true"
    for _ in {1..20}; do
      if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        alive="false"
        break
      fi
      sleep 0.1
    done
    if [[ "$alive" != "true" ]]; then
      echo "{\"error\": \"Server started but was killed. Retry in a persistent terminal with: $SCRIPT_DIR/start-server.sh${PROJECT_DIR:+ --project-dir $PROJECT_DIR} --host $BIND_HOST --url-host $URL_HOST --foreground\"}"
      exit 1
    fi
    grep "server-started" "$LOG_FILE" | head -1
    exit 0
  fi
  sleep 0.1
done

# Timeout - server didn't start
echo '{"error": "Server failed to start within 5 seconds"}'
exit 1
