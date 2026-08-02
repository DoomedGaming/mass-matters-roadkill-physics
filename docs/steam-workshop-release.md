# Steam Workshop release checklist

This checklist prepares **Mass Matters: Roadkill Physics 1.0.0** for its first Steam Workshop publication. It does not authorize an upload by itself.

## Release identity

- Workshop title: **Mass Matters: Roadkill Physics [B42.20]**
- Release: **1.0.0**
- Project Zomboid Mod ID: `DoomedRoadkillPhysics`
- Compatibility claim: **tested only on Project Zomboid Build 42.20 stable**
- Initial Steam Workshop ID: leave `id=` empty until Steam creates the item
- Initial visibility: `private`

The Workshop item ID is permanent. Once Steam assigns it, record the same numeric ID in `workshop/workshop.txt` before packaging or uploading another update. Never make a second item merely to update the first one.

## 1. Build and inspect the upload tree

From the repository root:

```bash
PZ_GAME_JAR=/path/to/build-42.20/projectzomboid.jar ./scripts/verify.sh
./scripts/package-release.sh
sha256sum -c dist/SHA256SUMS.txt
```

Before opening the uploader, confirm:

- `release.json`, `CHANGELOG.md`, `README.md`, and `42/mod.info` all identify version 1.0.0;
- `dist/workshop-staging/workshop.txt` contains the approved public description, an empty `id=`, and `visibility=private`;
- `dist/workshop-staging/preview.png` is the intended public preview;
- the staging tree contains only normal Workshop metadata and the Lua mod—no JAR, class file, patcher, launcher, server configuration, save data, credentials, or test-server files;
- the ZIP and Workshop staging tree came from the same packaging run.

## 2. Create the private item

Copy `dist/workshop-staging/` into its own new folder under the Project Zomboid Workshop staging directory (`Zomboid/Workshop/`). Do not merge it into an existing Workshop item.

In Project Zomboid:

1. Open **Workshop**, then **Create and update items**.
2. Select the Mass Matters staging entry.
3. Review the title, preview, description, tags, and `private` visibility.
4. Accept the Steam Workshop legal agreement if Steam requires it.
5. Upload once and wait for a successful result.
6. Open the resulting Steam page and capture its numeric Workshop ID.

Immediately copy that ID into the source `workshop/workshop.txt` as `id=<numeric ID>`, then rebuild before any future upload. Keep the item private during validation.

## 3. Validate the Steam-downloaded copy

Remove or move aside the local development copy so it cannot shadow the subscribed Workshop copy. Subscribe to the private item, allow Steam to finish downloading it, and verify the installed content is the packaged 1.0.0 build.

Run these gates on Build 42.20 stable:

- single-player with a regular car and a heavy vehicle;
- live mouse or rat and live rabbit contacts;
- zombie and animal corpses under multiple wheels;
- standing live zombies at slowdown values `1.0`, `0.5`, and `0.0`;
- a prone living zombie, confirming its separate vanilla wheel lift and torque are still present as documented;
- a mid-session sandbox-option Apply;
- listen-server host and connected client;
- dedicated server with at least one connected driving client and `DoLuaChecksum=true`;
- clean client and server logs with the 1.0.0 load marker and no mod Lua errors.

Do not describe a successful server startup as collision proof. The vehicle tests must be performed by a connected client that owns the local vehicle physics simulation.

## 4. Server installation text

After Steam assigns the ID, server operators append the two different identifiers to their existing lists:

```ini
WorkshopItems=<numeric Steam Workshop ID>
Mods=DoomedRoadkillPhysics
DoLuaChecksum=true
```

`WorkshopItems=` receives the numeric Steam item ID. `Mods=` receives `DoomedRoadkillPhysics`; do not place the Workshop ID in `Mods=`. Existing saves need no migration, but a server must go through its normal restart when first loading the new mod. Do not replace unrelated entries in either semicolon-separated list.

## 5. Make it public

Only after all gates pass:

1. Verify the Steam page still points to the recorded immutable item ID.
2. Re-read the page description, especially the Build 42.20-only testing statement and prone living-zombie limitation.
3. Change the existing item's visibility from `private` to `public`.
4. Confirm the public page renders the preview, description sections, tags, and release version correctly.
5. Record the final Workshop URL and ID in the GitHub release notes and project documentation.

Later game builds require a fresh collision/API audit and gameplay test pass before changing the compatibility claim.
