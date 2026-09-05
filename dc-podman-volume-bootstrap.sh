#!/usr/bin/env sh
set -e

log() { printf '[dcbootstrap] %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1) Container engine socket: podman 6.x may mount its API socket into the
#    container (commonly /root/.poop/poop). Bind it to the conventional paths
#    and expose it via DOCKER_HOST.
# ---------------------------------------------------------------------------
POOP="${POOP_SOCKET:-/root/.poop/poop}"
found=""
for s in "$POOP" /var/run/docker.sock /run/podman/podman.sock; do
    if [ -S "$s" ]; then found="$s"; break; fi
done
if [ -z "$found" ]; then
    log "WARNING: no container engine socket found; devcontainer CLI will fail"
else
    mkdir -p /run/podman /var/run
    ln -sfn "$found" /run/podman/podman.sock
    ln -sfn "$found" /var/run/docker.sock
    export DOCKER_HOST="unix:///run/podman/podman.sock"
    export PODMAN_HOST="$DOCKER_HOST"
    export CONTAINER_HOST="$DOCKER_HOST"
    log "socket -> DOCKER_HOST=$DOCKER_HOST"
fi

# ---------------------------------------------------------------------------
# 2) Clone (or pull) the project into the named workspace volume.
# ---------------------------------------------------------------------------
WORKSPACE="/workspace"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

PROJ=""
if [ -n "${GIT_URL:-}" ]; then
    PROJ="${PROJECT_NAME:-$(basename "$GIT_URL" .git)}"
    if [ -d "$PROJ/.git" ]; then
        log "project exists; git pull"
        git -C "$PROJ" pull --ff-only
    else
        log "cloning $GIT_URL -> $PROJ"
        git clone "$GIT_URL" "$PROJ"
    fi
    cd "$PROJ"
else
    log "GIT_URL not set; using mounted workspace"
    PROJ="$(basename "$PWD")"
fi

# ---------------------------------------------------------------------------
# 3) Locate the dev container configuration (spec precedence).
# ---------------------------------------------------------------------------
DC=""
for f in .devcontainer/devcontainer.json .devcontainer.json; do
    [ -f "$f" ] && { DC="$f"; break; }
done
if [ -z "$DC" ]; then
    DC="$(find . -maxdepth 3 -name devcontainer.json -not -path '*/node_modules/*' | head -n1)"
fi
if [ -z "$DC" ]; then
    log "no devcontainer.json found in $PWD"
    exit 1
fi
log "config: $DC"

# ---------------------------------------------------------------------------
# 4) Inject volume-based workspaceMount/workspaceFolder and devnet runArgs.
#    The CLI passes an explicit workspaceMount verbatim; without it, it would
#    synthesize a host bind mount that breaks a volume workspace.
# ---------------------------------------------------------------------------
VOL="${WORKSPACE_VOLUME:?WORKSPACE_VOLUME is required}"
NETWORK="${NETWORK:-devnet}"
CFG_DIR="$(mktemp -d)"
CFG="$CFG_DIR/devcontainer.json"

NODE_DC="$DC" NODE_VOL="$VOL" NODE_PROJ="$PROJ" NODE_NETWORK="$NETWORK" NODE_OUT="$CFG" node -e '
  const fs = require("fs");
  const raw = fs.readFileSync(process.env.NODE_DC, "utf8");
  let cur = "", inStr = false, esc = false;
  for (let i = 0; i < raw.length; i++) {
    const c = raw.charAt(i), n = raw.charAt(i + 1);
    if (inStr) {
      cur += c;
      if (esc) esc = false;
      else if (c === "\\") esc = true;
      else if (c === "\"") inStr = false;
      continue;
    }
    if (c === "\"") { inStr = true; cur += c; continue; }
    if (c === "/" && n === "/") { i += 2; while (i < raw.length && raw.charAt(i) !== "\n") i++; cur += "\n"; continue; }
    if (c === "/" && n === "*") { i += 2; while (i < raw.length && !(raw.charAt(i) === "*" && raw.charAt(i + 1) === "/")) i++; i++; continue; }
    cur += c;
  }
  let out = "", inStr2 = false, esc2 = false;
  for (let i = 0; i < cur.length; i++) {
    const c = cur.charAt(i);
    if (inStr2) {
      out += c;
      if (esc2) esc2 = false;
      else if (c === "\\") esc2 = true;
      else if (c === "\"") inStr2 = false;
      continue;
    }
    if (c === "\"") { inStr2 = true; out += c; continue; }
    if (c === ",") { let j = i + 1; while (j < cur.length && /\s/.test(cur.charAt(j))) j++; if (cur.charAt(j) === "}" || cur.charAt(j) === "]") continue; }
    out += c;
  }
  const src = JSON.parse(out);
  src.workspaceMount = "type=volume,source=" + process.env.NODE_VOL + ",target=/workspace";
  src.workspaceFolder = "/workspace/" + process.env.NODE_PROJ;
  const ra = Array.isArray(src.runArgs) ? src.runArgs : [];
  const net = "--network=" + process.env.NODE_NETWORK;
  if (!ra.includes(net)) ra.push(net);
  src.runArgs = ra;
  fs.writeFileSync(process.env.NODE_OUT, JSON.stringify(src, null, 2) + "\n");
'
log "injected $CFG (workspaceMount=$VOL -> /workspace, network=$NETWORK)"

# ---------------------------------------------------------------------------
# 5) Launch the dev container against the host's rootless podman socket.
# ---------------------------------------------------------------------------
log "launching dev container for $PWD"
exec devcontainer up \
    --docker-path /usr/bin/podman \
    --workspace-folder "$PWD" \
    --config "$CFG" \
    --mount-workspace-git-root=false