# Workshop staging

`workshop/` is the complete Lua-only source template. Run `scripts/package-release.sh`, then upload `dist/workshop-staging/` with the normal Project Zomboid Workshop uploader.

The descriptor is prepared for the 1.0.0 release and clearly marks the mod as tested only on Project Zomboid Build 42.20 stable. Leave `id=` empty until Steam creates the item. Record the assigned immutable numeric ID in both `workshop/workshop.txt` and the release records before any update. Do not create a replacement item after Steam assigns the ID.

Keep `visibility=private` for the initial upload and test the copy downloaded through Steam, not a local development copy. Change visibility only after the single-player, listen-server, and dedicated connected-client gates pass. The complete upload checklist is in [`docs/steam-workshop-release.md`](../docs/steam-workshop-release.md).

Server configuration uses the two different identifiers:

```ini
WorkshopItems=<numeric Steam Workshop ID>
Mods=DoomedRoadkillPhysics
DoLuaChecksum=true
```

The staged tree intentionally contains no JAR, class file, patcher, launcher, or manual installer.
