#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mod_root="$repo_root/workshop/Contents/mods/DoomedRoadkillPhysics"

for tool in node lua luac identify sha256sum; do
  command -v "$tool" >/dev/null || { echo "Required verification tool missing: $tool" >&2; exit 1; }
done
node "$repo_root/scripts/verify-package.mjs"

while IFS=$'\t' read -r folder target runtime; do
  shared="$mod_root/$folder/media/lua/shared"
  client="$mod_root/$folder/media/lua/client/DoomedRoadkillPhysics_Client.lua"
  server="$mod_root/$folder/media/lua/server/DoomedRoadkillPhysics_Server.lua"
  core="$shared/DoomedRoadkillPhysics_Core.lua"
  luac -p "$core"
  luac -p "$client"
  luac -p "$server"
  lua "$repo_root/tests/lua/core_formula_test.lua" "$core" "$target"
  lua "$repo_root/tests/lua/client_runtime_test.lua" "$client" "$shared" "$runtime"
  lua "$repo_root/tests/lua/server_runtime_test.lua" "$server" "$shared" "$runtime"
  if [[ "$folder" != 42 && "$runtime" == "$target" ]]; then
    lua "$repo_root/tests/lua/unsupported_runtime_test.lua" "$client" "$server" "$shared" "$target"
  fi
  [[ "$(identify -format '%wx%h' "$mod_root/$folder/poster.png")" == "256x256" ]]
  echo "Lua regression tests passed for $folder on runtime $runtime."
done < <(node - "$repo_root/release.json" <<'NODE'
const fs = require('node:fs');
const release = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
for (const profile of release.projectZomboid.profiles) {
  for (const runtime of profile.runtimeVersions) console.log(`${profile.folder}\t${profile.runtimeVersions[0]}\t${runtime}`);
}
NODE
)

[[ "$(identify -format '%wx%h' "$repo_root/workshop/preview.png")" == "256x256" ]]

# Keep the original environment interface, and accept more audited JARs as arguments.
jars=("$@")
if [[ -n "${PZ_GAME_JAR:-}" ]]; then jars+=("$PZ_GAME_JAR"); fi
for PZ_GAME_JAR in "${jars[@]}"; do
  command -v javap >/dev/null || { echo 'Required verification tool missing: javap' >&2; exit 1; }
  [[ -f "$PZ_GAME_JAR" ]] || { echo "Not a game JAR: $PZ_GAME_JAR" >&2; exit 1; }
  actual_hash="$(sha256sum "$PZ_GAME_JAR" | awk '{print $1}')"
  audit="$(node - "$repo_root/release.json" "$actual_hash" <<'NODE'
const fs = require('node:fs');
const release = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
for (const profile of release.projectZomboid.profiles) {
  for (const build of profile.auditedBuilds) {
    if (build.jarSha256 === process.argv[3]) {
      console.log(`Build ${build.version}, Steam ${build.steamBuildId}, profile ${profile.folder}`);
      process.exit(0);
    }
  }
}
console.error(`Unaudited game JAR SHA-256: ${process.argv[3]}`);
process.exit(1);
NODE
)"
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
  echo "$audit: exact audited JAR and 22 API/event/exposure checks passed."
  if [[ "$audit" == *'profile 42.21' || "$audit" == *'profile 42.22' ]]; then
    PZ_GAME_JAR="$PZ_GAME_JAR" bash "$repo_root/tests/integration/run.sh"
  fi
done
if [[ ${#jars[@]} == 0 ]]; then
  echo 'No game JAR supplied: engine hash/API checks were not run.'
fi

echo 'Mass Matters versioned Workshop package verification passed.'
