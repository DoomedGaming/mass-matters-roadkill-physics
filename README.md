# Mass Matters: Roadkill Physics

[![Verify](https://github.com/DoomedGaming/mass-matters-roadkill-physics/actions/workflows/verify.yml/badge.svg)](https://github.com/DoomedGaming/mass-matters-roadkill-physics/actions/workflows/verify.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)

Mass Matters is a vehicle-physics balance mod for Project Zomboid. Its purpose is simple: the vehicle reaction should make sense for the mass of what was hit.

It addresses three disproportionate Build 42.20 reactions:

- a live mouse or rat can stop a road vehicle because the vanilla animal impulse scales with vehicle mass;
- a zombie or animal corpse can pitch or launch a vehicle because the vanilla wheel lift also scales with vehicle mass;
- the forward slowdown from hitting a live zombie can be tuned independently without changing its damage or prone wheel lift.

It works with multiplayer's normal Workshop distribution and can be added to an existing world without save migration.

## Compatibility warning

**Version 1.0.0 has been tested only on Project Zomboid Build 42.20 stable.** It is not advertised as compatible with Build 41, later Build 42 releases, or unstable branches. The implementation depends on exact 42.20 collision timing and public vehicle APIs, so it should be re-audited before use on another game build even if the Lua files still load.

Version 1.0.0 has passed Lua formula/runtime tests, exact 42.20 API and JAR verification, package-integrity checks, dedicated-server loading and checksum generation, and local connected multiplayer driving tests. This does not guarantee compatibility with every custom vehicle or modpack; the broader regression matrix remains available in [the gameplay test plan](docs/test-matrix.md).

The exact audited local build is Steam build ID `24449119`, with this game JAR:

```text
e4661ca9cb168abc995d3cf59994fa17f66ba8a4e2c2899cbfa48f7eacea54b8  projectzomboid.jar
```

## Features

- Mass-aware live-animal reactions so mice, rats, rabbits, and other small animals do not behave like concrete barriers.
- Mass-aware corpse wheel reactions intended to stop a single body from launching a car or semi.
- A separate `ZombieImpulseMultiplier` for live-zombie horizontal slowdown, from vanilla (`1.0`) to removed (`0.0`).
- Per-world sandbox controls that multiplayer administrators can apply live.
- Multiplayer authority safety: only the client locally simulating a vehicle queues its correction.
- Vanilla target damage, death, hit sounds, wheel/part damage, traction, drivetrain, and unrelated collisions remain untouched.

## Known limitation

`ZombieImpulseMultiplier` controls the horizontal pedestrian slowdown from a live zombie. It does **not** remove the separate vertical wheel lift and pitch/roll torque produced after a living zombie falls prone beneath the wheels. Build 42.20 does not expose those final per-wheel forces to mods. An approximate counterforce could make crowded contacts less stable, so version 1.0.0 deliberately leaves that path vanilla.

## How it works

Build 42.20 exposes the necessary vehicle methods to Lua even though it does not expose a replaceable collision callback.

The client uses a two-phase `OnTickEvenPaused` to `OnTick` contact detector. A false-to-true engine persistent-contact transition identifies the exact initial vehicle/animal hit without re-testing an animal after the impact has moved it. Once the engine's short persistent-contact window expires, a later impact with the same animal can form a new exact edge.

Sustained multiplayer overlap needs a separate conservative path. Build 42.20's successful client animal-hit path does not reliably set `isVehicleCollision`, and `hitAnimal` can queue both the vehicle-mass-derived main impulse and the fixed `+1` again until `AnimalFalldownState` or authoritative server state arrives. The mod therefore requires overlap both before and after the world update and uses the animal's pre-update state as an inference: it corrects main plus fixed when that state was not `AnimalFalldownState`, and fixed only when it was. This repeated-contact inference is deliberately not presented as an exact hit signal. The retained animal reaction uses animal mass and is never greater than the corresponding inferred vanilla reaction.

For a live zombie, the same contact timing scales only the horizontal pedestrian impulse responsible for forward slowdown. `ZombieImpulseMultiplier` keeps vanilla slowdown at `1.0`, approximately half at `0.5`, or none of that forward impulse at `0.0`. The correction uses the public `applyImpulseGeneric` API at the vehicle center, using the engine-recorded `hitDir` when available and a positional fallback otherwise. The normal `hitDir` path is no longer redirected by a zombie that moved after impact, and the centered correction remains torque-free. The conservative multiplayer fallback for a standing zombie still requires the same vehicle/zombie pair to remain both persistently contacted and geometrically overlapped before and after the update.

The separate vertical wheel-lift and off-center torque produced when a wheel runs over a prone living zombie remain vanilla. Build 42.20 keeps the exact pending values in private per-wheel state that mods cannot safely read or scale; calling the public prone collision test again would itself rewrite that state.

For a corpse, the mod repeats vanilla's nearby-body scan in the same order after the vanilla scan. It temporarily substitutes a mass-aware `corpseSize` and calls `testCollisionWithCorpse(body, false)`. Build 42.20 keeps one pending corpse impulse per wheel, so this replaces the oversized value before the next physics step; `false` prevents a duplicate sound. The body's original mod data is restored immediately.

Only a vehicle for which `isLocalPhysicSim()` is true is corrected. In multiplayer, that is the client currently responsible for the vehicle, and ordinary vehicle synchronization carries the corrected result to the server and other players.

See [the physics notes](docs/physics-notes.md) for the audited formulas and timing.

## Scope

The mod changes only the vehicle reaction to:

- a live `IsoAnimal` during a current vehicle contact, including a later contact after separation;
- the forward slowdown from hitting a live `IsoZombie`;
- an `IsoDeadBody` contacting a wheel.

It does not intentionally change target damage or death, vehicle-part or wheel damage, hit sounds, prone-living-character vertical wheel lift or its torque, traction, drivetrain, wall or tree impacts, or vehicle-to-vehicle collisions.

The normal corpse wheel-lift path is covered. A separate legacy-looking high-speed corpse callback was found in the game code, but normal bodies are scanned through `staticMovingObjects`; this release does not claim to alter an unproven path.

## Installation

### Steam Workshop

Subscribe to **Mass Matters: Roadkill Physics**, enable it for the world, and restart the game normally when adding or updating the mod. The Workshop link and numeric item ID will be added here after the first Steam publication.

### Manual local install

Use a disposable save and back it up first.

1. Download the matching release ZIP or run `./scripts/package-release.sh` from source.
2. Copy `workshop/Contents/mods/DoomedRoadkillPhysics` from the archive into your user `Zomboid/mods/` directory.
3. Enable **Mass Matters: Roadkill Physics** for the test save.

There is no executable installer and nothing is copied into the Project Zomboid game directory.

## Multiplayer server install

After Steam assigns the item its numeric Workshop ID, configure the server normally:

```ini
WorkshopItems=<numeric Workshop ID>
Mods=DoomedRoadkillPhysics
DoLuaChecksum=true
```

Append these values to existing semicolon-separated lists rather than replacing unrelated mods. `WorkshopItems=` receives the numeric Steam ID; `Mods=` receives the internal Mod ID shown above. Every connecting client must load the mod through the server's normal Workshop flow. See [multiplayer deployment](docs/multiplayer.md) for the authority model and release gates.

## Tuning

Three sandbox options are available:

- **Live animal vehicle reaction**: default `1.0`.
- **Live zombie forward slowdown**: default `1.0`.
- **Corpse vehicle reaction**: default `1.0`.

The animal and corpse options accept `0.0` through `2.0`, but their corrections are capped so they cannot make either reaction stronger than vanilla. For those two options, `0.0` removes nearly all of the targeted vehicle reaction and `1.0` is the intended mass-aware behavior.

The zombie option accepts `0.0` through `1.0`: `1.0` preserves vanilla horizontal slowdown, `0.5` retains half, and `0.0` removes it. A multiplayer administrator's Apply takes effect on connected clients immediately; no reconnect or restart is needed for a value change. The client logs the changed value and the first queued zombie correction. Existing servers whose sandbox data does not contain `ZombieImpulseMultiplier` automatically use `1.0`, so installing the option does not silently change live-zombie slowdown until an administrator tunes it.

## Build and verify

Requirements are Bash, Node.js, Lua/`luac`, a JDK providing `javap` for exact-API verification, ImageMagick, `zip`, and `unzip`.

```bash
PZ_GAME_JAR=/path/to/projectzomboid.jar ./scripts/verify.sh
./scripts/package-release.sh
```

Packaging writes a Lua-only ZIP, Workshop upload staging tree, and checked SHA-256 file to `dist/`. The verifier rejects any `.jar` or `.class` file in the Workshop tree.

## Compatibility

This implementation is exact-build code: its event timing and pending-impulse behavior were audited against 42.20. It should be re-audited for later game builds even if the Lua files still load.

Mods that independently rewrite animal vehicle impulses, live-zombie pedestrian impulses, corpse size, or the same per-wheel pending corpse slots may conflict. Content, map, and vehicle-definition mods should not inherently conflict, but custom vehicles and custom animal weights belong in gameplay testing.
