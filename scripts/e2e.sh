#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${CONTAINER:-podman}"
IMG="${IMG:-localhost/pbdc-volume-bootstrap:fedora}"
GIT_URL="${1:-https://github.com/microsoft/vscode-remote-try-python.git}"

PROJECT_NAME="$(basename "${GIT_URL%.git}")"
VOL="pbdc-volume-bootstrap-$(printf '%s' "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
SOCK="${PODMAN_SOCKET:-$XDG_RUNTIME_DIR/podman/podman.sock}"
LOCAL_MACHINE="$(hostname -s)"

if [ ! -S "$SOCK" ]; then
    echo "error: no podman socket at $SOCK (systemctl --user start podman.socket)" >&2
    exit 1
fi

if ! "$CONTAINER" volume exists "$VOL"; then
    "$CONTAINER" volume create "$VOL" >/dev/null
fi

run_bootstrap() {
    "$CONTAINER" run --rm --network devnet \
        --name "pbdcb-${PROJECT_NAME//[^a-zA-Z0-9_.-]/_}" \
        -v "$VOL":/workspace \
        -v "$SOCK":/root/.poop/poop \
        -e GIT_URL="$GIT_URL" \
        -e PROJECT_NAME="$PROJECT_NAME" \
        -e WORKSPACE_VOLUME="$VOL" \
        -e NETWORK=devnet \
        -e LOCAL_MACHINE="$LOCAL_MACHINE" \
        "$IMG"
}

DEVNAME="$LOCAL_MACHINE.microsoft.vscode-remote-try-python.devcontainer"
DEVIMG="microsoft/vscode-remote-try-python-devcontainer"

echo "--- bootstrap run 1 ---"
LOG1="$(run_bootstrap 2>&1)"
echo "$LOG1"
grep -q '"outcome":"success"' <<<"$LOG1"

echo "--- bootstrap run 2 (must git pull, not re-clone) ---"
LOG2="$(run_bootstrap 2>&1)"
echo "$LOG2"
grep -q '"outcome":"success"' <<<"$LOG2"
grep -q 'project exists; git pull' <<<"$LOG2"

echo "--- naming ---"
"$CONTAINER" inspect "$DEVNAME" >/dev/null
"$CONTAINER" inspect "$DEVIMG" >/dev/null
NETWORKS="$("$CONTAINER" inspect --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$DEVNAME")"
grep -q 'devnet' <<<"$NETWORKS"

echo "--- cleanup ---"
"$CONTAINER" stop "$DEVNAME" >/dev/null
"$CONTAINER" rm "$DEVNAME" >/dev/null

echo "E2E OK"