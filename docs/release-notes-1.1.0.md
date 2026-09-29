# Mass Matters: Roadkill Physics v1.1.0 candidate

This update adds a separate Build 42.21 profile and preserves the existing Build 42.20 profile unchanged. Subscribers on 42.20 keep the original code; 42.21 loads the new profile from the same Workshop item.

## Changes

- Keep Workshop ID `3776615501` and Mod ID `DoomedRoadkillPhysics`.
- Preserve all sandbox keys, defaults, and existing-world data. No save migration is required.
- Retain the audited animal, corpse, and live-zombie correction algorithms.
- Enable the new profile only for runtime versions `42.21` and `42.21.0`. Unrecognized versions skip its physics corrections.
- Keep prone living-zombie vertical wheel lift and torque vanilla.

## Validation status

The 42.21 engine audit and automated formula/runtime tests pass. Real 42.21 single-player, listen-server, and connected dedicated-server collision tests remain pending. This candidate has not been published to Steam Workshop.

The preserved 42.20 profile was gameplay-tested on 42.20.0. Preserving those bytes does not certify every later 42.20 patch, earlier Build 42 release, custom vehicle, or modpack. Build 41 is not supported.

See the [compatibility audit](compatibility-42.21.md) and [gameplay matrix](test-matrix.md) for release gates.

## Installation and assets

Use the existing [Steam Workshop item](https://steamcommunity.com/sharedfiles/filedetails/?id=3776615501) after publication, or copy the complete `DoomedRoadkillPhysics` folder from the candidate ZIP for an isolated test. Servers retain their existing `WorkshopItems=3776615501` and `Mods=DoomedRoadkillPhysics` entries with `DoLuaChecksum=true`.

Candidate assets are `mass-matters-roadkill-physics-v1.1.0.zip` and `SHA256SUMS.txt`. Verify the ZIP with `sha256sum -c SHA256SUMS.txt` from the asset directory. A normal server restart is required to load an updated mod; schedule it separately from preparation and testing.
