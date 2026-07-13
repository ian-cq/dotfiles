# scripts/Dockerfile
# A minimal, "fresh" Ubuntu machine for exercising the onboarding scripts
# locally via scripts/run.sh. CI does the same thing directly on
# ubuntu-latest / macos-latest runners (.github/workflows/main.yaml) — this
# image exists so you can iterate on prereqs.sh / install without pushing.
#
# Deliberately does NOT pre-install git/stow/zsh/etc — that's prereqs.sh's job.
# Only the bare minimum:
#   * sudo + a non-root user (a real workstation is not root)
#   * ca-certificates/curl so the scripts can reach the network
#   * golang — stands in for the prebuilt release binary that `install` would
#     normally download; with FORCE_SOURCE_BUILD=1 `install` builds from source.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo ca-certificates curl golang-go \
 && rm -rf /var/lib/apt/lists/*

ARG USER=ian
RUN useradd -m -s /bin/bash "$USER" \
 && echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$USER" \
 && chmod 0440 /etc/sudoers.d/"$USER"

USER ian
WORKDIR /home/ian

# Copy the working tree in as ~/dotfiles (install skips cloning when present).
COPY --chown=ian:ian . /home/ian/dotfiles
WORKDIR /home/ian/dotfiles

CMD ["bash"]
