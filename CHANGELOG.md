# Changelog

## 1.2.0 - 2026-11-11

- Add a separate `42.22/` profile for Project Zomboid 42.22.2.
- Preserve the existing `42/`, `42.21/`, and `common/` files byte for byte, including their version bounds and runtime behavior.
- Keep Workshop item `3776615501`, Mod ID `DoomedRoadkillPhysics`, sandbox names, ranges, defaults, and save data unchanged.
- Accept `42.22`, the audited 42.22.2 client's runtime string, and `42.22.2` in the new profile. Other strings return before client physics hooks or vectors are created. Document that a future engine reusing `42.22` cannot be identified by this Lua guard.
- Extend loader, Lua-runtime, and package-preservation checks to the new profile.

## 1.1.0 - Unreleased

- Add a separate `42.21/` profile while keeping the released `42/` and `common/` files byte for byte unchanged.
- Preserve Workshop item `3776615501`, Mod ID `DoomedRoadkillPhysics`, sandbox keys, defaults, and existing-world behavior.
- Audit the 42.21 vehicle collision formulas, pending impulse handling, Lua APIs, and event timing. Retain the existing physics algorithms.
- Accept exact 42.21 and 42.21.0 runtime strings in the new profile and skip its physics corrections on unrecognized versions.
- Verify both profiles with formula and mocked runtime tests; retain original 42.20.0 gameplay evidence separately from the pending 42.21 gameplay pass.
- Correct the stale first-upload instructions to update the existing public Workshop item without creating another item or changing its visibility.

## 1.0.0 - 2026-08-02

- Stabilize the Build 42.20 scope: mass-aware live-small-animal reactions, mass-aware corpse wheel lift, and independently tunable live-zombie horizontal slowdown.
- Test and support this exact physics implementation only on Project Zomboid Build 42.20.0 (Steam build `24449119`); later game builds require a fresh collision and impulse audit.
- Support Steam Workshop multiplayer distribution: the locally authoritative vehicle client performs the collision corrections.
- Queue live-zombie horizontal corrections through public `applyImpulseGeneric`, preserving a torque-free correction and live `ZombieImpulseMultiplier` updates while leaving vanilla target damage, sound, and vehicle-part behavior intact.
- Document the known limitation that prone living zombies retain vanilla vertical per-wheel lift and off-center torque because Build 42.20 keeps the exact pending wheel state private from release-mode Lua.

## 0.3.1 - Pre-release development

- Add a conservative multiplayer fallback for continued standing-zombie hits when Build 42.20 does not retain `isVehicleCollision`: require the same locally simulated vehicle, persistent contact, and collision overlap both before and after the update bracket.
- Keep the engine-reported collision requirement for prone continuation because its only exact geometry test also rewrites wheel-lift slots.
- Read live `ZombieImpulseMultiplier` changes on the next pre-tick and log both a changed value and the first correction that actually queues for that value.
- Add runtime regressions for multiplayer fallback safety, separation without correction, single-player flag requirements, and a live change to `0.0`.
- Continue leaving the separate prone-living-zombie wheel-lift reaction unchanged.

## 0.3.0 - Pre-release development

- Replace animal death-state detection with a reusable contact-edge detector spanning `OnTickEvenPaused` to `OnTick`.
- Use a false-to-true persistent-contact edge as the exact signal for an initial live-animal hit.
- Stop relying on `isVehicleCollision` for sustained multiplayer animal contact because Build 42.20's successful client path does not reliably set it.
- Conservatively require pre/post-update overlap for sustained contact, correcting main plus fixed when the animal's pre-update state was not `AnimalFalldownState` and fixed only when it was.
- Add `ZombieImpulseMultiplier` from `0.0` through `1.0`, defaulting to `1.0`: vanilla forward slowdown at `1.0`, half at `0.5`, and none at `0.0`.
- Leave the separate wheel-lift reaction for prone living zombies unchanged.
- Preserve multiplayer's locally simulated vehicle authority and vanilla damage, death, sound, and vehicle-part behavior.
- Treat a missing zombie option on an existing server as `1.0`; no save migration is required.
- Keep the inferred repeated-animal path, real single-player collisions, and connected-multiplayer collision behavior explicitly unverified until the gameplay matrix passes.

## 0.2.1 - Pre-release development

- Iterate Build 42.20's `IsoCell:getVehicles()` Java `Set` through its iterator instead of invalid indexed access.
- Make the client runtime mock Set-shaped and add an exact-JAR return-type gate so this API mismatch cannot regress silently.

## 0.2.0 - Pre-release development

- Replace the rejected Java-overlay prototype with a normal Steam Workshop Lua mod.
- Introduce the initial live-animal excess-impulse correction, superseded by version 0.3.0's reusable contact detector.
- Recalculate corpse wheel lift from corpse mass by overwriting Build 42.20's pending per-wheel value in vanilla scan order.
- Restrict physics changes to the locally simulated vehicle for multiplayer authority safety.
- Preserve vanilla target damage, death handling, hit sounds, and unrelated vehicle collisions.
- Add formula and runtime tests, exact Build 42.20 API verification, package checks, and a connected-client gameplay matrix.
