#!/usr/bin/env bash
# Point sources.json at the newest Ardia release that ships a Linux tarball.
# Upstream publishes Linux builds only in some nightlies, so releases are
# scanned newest first (prereleases included, drafts skipped) and the first
# one carrying the asset wins. The hash comes from upstream's .sha256 sidecar,
# so the tarball itself is never downloaded.
#
# Needs: gh (authenticated, or GH_TOKEN set), jq, nix.
# Prints the new version on stdout when sources.json changed, nothing otherwise.
set -euo pipefail
cd "$(dirname "$0")"

repo=${ARDIA_REPO:-ardia-browser/ardia}
asset_re='^Ardia-.*-linux-x64\.tar\.xz$'

release=$(gh api "repos/$repo/releases?per_page=100" | jq --arg re "$asset_re" '
  [.[] | select(.draft | not)
       | select(any(.assets[]; .name | test($re)))][0]
  | {tag: .tag_name,
     url: (.assets[] | select(.name | test($re)) | .browser_download_url)}')

if [[ -z $release || $release == null ]]; then
  echo "update.sh: no release of $repo has a Linux tarball" >&2
  exit 1
fi

tag=$(jq -r .tag <<<"$release")
url=$(jq -r .url <<<"$release")
version=${tag#v}

if [[ $(jq -r .version sources.json 2>/dev/null) == "$version" ]]; then
  exit 0
fi

hex=$(curl -fsSL "$url.sha256" | awk '{print $1}')
if [[ ! $hex =~ ^[0-9a-f]{64}$ ]]; then
  echo "update.sh: $url.sha256 is not a SHA-256 digest" >&2
  exit 1
fi
hash=$(nix hash convert --hash-algo sha256 --to sri "$hex")

jq -n --arg version "$version" --arg url "$url" --arg hash "$hash" \
  '{version: $version, url: $url, hash: $hash}' > sources.json
echo "$version"
