require "DoomedRoadkillPhysics_Core"

local Core = DoomedRoadkillPhysics

local function onServerStarted()
    local actual = tostring(getCore():getVersionNumber())
    if not Core.isTargetGameVersion(actual) then
        print("[" .. Core.MOD_ID .. "] WARNING: collision correction profile "
            .. Core.TARGET_GAME_VERSION .. " does not support Project Zomboid "
            .. actual .. "; client corrections are disabled on this version.")
    else
        print("[" .. Core.MOD_ID .. "] Workshop Lua v" .. Core.MOD_VERSION
            .. " loaded on server (Project Zomboid " .. actual .. ").")
    end
end

Events.OnServerStarted.Add(onServerStarted)
