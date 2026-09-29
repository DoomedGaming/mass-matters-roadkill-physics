#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${PZ_GAME_JAR:?Set PZ_GAME_JAR to the installed 42.21 projectzomboid.jar}"
game_jar="$(realpath "$PZ_GAME_JAR")"
game_dir="$(dirname "$game_jar")"
stdlib="${PZ_STDLIB_LUA:-$game_dir/stdlib.lua}"
java_bin="${JAVA:-$game_dir/jre64/bin/java}"
javac_bin="${JAVAC:-javac}"
mod_root="$repo_root/workshop/Contents/mods/DoomedRoadkillPhysics"

[[ -f "$stdlib" ]] || { echo "Missing game stdlib.lua: $stdlib" >&2; exit 1; }
[[ -x "$java_bin" ]] || { echo "Missing game Java; set JAVA explicitly: $java_bin" >&2; exit 1; }

test_dir="$(mktemp -d /tmp/mass-matters-4221-integration.XXXXXXXX)"
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
  "$java_bin" "${java_args[@]}" LoaderProbe "$mod_root" "$version" "$folder" "$available"
done <<'MATRIX'
42.19 42 false
42.20 42 true
42.20.0 42 true
42.20.1 42 true
42.21 42.21 true
42.21.0 42.21 true
42.21.1 42.21 true
42.22 42.21 false
MATRIX

"$java_bin" "${java_args[@]}" KahluaProbe "$mod_root/42" 42.20 true
while read -r version enabled; do
  "$java_bin" "${java_args[@]}" KahluaProbe "$mod_root/42.21" "$version" "$enabled"
done <<'MATRIX'
42.20 false
42.21 true
42.21.0 true
42.21.1 false
42.21-debug false
42.22 false
43.0 false
MATRIX

echo 'Installed 42.21 loader and Kahlua integration checks passed; gameplay is not exercised.'
