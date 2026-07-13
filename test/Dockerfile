# Test image: a minimal, "fresh" Ubuntu machine for exercising onboarding.
#
# It intentionally does NOT pre-install the dotfiles toolchain (git, stow,
# zsh, …) — scripts/prereqs.sh is responsible for that. The only extras are:
#   * sudo + a non-root user (a real workstation is not root)
#   * ca-certificates/curl so the scripts can reach the network
#   * golang — stands in for the prebuilt release binary that `install` would
#     normally download; here `install` builds setup_quanianitis from source.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo ca-certificates curl golang-go \
 && rm -rf /var/lib/apt/lists/*

# Non-root user with passwordless sudo, mirroring a real workstation account.
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
