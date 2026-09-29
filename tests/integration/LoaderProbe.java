import java.lang.reflect.Field;
import java.nio.file.Path;
import zombie.ZomboidFileSystem;
import zombie.core.Core;
import zombie.core.GameVersion;
import zombie.gameStates.ChooseGameInfo;

public final class LoaderProbe {
    public static void main(String[] args) throws Exception {
        ZomboidFileSystem.instance.setCacheDir(System.getProperty("user.home") + "/cache");
        ZomboidFileSystem.instance.init();
        GameVersion actual = Core.getInstance().getGameVersion();
        String shippedVersion = actual.toString();
        if (!"42.21".equals(shippedVersion)) {
            throw new AssertionError("This integration matrix targets the 42.21 engine, got " + shippedVersion);
        }
        GameVersion simulated = GameVersion.parse(args[1]);
        // Test-process override only. No game file or Workshop code is altered.
        for (String name : new String[]{"major", "minor", "suffix", "string"}) {
            Field f = GameVersion.class.getDeclaredField(name);
            f.setAccessible(true);
            f.set(actual, f.get(simulated));
        }
        String selected = ZomboidFileSystem.instance.getModVersionDirName(Path.of(args[0]));
        System.out.println("LOADER shipped=" + shippedVersion + " simulated=" + actual + " selected=" + selected);
        ChooseGameInfo.Mod mod = ChooseGameInfo.readModInfo(args[0]);
        if (mod == null) throw new AssertionError("Metadata did not load");
        if (!"DoomedRoadkillPhysics".equals(mod.getId())) throw new AssertionError("Wrong mod ID");
        if (!Path.of(mod.getVersionDir()).getFileName().toString().equals(selected)) {
            throw new AssertionError("Metadata did not use the selected directory");
        }
        System.out.println("METADATA id=" + mod.getId() + " version=" + mod.getModVersion() + " directory=" + mod.getVersionDir() + " min=" + mod.getVersionMin() + " max=" + mod.getVersionMax() + " available=" + mod.isAvailableSelf());
        if (args.length > 2 && !selected.equals(args[2])) throw new AssertionError("Wrong profile: " + selected);
        if (args.length > 3 && mod.isAvailableSelf() != Boolean.parseBoolean(args[3])) throw new AssertionError("Wrong availability");
    }
}
