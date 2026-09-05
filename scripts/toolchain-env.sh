# Wire podman to the host engine when a poop socket is present, otherwise let
# podman act as an in-container (nested) engine.
if [ -n "${POOP_SOCKET:-}" ] && [ -S "$POOP_SOCKET" ]; then
    export CONTAINER_HOST="unix://$POOP_SOCKET"
    export PODMAN_HOST="$CONTAINER_HOST"
fi