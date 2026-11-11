# Installed-game integration checks

Run from the repository root with a JDK 25 or newer compiler and an audited
42.21 or 42.22.2 game JAR:

```bash
PZ_GAME_JAR=/path/to/ProjectZomboid/projectzomboid/projectzomboid.jar \
  bash tests/integration/run.sh
```

The runner uses the game's adjacent `jre64/bin/java` and `stdlib.lua`. Override
`JAVA`, `JAVAC`, or `PZ_STDLIB_LUA` if those are stored elsewhere. It creates a
temporary work directory, Java home property, and game cache under `/tmp`, then
removes only that temporary directory. It reads the installed game files and the
repository payload without starting the game, contacting a server, or using the
normal Zomboid user directory.

The runner matches the JAR's SHA-256 to `release.json`. Each probe also asserts
the actual engine version before substituting a test value. The audited 42.22.2
client reports `42.22` through Core, so that is the expected shipped string for
that binary. The new profile accepts `42.22` and the explicit `42.22.2` alias.
This runtime string cannot distinguish other binaries reporting `42.22`; the
audit applies only to the recorded binary hash.

`LoaderProbe` calls the actual installed game's `getModVersionDirName`,
`ChooseGameInfo.readModInfo`, and `isAvailableSelf`. For each matrix row, it
substitutes the private `GameVersion` fields **inside its own fresh test JVM**.
The 14 cases verify how the supplied engine's loader handles older/newer version
values; they do not execute those older game binaries. The reflected fields are
never part of the Workshop payload or mod runtime. Metadata version comparisons
ignore suffixes, so `42.21.1`, `42.22.0`, `42.22.1`, and `42.22.3` deliberately
pass metadata while their selected profile's client hooks remain disabled. The
matrix also checks that 42.20 keeps `42/`, 42.21 keeps `42.21/`, and 42.22 selects
`42.22/`. Later minor versions fail the metadata bounds.

`KahluaProbe` compiles and runs the actual profile Lua using the installed game's
Kahlua compiler/VM and registers callbacks through its actual `LuaEventManager`.
The harness loads Core before providing a no-op `require`, supplies a synthetic
version accessor and an empty world, and counts real vector allocations and
event callbacks. Supported profiles register four client callbacks; unsupported
versions register zero and allocate no vectors. Supported callbacks are invoked
directly through Kahlua with an empty world to check their basic lifecycle.
The server Lua is also compiled and its separate diagnostic callback invoked.
The 22 cases cover all three profiles, both supported 42.22 strings, earlier
explicit patch strings, future patch strings, and malformed aliases.

These checks establish loader selection, metadata handling, Lua compatibility,
registration, and the fail-closed version guard. They do not simulate collisions,
Bullet physics, vehicles, animals, zombies, or multiplayer replication. The
gameplay matrix in `docs/test-matrix.md` remains separate validation.
