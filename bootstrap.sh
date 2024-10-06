#!/bin/bash

set -eo pipefail

repository_owner="quanianitis"
repository_name="dotfiles"

if [[ "$1" == "--version" && -n "$2" ]]; then
    version="$2"
    echo "[INFO] Version provided: ${version}"
else
    echo -e "Usage: $0 --version <dotfiles_release_version>\nDefaulting to latest version..."
    sleep 2
    version=$(curl --silent "https://api.github.com/repos/${repository_owner}/${repository_name}/releases/latest" \
      | awk -F '"' '/"tag_name"/ {print $4}')
    echo "[INFO] Latest version found: ${version}"
fi

os=$(uname -s | awk '{print tolower($0)}')
arch=$(uname -m | sed 's/x86_64/amd64/;s/arm64/arm64/;s/aarch64/arm64/')

base_url="https://github.com/${repository_owner}/${repository_name}"
binary_path="releases/download"
binary="setup_quanianitis-${version}-${os}-${arch}.tar.gz"
source_code_path="archive/refs/tags"
source_code="${version}.tar.gz"
  
echo "[INFO] Downloading binaries and source code for version ${version}..."
curl -LO "${base_url}/${binary_path}/${version}/${binary}" \
     -LO "${base_url}/${source_code_path}/${source_code}"
# echo "${base_url}/${binary_path}/${version}/${binary}"
# echo "${base_url}/${source_code_path}/${source_code}"

tar -xzvf "${binary}"
tar -xzvf "${source_code}"

echo "[INFO] Copying dotfiles to home directory..."
cp -r "dotfiles-${version}/" "$HOME/dotfiles"
sudo mv ./setup_quanianitis /usr/local/bin

echo "[INFO] Running setup_quanianitis script..."
cd $HOME/dotfiles && /usr/local/bin/setup_quanianitis

echo "[INFO] Script completed successfully!"
