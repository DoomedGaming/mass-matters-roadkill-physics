# Mass Matters: Roadkill Physics v1.2.0

This update adds a separate `42.22/` profile for the audited Project Zomboid 42.22.2 build. The existing `42/`, `42.21/`, and `common/` files remain byte for byte unchanged, so older players keep their existing profile from the same Workshop item.

## Changes

- Keep Workshop ID `3776615501`, Mod ID `DoomedRoadkillPhysics`, sandbox names, defaults, and save data unchanged.
- Retain the animal, corpse, and live-zombie correction algorithms. Prone living-zombie vertical wheel lift and torque remain vanilla.
- Accept `42.22`, the audited client's runtime string, and explicit `42.22.2`. Other strings disable the new profile's client corrections before physics callbacks or vectors are created.
- Preserve the earlier profiles' version bounds and behavior.

The runtime guard cannot distinguish another binary that also reports `42.22`. The exact JAR check is part of the developer verifier, not the distributed Lua mod. See the [42.22.2 audit](compatibility-42.22.2.md).

## Validation and installation

The 42.22.2 engine audit, Lua regressions, installed-engine loader/Kahlua checks, and package integrity checks pass. All 20 existing profile/common files match their frozen hashes in source, staging, and the extracted ZIP. Original gameplay evidence applies to 42.20.0. Version 1.2.0 is prepared for upload and has not yet been published to Steam Workshop.

For an isolated test, copy the complete `DoomedRoadkillPhysics` folder from `mass-matters-roadkill-physics-v1.2.0.zip`, including all three version directories and `common/`. Verify the archive with `sha256sum -c SHA256SUMS.txt` from its directory. Avoid loading a subscribed copy and development copy together.

After publication, use the existing [Steam Workshop item](https://steamcommunity.com/sharedfiles/filedetails/?id=3776615501). Servers retain `WorkshopItems=3776615501` and `Mods=DoomedRoadkillPhysics` with `DoLuaChecksum=true`. A normal server restart loads an update; schedule it separately from package preparation. No save migration is required.
