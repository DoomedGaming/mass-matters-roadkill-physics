# Installed-game integration checks

Run from the repository root with a JDK 25 or newer compiler:

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

`LoaderProbe` calls the actual installed game's `getModVersionDirName`,
`ChooseGameInfo.readModInfo`, and `isAvailableSelf`. For each matrix row, it
substitutes the private `GameVersion` fields **inside its own fresh test JVM**.
This verifies how the installed 42.21 loader handles older/newer version values;
it does not run a 42.20 game binary. The reflected fields are never part of the
Workshop payload or mod runtime. Metadata version comparisons ignore suffixes,
so `42.21.1` is deliberately expected to pass metadata while its client
correction hooks remain disabled.

`KahluaProbe` compiles and runs the actual profile Lua using the installed game's
Kahlua compiler/VM and registers callbacks through its actual `LuaEventManager`.
The harness loads Core before providing a no-op `require`, supplies a synthetic
version accessor and an empty world, and counts real vector allocations and
event callbacks. Supported profiles register four client callbacks; unsupported
versions register zero and allocate no vectors. Supported callbacks are invoked
directly through Kahlua with an empty world to check their basic lifecycle.
The server Lua is also compiled and its separate diagnostic callback invoked.

These checks establish loader selection, metadata handling, Lua compatibility,
registration, and the fail-closed version guard. They do not simulate collisions,
Bullet physics, vehicles, animals, zombies, or multiplayer replication. The
gameplay matrix in `docs/test-matrix.md` remains separate validation.
