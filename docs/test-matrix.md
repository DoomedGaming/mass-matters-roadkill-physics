# Gameplay verification matrix

Use a disposable save cloned from one fixed baseline. Run vanilla and modded passes with the same vehicle condition, tire pressure, fuel, cargo, target, approach line, weather, and commanded speed. Record video or telemetry from immediately before contact until the vehicle settles.

Version 1.2.0 preserves the 42.20 and 42.21 profiles and adds a separate `42.22/` profile for 42.22 and every numeric 42.22.x patch. Run the new profile on the 42.22 patch being evaluated and repeat preserved-profile regressions on 42.20 and 42.21 where those engines are available. Record exact engine and profile versions with every result. See the [42.22.2 compatibility audit](compatibility-42.22.2.md).

## Automated preflight

```bash
./scripts/verify.sh /path/to/42.20/projectzomboid.jar /path/to/42.21/projectzomboid.jar /path/to/42.22.2/projectzomboid.jar
./scripts/package-release.sh
```

Preflight must pass Lua syntax, formula tests, mocked client/server runtime tests, the frozen legacy-file manifest, profile-metadata and runtime-guard checks, supplied exact JAR/API checks, image dimensions, JSON parsing, a no-Java package scan, ZIP integrity, and SHA-256 verification.

## Version and upgrade checks

- Confirm 42.20 selects the unchanged `42/` profile, 42.21 selects the unchanged `42.21/` profile, and 42.22.x selects `42.22/`, all with the same Mod ID and sandbox values.
- Start a copied existing world with the new package. Confirm no settings or saved progress change merely from the mod update.
- Confirm the new profile accepts `42.22` and any numeric patch such as `42.22.0`, `42.22.1`, `42.22.2`, `42.22.3`, `42.22.20`, or `42.22.999999`. Other major/minor versions such as `42.23.0` and `43.0.0`, and malformed strings, must register no client physics hooks and queue no correction. Record the audited JAR identity separately from this loading policy. The preserved 42.21 profile still accepts `42.21` and `42.21.0`.
- After publication, repeat profile-selection and checksum checks with Steam-downloaded files rather than a local development copy.

## Single-player matrix

| Vehicle | Live targets | Ground targets |
| --- | --- | --- |
| Compact car | mouse, rat, live zombie, larger animal | one zombie corpse, five-corpse pile, small and large animal corpse |
| Pickup | mouse, rat, live zombie, larger animal | one zombie corpse, five-corpse pile, small and large animal corpse |
| Semi or heaviest available truck | mouse, rat, live zombie, larger animal | one zombie corpse, five-corpse pile, small and large animal corpse |

Run centered and wheel-offset contacts at approximately 10, 30, 60, and 90 km/h where safe. Add reverse, angled contact, a slope, a body beside a wall, engine-on versus engine-off coasting, a trailer, and more than one body under the same wheel.

For live animals, include a sustained overlap both before and after the transition to `AnimalFalldownState`, then separate from and re-contact the same animal. Repeat with normal and deliberately elevated network latency so delayed server state exercises the conservative pre/post-overlap inference. For live zombies, repeat the same controlled approach with `ZombieImpulseMultiplier` at `1.0`, `0.5`, and `0.0`, including a mid-session Apply, continued standing overlap, clean separation/re-contact, and a prone living zombie at every setting. Add angled hits where the zombie slides or is displaced substantially between engine contact and the correction pass; include both sides of the vehicle, reverse, and the highest safe test speed.

## Record

- speed immediately before and after contact;
- lateral velocity and heading/yaw change across live-zombie contact;
- peak vertical displacement, pitch, and roll;
- time until every wheel settles;
- vehicle-part condition before and after;
- target damage/death result;
- hit and run-over sounds;
- duplicate hit events or repeated correction;
- console errors, the `DoomedRoadkillPhysics` startup line, the live multiplier-change line, and the first-correction detector line.

## Provisional gameplay criteria

- A mouse or rat cannot dead-stop a roadworthy moving vehicle.
- One human/zombie corpse cannot launch or roll any tested roadworthy vehicle.
- A semi accelerates and rotates less than a compact car from the same corpse contact.
- Larger live animals remain more noticeable than mice and rats, and no corrected reaction exceeds vanilla.
- Sustained animal contact does not reintroduce the mass-derived or fixed `+1` slowdown while pre-state is not `AnimalFalldownState`, does not reintroduce the fixed component after that transition, and never over-corrects into forward acceleration.
- The same animal is corrected again after the engine's persistent-contact window expires and a later impact forms a new edge.
- Live-zombie forward slowdown matches vanilla at `1.0`, is approximately halved at `0.5`, and is removed at `0.0` without adding forward acceleration; a mid-session Apply is reflected immediately.
- Angled or fast live-zombie hits with an engine-recorded `hitDir` do not retain a residual correction caused by target movement, and the centered horizontal correction adds no new yaw, pitch, or roll torque.
- Prone-living-zombie vertical wheel lift and off-center torque, walls, trees, drivetrain, traction, target damage, and vehicle-part outcomes remain consistent with the vanilla control at every zombie setting.
- No duplicate sound, reverse launch, stale correction, or unintended repeated force occurs.
- Engine-off coasting does not gain a corpse impulse that vanilla would not have queued.

Tune numerical speed-loss and pitch/roll thresholds only after repeatable baseline captures; do not choose a public claim from a single run.

## Multiplayer matrix

After single-player passes, repeat representative cases on a listen server and dedicated server with two clients:

- driver A with client B observing;
- driver B after a clean vehicle handoff;
- passenger-to-driver seat switch;
- disconnect/reconnect and re-entry;
- elevated latency;
- sustained live-animal overlap across delayed `AnimalFalldownState`/server-state arrival, followed by a clean later re-contact;
- all three live-zombie tuning points;
- angled standing-zombie hits with visible target displacement under normal and elevated latency;
- a prone living zombie at every zombie tuning point;
- semi/trailer and corpse pile;
- engine-on and engine-off contacts.

Driver, observer, and server must converge without rubber-banding, speed-anticheat warnings, duplicate sounds, duplicate damage, or a second correction after authority transfer. A headless server load by itself is not multiplayer collision proof.
