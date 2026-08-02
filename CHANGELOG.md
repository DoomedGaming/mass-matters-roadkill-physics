# Changelog

## 1.0.0 - 2026-08-02

- Stabilize the Build 42.20 scope: mass-aware live-small-animal reactions, mass-aware corpse wheel lift, and independently tunable live-zombie horizontal slowdown.
- Test and support this exact physics implementation only on Project Zomboid Build 42.20.0 (Steam build `24449119`); later game builds require a fresh collision and impulse audit.
- Ship as a pure Lua Steam Workshop mod with multiplayer support: the locally authoritative vehicle client performs corrections without patching game, client, or server files.
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
- Preserve multiplayer's locally simulated vehicle authority and vanilla damage, death, sound, and vehicle-part behavior in a pure Lua Workshop package.
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
- Add Lua formula and runtime tests, exact Build 42.20 API verification, Lua-only package checks, and a connected-client gameplay matrix.
- Remove the patcher, Java class overlays, manual client install, compatibility handshake, and all generated Java artifacts from the release design.

## 0.1.0 - Superseded prototype

- Prototyped an exact-build Java transformation and companion Lua mod.
- Never installed it into the live game, published it to Workshop, or deployed it to a multiplayer server.
