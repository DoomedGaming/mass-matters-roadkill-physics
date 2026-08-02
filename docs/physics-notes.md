# Build 42.20 physics notes

These notes describe the exact Steam 42.20 stable JAR recorded in `release.json` and the Lua-only correction used by version 1.0.0.

## Live animals

`IsoAnimal.testCollideWithVehicles` uses a hardcoded `0.3` character-collision radius. On a hit it calls `BaseVehicle.hitAnimal(animal)`, then queues another fixed `1.0` through `applyImpulseFromHitObject`.

When the vehicle is moving into the animal, `hitAnimal` queues this main vehicle reaction:

```text
vanillaMain = vehicleMass * 7 * min(planarSpeed, 15) / 15 * abs(impactDot)
```

Animal mass is absent. The mod's desired reaction is:

```text
desiredMain = min(
    vanillaMain,
    animalMassKg * 12 * multiplier * min(planarSpeed, 15) / 15 * abs(impactDot)
)

desiredFixed = min(1, animalMassKg / 100 * multiplier)
```

It calls the public `applyImpulseFromHitObject(animal, -excess)` with:

```text
excess = (vanillaMain + 1) - (desiredMain + desiredFixed)
```

The API does not clamp a negative scalar. It builds the same direction and opposite contact offset as the vanilla calls and appends it to `impulsesFromHitObjects`. Those entries are summed before the next vehicle-physics step, so the correction removes excess force without introducing a separate torque.

Version 0.3.0 does not depend on an animal becoming roadkill. `OnTickEvenPaused` records the engine's persistent-contact state before the world update, and `OnTick` compares it after `BaseVehicle.postupdate`. A false-to-true transition proves that exact vehicle completed the hit path in the bracketed update. The engine retains that contact for about 3.5 physics seconds; after it expires, a later impact with the same animal can form a new edge.

The mass-derived main impulse and fixed `+1` are corrected on that exact new edge without a post-hit spatial re-test.

The sustained-contact case is less direct on a multiplayer client. The successful client animal-hit path does not reliably set `isVehicleCollision`, so that flag cannot serve as proof that a repeated impulse was queued. While collision geometry remains overlapped, `hitAnimal` can run again and queue both the mass-derived main impulse and fixed `+1` until `AnimalFalldownState` or authoritative server state arrives. Once the animal was already in `AnimalFalldownState`, the guarded main path is no longer inferred, but the outer collision path can still queue the fixed `+1`.

Version 0.3.0 handles this with a conservative inference. `OnTickEvenPaused` records both collision overlap and the animal state, and `OnTick` requires that the same pair still overlap. For a sustained pair without a new persistent-contact edge:

- a pre-update state other than `AnimalFalldownState` is treated as main plus fixed, using the full `excess` formula above;
- a pre-update `AnimalFalldownState` is treated as fixed only, using `1 - desiredFixed`.

This pre/post-overlap and pre-state inference avoids depending on the unreliable client flag, but it is not an exact repeated-hit detector. Connected gameplay under different state-replication timings remains required. The mod does not replace `IsoAnimal.Hit`, damage, death handling, or state synchronization.

## Live zombies

The ordinary live-zombie hit path applies a horizontal pedestrian impulse that slows the vehicle. Version 1.0.0 retains a configurable fraction of that forward slowdown:

```text
desiredZombieForward = vanillaZombieForward * ZombieImpulseMultiplier
correction = vanillaZombieForward * (1 - ZombieImpulseMultiplier)
```

`ZombieImpulseMultiplier` is bounded from `0.0` through `1.0`. Its default and missing-value fallback are `1.0`, which is vanilla behavior; `0.5` keeps half of the forward slowdown and `0.0` removes it. Live multiplayer changes are read on the next pre-tick.

The exact false-to-true persistent-contact edge handles an initial hit. For continued standing overlap on a multiplayer client, the mod does not depend on the unreliable `isVehicleCollision` flag: it requires the same locally simulated vehicle/zombie pair to have persistent contact and `testCollisionWithCharacter` overlap on both sides of the update bracket. Losing post-update overlap prevents a correction. Single-player continuation and prone multiplayer continuation retain the engine-reported flag requirement.

`applyImpulseFromHitObject` derives its direction from the target's position when Lua queues the correction. A hit can move the zombie between the engine collision and the correction pass, so that recomputed direction can differ from the direction of the original pedestrian impulse and leave a residual component.

Version 1.0.0 reads the engine-recorded `hitDir` components and calls public `applyImpulseGeneric` at the vehicle's current center with a positive correction scalar along that direction. If `hitDir` is unavailable or zero, it retains an explicit current-position fallback. The generic API normalizes the selected direction and stores a zero relative contact offset. The normal `hitDir` path therefore continues to oppose the original slowdown even after target movement, and both paths remain torque-free. The correction still enters the ordinary pending hit-object impulse queue on only the locally simulated vehicle.

This option applies only to a live `IsoZombie`. A prone living zombie has two separate reactions: the tunable horizontal pedestrian slowdown above and vanilla vertical impulses applied at individual wheels. The exact pending wheel values live in private `impulsesFromSquishedBodies` state. The public prone collision test both detects geometry and rewrites those slots, so calling it a second time is not a safe read or scale operation. Release-mode pure Lua has no supported way to modify only the already-queued vertical values without reflection or a class patch. Version 1.0.0 therefore leaves prone vertical wheel lift and its resulting pitch/roll torque unchanged.

## Corpses

For every contacting wheel, `testCollisionWithCorpse` queues an upward impulse at the wheel offset:

```text
vanillaWheel = 0.065 * vehicleMass * max(speedKmh, 10) / 10 * corpseSize
```

The off-center vertical impulse is what produces lift, pitch, and roll. Human and zombie corpses normally have no `corpseSize`, which means `1.0`; animal bodies may supply one.

Build 42.20 stores one pending squished-body impulse per wheel. A later collision test overwrites that slot and marks it unapplied. During client `OnTick`, after vanilla's `breakingObjects` scan, the mod temporarily uses:

```text
effectiveCorpseSize = min(originalCorpseSize, corpseMassKg * multiplier / vehicleMass)
```

and calls `testCollisionWithCorpse(body, false)`. The resulting value is:

```text
desiredWheel = 0.065 * corpseMassKg * multiplier * max(speedKmh, 10) / 10
```

This applies comparable force for a given body but produces less acceleration in a heavier vehicle. Missing human/zombie corpse weight uses the game's 100 kg character-mass reference. Invalid animal weight falls back to vanilla by skipping the rewrite.

The replacement scan preserves vanilla's engine/tow `shouldCollideWithObjects()` gate, minimum 3 km/h gate, radius, `yy`/`xx` square order, and `staticMovingObjects` order. That order matters for a corpse pile because a later body can overwrite the same wheel slot. The original `corpseSize` is restored immediately, and `false` suppresses only a duplicate run-over sound.

## Frame timing and multiplayer authority

In the audited update order, `OnTickEvenPaused` and `OnTick` bracket the snapshot and correction work while the relevant pending collision impulses can still be adjusted before their vehicle-physics step. This is why a same-update Lua correction is possible without patching a class. The initial false-to-true persistent edge is exact; the sustained animal and multiplayer standing-zombie paths remain the conservative inferences described above. Zombie direction normally comes from the engine-recorded `hitDir`; current position is used only by the explicit fallback.

The code runs only when `vehicle:isLocalPhysicSim()` is true. On a multiplayer client, that is the locally authoritative physics instance; on a dedicated server the relevant vehicle methods discard these impulse queues. Normal vehicle replication distributes the corrected motion.

## Deliberate exclusions

- Only the live-zombie horizontal slowdown is tunable; prone-living-character vertical wheel lift and its off-center torque remain vanilla.
- No damage, death, sound, vehicle-part or wheel-damage, traction, drivetrain, wall, tree, or vehicle-to-vehicle code is replaced.
- A separate `IsoDeadBody.Collision`/horizontal-reaction method exists, but normal bodies are held in `staticMovingObjects` and the normal vehicle scan calls `testCollisionWithCorpse` directly. Version 1.0.0 does not claim to correct that unproven path.
