#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(node -p "require('$repo_root/release.json').version")"
mod_root="$repo_root/workshop/Contents/mods/DoomedRoadkillPhysics/42"
shared_lua="$mod_root/media/lua/shared"
client_lua="$mod_root/media/lua/client/DoomedRoadkillPhysics_Client.lua"
server_lua="$mod_root/media/lua/server/DoomedRoadkillPhysics_Server.lua"
core_lua="$shared_lua/DoomedRoadkillPhysics_Core.lua"

required_files=(
  "$repo_root/LICENSE.md"
  "$repo_root/README.md"
  "$repo_root/CHANGELOG.md"
  "$repo_root/release.json"
  "$repo_root/docs/physics-notes.md"
  "$repo_root/docs/test-matrix.md"
  "$repo_root/docs/multiplayer.md"
  "$repo_root/docs/release-notes-$version.md"
  "$repo_root/docs/steam-workshop-release.md"
  "$repo_root/workshop/workshop.txt"
  "$repo_root/workshop/preview.png"
  "$mod_root/mod.info"
  "$mod_root/poster.png"
  "$repo_root/workshop/Contents/mods/DoomedRoadkillPhysics/common/media/AnimSets/DoomedRoadkillPhysics_common.keep"
  "$repo_root/workshop/Contents/mods/DoomedRoadkillPhysics/common/media/actiongroups/DoomedRoadkillPhysics_common.keep"
  "$mod_root/media/AnimSets/DoomedRoadkillPhysics_42.keep"
  "$mod_root/media/actiongroups/DoomedRoadkillPhysics_42.keep"
  "$repo_root/workshop/Contents/mods/DoomedRoadkillPhysics/LICENSE.txt"
  "$mod_root/media/sandbox-options.txt"
  "$client_lua"
  "$server_lua"
  "$core_lua"
  "$shared_lua/Translate/EN/Sandbox.json"
)

for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || { echo "Missing required file: $file" >&2; exit 1; }
done

grep -qx 'id=DoomedRoadkillPhysics' "$mod_root/mod.info"
grep -qx "modversion=$version" "$mod_root/mod.info"
grep -qx 'versionMin=42.20.0' "$mod_root/mod.info"
grep -qx 'versionMax=42.20.0' "$mod_root/mod.info"
grep -Eq '^id=([0-9]+)?$' "$repo_root/workshop/workshop.txt"
grep -Eq '^visibility=(private|public|friendsOnly|unlisted)$' "$repo_root/workshop/workshop.txt"
grep -Fq 'tested only on Project Zomboid Build 42.20 stable' "$repo_root/workshop/workshop.txt"
grep -Fq 'prone living-zombie reaction remains vanilla' "$repo_root/workshop/workshop.txt"
grep -q 'applyImpulseFromHitObject' "$client_lua"
grep -q 'applyImpulseGeneric' "$client_lua"
grep -q 'testCollisionWithCorpse' "$client_lua"
grep -q 'isLocalPhysicSim' "$client_lua"
grep -q 'getAnimals' "$client_lua"
grep -q 'getZombieList' "$client_lua"
grep -q 'OnTickEvenPaused' "$client_lua"
grep -q 'isPersistentContact' "$client_lua"
grep -q 'getCurrentStateName' "$client_lua"
grep -q 'isClient()' "$client_lua"
grep -q 'ZombieImpulseMultiplier' "$client_lua"
grep -q 'OnCharacterDeath' "$client_lua"
grep -q 'isTargetGameVersion' "$client_lua"
grep -q 'isTargetGameVersion' "$server_lua"
grep -q 'shouldCollideWithObjects' "$client_lua"
grep -q 'DoLuaChecksum=true' "$repo_root/docs/multiplayer.md"
grep -q 'vehicles:iterator()' "$client_lua"

if grep -q 'vehicles:get(' "$client_lua"; then
  echo 'IsoCell:getVehicles() returns a Set; indexed vehicle access is invalid.' >&2
  exit 1
fi

if grep -q 'vehicle:testCollisionWithProneCharacter' "$client_lua"; then
  echo 'Client correction must not call the side-effectful prone collision test.' >&2
  exit 1
fi

if find "$repo_root/workshop" -type f \( -name '*.java' -o -name '*.jar' -o -name '*.class' \) | grep . >/dev/null; then
  echo 'Workshop package must not contain Java source, archives, or class files.' >&2
  exit 1
fi

node - "$repo_root/release.json" "$shared_lua/Translate/EN/Sandbox.json" <<'NODE'
const fs = require('node:fs')
for (const path of process.argv.slice(2)) JSON.parse(fs.readFileSync(path, 'utf8'))
const release = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
if (!/^\d+\.\d+\.\d+$/.test(release.version)) throw new Error('release version must be semantic')
if (release.projectZomboid.version !== '42.20.0') throw new Error('exact PZ version changed')
if (release.modId !== 'DoomedRoadkillPhysics') throw new Error('Mod ID mismatch')
if (release.distribution !== 'steam-workshop-lua-only') throw new Error('distribution must remain Lua-only')
NODE

if command -v luac >/dev/null 2>&1; then
  luac -p "$core_lua"
  luac -p "$client_lua"
  luac -p "$server_lua"
fi

if command -v lua >/dev/null 2>&1; then
  lua "$repo_root/tests/lua/core_formula_test.lua" "$core_lua"
  lua "$repo_root/tests/lua/client_runtime_test.lua" "$client_lua" "$shared_lua"
  lua "$repo_root/tests/lua/server_runtime_test.lua" "$server_lua" "$shared_lua"
fi

if command -v identify >/dev/null 2>&1; then
  [[ "$(identify -format '%wx%h' "$repo_root/workshop/preview.png")" == "256x256" ]]
  [[ "$(identify -format '%wx%h' "$mod_root/poster.png")" == "256x256" ]]
fi

if [[ -n "${PZ_GAME_JAR:-}" ]]; then
  [[ -f "$PZ_GAME_JAR" ]] || { echo "PZ_GAME_JAR is not a file: $PZ_GAME_JAR" >&2; exit 1; }
  expected_hash="$(node -p "require('$repo_root/release.json').projectZomboid.jarSha256")"
  actual_hash="$(sha256sum "$PZ_GAME_JAR" | awk '{print $1}')"
  [[ "$actual_hash" == "$expected_hash" ]] || {
    echo "Project Zomboid JAR hash mismatch: $actual_hash" >&2
    exit 1
  }
  javap -classpath "$PZ_GAME_JAR" zombie.vehicles.BaseVehicle \
    | grep 'applyImpulseFromHitObject(zombie.iso.IsoObject, float)' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.vehicles.BaseVehicle \
    | grep 'applyImpulseGeneric(float, float, float, float, float, float, float)' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.vehicles.BaseVehicle \
    | grep 'testCollisionWithCorpse(zombie.iso.objects.IsoDeadBody, boolean)' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.vehicles.BaseVehicle \
    | grep 'isLocalPhysicSim()' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.vehicles.BaseVehicle \
    | grep 'shouldCollideWithObjects()' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.vehicles.BaseVehicle \
    | grep 'isPersistentContact(zombie.characters.IsoGameCharacter)' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.vehicles.BaseVehicle \
    | grep 'testCollisionWithCharacter(zombie.characters.IsoGameCharacter, float, zombie.iso.Vector2)' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.vehicles.BaseVehicle \
    | grep 'testCollisionWithProneCharacter(zombie.characters.IsoGameCharacter, boolean, zombie.iso.Vector2)' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.iso.IsoCell \
    | grep 'getAnimals()' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.iso.IsoCell \
    | grep 'getZombieList()' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.iso.IsoMovingObject \
    | grep 'getHitDir()' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.characters.IsoGameCharacter \
    | grep 'getMass()' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.characters.IsoGameCharacter \
    | grep 'isVehicleCollision()' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.characters.IsoGameCharacter \
    | grep 'getCurrentStateName()' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.iso.Vector2 \
    | grep 'getX()' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.iso.Vector2 \
    | grep 'getY()' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.ai.IStateCharacter \
    | grep 'canBeHitByVehicle(zombie.vehicles.BaseVehicle)' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.ai.IStateCharacter \
    | grep 'canSlowDownVehicleWhenHit(zombie.vehicles.BaseVehicle)' >/dev/null
  javap -classpath "$PZ_GAME_JAR" zombie.iso.IsoCell \
    | grep -F 'public java.util.Set<zombie.vehicles.BaseVehicle> getVehicles();' >/dev/null
  javap -classpath "$PZ_GAME_JAR" -c -p 'zombie.Lua.LuaManager$Exposer' \
    | grep -F 'class java/util/HashSet' >/dev/null
  javap -classpath "$PZ_GAME_JAR" -c -p 'zombie.Lua.LuaManager$Exposer' \
    | grep -F 'class java/util/Iterator' >/dev/null
  javap -classpath "$PZ_GAME_JAR" -c -p zombie.Lua.LuaEventManager \
    | grep -F 'String OnTickEvenPaused' >/dev/null
  echo "Exact Build 42.20 JAR and required public APIs verified."
fi

echo "Mass Matters pure Workshop package verification passed."
