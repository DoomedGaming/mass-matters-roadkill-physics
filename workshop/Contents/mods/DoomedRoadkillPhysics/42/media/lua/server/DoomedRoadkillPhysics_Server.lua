require "DoomedRoadkillPhysics_Core"

local Core = DoomedRoadkillPhysics

local function onServerStarted()
    local actual = tostring(getCore():getVersionNumber())
    if not Core.isTargetGameVersion(actual) then
        print("[" .. Core.MOD_ID .. "] WARNING: server is Project Zomboid "
            .. actual .. "; this mod targets " .. Core.TARGET_GAME_VERSION .. ".")
    else
        print("[" .. Core.MOD_ID .. "] Workshop Lua v" .. Core.MOD_VERSION
            .. " loaded on server (Project Zomboid " .. actual .. ").")
    end
end

Events.OnServerStarted.Add(onServerStarted)
