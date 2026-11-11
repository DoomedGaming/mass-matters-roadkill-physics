# Mass Matters: Roadkill Physics

[![Verify](https://github.com/DoomedGaming/mass-matters-roadkill-physics/actions/workflows/verify.yml/badge.svg)](https://github.com/DoomedGaming/mass-matters-roadkill-physics/actions/workflows/verify.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)

Mass Matters makes vehicle reactions to live animals and corpses depend on body mass. It also provides independent tuning for the horizontal slowdown caused by live-zombie impacts.

A mouse or rat should not stop a road vehicle, and a single corpse should not launch a truck. The mod corrects those oversized reactions without replacing target damage, death handling, sounds, vehicle-part damage, traction, or unrelated collisions.

## Compatibility and validation

**Version 1.2.0** adds a separate Build 42.22.2 profile while preserving the existing `42/`, `42.21/`, and `common/` files byte for byte. The 42.22.2 engine audit and automated checks pass.

| Game version | Package behavior | Validation |
| --- | --- | --- |
| 42.20.x | Loads the unchanged `42/` profile from release 1.0.0 | Original gameplay testing was on 42.20.0; each later 42.20 patch has not been independently certified |
| 42.21 or 42.21.0 | Loads the unchanged `42.21/` profile | Prior engine/API audit and automated tests pass |
| 42.22.2 | Loads the new `42.22/` profile | Engine/API and automated checks pass |
| Other versions | No compatibility claim | The new profile skips physics on an unrecognized runtime version |

The new profile accepts `42.22`, the runtime string reported by the audited 42.22.2 client, and `42.22.2`. It rejects other strings, including `42.22.0`, `42.22.1`, and `42.22.3`. The runtime gate cannot distinguish a future engine that also reports `42.22`; the exact JAR check runs only in the developer verifier. The preserved 42.21 profile still accepts `42.21` and `42.21.0`. Build 41 and builds earlier than 42.20 remain outside this package's support range.

The Mod ID, Workshop item, sandbox option names, and defaults stay the same. Existing worlds need no save migration. See the [42.22.2 compatibility audit](docs/compatibility-42.22.2.md) for evidence and testing limits. The [42.21 audit](docs/compatibility-42.21.md) records the earlier profile.

## Features

- Mass-aware live-animal reactions, from mice and rats to larger animals.
- Mass-aware zombie and animal corpse wheel reactions.
- A separate `ZombieImpulseMultiplier` for live-zombie horizontal slowdown, from vanilla at `1.0` to removed at `0.0`.
- Per-world sandbox controls that multiplayer administrators can apply live.
- Corrections only on the client locally simulating the vehicle.
- Normal Steam Workshop installation and multiplayer distribution.

## Known limitation

`ZombieImpulseMultiplier` changes the horizontal pedestrian slowdown. It does **not** remove the separate vertical wheel lift and pitch/roll torque produced when a living zombie falls prone beneath the wheels. The audited engines keep those final per-wheel values private. Repeating the public prone collision test would rewrite the pending forces, so the mod leaves that path vanilla.

Custom vehicles and modpacks still need gameplay testing. Mods that independently rewrite animal impulses, live-zombie pedestrian impulses, corpse size, or the same pending corpse-wheel forces may conflict.

## How it works

The client snapshots contact state in `OnTickEvenPaused` and applies corrections in `OnTick`. A false-to-true persistent-contact transition identifies an initial hit in that update. After the engine's contact window expires, the same animal can produce a new edge on a later impact.

For sustained multiplayer animal overlap, the engine's client hit path does not reliably set `isVehicleCollision`. The mod requires overlap before and after the update and uses the animal's pre-update `AnimalFalldownState` to infer whether to correct the main impulse plus the fixed impulse, or only the fixed impulse. This is a conservative repeated-hit inference, not an exact collision callback.

Live-zombie corrections use public `applyImpulseGeneric` at the vehicle center. The engine-recorded `hitDir` supplies the direction where available, with a positional fallback. The centered correction adds no torque.

For corpses, the mod repeats the nearby-body scan in vanilla order. It temporarily substitutes a mass-aware `corpseSize`, calls `testCollisionWithCorpse(body, false)` to replace the pending per-wheel impulse without another sound, and immediately restores the body's original mod data.

Only a vehicle with `isLocalPhysicSim()` is corrected. Normal vehicle synchronization carries its motion to the server and other players. See the [original physics audit](docs/physics-notes.md), [42.21 audit](docs/compatibility-42.21.md), and [42.22.2 audit](docs/compatibility-42.22.2.md).

## Installation

Subscribe to [Mass Matters: Roadkill Physics on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3776615501), enable it for the world, and restart normally when adding or updating the mod. The public Workshop item remains at its last published version until version 1.2.0 is uploaded.

For a manual test, copy `workshop/Contents/mods/DoomedRoadkillPhysics` from the release archive into your user `Zomboid/mods/` directory. Copy the complete mod folder, including all three version directories and `common/`. Use a disposable save and avoid loading both the development and subscribed copies.

For a multiplayer server, append these identifiers to the existing lists:

```ini
WorkshopItems=3776615501
Mods=DoomedRoadkillPhysics
DoLuaChecksum=true
```

Preserve unrelated entries and their order. All connecting clients use the server's normal Workshop flow. See [multiplayer deployment](docs/multiplayer.md).

## Tuning

| Sandbox option | Range | Default |
| --- | --- | --- |
| Live animal vehicle reaction | 0.0 to 2.0 | 1.0 |
| Live zombie forward slowdown | 0.0 to 1.0 | 1.0 |
| Corpse vehicle reaction | 0.0 to 2.0 | 1.0 |

Animal and corpse corrections are capped so they cannot increase the targeted reaction above vanilla. For those options, `0.0` removes nearly all of the targeted reaction and `1.0` gives the intended mass-aware result. Zombie slowdown retains vanilla at `1.0`, about half at `0.5`, and none of the targeted horizontal impulse at `0.0`.

A multiplayer administrator's Apply takes effect on connected clients. The client logs a changed zombie value and the first queued correction. Existing sandbox data missing `ZombieImpulseMultiplier` uses `1.0`.

## Build and verify

Requirements are Bash, Node.js, Lua/`luac`, ImageMagick, `zip`, and `unzip`. Exact-engine checks additionally need a JDK 25 or newer with `javap` and `javac`, plus the installed game's bundled Java runtime and `stdlib.lua`.

```bash
./scripts/verify.sh
./scripts/package-release.sh
sha256sum -c dist/SHA256SUMS.txt
```

Use the exact-JAR commands in the [release checklist](docs/steam-workshop-release.md) for an engine audit. Packaging writes a Lua-only ZIP and Workshop staging tree to `dist/`. Neither is an upload. The verifier rejects Java binaries in the Workshop tree.

Automated checks do not prove real collision timing or multiplayer convergence. Follow the [gameplay test matrix](docs/test-matrix.md) before changing the release's testing claim.
