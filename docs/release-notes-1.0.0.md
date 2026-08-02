# Mass Matters: Roadkill Physics v1.0.0 (Build 42.20)

First public release of Mass Matters: Roadkill Physics.

Tiny animals should not stop a car, and a corpse should not launch a truck. This pure-Lua mod makes vehicle reactions to live animals and corpses depend on body mass instead of producing disproportionate reactions from vehicle mass. It also adds independent tuning for the horizontal slowdown caused by live-zombie impacts.

## Highlights

- Mass-aware reactions for mice, rats, rabbits, and other live animals.
- Mass-aware corpse wheel reactions for regular cars through heavy trucks.
- Configurable live-zombie horizontal slowdown.
- Pure Steam Workshop Lua package: no patcher, launcher, Java overlay, or modified game files.
- Single-player and multiplayer support through normal vehicle authority and synchronization.
- Existing worlds require no save migration.
- Vanilla damage, sounds, vehicle-part condition, traction, drivetrain, wall/tree impacts, and vehicle-to-vehicle collisions remain unchanged.

## Compatibility

**Tested only on Project Zomboid Build 42.20 stable** (Steam build `24449119`). Later builds are not supported until their collision physics and public APIs have been re-audited.

## Known limitation

The zombie option scales the targeted horizontal pedestrian impulse. Vertical per-wheel lift and torque from driving over a prone living zombie remain vanilla because Build 42.20 keeps those pending forces private from release-mode Lua. A pile of prone living zombies may therefore still lift or slow a vehicle.

## Server installation

After the Steam Workshop item is published, add its numeric item ID to `WorkshopItems=` and add the internal Mod ID to:

```ini
Mods=DoomedRoadkillPhysics
DoLuaChecksum=true
```

A normal server restart is required when adding or updating the mod. Existing worlds require no migration.

## Release assets

- `mass-matters-roadkill-physics-v1.0.0.zip`
- `SHA256SUMS.txt`

The ZIP contains the Lua-only Workshop source tree, manual-install files, license, and release documentation. Verify it with `sha256sum -c SHA256SUMS.txt`.
