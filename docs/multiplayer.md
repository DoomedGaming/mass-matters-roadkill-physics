# Multiplayer deployment

## Normal Workshop installation

Use the existing [Workshop item 3776615501](https://steamcommunity.com/sharedfiles/filedetails/?id=3776615501). Existing installations keep the same identifiers. For a new installation, append them to the server's existing semicolon-separated settings:

```ini
WorkshopItems=3776615501
Mods=DoomedRoadkillPhysics
DoLuaChecksum=true
```

Do not put `DoomedRoadkillPhysics` in `WorkshopItems=` and do not put the numeric Workshop ID in `Mods=`. Preserve every unrelated existing entry and its ordering.

The server and all clients use the same ordinary Workshop package. There is no JAR, class overlay, launcher, patcher, post-download executable, or manual game-directory step. A normal server restart is still required when enabling or updating a server mod.

An existing world does not require save migration. If its sandbox data predates version 0.3.0 and has no `ZombieImpulseMultiplier`, the mod uses `1.0`, preserving vanilla live-zombie forward slowdown until the administrator explicitly tunes it.

## Versioned package

Version 1.2.0 preserves `42/`, `42.21/`, and `common/` unchanged and adds `42.22/` for the audited 42.22.2 build. The game selects the profile appropriate to its version. Keep the full package on server and clients; do not distribute only the new directory.

Original connected-driving evidence applies to 42.20.0. Connected gameplay, authority handoffs, latency behavior, and anticheat checks remain pending for 42.21 and 42.22.2. See the [42.22.2 compatibility audit](compatibility-42.22.2.md) and the historical [42.21 audit](compatibility-42.21.md).

## Authority model

The audited Build 42.20, 42.21, and 42.22.2 engines simulate an actively controlled multiplayer vehicle on an authorized client. The mod's `OnTickEvenPaused` snapshot, `OnTick` correction pass, and all animal, live-zombie, and corpse corrections therefore run only when `vehicle:isLocalPhysicSim()` is true:

- the current vehicle authority queues the corrected impulse;
- the dedicated server loads and checks the Lua package but does not try to run client physics;
- normal vehicle packets replicate the resulting motion to the server, passengers, and observers.

No custom networking or compatibility handshake is required. Keep `DoLuaChecksum=true` so clients use the server's Lua content rather than an altered local copy.

The initial live-animal or live-zombie hit uses an exact false-to-true persistent-contact edge. Sustained overlap is intentionally more conservative. The audited engines' client success path does not reliably set `isVehicleCollision`, so the animal path requires pre/post-update overlap and infers whether main plus fixed or fixed-only correction was queued from the animal's pre-update `AnimalFalldownState`. The standing-zombie path uses the same pre/post-overlap fallback while retaining the engine flag requirement for prone continuation. These are not claimed as exact repeated-hit detectors and must be tested with real clients and delayed server state.

All profiles apply the live-zombie horizontal correction through public `applyImpulseGeneric` at the locally simulated vehicle's center. The correction uses the engine-recorded `hitDir` when available and falls back to current vehicle/target position otherwise. Target movement between collision and `OnTick` therefore cannot redirect the normal `hitDir` path, and the zero relative offset remains torque-free. This remains ordinary client-authoritative vehicle physics replicated through normal vehicle packets; it adds no custom network message.

Prone-living-zombie vertical wheel lift and its off-center torque remain vanilla. Their exact pending values are private per-wheel state, and the only public geometry call would also rewrite that state. The Workshop build does not use reflection, patch a class, or repeat the side-effectful prone collision call to scale it.

Applying `ZombieImpulseMultiplier` from the multiplayer sandbox-options UI is live. The mod rereads the broadcast option value every pre-tick. Live Apply was verified during 42.20.0 development and must be repeated in the 42.21 and 42.22.2 gameplay passes. The startup marker is only an initial snapshot; the client prints a separate line when the value changes and another when the first correction for that value is queued.

## What package loading proves

A dedicated server reaching `SERVER STARTED` with the mod enabled proves that the package layout, server Lua, and checksum stage load. It does not prove collision authority, impulse timing, or absence of multiplayer correction snapback. Those require at least one connected driver and observer.

## Multiplayer release gates

Test on both a listen server and a dedicated server:

- each client takes a turn driving while another client observes;
- enter, exit, reconnect, change seats, and hand vehicle authority to the other player;
- repeat sustained live-animal overlap before and after delayed `AnimalFalldownState`/server-state arrival under normal and elevated latency;
- let the persistent-contact window expire, then verify a later hit of the same animal forms a fresh exact edge;
- test live-zombie forward slowdown at multipliers `1.0`, `0.5`, and `0.0`, plus prone-living-zombie wheel lift at each setting;
- test angled standing-zombie hits with substantial target displacement under normal and elevated latency, checking that correction direction remains aligned with the engine hit direction;
- repeat representative corpse contacts under normal and elevated latency;
- test a passenger, a trailer/semi combination, reverse motion, slopes, and corpse piles;
- compare driver, observer, and server position/speed for rubber-banding or anticheat warnings;
- confirm no duplicate hit, damage, death, or sound occurs.

Version 1.0.0 has been exercised with a connected driver on the isolated Build 42.20 dedicated test server. Do not treat that as proof for every authority handoff, latency condition, custom vehicle, or modpack; use the gates above when validating a production server.
