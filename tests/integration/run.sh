#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${PZ_GAME_JAR:?Set PZ_GAME_JAR to an audited 42.21 or 42.22.2 projectzomboid.jar}"
game_jar="$(realpath "$PZ_GAME_JAR")"
game_dir="$(dirname "$game_jar")"
stdlib="${PZ_STDLIB_LUA:-$game_dir/stdlib.lua}"
java_bin="${JAVA:-$game_dir/jre64/bin/java}"
javac_bin="${JAVAC:-javac}"
mod_root="$repo_root/workshop/Contents/mods/DoomedRoadkillPhysics"

[[ -f "$stdlib" ]] || { echo "Missing game stdlib.lua: $stdlib" >&2; exit 1; }
[[ -x "$java_bin" ]] || { echo "Missing game Java; set JAVA explicitly: $java_bin" >&2; exit 1; }

# Verify the exact binary even when this runner is called without verify.sh.
# The actual engine version is asserted separately before every substitution.
engine_version="$(node - "$repo_root/release.json" "$game_jar" <<'NODE'
const fs = require('node:fs');
const { createHash } = require('node:crypto');
const release = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const hash = createHash('sha256').update(fs.readFileSync(process.argv[3])).digest('hex');
for (const profile of release.projectZomboid.profiles) {
  if (['42.21', '42.22'].includes(profile.folder)
      && profile.auditedBuilds.some(build => build.jarSha256 === hash)) {
    console.log(profile.runtimeVersions[0]);
    process.exit(0);
  }
}
console.error(`No integration audit for game JAR SHA-256: ${hash}`);
process.exit(1);
NODE
)"

test_dir="$(mktemp -d /tmp/mass-matters-integration.XXXXXXXX)"
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/home" "$test_dir/classes" \
  "$test_dir/media/anims" "$test_dir/media/anims_X" \
  "$test_dir/media/AnimSets" "$test_dir/media/actiongroups"
cp "$stdlib" "$test_dir/stdlib.lua"
"$javac_bin" --release 25 -cp "$game_jar" -d "$test_dir/classes" \
  "$repo_root/tests/integration/LoaderProbe.java" \
  "$repo_root/tests/integration/KahluaProbe.java"

cd "$test_dir"
java_args=(-Djava.awt.headless=true "-Duser.home=$test_dir/home" \
  -cp "$test_dir/classes:$game_jar")

# Each probe gets a fresh JVM. Version substitution affects only that process.
while read -r version folder available; do
  "$java_bin" "${java_args[@]}" LoaderProbe "$mod_root" "$version" "$folder" "$available" "$engine_version"
done <<'MATRIX'
42.19 42 false
42.20 42 true
42.20.0 42 true
42.20.1 42 true
42.21 42.21 true
42.21.0 42.21 true
42.21.1 42.21 true
42.22 42.22 true
42.22.0 42.22 true
42.22.1 42.22 true
42.22.2 42.22 true
42.22.3 42.22 true
42.22.20 42.22 true
42.22.999999 42.22 true
42.23 42.22 false
43.0 42.22 false
43.22 42.22 false
MATRIX

while read -r folder version enabled; do
  "$java_bin" "${java_args[@]}" KahluaProbe "$mod_root/$folder" "$version" "$enabled" "$engine_version"
done <<'MATRIX'
42 42.20 true
42.21 42.20 false
42.21 42.21 true
42.21 42.21.0 true
42.21 42.21.1 false
42.21 42.21-debug false
42.21 42.22 false
42.21 42.22.2 false
42.21 43.0 false
42.22 42.20 false
42.22 42.21 false
42.22 42.21.0 false
42.22 42.22 true
42.22 42.22.0 true
42.22 42.22.1 true
42.22 42.22.2 true
42.22 42.22.3 true
42.22 42.22.20 true
42.22 42.22.999999 true
42.22 42.22.0002 true
42.22 42.22.12345678901234567890 true
42.22 42.22.2.0 false
42.22 42.22. false
42.22 42.22.+1 false
42.22 42.22.1-beta false
42.22 142.22.2 false
42.22 42.220.2 false
42.22 42.22-debug false
42.22 42.23 false
42.22 43.0 false
42.22 43.22 false
MATRIX

echo "Installed $engine_version loader and Kahlua integration checks passed; gameplay is not exercised."
