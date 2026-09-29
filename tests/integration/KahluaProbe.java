import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.Event;
import zombie.Lua.LuaEventManager;
import zombie.Lua.LuaManager;

public final class KahluaProbe {
    static int vectors;
    static J2SEPlatform platform;
    static KahluaTable env;
    static KahluaThread thread;
    static void run(Path p) throws Exception {
        Object[] result = thread.pcall(LuaCompiler.loadstring(Files.readString(p), p.toString(), env), new Object[0]);
        if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(java.util.Arrays.toString(result));
    }
    public static void main(String[] args) throws Exception {
        zombie.ZomboidFileSystem.instance.setCacheDir(System.getProperty("user.home") + "/cache");
        if (!"42.21".equals(zombie.core.Core.getInstance().getVersionNumber())) {
            throw new AssertionError("This integration matrix targets the 42.21 engine");
        }
        platform = J2SEPlatform.getInstance();
        env = platform.newEnvironment();
        thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        LuaManager.platform = platform;
        LuaManager.env = env;
        LuaManager.thread = thread;
        LuaEventManager.register(platform, env);
        Path profile = Path.of(args[0]);
        KahluaTable core = platform.newTable();
        // Minimal adapters: real Kahlua and real Event.Add, but no live world.
        core.rawset("getVersionNumber", (JavaFunction)(frame, count) -> frame.push(args[1]));
        env.rawset("getCore", (JavaFunction)(frame, count) -> frame.push(core));
        env.rawset("require", (JavaFunction)(frame, count) -> 0);
        env.rawset("print", (JavaFunction)(frame, count) -> { System.out.println("LUA " + frame.get(0)); return 0; });
        env.rawset("getCell", (JavaFunction)(frame, count) -> frame.push((Object)null));
        env.rawset("isClient", (JavaFunction)(frame, count) -> frame.push(Boolean.FALSE));
        KahluaTable v2 = platform.newTable();
        v2.rawset("new", (JavaFunction)(frame, count) -> { vectors++; return frame.push(new zombie.iso.Vector2()); });
        env.rawset("Vector2", v2);
        KahluaTable v3 = platform.newTable();
        v3.rawset("new", (JavaFunction)(frame, count) -> { vectors++; return frame.push(new org.joml.Vector3f()); });
        env.rawset("Vector3f", v3);
        run(profile.resolve("media/lua/shared/DoomedRoadkillPhysics_Core.lua"));
        run(profile.resolve("media/lua/client/DoomedRoadkillPhysics_Client.lua"));
        ArrayList<Event> events = new ArrayList<>();
        HashMap<String, Event> byName = new HashMap<>();
        LuaEventManager.getEvents(events, byName);
        int callbacks = events.stream().mapToInt(e -> e.callbacks.size()).sum();
        System.out.println("KAHLUA version=" + args[1] + " callbacks=" + callbacks + " vectors=" + vectors);
        boolean supported = Boolean.parseBoolean(args[2]);
        if (callbacks != (supported ? 4 : 0) || vectors != (supported ? 2 : 0)) throw new AssertionError("Incorrect client startup gate");
        if (supported) {
            for (String name : new String[]{"OnGameStart", "OnTickEvenPaused", "OnTick", "OnCharacterDeath"}) {
                Event event = byName.get(name);
                if (event == null || event.callbacks.size() != 1) throw new AssertionError("Missing " + name);
                Object[] result = thread.pcall(event.callbacks.get(0), new Object[]{Double.valueOf(1)});
                if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(name + ": " + java.util.Arrays.toString(result));
            }
            System.out.println("KAHLUA empty-world callbacks passed");
        }
        run(profile.resolve("media/lua/server/DoomedRoadkillPhysics_Server.lua"));
        Event serverStarted = byName.get("OnServerStarted");
        if (serverStarted == null || serverStarted.callbacks.size() != 1) {
            throw new AssertionError("Missing server diagnostic callback");
        }
        Object[] serverResult = thread.pcall(serverStarted.callbacks.get(0), new Object[0]);
        if (!Boolean.TRUE.equals(serverResult[0])) {
            throw new AssertionError("Server diagnostic: " + java.util.Arrays.toString(serverResult));
        }
        System.out.println("KAHLUA server diagnostic callback passed");
    }
}
