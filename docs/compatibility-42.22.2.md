# Build 42.22.2 compatibility audit

Version 1.2.0 adds a separate `42.22/` profile. The existing `42/`, `42.21/`, and `common/` files remain byte for byte unchanged. Workshop item `3776615501`, Mod ID `DoomedRoadkillPhysics`, sandbox keys, defaults, and saved-world data stay the same.

The 42.22.2 engine audit, Lua regressions, installed-engine loader/Kahlua checks, and package integrity checks pass. Package loading and automated checks cannot prove vehicle handling or network convergence.

## Engine identity and runtime version

| Release | Steam client build | JAR SHA-256 | Runtime string |
| --- | --- | --- | --- |
| 42.22.2 | 26486631 | `3c4a7c5f149d784758c6fb5f8fa85f3a21d572e38bc081400e89035f8120d287` | `42.22` |

The inspected client initializes `GameVersion` with major 42, minor 22, and an empty suffix. Its Lua `getVersionNumber()` therefore returns `42.22`, even though Steam distributes it as 42.22.2. The new profile accepts that observed string and explicit `42.22.2`. It rejects other strings, including `42.22.0`, `42.22.1`, `42.22.3`, and debug suffixes, before allocating client vectors or registering client physics callbacks.

This is a version-string guard, not runtime JAR verification. A future or older engine that also reports `42.22` passes the guard. The game's metadata comparison also uses major and minor components, so `versionMin=42.22.2` and `versionMax=42.22.2` cannot enforce the patch number. Recheck the binary after Steam updates it. The developer verifier rejects unknown JAR hashes; the distributed Lua mod does not inspect or modify the game binary.

The Steam client build above is distinct from dedicated-server build IDs. This audit identifies the client engine that runs vehicle corrections.

## Inspected physics paths

A fresh inspection of the 42.22.2 bytecode matches the correction assumptions in the prior documented audit. This was not a direct binary comparison with the older engine; its JAR was unavailable. The new profile keeps the existing physics algorithms:

- `OnTickEvenPaused` runs before the world update. The physics step consumes earlier pending impulses, then the cell update queues new contacts. `OnTick` runs afterward, so corrections reach the pending queue before the next physics step.
- Live-animal reactions retain the vehicle-mass-derived main impulse and fixed `+1` impulse. The main scalar is `vehicleMass * 7 * min(planarSpeed, 15) / 15 * abs(impactDot)`.
- Live-zombie slowdown retains `-impactDot * characterMass * stanceFactor * planarSpeed`, with `0.8` standing and `0.2` prone. The public centered `applyImpulseGeneric` correction remains available.
- Corpse wheel lift retains `0.065 * vehicleMass * max(speedKmH, 10) / 10 * corpseSize`. A repeated corpse test replaces the pending impulse for that wheel; `false` suppresses another sound. The mod preserves vanilla scan order and restores the original corpse mod data.
- `isLocalPhysicSim()` remains the vehicle authority check. Normal vehicle packets carry the resulting motion.

Sustained animal overlap still requires the existing inference from pre/post-update overlap and pre-update `AnimalFalldownState`. Prone living-zombie wheel lift and torque remain vanilla because their pending per-wheel state is private. See the [original physics audit](physics-notes.md) and [42.21 audit](compatibility-42.21.md) for those limits.

The official [42.22.2 stable notes](https://theindiestone.com/forums/topic/103067-42222-stable-released/) report server-side damage calculations, further anticheat checks, and multiplayer trailer/towing fixes. These changes make damage outcomes, authority handoff, trailer behavior, and delayed state arrival useful gameplay checks. Patch notes alone do not establish compatibility.

## Backward compatibility

| Runtime | Selected profile | Behavior |
| --- | --- | --- |
| 42.20.x | `42/` | Preserved release 1.0.0 behavior; original gameplay evidence covers 42.20.0 |
| 42.21 or 42.21.0 | `42.21/` | Preserved 1.1.0 profile; prior engine audit passes |
| 42.21.1 or another unsupported 42.21 string | `42.21/` | Preserved guard disables corrections |
| Audited 42.22.2 client reporting 42.22, or explicit 42.22.2 | `42.22/` | New 1.2.0 profile enables corrections |
| 42.22.0, 42.22.1, 42.22.3, or another unsupported string | `42.22/` where selected | Guard disables corrections |

The package adds no Build 41 implementation. Existing save data requires no migration. Keep every version directory and `common/` together when installing or uploading.

## Validation status

| Check | Status |
| --- | --- |
| 42.22.2 binary identity and physics inspection | Passed; bundled Java runtime reports `42.22` |
| Exact JAR/API checks | Passed, 22 API/event/exposure checks |
| Formula and mocked client/server regressions | Passed for all five supported profile/runtime combinations |
| Original 42.20 and 42.21 file preservation | Passed, all 20 frozen profile/common files in source, staging, and extracted ZIP |
| Release archive and Workshop staging | ZIP integrity, SHA-256, staging equality, and Lua-only payload checks passed |
| Installed-engine loader and Kahlua checks | Passed, 14 loader cases and 22 Kahlua cases on the installed 42.22.2 client |
| Unsupported-version Lua guards | Passed, 11 rejected strings for 42.21 and 16 for 42.22 |
| Original 42.20.0 gameplay evidence | Retained from release 1.0.0 |
| Workshop upload and downloaded-content verification | Pending |

Run the exact-engine verifier with available audited JARs, then package:

```bash
./scripts/verify.sh /path/to/42.22.2/projectzomboid.jar
./scripts/package-release.sh
sha256sum -c dist/SHA256SUMS.txt
```

Older JARs can be supplied as additional arguments. Without a JAR, the verifier runs source/package checks and reports that engine checks were skipped. The integration probes run the installed loader and Kahlua in isolated JVMs with temporary home/cache directories. Simulated version values test that installed loader; they do not execute every older engine. Empty-world callbacks do not exercise collisions or multiplayer.

The [gameplay matrix](test-matrix.md) provides a reference for collision and multiplayer validation. Follow the [Workshop update checklist](steam-workshop-release.md) for publication and downloaded-file verification.
