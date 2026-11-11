# Workshop staging

`workshop/` is the complete Lua-only source template. Run `scripts/package-release.sh` to create `dist/workshop-staging/` for the normal Project Zomboid Workshop uploader.

Version 1.2.0 is prepared as an update to the existing public [item 3776615501](https://steamcommunity.com/sharedfiles/filedetails/?id=3776615501). Keep `id=3776615501` and `visibility=public`. Do not create a second item or reuse the obsolete first-upload private workflow.

The package preserves `42/`, `42.21/`, and `common/` unchanged and adds `42.22/` for the audited 42.22.2 build. The 42.22.2 engine audit and automated checks pass; real 42.21 and 42.22.2 gameplay validation remain pending. Packaging does not upload or publish the candidate. Follow the [update checklist](../docs/steam-workshop-release.md), complete gameplay gates, and obtain upload authorization before publishing.

Server configuration uses two different identifiers:

```ini
WorkshopItems=3776615501
Mods=DoomedRoadkillPhysics
DoLuaChecksum=true
```

The staging tree contains no JAR, class file, patcher, launcher, or manual installer. Copy the complete versioned tree so older players keep their existing profile.
