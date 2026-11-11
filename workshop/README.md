# Workshop staging

`workshop/` is the complete Lua-only source template. Run `scripts/package-release.sh` to create `dist/workshop-staging/` for the normal Project Zomboid Workshop uploader.

Version 1.2.0 was published on 2026-11-11 as an update to the existing public [item 3776615501](https://steamcommunity.com/sharedfiles/filedetails/?id=3776615501). Keep `id=3776615501` and `visibility=public`. Do not create a second item or reuse the obsolete first-upload private workflow.

The package preserves `42/`, `42.21/`, and `common/` unchanged and adds `42.22/` for 42.22 and every numeric 42.22.x patch. Normal 42.22 patch updates load without a mod update while major 42 and minor 22 remain locked. The 42.22.2 engine audit and automated checks pass. The packaging script creates local release files; it does not upload them. Follow the [update checklist](../docs/steam-workshop-release.md) for future Workshop updates.

Server configuration uses two different identifiers:

```ini
WorkshopItems=3776615501
Mods=DoomedRoadkillPhysics
DoLuaChecksum=true
```

The staging tree contains no JAR, class file, patcher, launcher, or manual installer. Copy the complete versioned tree so older players keep their existing profile.
