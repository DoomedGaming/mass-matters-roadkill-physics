# Mass Matters: Roadkill Physics v1.2.0

This update adds a separate `42.22/` profile for Project Zomboid 42.22 and every numeric 42.22.x patch, audited against 42.22.2. The existing `42/`, `42.21/`, and `common/` files remain byte for byte unchanged, so older players keep their existing profile from the same Workshop item.

## Changes

- Keep Workshop ID `3776615501`, Mod ID `DoomedRoadkillPhysics`, sandbox names, defaults, and save data unchanged.
- Retain the animal, corpse, and live-zombie correction algorithms. Prone living-zombie vertical wheel lift and torque remain vanilla.
- Accept `42.22` and `42.22.<digits>`, so normal future 42.22 patches load without a mod update. Keep major 42 and minor 22 locked; other major/minor versions and malformed strings disable the new profile before client physics callbacks or vectors are created.
- Preserve the earlier profiles' version bounds and behavior.

The exact JAR check identifies the engine used for the developer audit. It does not block the distributed Lua mod from loading on another 42.22 patch. See the [42.22.2 audit](compatibility-42.22.2.md).

## Validation and installation

The 42.22.2 engine audit, Lua regressions, installed-engine loader/Kahlua checks, and package integrity checks pass. All 20 existing profile/common files match their frozen hashes in source, staging, and the extracted ZIP. Original gameplay evidence applies to 42.20.0. Version 1.2.0 was published to the existing Steam Workshop item on 2026-11-11.

For an isolated test, copy the complete `DoomedRoadkillPhysics` folder from `mass-matters-roadkill-physics-v1.2.0.zip`, including all three version directories and `common/`. Verify the archive with `sha256sum -c SHA256SUMS.txt` from its directory. Avoid loading a subscribed copy and development copy together.

Use the existing [Steam Workshop item](https://steamcommunity.com/sharedfiles/filedetails/?id=3776615501). Servers retain `WorkshopItems=3776615501` and `Mods=DoomedRoadkillPhysics` with `DoLuaChecksum=true`. A normal server restart loads an update; schedule it separately from package preparation. No save migration is required.
