#!/usr/bin/env bash
#
# Build a fresh Ubuntu container and run the two-step dotfiles onboarding in it,
# then verify the result. This is the smoke test for "does onboarding work on a
# clean Linux machine in two script runs?".
#
# Usage:
#   test/run.sh          # build image + run onboarding + verify
#   test/run.sh shell    # drop into an interactive shell in the test container
#
# Container engine: auto-detected in this order — nerdctl (containerd), podman,
# docker. Override with CONTAINER_ENGINE=<name>. Rootful engines (nerdctl talking
# to a system containerd) are invoked with sudo automatically when needed.
set -euo pipefail

IMAGE="dotfiles-onboard-test"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- pick a container engine ------------------------------------------------
pick_engine() {
  if [[ -n "${CONTAINER_ENGINE:-}" ]]; then echo "$CONTAINER_ENGINE"; return; fi
  for e in nerdctl podman docker; do
    command -v "$e" >/dev/null && { echo "$e"; return; }
  done
  echo ""
}

ENGINE="$(pick_engine)"
[[ -n "$ENGINE" ]] || { echo "[test] no container engine found (nerdctl/podman/docker)" >&2; exit 1; }
command -v "$ENGINE" >/dev/null || { echo "[test] '$ENGINE' not found" >&2; exit 1; }

# Decide whether the engine needs sudo to reach its daemon.
SUDO=""
if ! "$ENGINE" info >/dev/null 2>&1; then
  if command -v sudo >/dev/null && sudo "$ENGINE" info >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "[test] '$ENGINE' cannot reach its daemon (even with sudo). Is containerd running?" >&2
    exit 1
  fi
fi

run() { $SUDO "$ENGINE" "$@"; }

echo "[test] Engine: ${SUDO:+sudo }$ENGINE"
echo "[test] Building image ${IMAGE} from a clean ubuntu:24.04…"
run build -t "$IMAGE" -f "$REPO_ROOT/test/Dockerfile" "$REPO_ROOT"

if [[ "${1:-}" == "shell" ]]; then
  exec $SUDO "$ENGINE" run --rm -it "$IMAGE" bash
fi

echo "[test] Running onboarding + verification inside the container…"
run run --rm "$IMAGE" bash /home/ian/dotfiles/test/onboard-and-verify.sh
