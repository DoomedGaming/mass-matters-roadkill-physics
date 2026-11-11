#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(node -p "require('$repo_root/release.json').version")"
asset_root="mass-matters-roadkill-physics-v$version"
dist="$repo_root/dist"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

bash "$repo_root/scripts/verify.sh" "$@"
rm -rf "$dist"
mkdir -p "$dist/workshop-staging" "$staging/$asset_root/docs"

cp "$repo_root/README.md" "$staging/$asset_root/README.md"
cp "$repo_root/CHANGELOG.md" "$staging/$asset_root/CHANGELOG.md"
cp "$repo_root/LICENSE.md" "$staging/$asset_root/LICENSE.md"
cp "$repo_root/release.json" "$staging/$asset_root/release.json"
cp "$repo_root/docs/physics-notes.md" "$staging/$asset_root/docs/physics-notes.md"
cp "$repo_root/docs/compatibility-42.21.md" "$staging/$asset_root/docs/compatibility-42.21.md"
cp "$repo_root/docs/compatibility-42.22.2.md" "$staging/$asset_root/docs/compatibility-42.22.2.md"
cp "$repo_root/docs/test-matrix.md" "$staging/$asset_root/docs/test-matrix.md"
cp "$repo_root/docs/multiplayer.md" "$staging/$asset_root/docs/multiplayer.md"
cp "$repo_root/docs/release-notes-$version.md" "$staging/$asset_root/docs/release-notes-$version.md"
cp "$repo_root/docs/steam-workshop-release.md" "$staging/$asset_root/docs/steam-workshop-release.md"
cp -R "$repo_root/workshop" "$staging/$asset_root/workshop"

cp "$repo_root/workshop/workshop.txt" "$dist/workshop-staging/workshop.txt"
cp "$repo_root/workshop/preview.png" "$dist/workshop-staging/preview.png"
cp -R "$repo_root/workshop/Contents" "$dist/workshop-staging/Contents"

node "$repo_root/scripts/verify-package.mjs" "$staging/$asset_root"

(
  cd "$staging"
  zip -qr "$dist/$asset_root.zip" "$asset_root"
)

if find "$dist" -type f \( -name '*.java' -o -name '*.jar' -o -name '*.class' \) | grep . >/dev/null; then
  echo 'Release output unexpectedly contains Java files.' >&2
  exit 1
fi

(
  cd "$dist"
  sha256sum "$asset_root.zip" > SHA256SUMS.txt
  sha256sum -c SHA256SUMS.txt
  unzip -t "$asset_root.zip" >/dev/null
)

# Inspect extracted bytes as well as the source/staging trees.
unzip -q "$dist/$asset_root.zip" -d "$staging/extracted"
node "$repo_root/scripts/verify-package.mjs" "$staging/extracted/$asset_root"
diff -qr "$repo_root/workshop/Contents" "$dist/workshop-staging/Contents" >/dev/null

echo "Lua-only release ZIP and Workshop staging created in $dist"
