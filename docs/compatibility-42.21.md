# Build 42.21 compatibility audit

Version 1.1.0 adds an isolated `42.21/` profile. It preserves the released `42/` profile and `common/` files byte for byte, keeps the same Workshop item and Mod ID, and retains the existing physics algorithms.

**Current status: engine audit and automated tests pass; real 42.21 gameplay validation is pending.** This document records preparation for release, not proof of publication or connected driving tests.

## Exact engine evidence

| Profile | Audited game version | Steam build ID | JAR SHA-256 |
| --- | --- | --- | --- |
| `42/` | 42.20.0 | 24449119 | `e4661ca9cb168abc995d3cf59994fa17f66ba8a4e2c2899cbfa48f7eacea54b8` |
| `42.21/` | 42.21.0 | 25485521 | `e1a69eb743ede60b213a0fe7f8b83d4fcab773036d256cc4543a336f3b058a33` |

The new audit inspected the installed 42.21 public-branch engine. Its Core initializer identifies major 42 and minor 21. Record these identities again if Steam replaces the binary; matching a displayed version alone does not establish that a later engine is identical.

Inspection found the correction assumptions still present in 42.21:

- `OnTickEvenPaused` and `OnTick` bracket the relevant world update and pending-impulse corrections.
- Live animals retain the vehicle-mass-derived main impulse and fixed `+1` reaction. Persistent contact, state-dependent guards, and the sustained multiplayer inference remain relevant.
- Live zombies retain the pedestrian slowdown formula and the public centered `applyImpulseGeneric` correction path.
- Corpse collision tests still replace one pending impulse per wheel, support sound suppression, and use `corpseSize` for the wheel reaction. The mod must keep vanilla scan order and restore the original mod data.
- The vehicle authority check remains `isLocalPhysicSim()`. The mod uses ordinary vehicle synchronization.

The exact API/event/exposure audit passed 22 checks. This establishes the inspected engine interfaces and code assumptions; it does not measure actual handling, packet convergence, or anticheat behavior in gameplay.

## Why version directories preserve older players

Build 42 selects the most recent compatible numeric mod directory. The developers' [versioned-mod explanation](https://projectzomboid.com/blog/news/2024/08/tidy-up-time/) explicitly uses `42/` and `42.21/` as examples. Shared `common/` content affects every profile, so it also stays unchanged.

For this package:

| Runtime | Result |
| --- | --- |
| 42.20.x | Selects the original `42/` profile, including its original code and metadata |
| 42.21 or 42.21.0 | Selects `42.21/`; its exact runtime guard allows corrections |
| An unrecognized string such as 42.21.1 | The new profile skips physics corrections and reports the unsupported runtime |
| Before 42.20, later minor versions, or Build 41 | No compatibility claim; require a separate audit and profile |

The game's inspected metadata version comparison uses major and minor components. Consequently, the preserved `versionMin=42.20.0` and `versionMax=42.20.0` do not exclude every 42.20 patch. The original runtime check only logs a warning and does not stop corrections. Preserving that behavior avoids changing existing users, but only 42.20.0 has the original formal gameplay evidence. Do not describe all 42.20.x patches as newly certified.

The new profile has a stricter runtime guard. Both client and server accept `42.21` and `42.21.0`; the client skips physics on an unrecognized value. Future support should add an audited profile or explicitly audit and allow the next patch, rather than remove the guard.

Build 41 reads root-level mod files and ignores the Build 42 directories. This repository has no B41 implementation.

## Upstream changes that still need gameplay checks

The official [42.21 patch notes](https://theindiestone.com/forums/topic/101693-4221-patch-notes/) include changes to animal death-state delay, zombie knockdown and coordinate synchronization, high-latency driving, and anticheat. They do not announce a signature or event-order change for this mod's APIs. The absence of such a note is not compatibility evidence by itself.

The shorter animal death-state delay deserves a real sustained-contact test: the mod infers repeated impulses from overlap and pre-update animal state, so changed state timing can affect the observations even when the formula is unchanged.

## Validation and release gates

| Check | Status |
| --- | --- |
| 42.21 binary identity and engine/API audit | Passed |
| Formula and mocked client/server tests | Passed |
| All 11 legacy files preserved in source and extracted release ZIP | Passed against release 1.0.0 hashes |
| Unknown-version guard | Passed for 10 unsupported runtime strings |
| Installed 42.21 mod-loader and Kahlua checks | Passed in isolated test JVMs; see limitations below |
| Original 42.20.0 gameplay evidence | Retained from release 1.0.0 |
| Fresh 42.21 single-player collisions | Pending |
| 42.21 listen server with connected driver/observer | Pending |
| 42.21 dedicated server with connected driver/observer | Pending |
| 42.21 authority handoff, latency, live tuning, and anticheat checks | Pending |
| Candidate upload and Steam-downloaded content verification | Pending |

The verifier checks the frozen legacy files against `tests/fixtures/legacy-1.0.0.json`. Run it with both exact JARs where available:

```bash
./scripts/verify.sh /path/to/42.20/projectzomboid.jar /path/to/42.21/projectzomboid.jar
./scripts/package-release.sh
sha256sum -c dist/SHA256SUMS.txt
```

With no JAR supplied, the verifier checks source, mocked behavior, and package metadata, and explicitly skips the engine audit. A successful mock test or server startup cannot close a pending gameplay gate.

When the supplied JAR matches the audited 42.21 build, verification also runs the installed game's mod loader and Kahlua Lua runtime using `tests/integration/run.sh`. The loader matrix substitutes version values inside isolated test JVMs to check folder selection and metadata bounds. This is a test of the 42.21 loader, not a fresh run of the older 42.20 engine. Kahlua checks compile the actual profile scripts, register real game event callbacks, and invoke them in an empty world. Supported versions register four client callbacks and allocate two vectors; rejected versions register none and allocate none. No collision physics or network session is simulated. The tests use a temporary home/cache and do not launch or change the user's game.

The exact-engine verification requires a JDK 25 or newer compiler plus the installed game's adjacent Java runtime and `stdlib.lua`. See `tests/integration/README.md` in the source repository for overrides. Test-only Java code and reflection are excluded from the Workshop payload.

Follow the [gameplay matrix](test-matrix.md), compare against vanilla at the same conditions, and record logs or telemetry. Test sustained animal overlap through death/falldown, later re-contact, multiple corpses under one wheel, zombie tuning at `1.0`, `0.5`, and `0.0`, and vehicle authority transfer. Keep the prone living-zombie vertical-lift limitation documented.

Update the existing [Workshop item 3776615501](https://steamcommunity.com/sharedfiles/filedetails/?id=3776615501) only after release validation and upload authorization. Its identity and public visibility were verified through Steam's published-file API on 2026-09-28. Recheck them immediately before uploading; do not create a replacement item or change its visibility as part of this update.
