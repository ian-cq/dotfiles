#!/usr/bin/env bash
#
# Build a fresh Ubuntu container and run the two-step dotfiles onboarding in it.
# Useful for iterating locally on prereqs.sh / install without pushing to CI.
#
# Verification is intentionally NOT done here — the authoritative onboarding
# smoke test lives in .github/workflows/main.yaml (which exercises both
# ubuntu-latest and macos-latest). This script is a local convenience wrapper.
#
# Usage:
#   scripts/run.sh          # build image + run onboarding
#   scripts/run.sh shell    # drop into an interactive shell in the container
#
# Container engine: auto-detected — nerdctl (containerd), podman, docker.
# Override with CONTAINER_ENGINE=<name>. Rootful engines are invoked with sudo
# automatically when needed.
set -euo pipefail

IMAGE="dotfiles-onboard-test"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pick_engine() {
  if [[ -n "${CONTAINER_ENGINE:-}" ]]; then echo "$CONTAINER_ENGINE"; return; fi
  for e in nerdctl podman docker; do
    command -v "$e" >/dev/null && { echo "$e"; return; }
  done
  echo ""
}

ENGINE="$(pick_engine)"
[[ -n "$ENGINE" ]] || { echo "[run] no container engine found (nerdctl/podman/docker)" >&2; exit 1; }

SUDO=""
if ! "$ENGINE" info >/dev/null 2>&1; then
  if command -v sudo >/dev/null && sudo "$ENGINE" info >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "[run] '$ENGINE' cannot reach its daemon (even with sudo)." >&2
    exit 1
  fi
fi

run() { $SUDO "$ENGINE" "$@"; }

echo "[run] Engine: ${SUDO:+sudo }$ENGINE"
echo "[run] Building image ${IMAGE} from a clean ubuntu:24.04…"
run build -t "$IMAGE" -f "$REPO_ROOT/scripts/Dockerfile" "$REPO_ROOT"

if [[ "${1:-}" == "shell" ]]; then
  exec $SUDO "$ENGINE" run --rm -it "$IMAGE" bash
fi

echo "[run] Running onboarding inside the container (SKIP_BREW=1, FORCE_SOURCE_BUILD=1)…"
run run --rm \
  -e SKIP_BREW=1 \
  -e FORCE_SOURCE_BUILD=1 \
  "$IMAGE" bash -c './scripts/prereqs.sh && ./install'
