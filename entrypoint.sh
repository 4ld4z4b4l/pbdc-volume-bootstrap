#!/usr/bin/env sh
set -e

log() { printf '[devctl] %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1) Container engine socket: detect the "poop" socket and bind the default
#    podman/docker socket paths to it, then expose via env vars.
# ---------------------------------------------------------------------------
POOP="${POOP_SOCKET:-/root/.poop/poop}"
if [ -S "$POOP" ]; then
    log "detected poop socket at $POOP"
    mkdir -p /run/podman /var/run
    if command -v mount >/dev/null 2>&1; then
        mount --bind "$POOP" /run/podman/podman.sock 2>/dev/null || true
        mount --bind "$POOP" /var/run/docker.sock 2>/dev/null || true
    fi
    ln -sfn "$POOP" /run/podman/podman.sock
    ln -sfn "$POOP" /var/run/docker.sock
    export DOCKER_HOST="unix:///var/run/docker.sock"
    export PODMAN_HOST="unix:///var/run/docker.sock"
    export CONTAINER_HOST="$DOCKER_HOST"
    log "bound socket -> DOCKER_HOST=$DOCKER_HOST"
elif [ -S /var/run/docker.sock ]; then
    export DOCKER_HOST="unix:///var/run/docker.sock"
    export PODMAN_HOST="$DOCKER_HOST"
    export CONTAINER_HOST="$DOCKER_HOST"
    log "using existing Docker/docker-compatible socket"
elif [ -S /run/podman/podman.sock ]; then
    export DOCKER_HOST="unix:///run/podman/podman.sock"
    export PODMAN_HOST="$DOCKER_HOST"
    export CONTAINER_HOST="$DOCKER_HOST"
    log "using existing podman socket"
else
    log "WARNING: no container engine socket found; devcontainer CLI will fail"
fi

# ---------------------------------------------------------------------------
# 2) Clone the given git project into the workspace volume.
# ---------------------------------------------------------------------------
WORKS="${DEV_WORKSPACE:-/workspace}"
mkdir -p "$WORKS"
cd "$WORKS"

if [ -n "${GIT_URL:-}" ]; then
    NAME="${PROJECT_NAME:-$(basename "$GIT_URL" .git)}"
    if [ -d "$NAME/.git" ]; then
        log "project already cloned at $WORKS/$NAME"
    else
        log "cloning $GIT_URL -> $WORKS/$NAME"
        git clone --depth 1 "$GIT_URL" "$NAME"
    fi
    cd "$NAME"
    log "project dir: $(pwd)"
else
    log "GIT_URL not set; using mounted workspace $WORKS"
fi

# ---------------------------------------------------------------------------
# 3) Search for a devcontainer configuration.
# ---------------------------------------------------------------------------
DC=""
for f in .devcontainer/devcontainer.json .devcontainer.json; do
    if [ -f "$f" ]; then
        DC="$f"
        break
    fi
done
if [ -z "$DC" ]; then
    DC="$(find . -maxdepth 3 -name devcontainer.json -not -path '*/node_modules/*' | head -n1)"
fi
if [ -z "$DC" ]; then
    log "no devcontainer.json found in $(pwd)"
    exit 1
fi
log "devcontainer config: $DC"

# ---------------------------------------------------------------------------
# 4) Launch the devcontainer.
# ---------------------------------------------------------------------------
log "launching devcontainer for workspace $(pwd)"
exec devcontainer up --workspace-folder "$PWD" $DEVCTL_ARGS