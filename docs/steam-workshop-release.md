# Steam Workshop update checklist

Prepare **Mass Matters: Roadkill Physics 1.2.0** as an update to the existing public item. This checklist does not authorize an upload.

## Release identity

- Existing item: [3776615501](https://steamcommunity.com/sharedfiles/filedetails/?id=3776615501)
- Mod ID: `DoomedRoadkillPhysics`
- Candidate title: **Mass Matters: Roadkill Physics [B42.20 / B42.21 / B42.22.2]**
- Visibility: preserve `public`
- Package version: `1.2.0`; the unchanged `42/` and `42.21/` profiles retain `1.0.0` and `1.1.0` respectively

The source descriptor once contained an empty ID and `private` visibility from first-publication staging. Those values are obsolete. The existing public item's ID, application, creator, and visibility were checked during the earlier 1.1.0 preparation. That historical check does not establish the item's current state. Re-query it immediately before upload.

## 1. Verify and package

From the repository root:

```bash
./scripts/verify.sh /path/to/42.20/projectzomboid.jar /path/to/42.21/projectzomboid.jar /path/to/42.22.2/projectzomboid.jar
./scripts/package-release.sh
sha256sum -c dist/SHA256SUMS.txt
```

`PZ_GAME_JAR=/path/to/projectzomboid.jar ./scripts/verify.sh` remains available for a single engine audit. Without JAR paths, the verifier explicitly skips engine checks; do not record that run as engine validation.

Before opening the uploader, confirm:

- the `42/` and `common/` files match the frozen release 1.0.0 manifest, and `42.21/` matches its preserved-profile manifest;
- `42.22/mod.info`, release metadata, and current release notes identify the new 42.22.2 profile;
- `dist/workshop-staging/workshop.txt` has `id=3776615501` and `visibility=public`;
- title, preview, description, tags, and compatibility statements describe the completed validation accurately;
- the staging tree contains ordinary metadata and Lua content, with no Java binary, game file, server configuration, save, credential, or test-server data;
- the ZIP and Workshop staging tree came from the same packaging run.

## 2. Complete gameplay validation

Use isolated saves and test servers. Run the [gameplay matrix](test-matrix.md) on 42.22.2, including a connected driver and observer, normal and elevated latency, authority handoff, live sandbox Apply, and clean logs. Check preserved 42.20 and 42.21 package selection and behavior where those engines are available. The earlier 42.21 gameplay pass remains pending.

Record the exact game build, loaded profile, test cases, and outcomes in the [42.22.2 compatibility audit](compatibility-42.22.2.md). Only then change the candidate's pending-gameplay statements. A startup marker, API check, or mock test is not collision proof.

## 3. Upload to the existing item

After upload authorization:

1. Re-query item `3776615501`, confirm it is this mod for Project Zomboid and that visibility is still public.
2. Copy the complete verified staging tree to the game's Workshop staging directory. Ensure its descriptor still has `id=3776615501`.
3. Open **Workshop**, then **Create and update items**, and select this existing item's staging entry.
4. Review ID, title, preview, description, tags, release notes, and public visibility.
5. Update the existing item once and wait for Steam to report completion. Do not create a second item or switch the existing item to private.

## 4. Verify the distributed update

Allow Steam to finish downloading the update. Keep local development copies from shadowing the subscribed copy. Verify downloaded files and hashes against the packaged `42/`, `42.21/`, `42.22/`, and `common/` trees.

Confirm 42.20 and 42.21 select their preserved profiles and 42.22.2 selects the new profile. Repeat representative collision checks through the normal Steam-distributed multiplayer package with `DoLuaChecksum=true`. Check client/server logs and verify the existing public page renders the intended description, preview, version, and compatibility statement.

Record the Workshop update result and downloaded-file evidence. Do not claim publication solely from an uploader success message.

## Server configuration

Existing users retain their entries. New users append these identifiers to the current lists:

```ini
WorkshopItems=3776615501
Mods=DoomedRoadkillPhysics
DoLuaChecksum=true
```

Preserve unrelated entries and ordering. A normal server restart loads the updated mod; preparation does not authorize restarting a live server. Existing worlds require no migration.
